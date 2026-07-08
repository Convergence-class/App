package com.example.emotion_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log

class UsageAlertService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var observedPackageName: String? = null
    private var observedAppName: String? = null
    private var observedSinceMillis = 0L
    private var notifiedTestHours = 0
    private var lastPermissionNoticeAt = 0L
    private var tickCount = 0L

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG_SERVICE, "onCreate")
        try {
            ensureChannels()
            startForeground(
                SERVICE_NOTIFICATION_ID,
                buildNotification(
                    SERVICE_CHANNEL_ID,
                    "사용시간 테스트 실행 중",
                    "현재 사용 중인 앱을 감지하고 있어요."
                )
            )
            Log.d(TAG_SERVICE, "startForeground success notificationId=$SERVICE_NOTIFICATION_ID channelId=$SERVICE_CHANNEL_ID")
        } catch (exception: Exception) {
            Log.e(TAG_SERVICE, "onCreate exception=${exception.message}", exception)
            throw exception
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG_SERVICE, "onStartCommand flags=$flags startId=$startId intentAction=${intent?.action}")
        resetObservedApp("service_start")
        handler.removeCallbacksAndMessages(null)
        handler.post(checkRunnable)
        return START_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG_SERVICE, "onDestroy")
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private val checkRunnable = object : Runnable {
        override fun run() {
            try {
                checkUsageAlert()
            } catch (exception: Exception) {
                Log.e(TAG_SERVICE, "checkUsageAlert exception=${exception.message}", exception)
            }
            handler.postDelayed(this, CHECK_INTERVAL_MILLIS)
        }
    }

    private fun checkUsageAlert() {
        val now = System.currentTimeMillis()
        tickCount += 1
        val tracker = ForegroundAppTracker.read(this)
        val fallbackPackage = AppUsageAggregator.currentForegroundFromEvents(this, RECENT_EVENT_WINDOW_MILLIS)
        val fallback = fallbackPackage?.let { packageName ->
            ForegroundApp(
                packageName,
                AppUsageFilters.appLabel(this, packageName),
                now
            )
        }
        val current = selectCurrentApp(tracker, fallback)
        val selectedDecision = AppUsageFilters.evaluate(this, current?.packageName)
        val trackerDecision = AppUsageFilters.evaluate(this, tracker?.packageName)
        val fallbackDecision = AppUsageFilters.evaluate(this, fallback?.packageName)
        val selectedSource = when {
            current == null -> "none"
            tracker != null && current.packageName == tracker.packageName -> "accessibility_tracker"
            fallback != null && current.packageName == fallback.packageName -> "usage_events_fallback"
            else -> "unknown"
        }
        val elapsedMs = if (observedSinceMillis > 0L) now - observedSinceMillis else 0L
        val nextMilestone = if (observedSinceMillis > 0L) {
            (elapsedMs / TEST_HOUR_INTERVAL_MILLIS).toInt()
        } else {
            0
        }

        Log.d(
            TAG_TICK,
            "currentTime=$now tick=$tickCount " +
                "trackerPackage=${tracker?.packageName} trackerLabel=${tracker?.appName} trackerTimestamp=${tracker?.updatedAtMillis} trackerAgeMs=${tracker?.let { now - it.updatedAtMillis }} trackerValid=${trackerDecision.accepted} trackerRejectReason=${trackerDecision.reason} " +
                "fallbackPackage=${fallback?.packageName} fallbackLabel=${fallback?.appName} fallbackValid=${fallbackDecision.accepted} fallbackRejectReason=${fallbackDecision.reason} " +
                "selectedPackage=${current?.packageName} selectedLabel=${current?.appName} selectedSource=$selectedSource selectedValid=${selectedDecision.accepted} selectedRejectReason=${selectedDecision.reason} " +
                "observedPackageName=$observedPackageName observedAppName=$observedAppName observedSinceMillis=$observedSinceMillis elapsedMs=$elapsedMs nextMilestone=$nextMilestone notifiedTestHours=$notifiedTestHours"
        )

        if (current == null) {
            maybeNotifyPermissionNeeded(now)
            resetObservedApp("no_current_app")
            return
        }

        if (observedPackageName != current.packageName) {
            val previousPackage = observedPackageName
            val previousElapsed = elapsedMs
            observedPackageName = current.packageName
            observedAppName = current.appName
            observedSinceMillis = now
            notifiedTestHours = 0
            Log.d(
                TAG_TIMER,
                "reset reason=package_changed previousPackage=$previousPackage newPackage=${current.packageName} newLabel=${current.appName} previousElapsedMs=$previousElapsed observedSinceMillis=$observedSinceMillis"
            )
            return
        }

        val elapsed = now - observedSinceMillis
        val nextTestHour = (elapsed / TEST_HOUR_INTERVAL_MILLIS).toInt()
        val alreadyNotified = nextTestHour <= notifiedTestHours
        val willNotify = nextTestHour > 0 && !alreadyNotified
        Log.d(
            TAG_MILESTONE,
            "packageName=${current.packageName} appLabel=${current.appName} elapsedMs=$elapsed intervalMs=$TEST_HOUR_INTERVAL_MILLIS calculatedHour=$nextTestHour alreadyNotified=$alreadyNotified notifiedTestHours=$notifiedTestHours willNotify=$willNotify"
        )
        if (!willNotify) return

        notifiedTestHours = nextTestHour
        notifyUsage(
            current.packageName,
            current.appName,
            nextTestHour,
            "사용시간 테스트 알림",
            "${observedAppName ?: current.appName} 앱을 ${nextTestHour}시간 사용하고 있어요."
        )
    }

    private fun selectCurrentApp(tracker: ForegroundApp?, fallback: ForegroundApp?): ForegroundApp? {
        if (tracker == null) return fallback
        if (fallback == null) return tracker
        if (tracker.packageName == fallback.packageName) return tracker

        val trackerAgeMs = System.currentTimeMillis() - tracker.updatedAtMillis
        return if (trackerAgeMs > TRACKER_CROSS_CHECK_WINDOW_MILLIS) fallback else tracker
    }

    private fun maybeNotifyPermissionNeeded(now: Long) {
        if (hasAccessibilityPermission()) return
        if (now - lastPermissionNoticeAt < PERMISSION_NOTICE_INTERVAL_MILLIS) return
        lastPermissionNoticeAt = now
        notifyUsage(
            packageName,
            "마인드밸런스",
            0,
            "사용시간 테스트 알림",
            "접근성 권한을 켜면 현재 사용 중인 앱을 더 정확하게 감지할 수 있어요."
        )
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

    private fun resetObservedApp(reason: String) {
        val now = System.currentTimeMillis()
        val previousPackage = observedPackageName
        val previousElapsed = if (observedSinceMillis > 0L) now - observedSinceMillis else 0L
        observedPackageName = null
        observedAppName = null
        observedSinceMillis = 0L
        notifiedTestHours = 0
        Log.d(
            TAG_TIMER,
            "reset reason=$reason previousPackage=$previousPackage previousElapsedMs=$previousElapsed notifiedTestHours=0"
        )
    }

    private fun notifyUsage(packageName: String, appLabel: String, testHour: Int, title: String, body: String) {
        val notificationId = USAGE_TEST_NOTIFICATION_BASE_ID +
            (Math.floorMod(packageName.hashCode(), 1000) * 100) +
            testHour.coerceAtLeast(0)
        Log.d(
            TAG_NOTIFY,
            "packageName=$packageName appLabel=$appLabel testHour=$testHour notificationId=$notificationId channelId=$USAGE_CHANNEL_ID willNotify=true"
        )
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(
                notificationId,
                buildNotification(USAGE_CHANNEL_ID, title, body)
            )
            Log.d(
                TAG_NOTIFY,
                "notify called packageName=$packageName appLabel=$appLabel testHour=$testHour notificationId=$notificationId channelId=$USAGE_CHANNEL_ID"
            )
        } catch (exception: Exception) {
            Log.e(
                TAG_NOTIFY,
                "exception packageName=$packageName appLabel=$appLabel testHour=$testHour notificationId=$notificationId channelId=$USAGE_CHANNEL_ID message=${exception.message}",
                exception
            )
        }
    }

    private fun buildNotification(channelId: String, title: String, body: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setOngoing(channelId == SERVICE_CHANNEL_ID)
            .build()
    }

    private fun ensureChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val serviceChannel = NotificationChannel(
            SERVICE_CHANNEL_ID,
            "사용시간 테스트 서비스",
            NotificationManager.IMPORTANCE_LOW
        )
        serviceChannel.description = "현재 앱 감지 테스트 알림을 유지합니다."

        val usageChannel = NotificationChannel(
            USAGE_CHANNEL_ID,
            "앱 사용시간 알림",
            NotificationManager.IMPORTANCE_HIGH
        )
        usageChannel.description = "현재 앱 기준 사용시간 테스트 알림을 보여줍니다."

        manager.createNotificationChannel(serviceChannel)
        manager.createNotificationChannel(usageChannel)
        val storedUsageChannel = manager.getNotificationChannel(USAGE_CHANNEL_ID)
        Log.d(
            TAG_SERVICE,
            "ensureChannels serviceChannel=$SERVICE_CHANNEL_ID usageChannel=$USAGE_CHANNEL_ID usageImportance=${storedUsageChannel?.importance} usageBlocked=${storedUsageChannel?.importance == NotificationManager.IMPORTANCE_NONE}"
        )
    }

    companion object {
        private const val TAG_SERVICE = "MB_ALERT_SERVICE"
        private const val TAG_TICK = "MB_ALERT_TICK"
        private const val TAG_TIMER = "MB_TIMER"
        private const val TAG_MILESTONE = "MB_MILESTONE"
        private const val TAG_NOTIFY = "MB_NOTIFY"
        private const val SERVICE_CHANNEL_ID = "mind_balance_usage_service"
        private const val USAGE_CHANNEL_ID = "mind_balance_usage_test_v2"
        private const val SERVICE_NOTIFICATION_ID = 3300
        private const val USAGE_TEST_NOTIFICATION_BASE_ID = 3400
        private const val CHECK_INTERVAL_MILLIS = 10 * 1000L
        private const val TEST_HOUR_INTERVAL_MILLIS = 2 * 60 * 1000L
        private const val RECENT_EVENT_WINDOW_MILLIS = 10 * 60 * 1000L
        private const val TRACKER_CROSS_CHECK_WINDOW_MILLIS = 10 * 60 * 1000L
        private const val PERMISSION_NOTICE_INTERVAL_MILLIS = 2 * 60 * 1000L
    }
}
