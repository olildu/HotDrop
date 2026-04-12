package com.example.test_mobile

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.os.ParcelUuid
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*

class MainActivity: FlutterActivity() {
    
    // ==========================================
    // WI-FI HOTSPOT VARIABLES
    // ==========================================
    private val WIFI_CHANNEL = "com.example.wifi_direct/channel"
    private var reservation: WifiManager.LocalOnlyHotspotReservation? = null

    // ==========================================
    // BLE PERIPHERAL VARIABLES
    // ==========================================
    private val BLE_CHANNEL = "com.example.ble_poc/peripheral"
    private var bluetoothManager: BluetoothManager? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var gattServer: BluetoothGattServer? = null

    private val SERVICE_UUID = UUID.fromString("0000ABCD-0000-1000-8000-00805F9B34FB")
    private val CHAR_UUID = UUID.fromString("0000FFFE-0000-1000-8000-00805F9B34FB")
    private val CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")

    private var currentPayload: String = "{}"
    private val subscribedDevices = mutableSetOf<BluetoothDevice>()

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 1. Register Wi-Fi Direct Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIFI_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLocalOnlyHotspot" -> startHotspot(result)
                "stopLocalOnlyHotspot" -> {
                    stopHotspot()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // 2. Register BLE Peripheral Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAdvertising" -> {
                    val payload = call.argument<String>("payload") ?: "{}"
                    startBlePeripheral(payload)
                    result.success(null)
                }
                "stopAdvertising" -> {
                    stopBlePeripheral()
                    result.success(null)
                }
                "updatePayload" -> {
                    val payload = call.argument<String>("payload") ?: "{}"
                    updatePayloadAndNotify(payload)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ==========================================
    // WI-FI HOTSPOT LOGIC
    // ==========================================
    private fun startHotspot(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            
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

            @SuppressLint("MissingPermission")
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
                        stopHotspot()
                        result.error("UNAVAILABLE", "Configuration is null", null)
                    }
                }

                override fun onStopped() {
                    super.onStopped()
                    reservation = null 
                }

                override fun onFailed(reason: Int) {
                    super.onFailed(reason)
                    reservation = null
                    val msg = when (reason) {
                        WifiManager.LocalOnlyHotspotCallback.ERROR_INCOMPATIBLE_MODE -> "Hotspot already in use."
                        WifiManager.LocalOnlyHotspotCallback.ERROR_NO_CHANNEL -> "No usable channel."
                        WifiManager.LocalOnlyHotspotCallback.ERROR_TETHERING_DISALLOWED -> "Tethering not allowed."
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
        reservation?.close() 
        reservation = null
    }

    // ==========================================
    // BLE PERIPHERAL LOGIC
    // ==========================================
    @SuppressLint("MissingPermission")
    private fun startBlePeripheral(payload: String) {
        currentPayload = payload
        subscribedDevices.clear()

        bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter

        if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
            Log.e("BLE", "Bluetooth not enabled")
            return
        }

        bluetoothAdapter?.name = "HotDrop-Android-Host"

        gattServer?.clearServices()
        gattServer?.close()

        gattServer = bluetoothManager?.openGattServer(this, gattServerCallback)
        setupGattService()
    }

    @SuppressLint("MissingPermission")
    private fun setupGattService() {
        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

        val characteristic = BluetoothGattCharacteristic(
            CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ
        )

        val cccdDescriptor = BluetoothGattDescriptor(
            CCCD_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        characteristic.addDescriptor(cccdDescriptor)

        val payloadBytes = currentPayload.toByteArray(Charsets.UTF_8)
        characteristic.value = payloadBytes

        service.addCharacteristic(characteristic)
        gattServer?.addService(service)
    }

    @SuppressLint("MissingPermission")
    private fun startAdvertisingInternal() {
        bluetoothLeAdvertiser = bluetoothAdapter?.bluetoothLeAdvertiser

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setConnectable(true)
            .build()

        val data = AdvertiseData.Builder().addServiceUuid(ParcelUuid(SERVICE_UUID)).build()
        val scanResponse = AdvertiseData.Builder().setIncludeDeviceName(true).build()

        bluetoothLeAdvertiser?.startAdvertising(settings, data, scanResponse, advertiseCallback)
    }

    @SuppressLint("MissingPermission")
    private fun stopBlePeripheral() {
        bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback)
        gattServer?.clearServices()
        gattServer?.close()
        gattServer = null
        subscribedDevices.clear()
    }

    @SuppressLint("MissingPermission")
    private fun updatePayloadAndNotify(newPayload: String) {
        currentPayload = newPayload
        val service = gattServer?.getService(SERVICE_UUID)
        val characteristic = service?.getCharacteristic(CHAR_UUID)

        if (characteristic != null && subscribedDevices.isNotEmpty()) {
            characteristic.value = currentPayload.toByteArray(Charsets.UTF_8)
            for (device in subscribedDevices) {
                gattServer?.notifyCharacteristicChanged(device, characteristic, false)
                Log.d("BLE", "Notified \${device.address} with: \$currentPayload")
            }
        }
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) { Log.d("BLE", "Advertising started") }
        override fun onStartFailure(errorCode: Int) { Log.e("BLE", "Advertising failed: \$errorCode") }
    }

    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onServiceAdded(status: Int, service: BluetoothGattService) {
            Log.d("BLE", "Service added successfully")
            startAdvertisingInternal()
        }

        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                Log.d("BLE", "Connected: \${device.address}")
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                Log.d("BLE", "Disconnected: \${device.address}")
                subscribedDevices.remove(device)
            }
        }

        @SuppressLint("MissingPermission")
        override fun onDescriptorWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray
        ) {
            if (descriptor.uuid == CCCD_UUID) {
                if (Arrays.equals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE, value)) {
                    Log.d("BLE", "Subscribed: \${device.address}")
                    subscribedDevices.add(device)
                    updatePayloadAndNotify(currentPayload)
                } else if (Arrays.equals(BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE, value)) {
                    Log.d("BLE", "Unsubscribed: \${device.address}")
                    subscribedDevices.remove(device)
                }
                
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                }
            }
        }

        @SuppressLint("MissingPermission")
        override fun onCharacteristicReadRequest(
            device: BluetoothDevice, requestId: Int, offset: Int, characteristic: BluetoothGattCharacteristic
        ) {
            if (characteristic.uuid == CHAR_UUID) {
                val payloadBytes = currentPayload.toByteArray(Charsets.UTF_8)
                characteristic.value = payloadBytes
                val value = if (offset < payloadBytes.size) payloadBytes.copyOfRange(offset, payloadBytes.size) else ByteArray(0)
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
            } else {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, offset, null)
            }
        }
    }
}