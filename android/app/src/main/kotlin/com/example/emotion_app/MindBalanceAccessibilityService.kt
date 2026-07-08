package com.example.emotion_app

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class MindBalanceAccessibilityService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (!isAppSwitchEvent(event.eventType)) return

        val eventPackage = event.packageName?.toString()
        val className = event.className?.toString()
        val rootPackage = rootInActiveWindow?.packageName?.toString()
        val eventDecision = AppUsageFilters.evaluate(this, eventPackage)
        val rootDecision = AppUsageFilters.evaluate(this, rootPackage)
        val selectedPackage = selectPackage(eventPackage, eventDecision, rootPackage, rootDecision)
        val eventTypeName = eventTypeName(event.eventType)

        if (selectedPackage == null) {
            Log.d(
                TAG,
                "eventType=$eventTypeName(${event.eventType}) eventPackage=$eventPackage className=$className windowId=${event.windowId} rootPackage=$rootPackage eventLabel=${eventDecision.label} rootLabel=${rootDecision.label} decision=REJECT reason=event:${eventDecision.reason},root:${rootDecision.reason}"
            )
            return
        }

        val selectedDecision = AppUsageFilters.evaluate(this, selectedPackage)
        Log.d(
            TAG,
            "eventType=$eventTypeName(${event.eventType}) eventPackage=$eventPackage className=$className windowId=${event.windowId} rootPackage=$rootPackage label=${selectedDecision.label} decision=ACCEPT selectedPackage=$selectedPackage selectedSource=${if (selectedPackage == rootPackage) "root" else "event"}"
        )
        ForegroundAppTracker.update(
            this,
            selectedPackage,
            event.eventTime,
            source = "accessibility:$eventTypeName"
        )
    }

    override fun onInterrupt() = Unit

    private fun selectPackage(
        eventPackage: String?,
        eventDecision: AppCandidateDecision,
        rootPackage: String?,
        rootDecision: AppCandidateDecision
    ): String? {
        if (eventDecision.accepted) return eventPackage
        if (rootDecision.accepted) return rootPackage
        return null
    }

    private fun isAppSwitchEvent(eventType: Int): Boolean {
        return eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED
    }

    private fun eventTypeName(eventType: Int): String {
        return when (eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> "TYPE_WINDOW_STATE_CHANGED"
            AccessibilityEvent.TYPE_WINDOWS_CHANGED -> "TYPE_WINDOWS_CHANGED"
            else -> "TYPE_$eventType"
        }
    }

    companion object {
        private const val TAG = "MB_A11Y"
    }
}
