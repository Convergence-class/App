package com.example.emotion_app

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager

data class AppCandidateDecision(
    val accepted: Boolean,
    val reason: String,
    val label: String?
)

object AppUsageFilters {
    fun evaluate(context: Context, packageName: String?): AppCandidateDecision {
        if (packageName == null) return AppCandidateDecision(false, "null_package", null)
        if (packageName.isBlank()) return AppCandidateDecision(false, "blank_package", null)
        if (packageName == context.packageName) {
            return AppCandidateDecision(false, "own_package", appLabel(context, packageName))
        }
        if (packageName == "android") {
            return AppCandidateDecision(false, "android_base", "android")
        }
        if (packageName == "com.android.settings" || packageName == "com.samsung.android.settings") {
            return AppCandidateDecision(false, "settings", appLabel(context, packageName))
        }
        if (packageName == "com.android.systemui") {
            return AppCandidateDecision(false, "system_ui", appLabel(context, packageName))
        }
        if (packageName == "com.sec.android.app.launcher") {
            return AppCandidateDecision(false, "launcher", appLabel(context, packageName))
        }
        if (packageName == "com.google.android.permissioncontroller") {
            return AppCandidateDecision(false, "permission_controller", appLabel(context, packageName))
        }
        if (packageName.startsWith("com.samsung.android.app.cocktailbar")) {
            return AppCandidateDecision(false, "samsung_edge_panel", appLabel(context, packageName))
        }
        if (packageName.startsWith("com.samsung.android.game.gametools") ||
            packageName == "com.samsung.android.game.gos"
        ) {
            return AppCandidateDecision(false, "samsung_game_overlay", appLabel(context, packageName))
        }

        return try {
            val info = context.packageManager.getApplicationInfo(packageName, 0)
            val label = context.packageManager.getApplicationLabel(info).toString()
            val hasLauncher = context.packageManager.getLaunchIntentForPackage(packageName) != null
            val isSystem = info.flags and ApplicationInfo.FLAG_SYSTEM != 0

            if (isAccessibilityInfrastructurePackage(packageName, isSystem)) {
                return AppCandidateDecision(false, "accessibility_infrastructure", label)
            }
            if (isSystem && !hasLauncher) {
                return AppCandidateDecision(false, "non_launchable_system_app", label)
            }

            AppCandidateDecision(true, "accepted", label)
        } catch (_: PackageManager.NameNotFoundException) {
            AppCandidateDecision(false, "package_not_found", packageName)
        }
    }

    fun isCountableApp(context: Context, packageName: String?): Boolean {
        return evaluate(context, packageName).accepted
    }

    fun appLabel(context: Context, packageName: String): String {
        return try {
            val info = context.packageManager.getApplicationInfo(packageName, 0)
            context.packageManager.getApplicationLabel(info).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            packageName
        }
    }

    private fun isAccessibilityInfrastructurePackage(packageName: String, isSystem: Boolean): Boolean {
        val lower = packageName.lowercase()
        if (packageName == "com.samsung.accessibility") return true
        if (packageName == "com.android.accessibility") return true
        if (packageName == "com.google.android.marvin.talkback") return true
        return isSystem && lower.contains(".accessibility")
    }
}
