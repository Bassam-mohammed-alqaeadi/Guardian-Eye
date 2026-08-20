/*
 * Guardian Eye Pro — M8 boot resilience receiver.
 *
 * Restarts the transparent enforcement monitoring service after the device
 * finishes booting so that the enforcement decision chain has a fresh
 * verified foreground-app observation as soon as the user unlocks the device.
 *
 * What it does NOT do (and must never be claimed to do):
 *  - It does not reschedule WorkManager periodic tasks by itself. The
 *    workmanager Flutter plugin registers its own boot-complete behaviour and
 *    is responsible for re-registering periodic tasks after reboot. Flutter
 *    re-registers on app start via Workmanager().registerPeriodicTask.
 *  - It does not grant or check the usage-stats permission (a human action).
 *
 * Boot receiver limitations (honesty notes):
 *  - A force-stop of the app by the user or the system clears its broadcast
 *    receivers on most modern Android versions; BOOT_COMPLETED will not fire
 *    after a force-stop until the app is launched again. This is a platform
 *    limitation and is documented, not hidden.
 *  - Physical-device evidence for this path is HUMAN ACTION REQUIRED.
 */

package com.guardianeye.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putLong(KEY_LAST_BOOT_AT, System.currentTimeMillis())
            .putString(KEY_LAST_BOOT_REASON, "boot_completed")
            .apply()
        try {
            val serviceIntent = Intent(context, EnforcementService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (exception: Exception) {
            // If the app is in a stopped state this will fail; record it and
            // let the Flutter layer report honestly instead of crashing.
            prefs.edit()
                .putString(KEY_LAST_BOOT_REASON, "boot_restart_failed:${exception.javaClass.simpleName}")
                .apply()
        }
        // Background location tracking (foreground service of Android type
        // `location`). Only restarted when the user explicitly enabled
        // tracking previously; the enabled flag lives in the tracking
        // prefs, so a user who disabled tracking stays disabled after boot.
        try {
            if (LocationTrackingService.isEnabled(context)) {
                val trackingIntent = Intent(context, LocationTrackingService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(trackingIntent)
                } else {
                    context.startService(trackingIntent)
                }
            }
        } catch (exception: Exception) {
            // Location permission grant on boot is not guaranteed; the
            // service records an honest failure and stops itself rather
            // than crashing the app or pretending to track.
            prefs.edit()
                .putString(KEY_LAST_BOOT_REASON, "boot_location_restart_failed:${exception.javaClass.simpleName}")
                .apply()
        }
    }

    companion object {
        private const val PREFS = "guardian_m8_boot"
        const val KEY_LAST_BOOT_AT = "last_boot_at"
        const val KEY_LAST_BOOT_REASON = "last_boot_reason"
    }
}
