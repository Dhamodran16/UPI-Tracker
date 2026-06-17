package com.example.upi_tracker

import android.app.Notification
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
            "in.amazon.mShop.android.shopping"       to "AmazonPay"
        )

        private val AMOUNT_PATTERN = Pattern.compile(
            "(?:Rs\\.?|INR|₹)\\s*([\\d,]+(?:\\.\\d{1,2})?)", Pattern.CASE_INSENSITIVE
        )
        private val PAYEE_PATTERN = Pattern.compile(
            "(?:to|paid to|payment to)\\s+([\\w\\s@.\\-_]+?)(?:\\s+on|\\s+via|\\s+ref|\\s+upi|\$)",
            Pattern.CASE_INSENSITIVE
        )
        private val REF_PATTERN = Pattern.compile(
            "(?:ref|upi ref|txn|transaction id)[:\\s#]+([A-Z0-9]+)",
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
    }

    private fun parseUpi(text: String, appName: String): Map<String, Any>? {
        val amountMatcher = AMOUNT_PATTERN.matcher(text)
        if (!amountMatcher.find()) return null
        val amount = amountMatcher.group(1)?.replace(",", "")?.toDoubleOrNull() ?: return null
        if (amount <= 0) return null

        val payeeMatcher = PAYEE_PATTERN.matcher(text)
        val payee = if (payeeMatcher.find()) payeeMatcher.group(1)?.trim() ?: "Unknown" else "Unknown"

        val refMatcher = REF_PATTERN.matcher(text)
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
