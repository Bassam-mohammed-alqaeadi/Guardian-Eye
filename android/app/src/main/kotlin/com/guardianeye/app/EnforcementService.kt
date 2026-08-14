/*
 * Guardian Eye Pro — M8 screen-time enforcement foreground service.
 *
 * This service is the honest, minimal, battery-conscious mechanism that keeps
 * a recent verified foreground-app observation available to the enforcement
 * decision chain while the app is on the child device.
 *
 * What it does:
 *  - Starts as a transparent foreground service with a minimal persistent
 *    notification (required by Android so the service cannot be silently killed).
 *  - Periodically samples UsageStatsManager for the current foreground app.
 *  - Writes the latest verified observation into SharedPreferences so that the
 *    Flutter platform channel can read a last-known-good state even after the
 *    Flutter side restarts.
 *
 * What it does NOT do (and must never be claimed to do):
 *  - It does not block, kill, or close third-party apps. Consumer Android
 *    does not permit an app to restrict other apps without Device Administration
 *    / profile ownership, which is outside the intended family UX.
 *  - It does not poll aggressively: sampling interval is fixed and generous
 *    (default 5 minutes), with Doze-compatible scheduling preferred via the
 *    workmanager plugin on top of this service.
 *
 * Android 14+ note (HUMAN ACTION REQUIRED):
 *  On Android 14+ (API 34+) a foreground service MUST declare a
 *  foregroundServiceType. This service intentionally declares NO type here so
 *  it works on pre-14 devices; declaring a legitimate type for this use case
 *  (e.g., "dataSync") and verifying on a physical device requires a human
 *  device test before the app can be distributed. See the M8 completion
 *  report for the exact required action.
 */

package com.guardianeye.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Intent
import java.time.Instant
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

class EnforcementService : Service() {

    private lateinit var prefs: SharedPreferences
    private var scheduler: ScheduledExecutorService? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(ENFORCEMENT_PREFS, Context.MODE_PRIVATE)
        startForegroundSafe(createNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        scheduler?.shutdown()
        scheduler = Executors.newSingleThreadScheduledExecutor()
        scheduler?.scheduleAtFixedRate(
            { recordLatestObservation() },
            0,
            SAMPLE_INTERVAL_SECONDS,
            TimeUnit.SECONDS
        )
        return START_STICKY
    }

    override fun onDestroy() {
        scheduler?.shutdown()
        scheduler = null
        super.onDestroy()
    }

    // ------------------------------------------------------------------
    // Foreground notification (minimal, honest, user-visible)
    // ------------------------------------------------------------------

    private fun createNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.m8_fg_channel_name),
            NotificationManager.IMPORTANCE_MIN
        ).apply {
            description = getString(R.string.m8_fg_channel_description)
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentTitle(getString(R.string.m8_fg_notification_title))
            .setContentText(getString(R.string.m8_fg_notification_text))
            .setOngoing(true)
            // Silence is inherited from the IMPORTANCE_MIN channel; the platform
            // Notification.Builder has no setSilent (NotificationCompat only).
            .build()
    }

    private fun startForegroundSafe(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+ requires a service type; without one, startForeground
            // throws. We record the failure so the Flutter side can report it
            // honestly instead of crashing the app.
            recordFailure("foreground_type_required_android_14")
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_NONE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    // ------------------------------------------------------------------
    // Observation loop
    // ------------------------------------------------------------------

    private fun recordLatestObservation() {
        val observed = observeForeground()
        val snapshot = buildMap {
            put("status", observed.status)
            if (observed.reason != null) put("reason", observed.reason)
            if (observed.packageName != null) put("packageName", observed.packageName)
            if (observed.observedAt != null) put("observedAt", observed.observedAt)
            put("capturedAt", Instant.now().toString())
        }
        prefs.edit()
            .putString(KEY_LATEST_OBSERVATION, snapshot.toMinimalJson())
            .putLong(KEY_LATEST_OBSERVATION_AT, System.currentTimeMillis())
            .apply()
    }

    private data class ForegroundObservation(
        val status: String,
        val reason: String?,
        val packageName: String?,
        val observedAt: String?
    )

    private fun observeForeground(): ForegroundObservation {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return ForegroundObservation("unsupported", "usage_stats_api_unavailable", null, null)
        }
        val granted = isUsageStatsGranted()
        if (!granted) {
            return ForegroundObservation("blockedByPermission", "usage_stats_not_granted", null, null)
        }
        val manager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return ForegroundObservation("unsupported", "usage_stats_service_unavailable", null, null)
        val end = System.currentTimeMillis()
        val events = manager.queryEvents(end - 15 * 60 * 1000L, end)
        val event = UsageEvents.Event()
        var packageName: String? = null
        var observedAt: Long? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val isForeground = event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                    event.eventType == UsageEvents.Event.ACTIVITY_RESUMED)
            if (isForeground && !event.packageName.isNullOrBlank()) {
                packageName = event.packageName
                observedAt = event.timeStamp
            }
        }
        return if (packageName == null || observedAt == null) {
            ForegroundObservation("noObservation", "no_recent_foreground_event", null, null)
        } else {
            ForegroundObservation(
                "observed",
                null,
                packageName,
                Instant.ofEpochMilli(observedAt).toString()
            )
        }
    }

    private fun isUsageStatsGranted(): Boolean {
        val manager = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
        return manager.checkOpNoThrow(
            android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            packageName
        ) == android.app.AppOpsManager.MODE_ALLOWED
    }

    private fun recordFailure(reason: String) {
        val snapshot = buildMap {
            put("status", "unsupported")
            put("reason", reason)
            put("capturedAt", Instant.now().toString())
        }
        prefs.edit()
            .putString(KEY_LATEST_OBSERVATION, snapshot.toMinimalJson())
            .putLong(KEY_LATEST_OBSERVATION_AT, System.currentTimeMillis())
            .apply()
    }

    companion object {
        private const val CHANNEL_ID = "m8_enforcement_monitoring"
        private const val NOTIFICATION_ID = 5501
        private const val SAMPLE_INTERVAL_SECONDS = 300L

        const val ENFORCEMENT_PREFS = "guardian_m8_enforcement"
        const val KEY_LATEST_OBSERVATION = "latest_observation"
        const val KEY_LATEST_OBSERVATION_AT = "latest_observation_at"

        fun latestObservation(context: Context): Map<String, Any?>? {
            val prefs = context.getSharedPreferences(ENFORCEMENT_PREFS, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_LATEST_OBSERVATION, null) ?: return null
            return parseMinimalJson(raw)
        }

        fun latestObservationAt(context: Context): Long {
            val prefs = context.getSharedPreferences(ENFORCEMENT_PREFS, Context.MODE_PRIVATE)
            return prefs.getLong(KEY_LATEST_OBSERVATION_AT, 0L)
        }
    }
}

