package com.careersync.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.util.regex.Pattern

class UpiNotificationService : NotificationListenerService() {

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    companion object {
        private val UPI_PACKAGES = mapOf(
            "com.google.android.apps.nbu.paisa.user" to "GPay",
            "com.phonepe.app"                        to "PhonePe",
            "net.one97.paytm"                        to "Paytm",
            "in.org.npci.upiapp"                     to "BHIM",
            "in.amazon.mShop.android.shopping"       to "AmazonPay",
            "com.google.android.apps.messaging"      to "SMS",
            "com.android.mms"                        to "SMS",
            "com.samsung.android.messaging"          to "SMS",
            "com.sec.android.app.messaging"          to "SMS",
            "com.hmdglobal.messages"                 to "SMS",
            "com.oneplus.sms"                        to "SMS",
            "com.oneplus.mms"                        to "SMS",
            "com.coloros.mms"                        to "SMS",
            "com.oppo.im"                            to "SMS",
            "com.realme.im"                          to "SMS",
            "com.xiaomi.mms"                         to "SMS",
            "com.huawei.message"                     to "SMS",
            "com.android.messaging"                  to "SMS"
        )

        private val AMOUNT_PATTERN = Pattern.compile(
            "(?:Rs\\.?|INR|₹)\\s*([\\d,]+(?:\\.\\d{1,2})?)", Pattern.CASE_INSENSITIVE
        )
        
        private val PAYEE_PATTERN = Pattern.compile(
            "(?:to|paid to|payment to|spent at|spent on|transfer to|towards|at|info[:\\s]+)\\s+([\\w\\s@.\\-_&]+?)(?:\\s+on|\\s+via|\\s+ref|\\s+upi|\\s+linked|\\s+was|\\s+is|\\s+of|\\s+using|\\s+txn|\\s+transaction|\\s+ending|\\s+bal|\\s+balance|\\s+avail|\\s*\\d|\$)",
            Pattern.CASE_INSENSITIVE
        )
        
        private val REF_PATTERN = Pattern.compile(
            "(?:ref|upi ref|txn|transaction id)(?:\\s+no\\.?)?[:\\s#]+([A-Z0-9]+)",
            Pattern.CASE_INSENSITIVE
        )
        private val BALANCE_PATTERN = Pattern.compile(
            "(?:bal|balance|avail\\s+bal|available\\s+bal|available\\s+balance|avbl\\s+bal|ledger\\s+bal|net\\s+bal|effective\\s+bal)[:\\s#]*(?:Rs\\.?|INR|₹)?\\s*[\\d,]+(?:\\.\\d{1,2})?",
            Pattern.CASE_INSENSITIVE
        )

        var methodChannel: MethodChannel? = null
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        logDebug("Notification service disconnected.")
        serviceScope.cancel()
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        logDebug("Notification service connected and listening.")
    }

