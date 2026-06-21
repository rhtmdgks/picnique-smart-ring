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

import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.net.Uri
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "com.example.picnique_ring/ble"
        const val EVENT_CHANNEL = "com.example.picnique_ring/ble_events"
        const val HEALTH_EVENT_CHANNEL = "com.example.picnique_ring/health_events"

        const val FOREGROUND_CHANNEL = "com.example.picnique_ring/foreground_service_channel"
        const val BACKGROUND_CHANNEL = "com.example.picnique_ring/background_keepalive"
    }

    private lateinit var bridge: BleBridge

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val app: Application = this@MainActivity.application
        BleOperateManager.getInstance(app).init()
        bridge = BleBridge(this@MainActivity)
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
                    "connectWithScan" -> bridge.connectWithScan(
                        deviceAddress = call.argument<String>("deviceAddress"),
                        result = result
                    )
                    "setNeedConnect" -> bridge.setNeedConnect(
                        needConnect = call.argument<Boolean>("needConnect") ?: true,
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
                        interval = call.argument<Int>("interval")
                            ?: RingMeasurementPolicy.RING_AUTO_HEART_INTERVAL_MINUTES,
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
                    "executeManualMeasurement" -> bridge.executeManualMeasurement(
                        typeWire = call.argument<String>("type") ?: "",
                        result = result,
                    )
                    "isMeasurementBusy" -> result.success(bridge.isMeasurementBusy)
                    "resetMeasurementSession" -> {
                        bridge.resetMeasurementSession()
                        result.success(true)
                    }
                    "collectHealthIfIdle" -> {
                        CoroutineScope(Dispatchers.IO).launch {
                            val ok = bridge.collectHealthIfIdle(
                                this@MainActivity,
                                call.argument<Boolean>("force") ?: false,
                            )
                            withContext(Dispatchers.Main) { result.success(ok) }
                        }
                    }
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
                    "replacePendingHealthRecords" -> {
                        @Suppress("UNCHECKED_CAST")
                        val records = call.argument<List<Map<String, Any?>>>("records")
                            ?: emptyList()
                        PendingHealthQueue.replaceAll(this, records)
                        result.success(true)
                    }
                    "collectPendingHealthNow" -> {
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val address = RingBackgroundPrefs.ringAddress(this@MainActivity)
                                if (!address.isNullOrBlank()) {
                                    bridge.ensureConnected(address)
                                }
                                val ok = bridge.collectHealthIfIdle(
                                    this@MainActivity,
                                    force = true,
                                )
                                withContext(Dispatchers.Main) { result.success(ok) }
                            } catch (t: Throwable) {
                                withContext(Dispatchers.Main) {
                                    result.error(
                                        "COLLECT_FAIL",
                                        t.message,
                                        null,
                                    )
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(bridge.eventStreamHandler)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, HEALTH_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    bridge.setHealthEventSink { payload -> events?.success(payload) }
                }

                override fun onCancel(arguments: Any?) {
                    bridge.setHealthEventSink(null)
                }
            })
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
        super.onDestroy()
    }
}
