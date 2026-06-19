// ------------------------------------------------------------
// file: app/src/main/java/com/example/picnique_ring/MainActivity.kt
// ------------------------------------------------------------
package kr.picnique.smartring.picnique_rosary_healthcare_smartring

import android.app.Application
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.oudmon.ble.base.bluetooth.BleOperateManager
import android.content.IntentFilter
import android.content.Context
import androidx.localbroadcastmanager.content.LocalBroadcastManager

import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.net.Uri

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "com.example.picnique_ring/ble"
        const val EVENT_CHANNEL = "com.example.picnique_ring/ble_events"

        const val FOREGROUND_CHANNEL = "com.example.picnique_ring/foreground_service_channel"
        const val BACKGROUND_CHANNEL = "com.example.picnique_ring/background_keepalive"
    }

    private lateinit var bridge: BleBridge
    private var qcReceiver: QcRawReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val app: Application = this@MainActivity.application
        // Initialize BLE SDK singleton and register receivers
        BleOperateManager.getInstance(app).init()
        // Create bridge after SDK is ready
        bridge = BleBridge(this@MainActivity)
        qcReceiver = QcRawReceiver(bridge)

        val filter = IntentFilter().apply {
            addAction("com.qc.characteristic_changed_qc")
        }

        LocalBroadcastManager.getInstance(this).registerReceiver(qcReceiver!!, filter)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Ensure bridge is ready BEFORE channels use it
        if (!::bridge.isInitialized) {
            bridge = BleBridge(this@MainActivity)
        }
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "startScan" -> bridge.startScan(
                        namePrefix = call.argument<String>("namePrefix"),
                        timeoutMs = call.argument<Int>("timeoutMs") ?: 10_000,
                        result = result
                    )
                    "stopScan" -> bridge.stopScan(result)
                    "connectDirectly" -> bridge.connectDirectly(
                        deviceAddress = call.argument<String>("deviceAddress"),
                        result = result
                    )
                    "reconnectKnownDevice" -> bridge.reconnectKnownDevice(
                        deviceAddress = call.argument<String>("deviceAddress"),
                        result = result
                    )
                    "disconnect" -> bridge.disconnect(result)
                    "getBatteryLevel" -> bridge.getBatteryLevel(result)

                    "syncTimeAndGetCoreFeatures" -> bridge.syncTimeAndGetCoreFeatures(result)

                    "readHw" -> bridge.readHardwareRevision(result)
                    "readFw" -> bridge.readFirmwareRevision(result)
                    "enableRealtime" -> bridge.enableRealtimeNotifications(result)
                    "disableRealtime" -> bridge.disableRealtimeNotifications(result)
                    "readHrSetting" -> bridge.readHrSetting(result)
                    "writeHrSetting" -> bridge.writeHrSetting(
                        isEnable = call.argument<Boolean>("isEnable") ?: false,
                        interval = call.argument<Int>("interval") ?: 30,
                        result = result
                    )
                    "readSpo2Setting" -> bridge.readSpo2Setting(result)
                    "writeSpo2Setting" -> bridge.writeSpo2Setting(
                        isEnable = call.argument<Boolean>("isEnable") ?: false,
                        result = result
                    )
                    "readBpSetting" -> bridge.readBpSetting(result)
                    "writeBpSetting" -> bridge.writeBpSetting(
                        isEnable = call.argument<Boolean>("isEnable") ?: false,
                        startHour = call.argument<Int>("startHour") ?: 9,
                        startMinute = call.argument<Int>("startMinute") ?: 0,
                        endHour = call.argument<Int>("endHour") ?: 21,
                        endMinute = call.argument<Int>("endMinute") ?: 0,
                        multiple = call.argument<Int>("multiple") ?: 60,
                        result = result
                    )
                    "readPressureSetting" -> bridge.readPressureSetting(result)
                    "writePressureSetting" -> bridge.writePressureSetting(
                        isEnable = call.argument<Boolean>("isEnable") ?: false,
                        result = result
                    )
                    "readHrvSetting" -> bridge.readHrvSetting(result)
                    "writeHrvSetting" -> bridge.writeHrvSetting(
                        isEnable = call.argument<Boolean>("isEnable") ?: true,
                        result = result
                    )
                    // ---- Data sync ----
                    "syncTodaySport" -> bridge.syncTodaySport(result)
                    "syncSportDetail" -> bridge.syncSportDetail(
                        dayOffset = call.argument<Int>("dayOffset") ?: 0,
                        result = result
                    )
                    "syncSleepDisplay" -> bridge.syncSleepDisplay(
                        deviceAddress = call.argument<String>("deviceAddress"),
                        dayOffset = call.argument<Int>("dayOffset") ?: 0,
                        result = result
                    )
                    "syncSleepNew" -> bridge.syncSleepNew(
                        offset = call.argument<Int>("offset") ?: 0,
                        result = result
                    )
                    "syncSedentary" -> bridge.syncSedentary(
                        offset = call.argument<Int>("offset") ?: 0,
                        result = result
                    )
                    "syncHeartRate" -> bridge.syncHeartRate(
                        nowTime = call.argument<Number>("nowTime")?.toLong(),
                        result = result
                    )
                    "syncManualHeartRate" -> bridge.syncManualHeartRate(
                        result = result
                    )
                    "syncAutoBp" -> bridge.syncAutoBp(result)
                    "syncManualBp" -> bridge.syncManualBp(
                        offset = call.argument<Number>("offset")?.toLong() ?: 0,
                        result = result
                    )
                    "syncBloodOxygen" -> bridge.syncBloodOxygen(result)
                    "syncManualBloodOxygen" -> bridge.syncManualSpO2(
                        result = result
                    )
                    "syncPressure" -> bridge.syncPressure(
                        offset = call.argument<Number>("offset")?.toByte() ?: 0,
                        result = result
                    )
                    "syncManualPressure" -> bridge.syncManualPressure(
                        result = result
                    )
                    "syncHrv" -> bridge.syncHrv(
                        offset = call.argument<Number>("offset")?.toByte() ?: 0,
                        result = result
                    )
                    "syncManualHrv" -> bridge.syncManualHrv(
                        result = result
                    )
                    "registerTempCallback" -> bridge.registerTempCallback(result)
                    "syncAutoTemperature" -> bridge.syncAutoTemperature(
                        days = call.argument<Int>("days") ?: 2,
                        result = result
                    )
                    "syncManualTemperature" -> bridge.syncManualTemperature(
                        offset = call.argument<Int>("offset") ?: 0,
                        result = result
                    )
                    "enableSimpleTouchLogging" -> bridge.enableSimpleTouchLogging(result)
                    "getRingTouchCount" -> result.success(bridge.getTouchCount())
                    "disableSimpleTouchLogging" -> bridge.disableSimpleTouchLogging(result)
                    "enableRealtimeNotifications" -> bridge.enableRealtimeNotifications(result)
                    "disableRealtimeNotifications" -> bridge.disableRealtimeNotifications(result)
                    "ensureIgnoreBatteryOptimizations" -> ensureIgnoreBatteryOptimizations(result)
                    else -> result.notImplemented()
                }
            }

            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "startService" -> {
                        val intent = Intent(this, MyForegroundService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stopService" -> {
                        val intent = Intent(this, MyForegroundService::class.java)
                        stopService(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKGROUND_CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "startBackgroundKeepalive" -> {
                        val address = call.argument<String>("address")
                        val name = call.argument<String>("name")
                        RingBackgroundPrefs.setKeepalive(this, true, address, name)
                        val intent = Intent(this, MyForegroundService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stopBackgroundKeepalive" -> {
                        RingBackgroundPrefs.setKeepalive(this, false, null, null)
                        val intent = Intent(this, MyForegroundService::class.java)
                        stopService(intent)
                        result.success(true)
                    }
                    "fetchPendingHealthRecords" -> {
                        result.success(PendingHealthQueue.readAll(this))
                    }
                    "clearPendingHealthRecords" -> {
                        PendingHealthQueue.clear(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(bridge.eventStreamHandler)
    }

    private fun ensureIgnoreBatteryOptimizations(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(true)
            return
        }
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val pkg = packageName
        if (pm != null && pm.isIgnoringBatteryOptimizations(pkg)) {
            result.success(true)
            return
        }
        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$pkg")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            // false: 요청 화면을 띄웠음을 의미
            result.success(false)
        } catch (e: Exception) {
            result.error("battery_opt", e.message, null)
        }
    }
    override fun onDestroy() {
        try {
            qcReceiver?.let {
                LocalBroadcastManager.getInstance(this).unregisterReceiver(it)
            }
        } catch (_: Exception) {
            // 필요하면 로그 남겨도 됨
            // Log.e("MainActivity", "Failed to unregister qcReceiver", e)
        }
    
        qcReceiver = null
    
        super.onDestroy()
    }
}