    private fun logDebug(message: String) {
        android.util.Log.d("UpiTracker", message)
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val logsJson = prefs.getString("flutter.debug_logs", "[]")
            val jsonArray = JSONArray(logsJson)
            val newLog = JSONObject().apply {
                put("timestamp", System.currentTimeMillis())
                put("message", message)
            }
            if (jsonArray.length() >= 80) {
                jsonArray.remove(0)
            }
            jsonArray.put(newLog)
            prefs.edit().putString("flutter.debug_logs", jsonArray.toString()).apply()
        } catch (e: Exception) {
            android.util.Log.e("UpiTracker", "Failed to write debug log: ${e.message}")
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName
        val appName = UPI_PACKAGES[packageName]
        
        if (appName == null) {
            return
        }

        val extras = sbn.notification.extras
        
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""
        
        val textLines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
        val linesJoined = textLines?.joinToString(" ") { it.toString() } ?: ""

        val full = "$title $text $bigText $subText $linesJoined"

        logDebug("New message from $appName ($packageName): '$full'")

        val parsed = parseUpi(full, appName, sbn.postTime)
        if (parsed == null) {
            logDebug("Notification ignored: Not matching transaction patterns or is an incoming/OTP/mandate notification.")
            return
        }

        logDebug("Successfully parsed transaction: $parsed")

        // Send to Flutter UI on main thread
        CoroutineScope(Dispatchers.Main).launch {
            if (methodChannel != null) {
                methodChannel?.invokeMethod("onExpense", parsed)
                logDebug("Sent transaction to active Flutter method channel.")
            } else {
                logDebug("Flutter method channel is currently offline.")
            }
        }

        // POST to backend on IO thread using class-level scope
        serviceScope.launch {
            postToBackend(parsed)
        }

        // Show transaction alert notification if enabled
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val enabledAlerts = prefs.getBoolean("flutter.enable_notifications", true)
            if (enabledAlerts) {
                val payee = parsed["payee"] as? String ?: "Unknown"
                val amount = parsed["amount"] as? Double ?: 0.0
                val category = parsed["category"] as? String ?: "Other"
                showNotification(payee, amount, category)
            }
        } catch (e: Exception) {
            logDebug("Failed checking notification settings: ${e.message}")
        }
    }

    private fun showNotification(payee: String, amount: Double, category: String) {
        try {
            val context = applicationContext
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "upi_tracker_alerts"

            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "Transaction Alerts",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "Alerts for automatically tracked transactions"
                }
                notificationManager.createNotificationChannel(channel)
            }

            var budgetLimitText = "No budget limit set"
            try {
                val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                val budgetsJson = prefs.getString("flutter.budgets", null)
                if (budgetsJson != null) {
                    val jsonObject = JSONObject(budgetsJson)
                    if (jsonObject.has(category)) {
                        val limit = jsonObject.getDouble(category)
                        budgetLimitText = "Limit: ₹${String.format("%.2f", limit)}"
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("UpiTracker", "Failed to parse budgets: ${e.message}")
            }

            val builder = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                android.app.Notification.Builder(context, channelId)
            } else {
                @Suppress("DEPRECATION")
                android.app.Notification.Builder(context)
            }

            val iconId = context.resources.getIdentifier("launcher_icon", "mipmap", context.packageName)
            val smallIcon = if (iconId != 0) iconId else android.R.drawable.ic_dialog_info

            builder.setSmallIcon(smallIcon)
                .setContentTitle("Spent ₹${String.format("%.2f", amount)}")
                .setContentText("Paid to $payee • $category")
                .setStyle(android.app.Notification.BigTextStyle()
                    .bigText("Paid to: $payee\nCategory: $category\nBudget $budgetLimitText"))
                .setAutoCancel(true)

            // Trigger notification
            val notificationId = (payee.hashCode() + amount.hashCode() + System.currentTimeMillis().hashCode())
            notificationManager.notify(notificationId, builder.build())
        } catch (e: Exception) {
            logDebug("Failed to show alert notification: ${e.message}")
        }
    }

    private fun parseUpi(text: String, appName: String, postTime: Long): Map<String, Any>? {
        val lowerText = text.lowercase()

        // Filter out OTP/Verification messages
        val isOtp = lowerText.contains("otp") ||
                lowerText.contains("verification code") ||
                lowerText.contains("one time password") ||
                lowerText.contains("verification pin") ||
                lowerText.contains("code to verify") ||
                lowerText.contains("securesms") ||
                lowerText.contains("verify transaction")

        if (isOtp) {
            logDebug("Filtered out OTP/Verification notification.")
            return null
        }

        // Determine transaction type
        val type = when {
            lowerText.contains("autopay cancelled") ||
            lowerText.contains("cancelled your autopay") ||
            lowerText.contains("mandate is successfully revoked") ||
            lowerText.contains("mandate revoked") ||
            lowerText.contains("autopay revoked") -> "autopay_cancelled"

            lowerText.contains("autopay created") ||
            lowerText.contains("mandate successfully created") ||
            lowerText.contains("mandate created") ||
            lowerText.contains("autopay set up") ||
            lowerText.contains("mandate set up") -> "autopay_created"

            lowerText.contains("received") ||
            lowerText.contains("refund") ||
            lowerText.contains("deposited") ||
            lowerText.contains("added") ||
            lowerText.contains("paid you") ||
            lowerText.contains("payment from") ||
            lowerText.contains("credited to") ||
            (lowerText.contains("credited") && 
             !lowerText.contains("debited") && 
             !lowerText.contains("paid") && 
             !lowerText.contains("sent")) -> "credit"

            else -> "debit"
        }

        val cleanText = BALANCE_PATTERN.matcher(text).replaceAll("")

        var amount = 0.0
        if (type != "autopay_cancelled") {
            val amountMatcher = AMOUNT_PATTERN.matcher(cleanText)
            if (!amountMatcher.find()) {
                logDebug("Amount extraction failed for text: '$cleanText'")
                return null
            }
            amount = amountMatcher.group(1)?.replace(",", "")?.toDoubleOrNull() ?: return null
            if (amount <= 0) {
                logDebug("Extracted amount is zero or negative: $amount")
                return null
            }
        } else {
            val amountMatcher = AMOUNT_PATTERN.matcher(cleanText)
            if (amountMatcher.find()) {
                amount = amountMatcher.group(1)?.replace(",", "")?.toDoubleOrNull() ?: 0.0
            }
        }

        val payeeMatcher = PAYEE_PATTERN.matcher(cleanText)
        val payee = if (payeeMatcher.find()) payeeMatcher.group(1)?.trim() ?: "Unknown" else "Unknown"

        val refMatcher = REF_PATTERN.matcher(cleanText)
        val ref = if (refMatcher.find()) refMatcher.group(1) else null

        val category = AutoCategorizer.detect("$payee $text")

        val dateString = try {
            java.time.Instant.ofEpochMilli(postTime).toString()
        } catch (e: java.lang.Exception) {
            java.time.Instant.now().toString()
        }

        val detectedApp = when {
            lowerText.contains("gpay") || lowerText.contains("google pay") || lowerText.contains("googlepay") -> "GPay"
            lowerText.contains("phonepe") || lowerText.contains("phone pe") -> "PhonePe"
            lowerText.contains("paytm") -> "Paytm"
            lowerText.contains("bhim") -> "BHIM"
            lowerText.contains("amazon pay") || lowerText.contains("amazonpay") -> "AmazonPay"
            else -> appName
        }

        return buildMap {
            put("payee",    payee)
            put("amount",   amount)
            put("category", category)
            put("upiApp",   detectedApp)
            if (ref != null) put("upiRef", ref)
            put("date",     dateString)
            put("type",     type)
        }
    }

    private fun postToBackend(data: Map<String, Any>) {
        try {
            val prefs    = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val token    = prefs.getString("flutter.jwt",          null)
            if (token.isNullOrBlank()) {
                logDebug("Cannot post transaction to backend: JWT token is missing (User not logged in).")
                return
            }
            val baseUrl  = prefs.getString("flutter.api_base_url", null)
            if (baseUrl.isNullOrBlank()) {
                logDebug("Cannot post transaction to backend: api_base_url is not set.")
                return
            }
            val endpoint = "$baseUrl/api/expenses"

            val json = JSONObject(data).toString()
            val url  = URL(endpoint)
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout  = 8_000
            conn.readTimeout     = 8_000
            conn.requestMethod   = "POST"
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.doOutput = true
            conn.outputStream.bufferedWriter(Charsets.UTF_8).use { it.write(json) }
            val code = conn.responseCode
            if (code in 200..299) {
                logDebug("Successfully posted transaction to backend. Response code: $code")
            } else {
                logDebug("Backend returned error response code $code for transaction post.")
            }
            conn.disconnect()
        } catch (e: Exception) {
            logDebug("postToBackend failed: ${e.message}")
        }
    }
}

