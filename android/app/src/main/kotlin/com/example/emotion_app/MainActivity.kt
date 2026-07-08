package com.example.emotion_app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "mind_balance/usage_stats"
    private val koreaTimeZone: TimeZone = TimeZone.getTimeZone("Asia/Seoul")
    private val mainHandler = Handler(Looper.getMainLooper())
    private val usageExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasUsagePermission())
                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "hasAccessibilityPermission" -> result.success(hasAccessibilityPermission())
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "startUsageAlertService" -> {
                    try {
                        startUsageAlertService()
                        result.success(null)
                    } catch (exception: Exception) {
                        Log.e(TAG_ALERT_SERVICE, "startUsageAlertService method exception=${exception.message}", exception)
                        result.error(
                            "START_USAGE_ALERT_SERVICE_FAILED",
                            exception.message,
                            null
                        )
                    }
                }
                "getTodayUsage" -> runUsageTask("getTodayUsage", result) { getTodayUsage() }
                "getCurrentForegroundUsage" -> runUsageTask("getCurrentForegroundUsage", result) {
                    getCurrentForegroundUsage()
                }
                "getUsageRange" -> {
                    val start = call.argument<Number>("startMillis")?.toLong()
                    val end = call.argument<Number>("endMillis")?.toLong()
                    if (start == null || end == null || start >= end) {
                        result.error("INVALID_RANGE", "startMillis and endMillis are required.", null)
                    } else {
                        runUsageTask("getUsageRange", result) { getUsageRange(start, end) }
                    }
                }
                "getDailyUsageRange" -> {
                    val start = call.argument<Number>("startMillis")?.toLong()
                    val end = call.argument<Number>("endMillis")?.toLong()
                    if (start == null || end == null || start >= end) {
                        result.error("INVALID_RANGE", "startMillis and endMillis are required.", null)
                    } else {
                        runUsageTask("getDailyUsageRange", result) { getDailyUsageRange(start, end) }
                    }
                }
                "getUsageOverviewRange" -> {
                    val start = call.argument<Number>("startMillis")?.toLong()
                    val end = call.argument<Number>("endMillis")?.toLong()
                    if (start == null || end == null || start >= end) {
                        result.error("INVALID_RANGE", "startMillis and endMillis are required.", null)
                    } else {
                        runUsageTask("getUsageOverviewRange", result) {
                            getUsageOverviewRange(start, end)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        usageExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun runUsageTask(
        name: String,
        result: MethodChannel.Result,
        block: () -> Any?
    ) {
        usageExecutor.execute {
            val startedAt = System.currentTimeMillis()
            Log.d(TAG_USAGE_METHOD, "$name start")
            try {
                val value = block()
                Log.d(TAG_USAGE_METHOD, "$name success elapsedMs=${System.currentTimeMillis() - startedAt}")
                mainHandler.post { result.success(value) }
            } catch (exception: Exception) {
                Log.e(
                    TAG_USAGE_METHOD,
                    "$name error elapsedMs=${System.currentTimeMillis() - startedAt} message=${exception.message}",
                    exception
                )
                mainHandler.post {
                    result.error("USAGE_METHOD_FAILED", exception.message, null)
                }
            }
        }
    }

    private fun hasUsagePermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun hasAccessibilityPermission(): Boolean {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val expected = "$packageName/${MindBalanceAccessibilityService::class.java.name}"
        return enabledServices.split(':').any { service ->
            service.equals(expected, ignoreCase = true) ||
                service.endsWith("/${MindBalanceAccessibilityService::class.java.name}", ignoreCase = true)
        }
    }

    private fun startUsageAlertService() {
        val intent = Intent(this, UsageAlertService::class.java)
        Log.d(TAG_ALERT_SERVICE, "startUsageAlertService requested sdk=${Build.VERSION.SDK_INT}")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        Log.d(TAG_ALERT_SERVICE, "startUsageAlertService dispatched")
    }

    private fun getTodayUsage(): List<Map<String, Any>> {
        val end = System.currentTimeMillis()
        return getUsageRange(todayStartMillis(end), end)
    }

    private fun getUsageRange(start: Long, end: Long): List<Map<String, Any>> {
        if (!hasUsagePermission()) return emptyList()

        return AppUsageAggregator.aggregateRange(this, start, end)
            .filter { it.value >= 1000L }
            .map { entry ->
                mapOf(
                    "packageName" to entry.key,
                    "appName" to AppUsageFilters.appLabel(this, entry.key),
                    "durationMinutes" to ((entry.value + 59999L) / 60000L).toInt()
                )
            }
            .sortedByDescending { it["durationMinutes"] as Int }
            .take(60)
    }

    private fun getCurrentForegroundUsage(): Map<String, Any>? {
        val end = System.currentTimeMillis()
        val tracked = ForegroundAppTracker.read(this)
        val packageName = tracked?.packageName
            ?: AppUsageAggregator.currentForegroundFromEvents(this, RECENT_EVENT_WINDOW_MILLIS)
            ?: return null
        val appName = tracked?.appName ?: AppUsageFilters.appLabel(this, packageName)
        val todayMillis = if (hasUsagePermission()) {
            AppUsageAggregator.aggregateRange(this, todayStartMillis(end), end)[packageName] ?: 0L
        } else {
            0L
        }
        val currentSessionMinutes = tracked?.let {
            ((end - it.updatedAtMillis).coerceAtLeast(0L) / 60000L).toInt()
        } ?: 0

        return mapOf(
            "packageName" to packageName,
            "appName" to appName,
            "durationMinutes" to ((todayMillis + 59999L) / 60000L).toInt(),
            "currentSessionMinutes" to currentSessionMinutes
        )
    }

    private fun getDailyUsageRange(start: Long, end: Long): List<Map<String, Any>> {
        if (!hasUsagePermission()) return emptyList()

        return AppUsageAggregator.dailyTotals(this, start, end)
            .map { entry ->
                mapOf(
                    "date" to entry.key,
                    "durationMinutes" to (entry.value / 60000L).toInt()
                )
            }
            .sortedBy { it["date"] as String }
    }

    private fun getUsageOverviewRange(start: Long, end: Long): Map<String, Any> {
        if (!hasUsagePermission()) {
            return mapOf("usage" to emptyList<Map<String, Any>>(), "daily" to emptyList<Map<String, Any>>())
        }

        val summary = AppUsageAggregator.summarizeRange(this, start, end)
        return mapOf(
            "usage" to summary.appTotals
                .filter { it.value >= 1000L }
                .map { entry ->
                    mapOf(
                        "packageName" to entry.key,
                        "appName" to AppUsageFilters.appLabel(this, entry.key),
                        "durationMinutes" to ((entry.value + 59999L) / 60000L).toInt()
                    )
                }
                .sortedByDescending { it["durationMinutes"] as Int }
                .take(60),
            "daily" to summary.dailyTotals
                .map { entry ->
                    mapOf(
                        "date" to entry.key,
                        "durationMinutes" to (entry.value / 60000L).toInt()
                    )
                }
                .sortedBy { it["date"] as String }
        )
    }

    private fun todayStartMillis(nowMillis: Long): Long {
        val calendar = Calendar.getInstance(koreaTimeZone)
        calendar.timeInMillis = nowMillis
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        return calendar.timeInMillis
    }

    private fun koreaDate(timeMillis: Long): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.KOREA)
        formatter.timeZone = koreaTimeZone
        return formatter.format(timeMillis)
    }

    companion object {
        private const val TAG_ALERT_SERVICE = "MB_ALERT_SERVICE"
        private const val TAG_USAGE_METHOD = "MB_USAGE_METHOD"
        private const val RECENT_EVENT_WINDOW_MILLIS = 10 * 60 * 1000L
    }
}
