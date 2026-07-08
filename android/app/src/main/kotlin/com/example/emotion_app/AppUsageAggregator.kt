package com.example.emotion_app

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

data class UsageSession(
    val packageName: String,
    val startMillis: Long,
    val endMillis: Long
)

data class UsageRangeSummary(
    val appTotals: Map<String, Long>,
    val dailyTotals: Map<String, Long>
)

object AppUsageAggregator {
    private const val TAG_FALLBACK = "MB_USAGE_FALLBACK"
    private const val TAG_RANGE = "MB_USAGE_RANGE"
    private val koreaTimeZone: TimeZone = TimeZone.getTimeZone("Asia/Seoul")
    private const val SESSION_LOOKBACK_MILLIS = 12 * 60 * 60 * 1000L

    fun aggregateRange(context: Context, start: Long, end: Long): Map<String, Long> {
        val totals = linkedMapOf<String, Long>()
        for (session in collectSessions(context, start, end)) {
            totals[session.packageName] =
                (totals[session.packageName] ?: 0L) + (session.endMillis - session.startMillis)
        }
        return totals
    }

    fun dailyTotals(context: Context, start: Long, end: Long): Map<String, Long> {
        val totals = emptyDailyTotals(start, end)

        for (session in collectSessions(context, start, end)) {
            var segmentStart = session.startMillis
            while (segmentStart < session.endMillis) {
                val segmentEnd = minOf(session.endMillis, nextKoreaMidnight(segmentStart), end)
                val key = koreaDate(segmentStart)
                totals[key] = (totals[key] ?: 0L) + (segmentEnd - segmentStart)
                segmentStart = segmentEnd
            }
        }
        return totals
    }

    fun summarizeRange(context: Context, start: Long, end: Long): UsageRangeSummary {
        val startedAt = System.currentTimeMillis()
        val appTotals = linkedMapOf<String, Long>()
        val dailyTotals = emptyDailyTotals(start, end)
        val sessions = collectSessions(context, start, end)

        for (session in sessions) {
            appTotals[session.packageName] =
                (appTotals[session.packageName] ?: 0L) + (session.endMillis - session.startMillis)

            var segmentStart = session.startMillis
            while (segmentStart < session.endMillis) {
                val segmentEnd = minOf(session.endMillis, nextKoreaMidnight(segmentStart), end)
                val key = koreaDate(segmentStart)
                dailyTotals[key] = (dailyTotals[key] ?: 0L) + (segmentEnd - segmentStart)
                segmentStart = segmentEnd
            }
        }

        Log.d(
            TAG_RANGE,
            "summarizeRange start=$start end=$end sessions=${sessions.size} apps=${appTotals.size} days=${dailyTotals.size} elapsedMs=${System.currentTimeMillis() - startedAt}"
        )
        return UsageRangeSummary(appTotals, dailyTotals)
    }

    fun currentForegroundFromEvents(context: Context, recentWindowMillis: Long): String? {
        val end = System.currentTimeMillis()
        val start = (end - recentWindowMillis).coerceAtLeast(0L)
        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usageStatsManager.queryEvents(start, end)
        val event = UsageEvents.Event()
        var currentPackage: String? = null
        var latestForegroundPackage: String? = null
        var eventCount = 0
        var acceptedCount = 0

        Log.d(TAG_FALLBACK, "queryRange start=$start end=$end recentWindowMs=$recentWindowMillis")

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            eventCount += 1
            val packageName = event.packageName ?: continue
            val decision = AppUsageFilters.evaluate(context, packageName)
            if (!decision.accepted) {
                Log.d(TAG_FALLBACK, "eventPackage=$packageName eventType=${event.eventType} decision=REJECT reason=${decision.reason} label=${decision.label}")
                continue
            }
            acceptedCount += 1

            if (isForegroundEvent(event.eventType)) {
                currentPackage = packageName
                latestForegroundPackage = packageName
                Log.d(TAG_FALLBACK, "eventPackage=$packageName eventType=${event.eventType} label=${decision.label} decision=FOREGROUND")
            } else if (isBackgroundEvent(event.eventType) && currentPackage == packageName) {
                currentPackage = null
            }
        }

        val selected = currentPackage ?: latestForegroundPackage
        Log.d(TAG_FALLBACK, "events=$eventCount accepted=$acceptedCount selectedPackage=$selected selectedLabel=${selected?.let { AppUsageFilters.appLabel(context, it) }}")
        return selected
    }

    private fun collectSessions(context: Context, start: Long, end: Long): List<UsageSession> {
        if (start >= end) return emptyList()

        val startedAt = System.currentTimeMillis()
        val queryStart = (start - SESSION_LOOKBACK_MILLIS).coerceAtLeast(0L)
        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usageStatsManager.queryEvents(queryStart, end)
        val event = UsageEvents.Event()
        val sessions = mutableListOf<UsageSession>()
        var currentPackage: String? = null
        var currentStart = queryStart
        var eventCount = 0

        fun closeCurrent(closeAt: Long) {
            val packageName = currentPackage ?: return
            val clampedStart = currentStart.coerceAtLeast(start)
            val clampedEnd = closeAt.coerceAtMost(end)
            if (clampedEnd > clampedStart && AppUsageFilters.isCountableApp(context, packageName)) {
                sessions.add(UsageSession(packageName, clampedStart, clampedEnd))
            }
            currentPackage = null
        }

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            eventCount += 1
            val packageName = event.packageName ?: continue
            val eventTime = event.timeStamp.coerceIn(queryStart, end)

            if (isForegroundEvent(event.eventType)) {
                if (currentPackage == packageName) {
                    continue
                }
                if (currentPackage != null) {
                    closeCurrent(eventTime)
                }
                if (AppUsageFilters.isCountableApp(context, packageName)) {
                    currentPackage = packageName
                    currentStart = eventTime
                } else {
                    currentPackage = null
                }
            } else if (isBackgroundEvent(event.eventType) && currentPackage == packageName) {
                closeCurrent(eventTime)
            }
        }

        closeCurrent(end)
        Log.d(
            TAG_RANGE,
            "collectSessions start=$start end=$end queryStart=$queryStart events=$eventCount sessions=${sessions.size} elapsedMs=${System.currentTimeMillis() - startedAt}"
        )
        return sessions
    }

    private fun emptyDailyTotals(start: Long, end: Long): LinkedHashMap<String, Long> {
        val totals = linkedMapOf<String, Long>()
        var cursor = start
        while (cursor < end) {
            totals[koreaDate(cursor)] = 0L
            cursor = nextKoreaMidnight(cursor).coerceAtMost(end)
        }
        return totals
    }

    private fun isForegroundEvent(eventType: Int): Boolean {
        return eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
            eventType == UsageEvents.Event.ACTIVITY_RESUMED
    }

    private fun isBackgroundEvent(eventType: Int): Boolean {
        return eventType == UsageEvents.Event.MOVE_TO_BACKGROUND ||
            eventType == UsageEvents.Event.ACTIVITY_PAUSED
    }

    private fun nextKoreaMidnight(timeMillis: Long): Long {
        val calendar = Calendar.getInstance(koreaTimeZone)
        calendar.timeInMillis = timeMillis
        calendar.add(Calendar.DAY_OF_MONTH, 1)
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
}
