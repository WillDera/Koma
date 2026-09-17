package com.koma.koma

import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.util.Log

/**
 * Live Wi-Fi / charging snapshot for Dart [DeviceConstraints].
 *
 * MainActivity exposes this over MethodChannel. WorkManager's FlutterEngine
 * never gets that channel, so we also persist into Flutter SharedPreferences
 * (same pattern as `dalvik_port`) for the background isolate to read.
 */
object DeviceConstraintsPublisher {
    private const val TAG = "DeviceConstraints"
    private const val PREFS = "FlutterSharedPreferences"
    private const val KEY_UNMETERED = "flutter.device_unmetered"
    private const val KEY_CHARGING = "flutter.device_charging"

    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var batteryReceiver: BroadcastReceiver? = null
    private var started = false

    fun snapshot(context: Context): Map<String, Any> {
        val app = context.applicationContext
        val cm = app.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = cm.activeNetwork
        val caps = network?.let { cm.getNetworkCapabilities(it) }
        val unmetered =
            caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == true
        val bm = app.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val charging = bm.isCharging
        return mapOf("unmetered" to unmetered, "charging" to charging)
    }

    fun persist(context: Context) {
        val snap = snapshot(context)
        try {
            context.applicationContext
                .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_UNMETERED, snap["unmetered"] as Boolean)
                .putBoolean(KEY_CHARGING, snap["charging"] as Boolean)
                .apply()
        } catch (e: Throwable) {
            Log.w(TAG, "persist failed", e)
        }
    }

    fun start(app: Application) {
        if (started) return
        started = true
        persist(app)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val cm = app.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) = persist(app)
                override fun onLost(network: Network) = persist(app)
                override fun onCapabilitiesChanged(
                    network: Network,
                    networkCapabilities: NetworkCapabilities,
                ) = persist(app)
            }
            networkCallback = callback
            try {
                cm.registerDefaultNetworkCallback(callback)
            } catch (e: Throwable) {
                Log.w(TAG, "network callback failed", e)
            }
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) = persist(app)
        }
        batteryReceiver = receiver
        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                app.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                app.registerReceiver(receiver, filter)
            }
        } catch (e: Throwable) {
            Log.w(TAG, "battery receiver failed", e)
        }
    }
}
