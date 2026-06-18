package com.example.upi_tracker

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
import java.net.HttpURLConnection
import java.net.URL
import java.util.regex.Pattern

class UpiNotificationService : NotificationListenerService() {

    // Class-level scope — cancelled when service is destroyed (fixes coroutine leak #10)
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
            "com.hmdglobal.messages"                 to "SMS"
        )

        private val AMOUNT_PATTERN = Pattern.compile(
            "(?:Rs\\.?|INR|₹)\\s*([\\d,]+(?:\\.\\d{1,2})?)", Pattern.CASE_INSENSITIVE
        )
        private val PAYEE_PATTERN = Pattern.compile(
            "(?:to|paid to|payment to|spent at|spent on|transfer to|info[:\\s]+)\\s+([\\w\\s@.\\-_]+?)(?:\\s+on|\\s+via|\\s+ref|\\s+upi|\\s+linked|\$)",
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

        // Set by MainActivity when Flutter engine is ready
        var methodChannel: MethodChannel? = null
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        serviceScope.cancel()  // Cancel all pending coroutines on disconnect (#10)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val appName = UPI_PACKAGES[sbn.packageName] ?: return

        val extras = sbn.notification.extras
        val title  = extras.getString(Notification.EXTRA_TITLE) ?: ""
        val text   = extras.getString(Notification.EXTRA_TEXT)  ?: ""
        val full   = "$title $text"

        val parsed = parseUpi(full, appName) ?: return

        // Send to Flutter UI on main thread
        CoroutineScope(Dispatchers.Main).launch {
            methodChannel?.invokeMethod("onExpense", parsed)
        }

        // POST to backend on IO thread using class-level scope (#10)
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
            android.util.Log.e("UpiTracker", "Failed checking notification settings: ${e.message}")
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
            android.util.Log.e("UpiTracker", "Failed to show notification: ${e.message}")
        }
    }

    private fun parseUpi(text: String, appName: String): Map<String, Any>? {
        val lowerText = text.lowercase()

        // Filter out incoming/credit transactions
        val isIncoming = lowerText.contains("received") ||
                lowerText.contains("refund") ||
                lowerText.contains("deposited") ||
                lowerText.contains("added") ||
                lowerText.contains("paid you") ||
                lowerText.contains("payment from") ||
                (lowerText.contains("credited") && 
                 !lowerText.contains("debited") && 
                 !lowerText.contains("paid") && 
                 !lowerText.contains("sent"))

        if (isIncoming) {
            return null
        }

        val cleanText = BALANCE_PATTERN.matcher(text).replaceAll("")

        val amountMatcher = AMOUNT_PATTERN.matcher(cleanText)
        if (!amountMatcher.find()) return null
        val amount = amountMatcher.group(1)?.replace(",", "")?.toDoubleOrNull() ?: return null
        if (amount <= 0) return null

        val payeeMatcher = PAYEE_PATTERN.matcher(cleanText)
        val payee = if (payeeMatcher.find()) payeeMatcher.group(1)?.trim() ?: "Unknown" else "Unknown"

        val refMatcher = REF_PATTERN.matcher(cleanText)
        val ref = if (refMatcher.find()) refMatcher.group(1) else null

        val category = AutoCategorizer.detect("$payee $text")

        return buildMap {
            put("payee",    payee)
            put("amount",   amount)
            put("category", category)
            put("upiApp",   appName)
            if (ref != null) put("upiRef", ref)
            put("date", java.time.Instant.now().toString())
        }
    }

    private fun postToBackend(data: Map<String, Any>) {
        try {
            // Both JWT and API_BASE_URL are written by Flutter's main.dart on startup
            // from the bundled .env file — no hardcoded URLs anywhere in this file.
            val prefs    = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val token    = prefs.getString("flutter.jwt",          null) ?: return
            val baseUrl  = prefs.getString("flutter.api_base_url", null)
            if (baseUrl.isNullOrBlank()) {
                android.util.Log.e("UpiTracker", "api_base_url not set — open the app first to load .env")
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
            if (code !in 200..299) {
                android.util.Log.w("UpiTracker", "Backend returned $code for expense post")
            }
            conn.disconnect()
        } catch (e: Exception) {
            android.util.Log.e("UpiTracker", "postToBackend failed: ${e.message}")
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
        return rules.entries.firstOrNull { (_, kws) -> kws.any { lower.contains(it) } }?.key ?: "Other"
    }
}
