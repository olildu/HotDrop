package com.example.test_mobile 

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.wifi_direct/channel"
    private var reservation: WifiManager.LocalOnlyHotspotReservation? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLocalOnlyHotspot" -> startHotspot(result)
                "stopLocalOnlyHotspot" -> {
                    stopHotspot()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startHotspot(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            
            // FIX: If we already have an active reservation, return existing creds immediately
            reservation?.let {
                val config = it.wifiConfiguration
                if (config != null) {
                    val creds = HashMap<String, String>()
                    creds["ssid"] = config.SSID
                    creds["password"] = config.preSharedKey
                    result.success(creds)
                    return
                }
            }

            wifiManager.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(res: WifiManager.LocalOnlyHotspotReservation?) {
                    super.onStarted(res)
                    reservation = res
                    val config = reservation?.wifiConfiguration
                    
                    if (config != null) {
                        val creds = HashMap<String, String>()
                        creds["ssid"] = config.SSID
                        creds["password"] = config.preSharedKey
                        result.success(creds)
                    } else {
                        // Cleanup if config is missing to avoid stuck states
                        stopHotspot()
                        result.error("UNAVAILABLE", "Configuration is null", null)
                    }
                }

                override fun onStopped() {
                    super.onStopped()
                    reservation = null // Reset on system-initiated stop
                }

                override fun onFailed(reason: Int) {
                    super.onFailed(reason)
                    reservation = null

                    val msg = when (reason) {
                        WifiManager.LocalOnlyHotspotCallback.ERROR_INCOMPATIBLE_MODE -> "Hotspot already in use by another application."
                        WifiManager.LocalOnlyHotspotCallback.ERROR_NO_CHANNEL -> "No usable channel for hotspot."
                        WifiManager.LocalOnlyHotspotCallback.ERROR_TETHERING_DISALLOWED -> "Tethering is not allowed."
                        else -> "Failed with reason code: $reason"
                    }
                    result.error("FAILED", msg, null)
                }
            }, null)
        } else {
            result.error("UNSUPPORTED", "LocalOnlyHotspot requires Android 8.0+", null)
        }
    }

    private fun stopHotspot() {
        reservation?.close() // Explicitly close the Android reservation
        reservation = null
    }
}