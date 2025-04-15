package com.example.test_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pInfo
import android.net.wifi.p2p.WifiP2pManager
import android.net.wifi.p2p.WifiP2pManager.Channel
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper

class MainActivity : FlutterActivity() {
    private lateinit var channel: MethodChannel
    private lateinit var wifiP2pManager: WifiP2pManager
    private lateinit var wifiP2pChannel: Channel
    private var receiver: BroadcastReceiver? = null
    private var targetDeviceName: String? = null

    private val intentFilter = IntentFilter().apply {
        addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
        addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
        addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
        addAction(WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.wifi_direct/channel")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> initializeWifiDirect(result)
                "discoverPeers" -> startPeerDiscovery(result)
                "requestPeers" -> requestPeerList(result)
                "setTargetDeviceName" -> setTargetDeviceName(call, result)
                "connectToPeer" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    if (deviceAddress != null) {
                        connectToPeer(deviceAddress, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Device address is null", null)
                    }
                }

                "checkConnectionStatus" -> checkConnectionStatus(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun initializeWifiDirect(result: MethodChannel.Result) {
        try {
            wifiP2pManager = getSystemService(Context.WIFI_P2P_SERVICE) as WifiP2pManager
            wifiP2pChannel = wifiP2pManager.initialize(this, mainLooper, null)
            receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    when (intent.action) {
                        WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> {
                            wifiP2pManager.requestConnectionInfo(wifiP2pChannel) { info: WifiP2pInfo? ->
                                val isConnected = info?.groupFormed ?: false
                                channel.invokeMethod("onPeerConnected", mapOf("deviceIP" to isConnected))
                
                                Log.e("WiFiDirect", "WECALLCHANNEL $isConnected ${info?.groupOwnerAddress?.hostAddress}")

                                if (isConnected) {
                                    channel.invokeMethod("onPeerConnected", mapOf("deviceIP" to info?.groupOwnerAddress?.hostAddress))
                                }
                            }
                        }
                    }
                }
            }
            registerReceiver(receiver, intentFilter)
            result.success("WiFi Direct Initialized")
        } catch (e: Exception) {
            result.error("INITIALIZATION_ERROR", e.message, null)
        }
    }

    private fun checkConnectionStatus(result: MethodChannel.Result) {
        if (!this::wifiP2pManager.isInitialized || !this::wifiP2pChannel.isInitialized) {
            result.error("NOT_INITIALIZED", "WiFi Direct not initialized", null)
            return
        }
    
        wifiP2pManager.requestConnectionInfo(wifiP2pChannel) { info: WifiP2pInfo? ->
            val isConnected = info?.groupFormed ?: false
            val deviceAddress = info?.groupOwnerAddress?.hostAddress ?: ""
    
            wifiP2pManager.requestPeers(wifiP2pChannel) { peers ->
                val device = peers.deviceList.find { it.deviceAddress == deviceAddress }
                val deviceName = device?.deviceName ?: "Unknown"
    
                runOnUiThread {
                    result.success(
                        mapOf(
                            "connected" to isConnected,
                            "deviceIP" to deviceAddress,
                            "deviceName" to deviceName
                        )
                    )
                }
            }
        }
    }
    

    private fun startPeerDiscovery(result: MethodChannel.Result) {
        wifiP2pManager.discoverPeers(wifiP2pChannel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                result.success(true)
            }

            override fun onFailure(reasonCode: Int) {
                result.error("DISCOVERY_ERROR", "Failed to start discovery: $reasonCode", null)
            }
        })
    }

    private fun setTargetDeviceName(call: MethodCall, result: MethodChannel.Result) {
        val deviceName = call.argument<String>("deviceName")?.lowercase()
        if (deviceName == null) {
            Log.e("WiFiDirect", "setTargetDeviceName failed: Device name is null")
            result.error("INVALID_ARGUMENT", "Device name is null", null)
            return
        }
    
        targetDeviceName = deviceName
        Log.d("WiFiDirect", "Target device name set: $targetDeviceName")
    
        retryDiscoverPeers(result, 3) // Retry up to 3 times
    }
    
    private fun retryDiscoverPeers(result: MethodChannel.Result, retriesLeft: Int) {
        if (retriesLeft <= 0) {
            Log.e("WiFiDirect", "Target device not found after multiple attempts")
            result.error("DEVICE_NOT_FOUND", "Target device not found after multiple attempts", null)
            return
        }
    
        wifiP2pManager.discoverPeers(wifiP2pChannel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                Log.d("WiFiDirect", "Peer discovery started successfully, attempts left: $retriesLeft")
    
                Handler(Looper.getMainLooper()).postDelayed({
                    wifiP2pManager.requestPeers(wifiP2pChannel) { peers ->
                        Log.d("WiFiDirect", "Received peer list: ${peers.deviceList}")
    
                        val device = peers.deviceList.find { it.deviceName.lowercase() == targetDeviceName }
                        Log.d("WiFiDirect", "Devices: ${peers.deviceList}")
    
                        if (device != null) {
                            Log.d("WiFiDirect", "Matching device found: ${device.deviceName} - ${device.deviceAddress}")
                            connectToPeer(device.deviceAddress, result)
                        } else {
                            Log.d("WiFiDirect", "Target device not found, retrying... (${retriesLeft - 1} retries left)")
                            retryDiscoverPeers(result, retriesLeft - 1) // Retry discovery
                        }
                    }
                }, 3000) // 3-second delay
            }
    
            override fun onFailure(reasonCode: Int) {
                Log.e("WiFiDirect", "Peer discovery failed with reason code: $reasonCode")
                result.error("DISCOVERY_FAILED", "Failed to start discovery: $reasonCode", null)
            }
        })
    }
    
    private fun connectToPeer(deviceAddress: String, result: MethodChannel.Result) {
        val config = WifiP2pConfig().apply {
            this.deviceAddress = deviceAddress
        }
    
        wifiP2pManager.connect(wifiP2pChannel, config, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                Log.d("WiFiDirect", "Connection initiated to $deviceAddress")
    
                wifiP2pManager.requestConnectionInfo(wifiP2pChannel) { info: WifiP2pInfo? ->
                    val isConnected = info?.groupFormed ?: false
                    if (isConnected) {
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
            }
    
            override fun onFailure(reasonCode: Int) {
                Log.e("WiFiDirect", "Connection failed: $reasonCode")
                result.success(false)
            }
        })
    }

    private fun requestPeerList(result: MethodChannel.Result) {
        wifiP2pManager.requestPeers(wifiP2pChannel) { peers ->
            val peerList = peers.deviceList.map { device ->
                mapOf(
                    "deviceName" to device.deviceName,
                    "deviceAddress" to device.deviceAddress
                )
            }
            result.success(peerList)
        }
    }
    

    override fun onResume() {
        super.onResume()
        receiver?.let { registerReceiver(it, intentFilter) }
    }

    override fun onPause() {
        super.onPause()
        receiver?.let { unregisterReceiver(it) }
    }
}