// ------------------------------------------------------------------
// Minimal JSON helpers (avoids adding a dependency)
// ------------------------------------------------------------------

internal fun Map<String, Any?>.toMinimalJson(): String {
    val sb = StringBuilder("{")
    var first = true
    for ((key, value) in this) {
        if (!first) sb.append(",")
        first = false
        sb.append('"').append(jsonEscape(key)).append('"').append(':')
        sb.append(when (value) {
            null -> "null"
            is String -> "\"${jsonEscape(value)}\""
            is Number -> value.toString()
            is Boolean -> value.toString()
            else -> "\"${jsonEscape(value.toString())}\""
        })
    }
    return sb.append("}").toString()
}

private fun jsonEscape(s: String): String = s
    .replace("\\", "\\\\")
    .replace("\"", "\\\"")
    .replace("\n", "\\n")
    .replace("\r", "\\r")
    .replace("\t", "\\t")

internal fun parseMinimalJson(raw: String): Map<String, Any?> {
    val result = mutableMapOf<String, Any?>()
    var i = raw.indexOf('{')
    if (i < 0) return result
    i++
    while (i < raw.length) {
        while (i < raw.length && raw[i].isWhitespace()) i++
        if (i >= raw.length || raw[i] == '}') break
        val key = readJsonString(raw, i)
        i = key.second
        while (i < raw.length && (raw[i] == ':' || raw[i].isWhitespace())) i++
        val (value, end) = readJsonValue(raw, i)
        result[key.first] = value
        i = end
        while (i < raw.length && (raw[i] == ',' || raw[i].isWhitespace())) i++
    }
    return result
}

private fun readJsonString(raw: String, start: Int): Pair<String, Int> {
    var i = if (raw[start] == '"') start + 1 else start
    val sb = StringBuilder()
    while (i < raw.length) {
        val c = raw[i]
        if (c == '"') return sb.toString() to (i + 1)
        if (c == '\\' && i + 1 < raw.length) {
            sb.append(raw[i + 1]); i += 2; continue
        }
        sb.append(c); i++
    }
    return sb.toString() to i
}

private fun readJsonValue(raw: String, start: Int): Pair<Any?, Int> {
    var i = start
    while (i < raw.length && raw[i].isWhitespace()) i++
    return when {
        i >= raw.length -> null to i
        raw[i] == '"' -> readJsonString(raw, i)
        raw.startsWith("null", i) -> null to (i + 4)
        raw.startsWith("true", i) -> true to (i + 4)
        raw.startsWith("false", i) -> false to (i + 5)
        else -> {
            val end = raw.indexOfFirst(i) { it == ',' || it == '}' }
            raw.substring(i, end).trim().toDoubleOrNull()?.let { it to end }
                ?: (raw.substring(i, end).trim() to end)
        }
    }
}

private inline fun String.indexOfFirst(start: Int, predicate: (Char) -> Boolean): Int {
    for (i in start until length) if (predicate(this[i])) return i
    return length
}
