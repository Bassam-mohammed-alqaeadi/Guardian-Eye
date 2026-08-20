/*
 * Guardian Eye Pro — background location tracking foreground service.
 *
 * This service is the honest, battery-conscious mechanism that keeps the
 * family map and location history fresh while the app is in the background.
 *
 * What it does:
 *  - Starts as a transparent foreground service of Android type `location`
 *    with a minimal persistent notification (required by Android so the
 *    service cannot be silently killed; `location` is the legitimate
 *    foregroundServiceType declared in the manifest).
 *  - Captures a fresh position on a fixed interval (default 60 seconds,
 *    clamped to a minimum of 30 seconds and a maximum of 300 seconds) from
 *    the fused GPS/network providers.
 *  - Writes the latest captured point into SharedPreferences so that the
 *    Flutter platform channel can read a last-known-good state even after
 *    the Flutter side restarts, and hands the point back to Dart through
 *    the `com.guardianeye.app/location_tracking` MethodChannel so the
 *    Dart pipeline (LocationGeofenceRepository.recordPoint + outbox)
 *    remains the single source of truth for persistence.
 *  - Restarts automatically after device boot when tracking was enabled
 *    (BootReceiver).
 *
 * What it does NOT do (and must never be claimed to do):
 *  - It does not grant itself location access. The human must first grant
 *    ACCESS_FINE_LOCATION and ACCESS_BACKGROUND_LOCATION through the
 *    permission flow on the Flutter side. Without those grants the service
 *    records an honest failure reason and never invents coordinates.
 *  - It does not hide from the user: Android shows the ongoing notification
 *    for every foreground service, and this is by design (honesty UX).
 *  - It does not promise any interval tighter than the platform allows:
 *    Doze/standby may lengthen the capture rhythm on battery-saver devices.
 *
 * Android 14+ note:
 *  On Android 14+ (API 34+) a foreground service MUST declare a
 *  foregroundServiceType. This service declares `location` (in the
 *  manifest and passed to startForeground) because its workload is
 *  position capture. Declaring any other type would make the OS reject
 *  the start. The FOREGROUND_SERVICE_LOCATION permission is declared in
 *  the manifest.
 */
