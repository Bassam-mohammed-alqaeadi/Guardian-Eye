package com.guardianeye.app

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.guardianeye.app/capabilities").setMethodCallHandler { call, result ->
            val capability = call.argument<String>("capability")
            when (call.method) {
                "isGranted" -> result.success(capability?.let(::isGranted) ?: false)
                "openSettings" -> { capability?.let(::openSettings); result.success(null) }
                "observeForegroundApplication" -> result.success(observeForegroundApplication())
                "queryPolicyUsage" -> {
                    val targets = call.argument<List<String>>("targets")
                        ?.filter { it.isNotBlank() }
                        ?.toSet()
                        ?: emptySet()
                    result.success(queryPolicyUsage(targets))
                }
                else -> result.notImplemented()
            }
        }

        // M8 enforcement channel (guardian_eye.enforcement)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "guardian_eye.enforcement")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getEnforcementState" -> {
                        val deviceId = call.argument<String>("deviceId")
                        if (deviceId.isNullOrBlank()) {
                            result.error("invalidArgument", "deviceId is required", null)
                            return@setMethodCallHandler
                        }
                        result.success(buildEnforcementStateMap())
                    }
                    "startEnforcementMonitoring" -> {
                        // Starts (or re-starts) the transparent foreground monitoring
                        // service. Returns the actual outcome so the Flutter side can
                        // report it honestly; never silently swallows the failure.
                        val intent = Intent(this@MainActivity, EnforcementService::class.java)
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(
                                mapOf(
                                    "started" to true,
                                    "reason" to null,
                                    "observation" to (EnforcementService.latestObservation(this@MainActivity)
                                        ?: mapOf("status" to "noObservation", "reason" to "no_observation_recorded_yet"))
                                )
                            )
                        } catch (exception: Exception) {
                            result.success(
                                mapOf(
                                    "started" to false,
                                    "reason" to "service_start_failed:${exception.javaClass.simpleName}",
                                    "observation" to null
                                )
                            )
                        }
                    }
                    "getLastVerifiedObservation" -> {
                        result.success(
                            mapOf(
                                "status" to "ok",
                                "observation" to (EnforcementService.latestObservation(this@MainActivity)
                                    ?: mapOf("status" to "noObservation", "reason" to "no_observation_recorded_yet")),
                                "capturedAt" to if (EnforcementService.latestObservationAt(this@MainActivity) > 0L)
                                    Instant.ofEpochMilli(EnforcementService.latestObservationAt(this@MainActivity)).toString()
                                else null
                            )
                        )
                    }
                    "getBootState" -> {
                        val prefs = getSharedPreferences("guardian_m8_boot", Context.MODE_PRIVATE)
                        result.success(
                            mapOf(
                                "lastBootAt" to if (prefs.getLong(BootReceiver.KEY_LAST_BOOT_AT, 0L) > 0L)
                                    Instant.ofEpochMilli(prefs.getLong(BootReceiver.KEY_LAST_BOOT_AT, 0L)).toString()
                                else null,
                                "lastBootReason" to prefs.getString(BootReceiver.KEY_LAST_BOOT_REASON, null)
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }
        }

    private fun buildEnforcementStateMap(): Map<String, Any?> {
        val granted = try {
            val manager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            manager.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            ) == AppOpsManager.MODE_ALLOWED
        } catch (exception: Exception) {
            false
        }
        val latest = EnforcementService.latestObservation(this)
        val latestAt = EnforcementService.latestObservationAt(this)
        return mapOf(
            "usageStatsPermission" to (if (granted) "granted" else "notGranted"),
            "observation" to (latest ?: mapOf("status" to "noObservation", "reason" to "no_observation_recorded_yet")),
            "lastObservationAt" to if (latestAt > 0L) Instant.ofEpochMilli(latestAt).toString() else null
        )
    }

    private fun isGranted(capability: String): Boolean = when (capability) {
        "usageStats" -> {
            val manager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            manager.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName) == AppOpsManager.MODE_ALLOWED
        }
        "overlay" -> Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
        else -> false
    }

    private fun openSettings(capability: String) {
        val intent = when (capability) {
            "usageStats" -> Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            "accessibility" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            "overlay" -> Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
            else -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        }
        startActivity(intent)
    }

    private fun observeForegroundApplication(): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return mapOf("status" to "unsupported", "reason" to "usage_stats_api_unavailable")
        }
        if (!isGranted("usageStats")) {
            return mapOf("status" to "blockedByPermission", "reason" to "usage_stats_not_granted")
        }
        val manager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return mapOf("status" to "unsupported", "reason" to "usage_stats_service_unavailable")
        val now = System.currentTimeMillis()
        val events = manager.queryEvents(now - 15 * 60 * 1000L, now)
        val event = UsageEvents.Event()
        var packageName: String? = null
        var observedAt: Long? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val isForeground = event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && event.eventType == UsageEvents.Event.ACTIVITY_RESUMED)
            if (isForeground && !event.packageName.isNullOrBlank()) {
                packageName = event.packageName
                observedAt = event.timeStamp
            }
        }
        return if (packageName == null || observedAt == null) {
            mapOf("status" to "noObservation", "reason" to "no_recent_foreground_event")
        } else {
            mapOf("status" to "observed", "packageName" to packageName, "observedAt" to Instant.ofEpochMilli(observedAt).toString())
        }
    }

    /**
     * Expands a policy target into the concrete Android packages it measures.
     *
     * Policy targets are category identifiers ('video', 'social', 'games',
     * 'browser') chosen in the M6 editor, but UsageStats is keyed by package
     * name. Without this expansion a category policy could never match a real
     * app, so `queryPolicyUsage` would always report a measured zero. A target
     * that is already a concrete package id (per-package policy, see the
     * `policyPackageId` localization) is used as-is.
     */
    private fun targetPackages(targets: Set<String>): Set<String> {
        val categories = mapOf(
            "video" to setOf(
                "com.google.android.youtube",
                "com.google.android.apps.youtube.music",
                "com.netflix.mediaclient",
                "com.samsung.android.video",
                "org.videolan.vlc",
                "video.player.videoplayer",
                "com.google.android.videos"
            ),
            "social" to setOf(
                "com.facebook.katana",
                "com.facebook.lite",
                "com.facebook.orca",
                "com.whatsapp",
                "com.instagram.android",
                "com.tiktok.tiktok",
                "com.snapchat.android"
            ),
            "games" to setOf(
                "com.supercell.clashofclans",
                "com.supercell.royale",
                "com.roblox.client",
                "com.nianticlabs.pokemongo"
            ),
            "browser" to setOf(
                "com.android.chrome",
                "com.sec.android.app.sbrowser",
                "org.mozilla.firefox",
                "com.kiwibrowser.browser",
                "com.opera.browser",
                "com.brave.browser"
            )
        )
        return targets.flatMap { categories[it] ?: setOf(it) }.toSet()
    }

    private fun queryPolicyUsage(targets: Set<String>): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return mapOf("status" to "unsupported", "reason" to "usage_stats_api_unavailable", "summaries" to emptyList<Map<String, Any?>>())
        }
        if (!isGranted("usageStats")) {
            return mapOf("status" to "permissionRequired", "reason" to "usage_stats_not_granted", "summaries" to emptyList<Map<String, Any?>>())
        }
        if (targets.isEmpty()) {
            return mapOf("status" to "noObservation", "reason" to "no_policy_targets", "summaries" to emptyList<Map<String, Any?>>())
        }
        val manager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return mapOf("status" to "unavailable", "reason" to "usage_stats_service_unavailable", "summaries" to emptyList<Map<String, Any?>>())
        val zone = ZoneId.systemDefault()
        val start = LocalDate.now(zone).atStartOfDay(zone).toInstant().toEpochMilli()
        val captured = System.currentTimeMillis()
        // queryAndAggregateUsageStats returns a corrupted map on this Android
        // 16 / Samsung build (every entry keyed as one system app), so
        // aggregate from the raw queryUsageStats rows instead.
        val rows = manager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, captured)
        val usage = rows
            .filter { !it.packageName.isNullOrBlank() }
            .groupBy { it.packageName }
            .mapValues { (_, list) ->
                UsageStatsAggregate(
                    totalTimeInForeground = list.sumOf { it.totalTimeInForeground },
                    lastTimeUsed = list.maxOfOrNull { it.lastTimeUsed } ?: 0L
                )
            }
        // UsageStats is keyed by package name, but the Dart coordinator looks
        // up summaries by the policy TARGET ('video', a concrete package id,
        // ...). Aggregate each target's member packages into one summary row
        // keyed by the target so `byTarget[target]` resolves on the Flutter
        // side. `lastUsedAt` is the most recent use among the members.
        val packages = targetPackages(targets)
        val packageToTarget = targets
            .flatMap { target -> targetPackages(setOf(target)).map { it to target } }
            .toMap()
        val matches = usage.entries
            .filter { packages.contains(it.key) && it.value.totalTimeInForeground >= 0L }
        val summaries = matches
            .groupBy { packageToTarget[it.key] ?: it.key }
            .map { (target, entries) ->
                mapOf(
                    "packageName" to target,
                    "totalMilliseconds" to entries.sumOf { it.value.totalTimeInForeground },
                    "lastUsedAt" to entries
                        .mapNotNull { entry ->
                            if (entry.value.lastTimeUsed > 0L) {
                                Instant.ofEpochMilli(entry.value.lastTimeUsed).toString()
                            } else {
                                null
                            }
                        }
                        .maxOrNull()
                )
            }
        return mapOf(
            "status" to if (summaries.isEmpty()) "noObservation" else "observed",
            "reason" to if (summaries.isEmpty()) "no_target_usage_today" else null,
            "dayStart" to Instant.ofEpochMilli(start).toString(),
            "capturedAt" to Instant.ofEpochMilli(captured).toString(),
            "summaries" to summaries
        )
    }
}

/// Lightweight per-package aggregation built from raw UsageStats rows
/// (queryAndAggregateUsageStats is unreliable on Android 16 / Samsung).
private data class UsageStatsAggregate(
    val totalTimeInForeground: Long,
    val lastTimeUsed: Long
)
