package com.example.emotion_app

import android.content.Context
import android.util.Log

data class ForegroundApp(
    val packageName: String,
    val appName: String,
    val updatedAtMillis: Long
)

object ForegroundAppTracker {
    private const val TAG = "MB_TRACKER"
    private const val PREFS = "mind_balance_foreground_app"
    private const val KEY_PACKAGE = "package_name"
    private const val KEY_APP_NAME = "app_name"
    private const val KEY_UPDATED_AT = "updated_at"
    private const val KEY_EVENT_AT = "event_at"

    fun update(
        context: Context,
        packageName: String?,
        eventTimeMillis: Long = 0L,
        source: String = "unknown"
    ) {
        val decision = AppUsageFilters.evaluate(context, packageName)
        if (!decision.accepted || packageName == null) {
            Log.d(TAG, "decision=REJECT source=$source package=$packageName reason=${decision.reason} label=${decision.label}")
            return
        }

        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val previousPackage = prefs.getString(KEY_PACKAGE, null)
        val previousLabel = prefs.getString(KEY_APP_NAME, null)
        val appName = decision.label ?: AppUsageFilters.appLabel(context, packageName)
        val now = System.currentTimeMillis()

        prefs
            .edit()
            .putString(KEY_PACKAGE, packageName)
            .putString(KEY_APP_NAME, appName)
            .putLong(KEY_UPDATED_AT, now)
            .putLong(KEY_EVENT_AT, eventTimeMillis)
            .apply()

        Log.d(
            TAG,
            "decision=ACCEPT source=$source previousPackage=$previousPackage previousLabel=$previousLabel newPackage=$packageName newLabel=$appName timestamp=$now eventTime=$eventTimeMillis"
        )
    }

    fun read(context: Context, maxAgeMillis: Long = Long.MAX_VALUE): ForegroundApp? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val packageName = prefs.getString(KEY_PACKAGE, null) ?: return null
        val decision = AppUsageFilters.evaluate(context, packageName)
        if (!decision.accepted) {
            Log.d(TAG, "stored=INVALID package=$packageName reason=${decision.reason} label=${decision.label}; clearing")
            prefs.edit().clear().apply()
            return null
        }
        val updatedAt = prefs.getLong(KEY_UPDATED_AT, 0L)
        if (updatedAt <= 0L) return null
        val ageMs = System.currentTimeMillis() - updatedAt
        if (ageMs > maxAgeMillis) {
            Log.d(TAG, "stored=STALE package=$packageName label=${decision.label} ageMs=$ageMs maxAgeMs=$maxAgeMillis")
            return null
        }
        val appName = prefs.getString(KEY_APP_NAME, null) ?: decision.label ?: AppUsageFilters.appLabel(context, packageName)
        val eventAt = prefs.getLong(KEY_EVENT_AT, 0L)
        Log.d(
            TAG,
            "read=VALID package=$packageName label=$appName updatedAt=$updatedAt eventAt=$eventAt ageMs=$ageMs"
        )
        return ForegroundApp(packageName, appName, updatedAt)
    }
}