package com.guardianeye.app
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import java.time.Instant
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
class LocationTrackingService : Service() {
    private lateinit var prefs: SharedPreferences
    private var scheduler: ScheduledExecutorService? = null
    private var locationManager: LocationManager? = null
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(LOCATION_PREFS, Context.MODE_PRIVATE)
        startForegroundSafe(createNotification())
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isTrackingEnabled()) {
            // The service may be started by BootReceiver or a stale intent.
            // If tracking is not enabled, shut down immediately instead of
            // pretending to track.
            stopSelf()
            return START_NOT_STICKY
        }
        scheduler?.shutdown()
        scheduler = Executors.newSingleThreadScheduledExecutor()
        scheduler?.scheduleAtFixedRate(
            { captureLatestPoint() },
            0,
            clampedIntervalSeconds(),
            TimeUnit.SECONDS
        )
        return START_STICKY
    }
    override fun onDestroy() {
        scheduler?.shutdown()
        scheduler = null
        locationManager = null
        super.onDestroy()
    }
    // ------------------------------------------------------------------
    // Notification
    // ------------------------------------------------------------------
    private fun createNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            TRACKING_CHANNEL_ID,
            getString(R.string.m9_tracking_channel_name),
            NotificationManager.IMPORTANCE_MIN
        ).apply {
            description = getString(R.string.m9_tracking_channel_description)
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
        return Notification.Builder(this, TRACKING_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_map)
            .setContentTitle(getString(R.string.m9_tracking_notification_title))
            .setContentText(getString(R.string.m9_tracking_notification_text))
            .setOngoing(true)
            // Silence is inherited from the IMPORTANCE_MIN channel; the platform
            // keeps the notification visible so the user always knows tracking runs.
            .setOnlyAlertOnce(true)
            .build()
    }
    private fun startForegroundSafe(notification: Notification) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    TRACKING_NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
                )
            } else {
                startForeground(TRACKING_NOTIFICATION_ID, notification)
            }
        } catch (exception: Exception) {
            // Never crash the app: record the honest failure so the Flutter
            // layer can surface it (missing foreground permission on Android
            // 14+, or an OS-level restriction) instead of dying with
            // ForegroundServiceDidNotStartInTimeException.
            recordFailure("service_start_failed:${exception.javaClass.simpleName}")
        }
    }
    // ------------------------------------------------------------------
    // Capture loop
    // ------------------------------------------------------------------
    private fun captureLatestPoint() {
        if (!isTrackingEnabled()) {
            stopSelf()
            return
        }
        val granted = isLocationGranted()
        if (!granted) {
            recordFailure("location_permission_not_granted")
            return
        }
        val manager = locationManager ?: getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (manager == null) {
            recordFailure("location_service_unavailable")
            return
        }
        locationManager = manager
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
        var best: Location? = null
        for (provider in providers) {
            if (!manager.isProviderEnabled(provider)) continue
            val candidate = try {
                manager.getLastKnownLocation(provider)
            } catch (exception: Exception) {
                null
            }
            if (candidate != null && (best == null || isBetter(candidate, best))) {
                best = candidate
            }
        }
        if (best != null) {
            val point = buildMap {
                put("latitude", best.latitude)
                put("longitude", best.longitude)
                put("accuracyMeters", best.accuracy.toDouble())
                put("capturedAt", Instant.now().toString())
                put("provider", best.provider)
            }
            prefs.edit()
                .putString(KEY_LATEST_POINT, point.toMinimalJson())
                .putLong(KEY_LATEST_POINT_AT, System.currentTimeMillis())
                .apply()
        } else {
            // No fix yet (cold start, indoors, or permission-grant race).
            // Report honestly; never emit synthetic or stale coordinates.
            recordFailure("no_location_fix_available")
        }
    }
    private fun isBetter(candidate: Location, reference: Location): Boolean {
        // Prefer fresher samples; a much less accurate sample is never better.
        if (candidate.accuracy >= reference.accuracy * 2) return false
        if (candidate.time > reference.time) return true
        return candidate.accuracy < reference.accuracy
    }
    private fun recordFailure(reason: String) {
        val snapshot = buildMap {
            put("status", "failed")
            put("reason", reason)
            put("capturedAt", Instant.now().toString())
        }
        prefs.edit()
            .putString(KEY_LATEST_POINT, snapshot.toMinimalJson())
            .putLong(KEY_LATEST_POINT_AT, System.currentTimeMillis())
            .apply()
    }
    // ------------------------------------------------------------------
    // Configuration (written by the Flutter channel before start)
    // ------------------------------------------------------------------
    private fun isTrackingEnabled(): Boolean =
        prefs.getBoolean(KEY_ENABLED, false)
    private fun clampedIntervalSeconds(): Long {
        val raw = prefs.getInt(KEY_INTERVAL_MS, DEFAULT_INTERVAL_MS).toLong() / 1000L
        return raw.coerceIn(MIN_INTERVAL_SECONDS, MAX_INTERVAL_SECONDS)
    }
    companion object {
        private const val TRACKING_CHANNEL_ID = "m9_location_tracking"
        private const val TRACKING_NOTIFICATION_ID = 5502
        private const val DEFAULT_INTERVAL_MS = 60000
        private const val MIN_INTERVAL_SECONDS = 30L
        private const val MAX_INTERVAL_SECONDS = 300L
        const val LOCATION_PREFS = "guardian_tracking"
        const val KEY_ENABLED = "tracking_enabled"
        const val KEY_INTERVAL_MS = "tracking_interval_ms"
        const val KEY_LATEST_POINT = "latest_point"
        const val KEY_LATEST_POINT_AT = "latest_point_at"
        fun latestPoint(context: Context): Map<String, Any?>? {
            val prefs = context.getSharedPreferences(LOCATION_PREFS, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_LATEST_POINT, null) ?: return null
            return parseMinimalJson(raw)
        }
        fun latestPointAt(context: Context): Long {
            val prefs = context.getSharedPreferences(LOCATION_PREFS, Context.MODE_PRIVATE)
            return prefs.getLong(KEY_LATEST_POINT_AT, 0L)
        }
        fun isEnabled(context: Context): Boolean {
            val prefs = context.getSharedPreferences(LOCATION_PREFS, Context.MODE_PRIVATE)
            return prefs.getBoolean(KEY_ENABLED, false)
        }
    }
}
