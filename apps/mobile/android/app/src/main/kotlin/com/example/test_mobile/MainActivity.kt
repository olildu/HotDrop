package com.example.test_mobile // Make sure this matches your actual package name!

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
            if (call.method == "startLocalOnlyHotspot") {
                startHotspot(result)
            } else if (call.method == "stopLocalOnlyHotspot") {
                stopHotspot()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun startHotspot(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            
            wifiManager.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(res: WifiManager.LocalOnlyHotspotReservation?) {
                    super.onStarted(res)
                    reservation = res
                    val config = reservation?.wifiConfiguration
                    
                    if (config != null) {
                        val creds = HashMap<String, String>()
                        creds["ssid"] = config.SSID
                        creds["password"] = config.preSharedKey
                        // Send the SSID and Password back to Flutter!
                        result.success(creds)
                    } else {
                        result.error("UNAVAILABLE", "Configuration is null", null)
                    }
                }

                override fun onStopped() {
                    super.onStopped()
                }

                override fun onFailed(reason: Int) {
                    super.onFailed(reason)
                    result.error("FAILED", "Failed to start hotspot. Reason code: $reason", null)
                }
            }, null)
        } else {
            result.error("UNSUPPORTED", "LocalOnlyHotspot requires Android 8.0+", null)
        }
    }

    private fun stopHotspot() {
        reservation?.close()
        reservation = null
    }
}