object AutoCategorizer {
    private val rules = mapOf(
        "Food & Dining" to listOf("swiggy","zomato","dominos","pizza","kfc","mcdonalds","burger","restaurant","cafe","food","dhaba","biryani","chai"),
        "Transport"     to listOf("uber","ola","rapido","auto","cab","taxi","metro","irctc","petrol","diesel","fuel","toll","redbus","makemytrip"),
        "Grocery"       to listOf("bigbasket","grofers","blinkit","jiomart","dmart","reliance fresh","grocery","vegetables","milk","kirana","supermarket"),
        "Bills"         to listOf("airtel","jio","vodafone","bsnl","recharge","electricity","bescom","tneb","water","gas","netflix","hotstar","spotify","insurance","lic","broadband"),
        "Health"        to listOf("pharmacy","medical","hospital","clinic","doctor","apollo","netmeds","pharmeasy","1mg","medicine","diagnostics"),
        "Shopping"      to listOf("amazon","flipkart","myntra","ajio","nykaa","meesho","croma","shopping","mall","store"),
        "Transfer"      to listOf("transfer","sent to","paid to","wallet","neft","imps","rtgs"),
    )

    fun detect(text: String): String {
        val lower = text.lowercase()
        return rules.entries.firstOrNull { (_, kws) ->
            kws.any { kw ->
                val pattern = Pattern.compile("\\b${Pattern.quote(kw)}\\b", Pattern.CASE_INSENSITIVE)
                pattern.matcher(lower).find()
            }
        }?.key ?: "Other"
    }
}
