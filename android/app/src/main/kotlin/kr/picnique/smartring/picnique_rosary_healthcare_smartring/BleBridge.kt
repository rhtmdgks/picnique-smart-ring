// ------------------------------------------------------------
// file: app/src/main/java/com/example/picnique_ring/BleBridge.kt
// ------------------------------------------------------------
package kr.picnique.smartring.picnique_rosary_healthcare_smartring

import android.app.Application
import android.bluetooth.BluetoothDevice
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log

import com.google.gson.Gson

import com.oudmon.ble.base.bean.SleepDisplay
import com.oudmon.ble.base.bluetooth.BleOperateManager
import com.oudmon.ble.base.communication.CommandHandle
import com.oudmon.ble.base.communication.Constants
import com.oudmon.ble.base.communication.ICommandResponse
import com.oudmon.ble.base.communication.ILargeDataSleepResponse
import com.oudmon.ble.base.communication.LargeDataHandler
import com.oudmon.ble.base.communication.bigData.BloodOxygenEntity
import com.oudmon.ble.base.communication.bigData.IBloodOxygenCallback
import com.oudmon.ble.base.communication.bigData.ILargeSettingForLongDataResponse
import com.oudmon.ble.base.communication.dfu_temperature.TemperatureEntity
import com.oudmon.ble.base.communication.dfu_temperature.TemperatureOnceEntity
import com.oudmon.ble.base.communication.file.FileHandle
import com.oudmon.ble.base.communication.file.SimpleCallback
import com.oudmon.ble.base.communication.req.BaseReqCmd
import com.oudmon.ble.base.communication.req.BloodOxygenSettingReq
import com.oudmon.ble.base.communication.req.BpSettingReq
import com.oudmon.ble.base.communication.req.HRVReq
import com.oudmon.ble.base.communication.req.HeartRateSettingReq
import com.oudmon.ble.base.communication.req.HrvSettingReq
import com.oudmon.ble.base.communication.req.PressureReq
import com.oudmon.ble.base.communication.req.PressureSettingReq
import com.oudmon.ble.base.communication.req.ReadDetailSportDataReq
import com.oudmon.ble.base.communication.req.ReadHeartRateReq
import com.oudmon.ble.base.communication.req.SimpleKeyReq
import com.oudmon.ble.base.communication.req.SetTimeReq
import com.oudmon.ble.base.communication.rsp.BaseRspCmd
import com.oudmon.ble.base.communication.rsp.BatteryRsp
import com.oudmon.ble.base.communication.rsp.BloodOxygenSettingRsp
import com.oudmon.ble.base.communication.rsp.BpSettingRsp
import com.oudmon.ble.base.communication.rsp.HRVRsp
import com.oudmon.ble.base.communication.rsp.HRVSettingRsp
import com.oudmon.ble.base.communication.rsp.HeartRateSettingRsp
import com.oudmon.ble.base.communication.rsp.LongSitResp
import com.oudmon.ble.base.communication.rsp.PressureRsp
import com.oudmon.ble.base.communication.rsp.PressureSettingRsp
import com.oudmon.ble.base.communication.rsp.ReadDetailSportDataRsp
import com.oudmon.ble.base.communication.rsp.ReadHeartRateRsp
import com.oudmon.ble.base.communication.rsp.StartHeartRateRsp
import com.oudmon.ble.base.communication.rsp.SetTimeRsp
import com.oudmon.ble.base.communication.rsp.BpDataRsp
import com.oudmon.ble.base.communication.req.CameraReq
import com.oudmon.ble.base.communication.rsp.CameraNotifyRsp
import com.oudmon.ble.base.request.ReadRequest
import com.oudmon.ble.base.scan.ScanRecord
import com.oudmon.ble.base.scan.ScanWrapperCallback
import com.oudmon.ble.base.util.ISleepCallback
import com.oudmon.ble.base.util.SleepAnalyzerUtils
import com.oudmon.ble.base.communication.responseImpl.DeviceNotifyListener
import com.oudmon.ble.base.communication.rsp.DeviceNotifyRsp
import com.oudmon.ble.base.bluetooth.ListenerKey
import com.oudmon.ble.base.communication.utils.BLEDataFormatUtils
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean
import java.util.Calendar


private const val TAG = "BleBridge"
private var largeDataNotifyEnabled = false

private fun ensureLargeDataNotifyEnabled() {
    if (!largeDataNotifyEnabled) {
        LargeDataHandler.getInstance().initEnable()
        largeDataNotifyEnabled = true
        Log.i("LargeData", "Serial-port notify enabled")
    }
}


class OneShotResult(private val delegate: MethodChannel.Result) : MethodChannel.Result {
    private val once = AtomicBoolean(false)
    private val main = Handler(Looper.getMainLooper())
    override fun success(result: Any?) {
        if (once.compareAndSet(false, true)) {
            if (Looper.myLooper() == Looper.getMainLooper()) delegate.success(result)
            else main.post { delegate.success(result) }
        }
    }
    override fun error(code: String, msg: String?, details: Any?) {
        if (once.compareAndSet(false, true)) {
            if (Looper.myLooper() == Looper.getMainLooper()) delegate.error(code, msg, details)
            else main.post { delegate.error(code, msg, details) }
        }
    }
    override fun notImplemented() {
        if (once.compareAndSet(false, true)) {
            if (Looper.myLooper() == Looper.getMainLooper()) delegate.notImplemented()
            else main.post { delegate.notImplemented() }
        }
    }
}

/** Simple EventChannel emitter wrapper */
class EventEmitter : EventChannel.StreamHandler {
    private var sink: EventChannel.EventSink? = null
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null }
    fun emit(event: Map<String, Any?>) { sink?.success(event) }
}

class BleBridge(private val appContext: Context) : RingMeasurementSessionHost {
    private val mainHandler = Handler(Looper.getMainLooper())

    val measurementSession = RingMeasurementSession(this)

    private var healthEventSink: ((Any?) -> Unit)? = null

    fun setHealthEventSink(sink: ((Any?) -> Unit)?) {
        healthEventSink = sink
    }

    // Expose as StreamHandler for EventChannel
    private val emitter = EventEmitter()
    val eventStreamHandler: EventChannel.StreamHandler = emitter

    private fun mapSpo2DeviceError(errCode: Int): Triple<String, String, Map<String, Any>> {
        val details = mapOf("deviceErrCode" to errCode)
        return when (errCode) {
            1 -> Triple("SPO2_MANUAL_BUSY", "Device errCode=1 (busy)", details)
            2 -> Triple("SPO2_MANUAL_SENSOR_ERR", "Device errCode=2 (sensor)", details)
            3, 5 -> Triple("SPO2_MANUAL_WEAR", "Device errCode=$errCode (not worn)", details)
            4 -> Triple("SPO2_MANUAL_TIMEOUT", "Device errCode=4 (device timeout)", details)
            else -> Triple("SPO2_MANUAL_DEVICE_ERR", "Device errCode=$errCode", details)
        }
    }

    private fun mapHrDeviceError(errCode: Int): Triple<String, String, Map<String, Any>> {
        val details = mapOf("deviceErrCode" to errCode)
        return when (errCode) {
            1 -> Triple(
                "HR_MANUAL_BUSY",
                "Device errCode=1 (busy)",
                details,
            )
            2 -> Triple(
                "HR_MANUAL_SENSOR_ERR",
                "Device errCode=2 (sensor)",
                details,
            )
            3, 5 -> Triple(
                "HR_MANUAL_WEAR",
                "Device errCode=$errCode (not worn)",
                details,
            )
            4 -> Triple(
                "HR_MANUAL_DEVICE_TIMEOUT",
                "Device errCode=4 (device timeout)",
                details,
            )
            else -> Triple(
                "HR_MANUAL_DEVICE_ERR",
                "Device errCode=$errCode",
                details,
            )
        }
    }

    private var realtimeListener: DeviceNotifyListener? = null

    // ---- Scan callback skeleton ----
    private val scanCallback = object : ScanWrapperCallback {
        override fun onStart() { Log.i(TAG, "scan start") }
        override fun onStop() { Log.i(TAG, "scan stop") }
        override fun onLeScan(device: BluetoothDevice, rssi: Int, record: ByteArray) {}
        override fun onScanFailed(errorCode: Int) {
            Log.w(TAG, "scan failed: $errorCode")
            emitter.emit(mapOf("type" to "scanFailed", "code" to errorCode))
        }
        override fun onParsedData(device: BluetoothDevice, scanRecord: ScanRecord) {
            emitter.emit(
                mapOf(
                    "type" to "scanResult",
                    "address" to device.address,
                    "name" to (device.name ?: "")
                )
            )
        }
        override fun onBatchScanResults(results: MutableList<android.bluetooth.le.ScanResult>?) {}
    }

    // --------------------------------------------------------
    // Flutter -> Android methods
    // --------------------------------------------------------

    fun startScan(namePrefix: String?, timeoutMs: Int, result: MethodChannel.Result) {
        try {
            // TODO: Hook actual SDK scanning API, e.g., BleScannerHelper.scanDevice(..., scanCallback)
            mainHandler.postDelayed({ stopScan(MethodResult.noop()) }, timeoutMs.toLong())
            result.success(true)
        } catch (t: Throwable) {
            result.error("SCAN_START_FAIL", t.message, null)
        }
    }

    fun stopScan(result: MethodChannel.Result) {
        try {
            // TODO: Hook actual SDK stop scan API
            result.success(true)
        } catch (t: Throwable) {
            result.error("SCAN_STOP_FAIL", t.message, null)
        }
    }

    fun connectDirectly(deviceAddress: String?, result: MethodChannel.Result) {
        if (deviceAddress.isNullOrBlank()) {
            result.error("BAD_ARGS", "deviceAddress is required", null)
            return
        }
        try {
            val app = (appContext.applicationContext as Application)
            BleOperateManager.getInstance(app).connectDirectly(deviceAddress)
            emitter.emit(
                mapOf(
                    "type" to "connected",
                    "address" to deviceAddress,
                    "name" to ""
                )
            )
            result.success(true)
        } catch (t: Throwable) {
            result.error("CONNECT_FAIL", t.message, null)
        }
    }

    fun reconnectKnownDevice(deviceAddress: String?, result: MethodChannel.Result) {
        connectDirectly(deviceAddress, result)
    }

    fun connectWithScan(deviceAddress: String?, result: MethodChannel.Result) {
        if (deviceAddress.isNullOrBlank()) {
            result.error("BAD_ARGS", "deviceAddress is required", null)
            return
        }
        try {
            val app = (appContext.applicationContext as Application)
            BleOperateManager.getInstance(app).connectWithScan(deviceAddress)
            emitter.emit(
                mapOf(
                    "type" to "connected",
                    "address" to deviceAddress,
                    "name" to ""
                )
            )
            result.success(true)
        } catch (t: Throwable) {
            result.error("CONNECT_SCAN_FAIL", t.message, null)
        }
    }

    fun setNeedConnect(needConnect: Boolean, result: MethodChannel.Result) {
        try {
            val app = (appContext.applicationContext as Application)
            BleOperateManager.getInstance(app).setNeedConnect(needConnect)
            result.success(true)
        } catch (t: Throwable) {
            result.error("SET_NEED_CONNECT_FAIL", t.message, null)
        }
    }

    fun disconnect(result: MethodChannel.Result) {
        try {
            val app = (appContext.applicationContext as Application)
            BleOperateManager.getInstance(app).disconnect()
            emitter.emit(
                mapOf(
                    "type" to "disconnected",
                    "address" to null,
                    "error" to ""
                )
            )
            result.success(true)
        } catch (t: Throwable) {
            result.error("DISCONNECT_FAIL", t.message, null)
        }
    }

    fun getBatteryLevel(result: MethodChannel.Result) {
        try {
            val req = SimpleKeyReq(Constants.CMD_GET_DEVICE_ELECTRICITY_VALUE)

            var responded = false
            val timeout = Runnable {
                if (!responded) {
                    responded = true
                    result.error("BATTERY_TIMEOUT", "BatteryRsp not received in time", null)
                }
            }
            mainHandler.postDelayed(timeout, 10_000)

            CommandHandle.getInstance().executeReqCmd(req, object : ICommandResponse<BatteryRsp> {
                override fun onDataResponse(response: BatteryRsp?) {
                    if (responded) return
                    responded = true
                    mainHandler.removeCallbacks(timeout)

                    if (response == null) {
                        result.error("BATTERY_NULL", "BatteryRsp is null", null)
                        return
                    }
                    val level = response.getBatteryValue()
                    result.success(level)
                }
            })
        } catch (t: Throwable) {
            result.error("BATTERY_FAIL", t.message, null)
        }
    }

    /** 배터리 % + 충전 여부 (백그라운드 주기 확인용). */
    fun getBatteryStatus(result: MethodChannel.Result) {
        try {
            val req = SimpleKeyReq(Constants.CMD_GET_DEVICE_ELECTRICITY_VALUE)

            var responded = false
            val timeout = Runnable {
                if (!responded) {
                    responded = true
                    result.error("BATTERY_TIMEOUT", "BatteryRsp not received in time", null)
                }
            }
            mainHandler.postDelayed(timeout, 10_000)

            CommandHandle.getInstance().executeReqCmd(req, object : ICommandResponse<BatteryRsp> {
                override fun onDataResponse(response: BatteryRsp?) {
                    if (responded) return
                    responded = true
                    mainHandler.removeCallbacks(timeout)

                    if (response == null) {
                        result.error("BATTERY_NULL", "BatteryRsp is null", null)
                        return
                    }
                    val level = response.getBatteryValue()
                    val chargingRaw = reflectInt(
                        response,
                        "getCharging",
                        "charging",
                        "isCharging",
                        "getChargingState",
                    ) ?: 0
                    result.success(
                        mapOf(
                            "level" to level,
                            "battery" to level,
                            "charging" to (chargingRaw > 0),
                        ),
                    )
                }
            })
        } catch (t: Throwable) {
            result.error("BATTERY_FAIL", t.message, null)
        }
    }

    fun syncTimeAndGetCoreFeatures(result: MethodChannel.Result) {
        val safe = OneShotResult(result)
        val main = Handler(Looper.getMainLooper())
        try {
            CommandHandle.getInstance().executeReqCmd(
                SetTimeReq(0),
                object : ICommandResponse<SetTimeRsp> {
                    override fun onDataResponse(rsp: SetTimeRsp?) {
                        if (rsp == null) {
                            safe.error("NULL_RSP", "SetTimeRsp is null", null)
                            return
                        }
                        val out = mapOf(
                            "supportTemperature" to rsp.mSupportTemperature,
                            "supportPlate" to rsp.mSupportPlate,
                            "supportMenstruation" to rsp.mSupportMenstruation,
                            "supportCustomWallpaper" to rsp.mSupportCustomWallpaper,
                            "supportBloodOxygen" to rsp.mSupportBloodOxygen,
                            "supportBloodPressure" to rsp.mSupportBloodPressure,
                            "supportFeature" to rsp.mSupportFeature,              // 피로도
                            "supportOneKeyCheck" to rsp.mSupportOneKeyCheck,      // 원클릭 측정
                            "supportWeather" to rsp.mSupportWeather,
                            "newSleepProtocol" to rsp.mNewSleepProtocol,
                            "maxWatchFace" to rsp.mMaxWatchFace,                  // 3 또는 6
                            "supportHrv" to rsp.mSupportHrv,

                            "supportContact"        to rsp.mSupportContact,
                            "supportManualHeart"    to rsp.mSupportManualHeart,
                            "supportECard"          to rsp.mSupportECard,
                            "supportLocation"       to rsp.mSupportLocation,
                            "maxContacts"           to rsp.mMaxContacts,          // 0이면 20, 아니면 data[12]*10
                            "musicSupport"          to rsp.mMusicSupport,
                            "rtkMcu"                to rsp.rtkMcu,                // RTK MCU 여부
                            "ebookSupport"          to rsp.mEbookSupport,
                            "supportWeChat"         to rsp.mSupportWeChat
                        )
                        safe.success(out)
                        return
                    }
                }
            )
        } catch (e: Throwable) {
            safe.error("SET_TIME_EX", e.message, null)
        }
    }


    fun readHardwareRevision(result: MethodChannel.Result) {
        try {
            val readReq: ReadRequest = CommandHandle.getInstance().readHwRequest
            CommandHandle.getInstance().execReadCmd(readReq)
            result.success(true)
        } catch (t: Throwable) {
            result.error("READ_HW_FAIL", t.message, null)
        }
    }

    fun readFirmwareRevision(result: MethodChannel.Result) {
        try {
            val readReq: ReadRequest = CommandHandle.getInstance().readFmRequest
            CommandHandle.getInstance().execReadCmd(readReq)
            result.success(true)
        } catch (t: Throwable) {
            result.error("READ_FW_FAIL", t.message, null)
        }
    }

    fun enableRealtimeNotifications(result: MethodChannel.Result) {
        try {
            // 이미 등록되어 있으면 다시 등록하지 않음
            if (realtimeListener != null) {
                result.success(true)
                return
            }

            // SDK 문서의 MyDeviceNotifyListener 를 그대로 옮긴 느낌의 리스너
            val listener = object : DeviceNotifyListener() {
                override fun onDataResponse(rsp: DeviceNotifyRsp?) {
                    if (rsp == null) return

                    // status 가 OK 인 것만 처리
                    if (rsp.status != BaseRspCmd.RESULT_OK) {
                        Log.w(TAG, "realtime notify status != OK : ${rsp.status}")
                        return
                    }

                    // 다른 리스너는 제거 (문서 예제처럼)
                    BleOperateManager.getInstance().removeOthersListener()

                    val dataType = rsp.dataType
                    val load = rsp.loadData
                    val hex = bytesToHex(load)

                    when (dataType) {
                        1 -> {
                            // 실시간 심박 변화
                            emitter.emit(
                                mapOf(
                                    "type"     to "rtHeart",
                                    "dataType" to dataType,
                                    "rawHex"   to hex
                                )
                            )
                        }
                        2 -> {
                            // 실시간 혈압 변화
                            emitter.emit(
                                mapOf(
                                    "type"     to "rtBloodPressure",
                                    "dataType" to dataType,
                                    "rawHex"   to hex
                                )
                            )
                        }
                        3 -> {
                            // 실시간 혈중산소 변화
                            emitter.emit(
                                mapOf(
                                    "type"     to "rtBloodOxygen",
                                    "dataType" to dataType,
                                    "rawHex"   to hex
                                )
                            )
                        }
                        4 -> {
                            // 걸음 수 디테일 변화
                            emitter.emit(
                                mapOf(
                                    "type"     to "rtStepDetail",
                                    "dataType" to dataType,
                                    "rawHex"   to hex
                                )
                            )
                        }
                        5 -> {
                            // 당일 체온 변화
                            emitter.emit(
                                mapOf(
                                    "type"     to "rtTemperature",
                                    "dataType" to dataType,
                                    "rawHex"   to hex
                                )
                            )
                        }
                        7 -> {
                            // 새 운동 기록 생성됨 (운동 자동 감지 끝나고 기록 하나 생겼다고 보면 됨)
                            emitter.emit(
                                mapOf(
                                    "type"     to "rtSportRecordNew",
                                    "dataType" to dataType,
                                    "rawHex"   to hex
                                )
                            )
                        }
                        0x0c -> {
                            // 충전/배터리 상태 변경 (문서 예제 참고)
                            val charging = BLEDataFormatUtils.bytes2Int(
                                byteArrayOf(load[2])
                            )
                            val battery = BLEDataFormatUtils.bytes2Int(
                                byteArrayOf(load[1])
                            )
                            if (charging > 0) {
                                emitter.emit(
                                    mapOf(
                                        "type"   to "rtCharging",
                                        "isCharging" to true,
                                        "percent" to battery,
                                        "rawHex" to hex
                                    )
                                )
                            } else {
                                emitter.emit(
                                    mapOf(
                                        "type"    to "rtBattery",
                                        "percent" to battery,
                                        "isCharging" to false,
                                        "rawHex"  to hex
                                    )
                                )
                            }
                        }
                        0x12 -> {
                            // 실시간 걸음/칼로리/거리 (문서 예제: step, calorie, distance)
                            val step = BLEDataFormatUtils.bytes2Int(
                                byteArrayOf(load[1], load[2], load[3])
                            )
                            val calorie = BLEDataFormatUtils.bytes2Int(
                                byteArrayOf(load[4], load[5], load[6])
                            )
                            val distance = BLEDataFormatUtils.bytes2Int(
                                byteArrayOf(load[7], load[8], load[9])
                            )

                            emitter.emit(
                                mapOf(
                                    "type"     to "rtSportSummary",
                                    "steps"    to step,
                                    "calorie"  to calorie,
                                    "distance" to distance,
                                    "rawHex"   to hex
                                )
                            )
                        }
                        else -> {
                            // 알 수 없는 타입은 그냥 raw 만 넘겨줌
                            emitter.emit(
                                mapOf(
                                    "type"     to "rtUnknown",
                                    "dataType" to dataType,
                                    "rawHex"   to hex
                                )
                            )
                        }
                    }
                }
            }

            // ListenerKey.All 로 모든 측정 변경 이벤트를 받음 (문서 기준)
            BleOperateManager.getInstance().addOutDeviceListener(ListenerKey.All, listener)

            realtimeListener = listener

            result.success(true)
        } catch (t: Throwable) {
            result.error("ENABLE_NOTIFY_FAIL", t.message, null)
        }
    }


    fun disableRealtimeNotifications(result: MethodChannel.Result) {
        try {
            // 문서 기준: 등록한 리스너는 꼭 제거해줘야 중복 콜백이 안 쌓임
            BleOperateManager.getInstance().removeNotifyListener(ListenerKey.All)
            realtimeListener = null
            result.success(true)
        } catch (t: Throwable) {
            result.error("DISABLE_NOTIFY_FAIL", t.message, null)
        }
    }


    fun readHrSetting(result: MethodChannel.Result) {
        try {
            CommandHandle.getInstance().executeReqCmd(
                HeartRateSettingReq.getReadInstance(),
                object : ICommandResponse<HeartRateSettingRsp> {
                    override fun onDataResponse(rsp: HeartRateSettingRsp?) {
                        if (rsp == null) { result.error("HR_READ_NULL", "HeartRateSettingRsp null", null); return }
                        val enabled = reflectBool(rsp, "isEnable", "getIsEnable", "getEnable") ?: false
                        val interval = reflectInt(rsp, "getHeartInterval", "heartInterval") ?: -1
                        result.success(mapOf("isEnable" to enabled, "interval" to interval))
                    }
                }
            )
        } catch (t: Throwable) { result.error("HR_READ_FAIL", t.message, null) }
    }


    fun writeHrSetting(isEnable: Boolean, interval: Int, result: MethodChannel.Result) {
        try {
            CommandHandle.getInstance().executeReqCmd(
                HeartRateSettingReq.getWriteInstance(isEnable, interval),
                object : ICommandResponse<HeartRateSettingRsp> {
                    override fun onDataResponse(rsp: HeartRateSettingRsp?) {
                        if (rsp == null) { result.error("HR_WRITE_NULL", "HeartRateSettingRsp null", null); return }
                        val enabled = reflectBool(rsp, "isEnable", "getIsEnable", "getEnable") ?: isEnable
                        val intervalRsp = reflectInt(rsp, "getHeartInterval", "heartInterval") ?: interval
                        result.success(mapOf("isEnable" to enabled, "interval" to intervalRsp))
                    }
                }
            )
        } catch (t: Throwable) { result.error("HR_WRITE_FAIL", t.message, null) }
    }

    fun readSpo2Setting(result: MethodChannel.Result) {
        try {
            CommandHandle.getInstance().executeReqCmd(
                BloodOxygenSettingReq.getReadInstance(),
                object : ICommandResponse<BloodOxygenSettingRsp> {
                    override fun onDataResponse(rsp: BloodOxygenSettingRsp?) {
                        if (rsp == null) { result.error("SPO2_READ_NULL", "BloodOxygenSettingRsp null", null); return }
                        val enabled = reflectBool(rsp, "isEnable", "getIsEnable", "getEnable") ?: false
                        result.success(mapOf("isEnable" to enabled))
                    }
                }
            )
        } catch (t: Throwable) { result.error("SPO2_READ_FAIL", t.message, null) }
    }


    fun writeSpo2Setting(isEnable: Boolean, result: MethodChannel.Result) {
        try {
            CommandHandle.getInstance().executeReqCmd(
                BloodOxygenSettingReq.getWriteInstance(isEnable),
                object : ICommandResponse<BloodOxygenSettingRsp> {
                    override fun onDataResponse(rsp: BloodOxygenSettingRsp?) {
                        if (rsp == null) { result.error("SPO2_WRITE_NULL", "BloodOxygenSettingRsp null", null); return }
                        val enabled = reflectBool(rsp, "isEnable", "getIsEnable", "getEnable") ?: isEnable
                        result.success(mapOf("isEnable" to enabled))
                    }
                }
            )
        } catch (t: Throwable) { result.error("SPO2_WRITE_FAIL", t.message, null) }
    }

    fun readBpSetting(result: MethodChannel.Result) {
        try {
            CommandHandle.getInstance().executeReqCmd(
                BpSettingReq.getReadInstance(),
                object : ICommandResponse<BpSettingRsp> {
                    override fun onDataResponse(rsp: BpSettingRsp?) {
                        if (rsp == null) { result.error("BP_READ_NULL", "BpSettingRsp null", null); return }
                        val enabled = reflectBool(rsp, "isEnable", "getIsEnable", "getEnable") ?: false
                        val multiple = reflectInt(rsp, "getMultiple", "multiple") ?: 60
                        val windowObj = reflectObj(rsp, "getStartEndTimeEntity", "startEndTimeEntity")
                        val startHour = reflectInt(windowObj, "getStartHour", "startHour")
                        val startMinute = reflectInt(windowObj, "getStartMinute", "startMinute")
                        val endHour = reflectInt(windowObj, "getEndHour", "endHour")
                        val endMinute = reflectInt(windowObj, "getEndMinute", "endMinute")
                        val window = if (windowObj != null) mapOf(
                            "startHour" to startHour, "startMinute" to startMinute,
                            "endHour" to endHour, "endMinute" to endMinute
                        ) else null
                        result.success(mapOf("isEnable" to enabled, "multiple" to multiple, "window" to window))
                    }
                }
            )
        } catch (t: Throwable) { result.error("BP_READ_FAIL", t.message, null) }
    }

    fun writeBpSetting(
        isEnable: Boolean,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        multiple: Int,
        result: MethodChannel.Result
    ) {
        try {
            val startEnd = makeStartEndTimeEntity(startHour, startMinute, endHour, endMinute)
                ?: run { result.error("BP_CLASS_NOT_FOUND", "StartEndTimeEntity class not found", null); return }

            // reflect static: BpSettingReq.getWriteInstance(boolean, StartEndTimeEntity, int)
            val cls = Class.forName("com.oudmon.ble.base.communication.req.BpSettingReq")
            val startEndCls = startEnd.javaClass
            val method = cls.getMethod("getWriteInstance", java.lang.Boolean.TYPE, startEndCls, Integer.TYPE)
            val reqAny = method.invoke(null, isEnable, startEnd, multiple)
            val req = reqAny as? BaseReqCmd ?: run { result.error("BP_REQ_BAD", "Failed to build request", null); return }

            CommandHandle.getInstance().executeReqCmd(req, object : ICommandResponse<BpSettingRsp> {
                override fun onDataResponse(rsp: BpSettingRsp?) {
                    if (rsp == null) { result.error("BP_WRITE_NULL", "BpSettingRsp null", null); return }
                    val enabled = reflectBool(rsp, "isEnable", "getIsEnable", "getEnable") ?: isEnable
                    val mult = reflectInt(rsp, "getMultiple", "multiple") ?: multiple
                    result.success(mapOf("isEnable" to enabled, "multiple" to mult))
                }
            })
        } catch (t: Throwable) { result.error("BP_WRITE_FAIL", t.message, null) }
    }

    fun readPressureSetting(result: MethodChannel.Result) {
        try {
            CommandHandle.getInstance().executeReqCmd(
                PressureSettingReq.getReadInstance(),
                object : ICommandResponse<PressureSettingRsp> {
                    override fun onDataResponse(rsp: PressureSettingRsp?) {
                        if (rsp == null) { result.error("PRESS_READ_NULL", "PressureSettingRsp null", null); return }
                        val enabled = reflectBool(rsp, "isEnable", "getIsEnable", "getEnable") ?: false
                        result.success(mapOf("isEnable" to enabled))
                    }
                }
            )
        } catch (t: Throwable) { result.error("PRESS_READ_FAIL", t.message, null) }
    }


    fun writePressureSetting(isEnable: Boolean, result: MethodChannel.Result) {
        try {
            CommandHandle.getInstance().executeReqCmd(
                PressureSettingReq.getWriteInstance(isEnable),
                object : ICommandResponse<PressureSettingRsp> {
                    override fun onDataResponse(rsp: PressureSettingRsp?) {
                        if (rsp == null) { result.error("PRESS_WRITE_NULL", "PressureSettingRsp null", null); return }
                        val enabled = reflectBool(rsp, "isEnable", "getIsEnable", "getEnable") ?: isEnable
                        result.success(mapOf("isEnable" to enabled))
                    }
                }
            )
        } catch (t: Throwable) { result.error("PRESS_WRITE_FAIL", t.message, null) }
    }

    fun readHrvSetting(result: MethodChannel.Result) {
        try {
            CommandHandle.getInstance().executeReqCmd(
                HrvSettingReq.getReadInstance(),
                object : ICommandResponse<HRVSettingRsp> {
                    override fun onDataResponse(rsp: HRVSettingRsp?) {
                        if (rsp == null) { result.error("HRV_READ_NULL", "HRVSettingRsp null", null); return }
                        val enabled = reflectBool(rsp, "isEnable", "getIsEnable", "getEnable") ?: false
                        result.success(mapOf("isEnable" to enabled))
                    }
                }
            )
        } catch (t: Throwable) { result.error("HRV_READ_FAIL", t.message, null) }
    }


    fun writeHrvSetting(isEnable: Boolean, result: MethodChannel.Result) {
        try {
            CommandHandle.getInstance().executeReqCmd(
                HrvSettingReq(isEnable),
                object : ICommandResponse<HRVSettingRsp> {
                    override fun onDataResponse(rsp: HRVSettingRsp?) {
                        if (rsp == null) { result.error("HRV_WRITE_NULL", "HRVSettingRsp null", null); return }
                        val enabled = reflectBool(rsp, "isEnable", "getIsEnable", "getEnable") ?: isEnable
                        result.success(mapOf("isEnable" to enabled))
                    }
                }
            )
        } catch (t: Throwable) { result.error("HRV_WRITE_FAIL", t.message, null) }
    }

    // ---- reflection helpers ----
    private fun reflectBool(obj: Any?, vararg names: String): Boolean? {
        if (obj == null) return null
        for (n in names) try {
            val m = obj.javaClass.methods.firstOrNull { it.name == n && it.parameterCount == 0 }
            if (m != null) {
                val v = m.invoke(obj)
                if (v is Boolean) return v
                if (v is java.lang.Boolean) return v.booleanValue()
            }
        } catch (_: Exception) {}
        return null
    }
    private fun reflectInt(obj: Any?, vararg names: String): Int? {
        if (obj == null) return null
        for (n in names) try {
            val m = obj.javaClass.methods.firstOrNull { it.name == n && it.parameterCount == 0 }
            if (m != null) {
                val v = m.invoke(obj)
                if (v is Int) return v
                if (v is java.lang.Integer) return v.toInt()
            }
        } catch (_: Exception) {}
        return null
    }
    private fun reflectObj(obj: Any?, vararg names: String): Any? {
        if (obj == null) return null
        for (n in names) try {
            val m = obj.javaClass.methods.firstOrNull { it.name == n && it.parameterCount == 0 }
            if (m != null) return m.invoke(obj)
        } catch (_: Exception) {}
        return null
    }

    private fun makeStartEndTimeEntity(sh: Int, sm: Int, eh: Int, em: Int): Any? {
        val cands = arrayOf(
            "com.oudmon.ble.base.communication.req.StartEndTimeEntity",
            "com.oudmon.ble.base.communication.req.bean.StartEndTimeEntity",
            "com.oudmon.ble.base.communication.req.entity.StartEndTimeEntity"
        )
        for (cn in cands) try {
            val cls = Class.forName(cn)
            val obj = cls.getDeclaredConstructor().newInstance()
            fun set(name: String, value: Int) {
                try {
                    val m = cls.methods.firstOrNull { it.name.equals(name, true) && it.parameterCount == 1 }
                    if (m != null) m.invoke(obj, value)
                    else try {
                        val f = cls.getDeclaredField(name)
                        f.isAccessible = true
                        f.set(obj, value)
                    } catch (_: Exception) {}
                } catch (_: Exception) {}
            }
            set("setStartHour", sh); set("startHour", sh)
            set("setStartMinute", sm); set("startMinute", sm)
            set("setEndHour", eh); set("endHour", eh)
            set("setEndMinute", em); set("endMinute", em)
            return obj
        } catch (_: Exception) {}
        return null
    }

    // ----------------------
    // DATA SYNC (steps/sleep/hr/bp/spo2/pressure/hrv/temperature)
    // ----------------------


    fun syncTodaySport(result: MethodChannel.Result) {
        try {
            val req = SimpleKeyReq(Constants.CMD_GET_STEP_TODAY)
            CommandHandle.getInstance().executeReqCmd(req, object : ICommandResponse<BaseRspCmd> {
                override fun onDataResponse(rsp: BaseRspCmd?) {
                    if (rsp == null) { result.error("SPORT_TODAY_NULL", "TodaySportDataRsp null", null); return }
                    val map = mapOf(
                        "daysAgo" to reflectInt(rsp, "getDaysAgo", "daysAgo"),
                        "year" to reflectInt(rsp, "getYear", "year"),
                        "month" to reflectInt(rsp, "getMonth", "month"),
                        "day" to reflectInt(rsp, "getDay", "day"),
                        "totalSteps" to reflectInt(rsp, "getTotalSteps", "totalSteps"),
                        "runningSteps" to reflectInt(rsp, "getRunningSteps", "runningSteps"),
                        "calorie" to reflectInt(rsp, "getCalorie", "calorie"),
                        "walkDistance" to reflectInt(rsp, "getWalkDistance", "walkDistance"),
                        "sportDuration" to reflectInt(rsp, "getSportDuration", "sportDuration"),
                        "sleepDuration" to reflectInt(rsp, "getSleepDuration", "sleepDuration")
                    )
                    result.success(map)
                }
            })
        } catch (t: Throwable) { result.error("SPORT_TODAY_FAIL", t.message, null) }
    }
    fun syncSportDetail(dayOffset: Int, result: MethodChannel.Result) {
        val once = OneShotResult(result)
        try {
            CommandHandle.getInstance().executeReqCmd(
                ReadDetailSportDataReq(dayOffset, 0, 95),
                object : ICommandResponse<ReadDetailSportDataRsp> {

                    override fun onDataResponse(rsp: ReadDetailSportDataRsp?) {
                        if (rsp == null) {
                            once.error("SPORT_DETAIL_NULL", "ReadDetailSportDataRsp null", null)
                            return
                        }

                        val listObj = reflectObj(rsp, "getBleStepDetailses", "bleStepDetailses") as? Iterable<*>
                        if (listObj == null) {
                            once.success(mapOf("details" to emptyList<Map<String, Any?>>()))
                            return
                        }

                        val details = mutableListOf<Map<String, Any?>>()
                        for (item in listObj) {
                            if (item != null) {
                                details.add(
                                    mapOf(
                                        "year"      to reflectInt(item, "getYear", "year"),
                                        "month"     to reflectInt(item, "getMonth", "month"),
                                        "day"       to reflectInt(item, "getDay", "day"),
                                        "timeIndex" to reflectInt(item, "getTimeIndex", "timeIndex"),
                                        "calorie"   to reflectInt(item, "getCalorie", "calorie"),
                                        "walkSteps" to reflectInt(item, "getWalkSteps", "walkSteps"),
                                        "distance"  to reflectInt(item, "getDistance", "distance"),
                                        "runSteps"  to reflectInt(item, "getRunSteps", "runSteps")
                                    )
                                )
                            }
                        }

                        once.success(mapOf("details" to details))
                    }
                }
            )
        } catch (t: Throwable) {
            once.error("SPORT_DETAIL_FAIL", t.message, null)
        }
    }


    fun syncSleepDisplay(
        deviceAddress: String?,
        dayOffset: Int,
        result: MethodChannel.Result
    ) {
        val once = OneShotResult(result)

        if (deviceAddress.isNullOrBlank()) {
            once.error("SLEEP_DISPLAY_ARG", "deviceAddress is null/blank", null)
            return
        }

        try {
            SleepAnalyzerUtils.getInstance().syncSleepReturnSleepDisplay(
                deviceAddress,
                dayOffset,
                object : ISleepCallback {
                    override fun sleepDisplay(display: SleepDisplay?) {
                        if (display == null) {
                            once.success(null)
                            return
                        }

                        val listObj = reflectObj(display, "getList", "list")
                        val beans = mutableListOf<Map<String, Any?>>()
                        if (listObj is Iterable<*>) {
                            for (it in listObj) {
                                beans.add(
                                    mapOf(
                                        "sleepStart" to (reflectObj(it, "getSleepStart", "sleepStart") as? Number)?.toLong(),
                                        "sleepEnd"   to (reflectObj(it, "getSleepEnd", "sleepEnd") as? Number)?.toLong(),
                                        "type"       to  reflectInt(it, "getType", "type")
                                    )
                                )
                            }
                        }

                        val payload = mapOf(
                            "totalSleepDuration"   to reflectInt(display, "getTotalSleepDuration", "totalSleepDuration"),
                            "deepSleepDuration"    to reflectInt(display, "getDeepSleepDuration", "deepSleepDuration"),
                            "shallowSleepDuration" to reflectInt(display, "getShallowSleepDuration", "shallowSleepDuration"),
                            "awakeDuration"        to reflectInt(display, "getAwakeDuration", "awakeDuration"),
                            "sleepTime"            to reflectInt(display, "getSleepTime", "sleepTime"),
                            "wakeTime"             to reflectInt(display, "getWakeTime", "wakeTime"),
                            "address"              to (reflectObj(display, "getAddress", "address") as? String),
                            "list"                 to beans
                        )

                        once.success(payload)
                    }
                }
            )
        } catch (t: Throwable) {
            once.error("SLEEP_DISPLAY_FAIL", t.message, null)
        }
    }


    private fun reflectLong(obj: Any, getter: String, field: String): Long {
        return try {
            val m = obj.javaClass.methods.firstOrNull { it.name == getter } ?: throw NoSuchMethodException()
            (m.invoke(obj) as Number).toLong()
        } catch (_: Throwable) {
            try {
                val f = obj.javaClass.declaredFields.first { it.name == field }
                f.isAccessible = true
                (f.get(obj) as Number).toLong()
            } catch (_: Throwable) { 0L }
        }
    }

    fun syncSleepNew(offset: Int, result: MethodChannel.Result) {
        ensureLargeDataNotifyEnabled()
        val main = android.os.Handler(android.os.Looper.getMainLooper())
        val replied = java.util.concurrent.atomic.AtomicBoolean(false)

        fun finishSuccess(payload: Map<String, Any?>?) {
            if (replied.compareAndSet(false, true)) main.post { result.success(payload) }
        }

        fun finishError(code: String, msg: String?) {
            if (replied.compareAndSet(false, true)) main.post { result.error(code, msg, null) }
        }

        // (선택) 시리얼포트 notify 보증
        // LargeDataHandler.getInstance().initEnable()

        // 워치독
        val watchdog = Runnable { finishError("SLEEP_NEW_TIMEOUT", "sleep proto timeout") }
        main.postDelayed(watchdog, 30_000)

        val clamped = if (offset <= 0) 0 else 1

        try {
            LargeDataHandler.getInstance().syncSleepList(
                clamped,
                object : ILargeDataSleepResponse {
                    override fun sleepData(resp: SleepDisplay?) {
                        main.removeCallbacks(watchdog)
                        try {
                            if (resp == null) return finishSuccess(null)
                            // *** 핵심: SleepDisplay의 올바른 getter 사용 ***
                            val st = reflectInt(resp, "getSleepTime", "sleepTime")
                            val et0 = reflectInt(resp, "getWakeTime", "wakeTime")
                            if(st == null || et0 == null) return finishSuccess(null)

                            val listObj = reflectObj(resp, "getList", "list")
                            val details = mutableListOf<Map<String, Any?>>()

                            if (listObj is Iterable<*>) {
                                for (item in listObj) {
                                    val start = reflectLong(item!!, "getSleepStart", "sleepStart")
                                    val end = reflectLong(item, "getSleepEnd", "sleepEnd")
                                    val type = reflectInt(item, "getType", "type")
                                    val dSec = ((end - start).coerceAtLeast(0L)).toInt()

                                    // SleepDisplay.Type(1=deep,2=light,3=awake,4=rem) → proto t(3,2,5,4)
                                    val t = when (type) {
                                        1 -> 3   // deep
                                        2 -> 2   // light
                                        3 -> 5   // awake
                                        4 -> 4   // rem
                                        else -> 0
                                    }
                                    details.add(mapOf("d" to dSec, "t" to t))
                                }
                            }

                            // et 누락/0일 때 보정
                            val et = if (et0 > 0) et0 else (st + details.sumOf { (it["d"] as Int) })

                            val payload = mapOf(
                                "st" to st,          // epoch-sec
                                "et" to et,          // epoch-sec
                                "list" to details    // [{d: seconds, t: 2|3|4|5}]
                            )
                            finishSuccess(payload)
                        } catch (t: Throwable) {
                            finishError("SLEEP_NEW_FAIL", t.message)
                        }
                    }
                }
            )
        } catch (t: Throwable) {
            main.removeCallbacks(watchdog)
            finishError("SLEEP_NEW_FAIL", t.message)
        }
    }


    // ---- Sedentary(장시간 좌식) 동기화 ----
    // offset: 0=오늘, 1=어제 (라이브러리 내부에서 0 -> 0, 그 외 -> -1 전송)
    fun syncSedentary(offset: Int, result: MethodChannel.Result) {
        try {
            LargeDataHandler.getInstance().syncLongSitList(
                offset,
                object : ILargeSettingForLongDataResponse {
                    override fun sleepData(resp: LongSitResp?) {
                        if (resp == null) { result.success(null); return }

                        val listObj = reflectObj(resp, "getList", "list")
                        val details = mutableListOf<Map<String, Any?>>()
                        if (listObj is Iterable<*>) {
                            for (it in listObj) {
                                details.add(
                                    mapOf(
                                        "d" to reflectInt(it, "getD", "d"),
                                        "t" to reflectInt(it, "getT", "t")
                                    )
                                )
                            }
                        }
                        val payload = mapOf(
                            "index" to reflectInt(resp, "getIndex", "index"),
                            "list"  to details
                        )
                        result.success(payload)
                    }
                }
            )
        } catch (t: Throwable) { result.error("SEDENTARY_FAIL", t.message, null) }
    }


    // ---- Heart Rate ----
    fun syncHeartRate(nowTime: Long?, result: MethodChannel.Result) {
        val once = OneShotResult(result)  // ← 중복 호출 가드
        try {
            val tzHours: Long = (java.util.TimeZone.getDefault().rawOffset / 3_600_000).toLong() // ms→h (DST 미포함)
            val computedNow: Long = (System.currentTimeMillis() / 1000L) + tzHours * 3600
            val reqTime: Long = nowTime ?: computedNow

            CommandHandle.getInstance().executeReqCmd(
                ReadHeartRateReq(reqTime),
                object : ICommandResponse<ReadHeartRateRsp> {
                    override fun onDataResponse(rsp: ReadHeartRateRsp?) {
                        if (rsp == null) {
                            once.error("HR_NULL", "ReadHeartRateRsp null", null)
                            return
                        }

                        val utcTime = rsp.getmUtcTime()
                        val endFlag = rsp.isEndFlag()
                        val heartArray = rsp.getmHeartRateArray() ?: ByteArray(0)
                        val hrList = heartArray.map { it.toInt() and 0xFF }

                        once.success(
                            mapOf(
                                "utcTime"        to utcTime,
                                "heartRateArray" to hrList,  // 5분 간격(인덱스*5=분)
                                "endFlag"        to endFlag
                            )
                        )
                    }

                }
            )
        } catch (t: Throwable) {
            once.error("HR_FAIL", t.message, null)
        }
    }



    private fun wrapManualResult(
        result: MethodChannel.Result,
        onComplete: () -> Unit,
    ): MethodChannel.Result = object : MethodChannel.Result {
        override fun success(r: Any?) {
            result.success(r)
            onComplete()
        }

        override fun error(code: String, msg: String?, details: Any?) {
            result.error(code, msg, details)
            onComplete()
        }

        override fun notImplemented() {
            result.notImplemented()
            onComplete()
        }
    }

    fun syncManualHeartRate(result: MethodChannel.Result) {
        measurementSession.resetToIdle()
        val main = android.os.Handler(android.os.Looper.getMainLooper())
        val replied = java.util.concurrent.atomic.AtomicBoolean(false)
        val TIMEOUT_MS = 45_000L

        fun u8(x: Any?): Int = when (x) {
            is Byte  -> x.toInt() and 0xFF
            is Short -> x.toInt() and 0xFF
            is Int   -> x and 0xFF
            is Number-> x.toInt() and 0xFF
            else     -> 0
        }
        fun optUxx(obj: Any, field: String): Int? = try {
            val f = obj.javaClass.getDeclaredField(field).apply { isAccessible = true }
            when (val v = f.get(obj)) {
                is Byte  -> v.toInt() and 0xFF
                is Short -> v.toInt() and 0xFFFF
                is Int   -> v
                is Number-> v.toInt()
                else     -> null
            }
        } catch (_: Throwable) { null }

        fun finishOk(payload: Map<String, Any?>) {
            if (replied.compareAndSet(false, true)) main.post { result.success(payload) }
        }
        fun finishErr(code: String, msg: String?) {
            if (replied.compareAndSet(false, true)) main.post { result.error(code, msg, null) }
        }

        main.postDelayed({
            finishErr("HR_MANUAL_TIMEOUT", "no final manual HR within ${TIMEOUT_MS}ms")
        }, TIMEOUT_MS)

        try {
            BleOperateManager.getInstance()
                .manualModeHeart(object : ICommandResponse<StartHeartRateRsp?> {
                    override fun onDataResponse(rsp: StartHeartRateRsp?) {
                        if (replied.get()) return
                        if (rsp == null) return finishErr("HR_MANUAL_NULL", "StartHeartRateRsp null")

                        val errCode = u8(rsp.errCode)
                        val bpm = u8(rsp.value)
                        val rri = optUxx(rsp, "rri") ?: 0
                        val status = optUxx(rsp, "status") ?: -1

                        if (errCode != 0) {
                            return finishErr("HR_MANUAL_DEVICE_ERR", "Device errCode=$errCode")
                        }

                        val isFinal = when {
                            status >= 0 -> status == 1
                            else -> bpm > 0
                        }
                        if (!isFinal) return
                        if (bpm <= 0) return finishErr("HR_MANUAL_EMPTY", "no HR value")

                        finishOk(
                            mapOf(
                                "type" to 1,
                                "errCode" to 0,
                                "hr" to bpm,
                                "value" to bpm,
                                "rri" to rri,
                            )
                        )
                    }
                })
        } catch (t: Throwable) {
            finishErr("HR_MANUAL_START_FAIL", t.message ?: "manualModeHeart threw")
        }
    }

    override fun runManualHeartRate(result: MethodChannel.Result, onComplete: () -> Unit) {
        syncManualHeartRate(wrapManualResult(result, onComplete))
    }

    // ---- Blood Pressure: Auto (매시 정시) ----
    fun syncAutoBp(result: MethodChannel.Result) {
        try {
            val req = SimpleKeyReq(Constants.CMD_BP_TIMING_MONITOR_DATA)
            CommandHandle.getInstance().executeReqCmd(req, object : ICommandResponse<BpDataRsp> {
                override fun onDataResponse(rsp: BpDataRsp) {
                    if (rsp == null) {
                        result.error("BP_AUTO_NULL", "BpDataRsp null", null)
                        return
                    }

                    // BpDataEntity 가져오기 (직접 호출 가능하면 reflectObj 대신 rsp.getBpDataEntity() 사용)
                    val entity = reflectObj(rsp, "getBpDataEntity", "bpDataEntity")
                    if (entity == null) {
                        result.error("BP_AUTO_EMPTY", "BpDataEntity is null", null)
                        return
                    }

                    // 값 리스트 추출
                    val rawList = reflectObj(entity, "getBpValues", "bpValues") as? Iterable<*>
                    val values = mutableListOf<Map<String, Any?>>()
                    rawList?.forEach { v ->
                        if (v != null) {
                            values.add(
                                mapOf(
                                    "timeMinute" to reflectInt(v, "getTimeMinute", "timeMinute"),
                                    "value"      to reflectInt(v, "getValue", "value")
                                )
                            )
                        }
                    }

                    // 최종 맵 구성 (month는 getMouth 오타 대응)
                    val out = mapOf(
                        "year"      to reflectInt(entity, "getYear", "year"),
                        "month"     to reflectInt(entity, "getMonth", "getMouth", "month", "mouth"),
                        "day"       to reflectInt(entity, "getDay", "day"),
                        "timeDelay" to reflectInt(entity, "getTimeDelay", "timeDelay"),
                        "bpValues"  to values
                    )

                    result.success(out)
                }

                // 만약 ICommandResponse에 실패 콜백이 있다면 함께 구현
                // override fun onFailed(e: Exception?) {
                //     result.error("BP_AUTO_FAIL", e?.message, null)
                // }
            })
        } catch (t: Throwable) {
            result.error("BP_AUTO_FAIL", t.message, null)
        }
    }


    // ---- Blood Pressure: Manual ----
    fun syncManualBp(offset: Long, result: MethodChannel.Result) {
        try {
            BleOperateManager.getInstance()
                .manualModeHeart(object : ICommandResponse<StartHeartRateRsp?> {
                    override fun onDataResponse(resultEntity: StartHeartRateRsp?) {

                    }
                })
        } catch (t: Throwable) { result.error("BP_MANUAL_FAIL", t.message, null) }
    }


    // ---- Blood Oxygen ----
    fun syncBloodOxygen(result: MethodChannel.Result) {
        val once = OneShotResult(result)
        ensureLargeDataNotifyEnabled()
        val main = android.os.Handler(android.os.Looper.getMainLooper())
        val TIMEOUT_MS = 30_000L
        val watchdog = Runnable { once.error("BLOOD_OXYGEN_TIMEOUT", "blood oxygen callback timeout", null) }
        try {
            Log.i("BleBridge", "syncBloodOxygen start")
            main.postDelayed(watchdog, TIMEOUT_MS)
            LargeDataHandler.getInstance().syncBloodOxygenWithCallback(
                object : IBloodOxygenCallback {
                    override fun readBloodOxygen(data: MutableList<BloodOxygenEntity>?) {
                        main.removeCallbacks(watchdog)
                        val out: List<Map<String, Any?>> = data?.map { e ->
                            val dateStr = (reflectObj(e, "getDateStr", "dateStr") as? String)

                            val minAny = reflectObj(e, "getMinArray", "minArray")
                            val minArray: List<Int> = when (minAny) {
                                is IntArray  -> minAny.toList()
                                is ByteArray -> minAny.map { it.toInt() and 0xFF }
                                is List<*>   -> minAny.mapNotNull { (it as? Number)?.toInt() }
                                else         -> emptyList()
                            }

                            val maxAny = reflectObj(e, "getMaxArray", "maxArray")
                            val maxArray: List<Int> = when (maxAny) {
                                is IntArray  -> maxAny.toList()
                                is ByteArray -> maxAny.map { it.toInt() and 0xFF }
                                is List<*>   -> maxAny.mapNotNull { (it as? Number)?.toInt() }
                                else         -> emptyList()
                            }

                            val unixAny = reflectObj(e, "getUnix_time", "getUnixTime", "unix_time", "unixTime")
                            val unixTime = (unixAny as? Number)?.toLong()

                            mapOf(
                                "dateStr"   to dateStr,
                                "minArray"  to minArray,
                                "maxArray"  to maxArray,
                                "unix_time" to unixTime
                            )
                        } ?: emptyList()

                        once.success(out)  // ← 한 번만 성공 반환
                    }
                }
            )
        } catch (t: Throwable) {
            main.removeCallbacks(watchdog)
            once.error("BLOOD_OXYGEN_FAIL", t.message, null)
        }
    }

        // ---- Manual SpO2 ----
    fun syncManualSpO2(result: MethodChannel.Result) {
        measurementSession.resetToIdle()
        val main = android.os.Handler(android.os.Looper.getMainLooper())
        val replied = java.util.concurrent.atomic.AtomicBoolean(false)
        val TIMEOUT_MS = 45_000L

        fun u8(x: Any?): Int = when (x) {
            is Byte  -> x.toInt() and 0xFF
            is Short -> x.toInt() and 0xFF
            is Int   -> x and 0xFF
            is Number-> x.toInt() and 0xFF
            else     -> 0
        }
        fun optUxx(obj: Any, field: String): Int? = try {
            val f = obj.javaClass.getDeclaredField(field).apply { isAccessible = true }
            when (val v = f.get(obj)) {
                is Byte  -> v.toInt() and 0xFF
                is Short -> v.toInt() and 0xFFFF
                is Int   -> v
                is Number-> v.toInt()
                else     -> null
            }
        } catch (_: Throwable) { null }

        fun finishOk(payload: Map<String, Any?>) {
            if (replied.compareAndSet(false, true)) main.post { result.success(payload) }
        }
        fun finishErr(code: String, msg: String?) {
            if (replied.compareAndSet(false, true)) main.post { result.error(code, msg, null) }
        }

        main.postDelayed({
            finishErr("SPO2_MANUAL_TIMEOUT", "no final manual SpO2 within ${TIMEOUT_MS}ms")
        }, TIMEOUT_MS)

        try {
            BleOperateManager.getInstance()
                .manualModeSpO2(object : ICommandResponse<StartHeartRateRsp?> {
                    override fun onDataResponse(rsp: StartHeartRateRsp?) {
                        if (replied.get()) return
                        if (rsp == null) return finishErr("SPO2_MANUAL_NULL", "StartHeartRateRsp null")

                        val type = u8(rsp.type)
                        val errCode = u8(rsp.errCode)
                        val spo2 = u8(rsp.value)
                        val rri = optUxx(rsp, "rri") ?: 0
                        val status = optUxx(rsp, "status") ?: -1

                        if (errCode != 0) {
                            return finishErr("SPO2_MANUAL_DEVICE_ERR", "Device errCode=$errCode")
                        }

                        val isFinal = when {
                            status >= 0 -> status == 1
                            else -> spo2 > 0
                        }
                        if (!isFinal) return
                        if (spo2 <= 0 || spo2 > 100) {
                            return finishErr("SPO2_MANUAL_RANGE", "out-of-range spo2=$spo2")
                        }

                        finishOk(
                            mapOf(
                                "type" to (if (type != 0) type else 3),
                                "errCode" to 0,
                                "spo2" to spo2,
                                "value" to spo2,
                                "rri" to rri,
                            )
                        )
                    }
                })
        } catch (t: Throwable) {
            finishErr("SPO2_MANUAL_FAIL", t.message)
        }
    }

    override fun runManualSpO2(result: MethodChannel.Result, onComplete: () -> Unit) {
        syncManualSpO2(wrapManualResult(result, onComplete))
    }




    // ---- Stress (Pressure) ----
    fun syncPressure(offset: Byte, result: MethodChannel.Result) {
        val once = OneShotResult(result)
        try {
            Log.d("BLE", "offset: $offset")
            CommandHandle.getInstance().executeReqCmd(
                PressureReq(offset),
                object : ICommandResponse<PressureRsp> {
                    override fun onDataResponse(rsp: PressureRsp?) {
                        if (rsp == null) {
                            once.error("PRESSURE_NULL", "PressureRsp null", null)
                            return
                        }
                        val gson = Gson()
                        Log.d("BLE", "rsp = ${gson.toJson(rsp)}")

                        val arrObj = reflectObj(rsp, "getPressureArray", "pressureArray")
                        val array: List<Int> = when (arrObj) {
                            is ByteArray -> arrObj.map { it.toInt() and 0xFF }
                            is IntArray  -> arrObj.toList()
                            is List<*>   -> arrObj.filterIsInstance<Number>().map { it.toInt() }
                            else         -> emptyList()
                        }

                        val today = reflectObj(rsp, "getToday", "today")
                        val todayMap = if (today != null)
                            mapOf(
                                "year"  to reflectInt(today, "getYear", "year"),
                                "month" to reflectInt(today, "getMonth", "month"),
                                "day"   to reflectInt(today, "getDay", "day")
                            ) else null

                        once.success(
                            mapOf(
                                "range" to (reflectInt(rsp, "getRange", "range") ?: 30),
                                "array" to array,
                                "today" to todayMap
                            )
                        )
                    }
                }
            )
        } catch (t: Throwable) {
            once.error("PRESSURE_FAIL", t.message, null)
        }
    }

    // ---- Manual Pressure (스트레스) ----
    fun syncManualPressure(result: MethodChannel.Result) {
        measurementSession.resetToIdle()
        val main = android.os.Handler(android.os.Looper.getMainLooper())
        val replied = java.util.concurrent.atomic.AtomicBoolean(false)
        val TIMEOUT_MS = 45_000L

        fun u8(x: Any?): Int = when (x) {
            is Byte  -> x.toInt() and 0xFF
            is Short -> x.toInt() and 0xFF
            is Int   -> x and 0xFF
            is Number-> x.toInt() and 0xFF
            else     -> 0
        }
        fun optUxx(obj: Any, field: String): Int? = try {
            val f = obj.javaClass.getDeclaredField(field).apply { isAccessible = true }
            when (val v = f.get(obj)) {
                is Byte  -> v.toInt() and 0xFF
                is Short -> v.toInt() and 0xFFFF
                is Int   -> v
                is Number-> v.toInt()
                else     -> null
            }
        } catch (_: Throwable) { null }

        fun finishOk(payload: Map<String, Any?>) {
            if (replied.compareAndSet(false, true)) main.post { result.success(payload) }
        }
        fun finishErr(code: String, msg: String?) {
            if (replied.compareAndSet(false, true)) main.post { result.error(code, msg, null) }
        }

        main.postDelayed({
            finishErr("PRESSURE_MANUAL_TIMEOUT", "no final manual Pressure within ${TIMEOUT_MS}ms")
        }, TIMEOUT_MS)

        try {
            BleOperateManager.getInstance()
                .manualModePressure(object : ICommandResponse<StartHeartRateRsp?> {
                    override fun onDataResponse(rsp: StartHeartRateRsp?) {
                        if (replied.get()) return
                        if (rsp == null) return finishErr("PRESSURE_MANUAL_NULL", "StartHeartRateRsp null")

                        val type = optUxx(rsp, "type") ?: -1
                        val errCode = u8(rsp.errCode)
                        val value = u8(rsp.value)
                        val sbp = u8(rsp.sbp)
                        val dbp = u8(rsp.dbp)
                        val rri = optUxx(rsp, "rri") ?: 0

                        if (errCode != 0) {
                            return finishErr("PRESSURE_MANUAL_DEVICE_ERR", "Device errCode=$errCode")
                        }
                        if (value > 0) {
                            return finishOk(
                                mapOf(
                                    "type" to type,
                                    "errCode" to 0,
                                    "pressure" to value,
                                    "value" to value,
                                    "rri" to rri,
                                )
                            )
                        }
                        if (sbp > 0 || dbp > 0) {
                            return finishOk(
                                mapOf(
                                    "type" to type,
                                    "errCode" to 0,
                                    "sbp" to sbp,
                                    "dbp" to dbp,
                                )
                            )
                        }
                    }
                })
        } catch (t: Throwable) {
            finishErr("PRESSURE_MANUAL_FAIL", t.message)
        }
    }

    override fun runManualPressure(result: MethodChannel.Result, onComplete: () -> Unit) {
        syncManualPressure(wrapManualResult(result, onComplete))
    }


    // ---- HRV ----
    fun syncHrv(offset: Byte, result: MethodChannel.Result) {
        try {
            CommandHandle.getInstance().executeReqCmd(
                HRVReq(offset),
                object : ICommandResponse<HRVRsp> {
                    override fun onDataResponse(rsp: HRVRsp?) {
                        if (rsp == null) { result.error("HRV_NULL", "HRVRsp null", null); return }

                        val arrObj = reflectObj(rsp, "getHrvArray", "getPressureArray", "hrvArray", "pressureArray")
                        val array: List<Int> = when (arrObj) {
                            is ByteArray -> arrObj.map { it.toInt() and 0xFF }
                            is IntArray  -> arrObj.toList()
                            is List<*>   -> arrObj.filterIsInstance<Number>().map { it.toInt() }
                            else         -> emptyList()
                        }
                        val today = reflectObj(rsp, "getToday", "today")
                        val todayMap = if (today != null)
                            mapOf(
                                "year"  to reflectInt(today, "getYear", "year"),
                                "month" to reflectInt(today, "getMonth", "month"),
                                "day"   to reflectInt(today, "getDay", "day")
                            ) else null

                        result.success(
                            mapOf(
                                "range" to (reflectInt(rsp, "getRange", "range") ?: 30),
                                "array" to array,
                                "today" to todayMap
                            )
                        )
                    }
                }
            )
        } catch (t: Throwable) { result.error("HRV_FAIL", t.message, null) }
    }

    // ---- Manual HRV ----
    fun syncManualHrv(result: MethodChannel.Result) {
        val main = android.os.Handler(android.os.Looper.getMainLooper())
        val replied = java.util.concurrent.atomic.AtomicBoolean(false)
        val TIMEOUT_MS = 45_000L

        fun u8(x: Any?): Int = when (x) {
            is Byte  -> x.toInt() and 0xFF
            is Short -> x.toInt() and 0xFF
            is Int   -> x and 0xFF
            is Number-> x.toInt() and 0xFF
            else     -> 0
        }
        fun u16(x: Any?): Int = when (x) {
            is Short -> x.toInt() and 0xFFFF
            is Int   -> x and 0xFFFF
            is Number-> x.toInt() and 0xFFFF
            is Byte  -> x.toInt() and 0xFF
            else     -> 0
        }
        fun optUxx(obj: Any, field: String): Int? = try {
            val f = obj.javaClass.getDeclaredField(field).apply { isAccessible = true }
            when (val v = f.get(obj)) {
                is Byte  -> v.toInt() and 0xFF
                is Short -> v.toInt() and 0xFFFF
                is Int   -> v
                is Number-> v.toInt()
                else     -> null
            }
        } catch (_: Throwable) { null }

        fun finishOk(payload: Map<String, Any?>) {
            if (replied.compareAndSet(false, true)) main.post { result.success(payload) }
        }
        fun finishErr(code: String, msg: String?) {
            if (replied.compareAndSet(false, true)) main.post { result.error(code, msg, null) }
        }

        // 타임아웃
        main.postDelayed({
            finishErr("HRV_MANUAL_TIMEOUT", "no final manual HRV within ${TIMEOUT_MS}ms")
        }, TIMEOUT_MS)

        try {
            BleOperateManager.getInstance()
                .manualModeHrv(object : ICommandResponse<StartHeartRateRsp?> {
                    override fun onDataResponse(rsp: StartHeartRateRsp?) {
                        if (replied.get()) return
                        if (rsp == null) return finishErr("HRV_MANUAL_NULL", "StartHeartRateRsp null")

                        try {
                            val gson = com.google.gson.GsonBuilder().serializeNulls().create()
                            android.util.Log.d("BLE", "HRV(manual) rsp(json) = ${gson.toJson(rsp)}")
                        } catch (_: Throwable) { }

                        val type    = optUxx(rsp, "type") ?: -1   // HRV도 모델별로 type 정의가 다를 수 있음
                        val errCode = u8(rsp.errCode)
                        val hrvVal  = u8(rsp.value)              // 일부 기기에서 HRV 지수(또는 SDNN 유사)가 여기
                        val rri     = optUxx(rsp, "rri") ?: 0    // R-R interval(있을 때만)
                        val sbp     = u8(rsp.sbp)                // 의미 없을 가능성 높음
                        val dbp     = u8(rsp.dbp)
                        val status  = optUxx(rsp, "status") ?: -1

                        android.util.Log.d(
                            "BLE",
                            "HRV(manual) parsed: type=$type err=$errCode hrvVal=$hrvVal rri=$rri status=$status sbp=$sbp dbp=$dbp"
                        )

                        if (errCode != 0) return finishErr("HRV_MANUAL_DEVICE_ERR", "Device errCode=$errCode")

                        // 최종 판단: rri>0 이면 우선적으로 채택, 아니면 value>0 채택
                        if (rri > 0) {
                            return finishOk(
                                mapOf(
                                    "type" to type,
                                    "errCode" to 0,
                                    "rri" to rri,
                                    "hrv" to hrvVal  // 기기별 정의가 다르므로 둘 다 전달
                                )
                            )
                        }
                        if (hrvVal > 0) {
                            return finishOk(
                                mapOf(
                                    "type" to type,
                                    "errCode" to 0,
                                    "hrv" to hrvVal
                                )
                            )
                        }
                        // 그 외에는 최종 프레임을 더 기다림
                    }
                })
        } catch (t: Throwable) {
            finishErr("HRV_MANUAL_FAIL", t.message)
        }
    }



    // ---- Temperature: Callback 등록 ----
    fun registerTempCallback(result: MethodChannel.Result) {
        try {
            FileHandle.getInstance().clearCallback()
            FileHandle.getInstance().registerCallback(object : SimpleCallback() {
                override fun onUpdateTemperature(data: TemperatureEntity) {
                    // 필요 시 EventChannel 등으로 전달
                }
                override fun onUpdateTemperatureList(array: MutableList<TemperatureOnceEntity>) {
                    // 단일 측정 배치 콜백
                }
            })
            FileHandle.getInstance().initRegister()
            result.success(true)
        } catch (t: Throwable) { result.error("TEMP_CB_FAIL", t.message, null) }
    }

    fun syncAutoTemperature(days: Int, result: MethodChannel.Result) {
        try {
            FileHandle.getInstance().clearCallback()
    
            FileHandle.getInstance().registerCallback(object : SimpleCallback() {
    
                override fun onUpdateTemperature(data: TemperatureEntity) {
                    try {
                        Log.d(TAG, "onUpdateTemperature: $data")
                        if (data.mValues != null && data.mValues.isNotEmpty()) {
    
                            val span = data.mTimeSpan   // 분 단위
    
                            // 오늘 0시(로컬 시간) 기준 timestamp 생성
                            val calendar = Calendar.getInstance().apply {
                                set(Calendar.HOUR_OF_DAY, 0)
                                set(Calendar.MINUTE, 0)
                                set(Calendar.SECOND, 0)
                                set(Calendar.MILLISECOND, 0)
                            }
                            val baseUtcMs = calendar.timeInMillis
    
                            // 전체 리스트 구성
                            val tempList = data.mValues.mapIndexed { idx, value ->
                                val ts = baseUtcMs + idx * span * 60 * 1000L
                                mapOf(
                                    "temperature" to value.toDouble(),
                                    "timestamp" to ts
                                )
                            }
    
                            result.success(
                                mapOf(
                                    "temperatures" to tempList,
                                    "source" to "auto"
                                )
                            )
    
                        } else {
                            result.error("TEMP_EMPTY", "Temperature values empty", null)
                        }
                    } catch (e: Exception) {
                        result.error("TEMP_PARSE_FAIL", e.message, null)
                    } finally {
                        FileHandle.getInstance().clearCallback()
                    }
                }

                override fun onUpdateTemperatureList(array: MutableList<TemperatureOnceEntity>) {
                    try {
                        if (array.isEmpty()) {
                            result.error("TEMP_EMPTY", "TemperatureOnceEntity list empty", null)
                            return
                        }
    
                        // TemperatureOnceEntity:
                        //   public long mTime;   // seconds
                        //   public float mValue; // ℃
                        val temps = array.map { entity ->
                            val tsMs = entity.mTime * 1000L
                            mapOf(
                                "temperature" to entity.mValue.toDouble(),
                                "timestamp" to tsMs
                            )
                        }
    
                        result.success(
                            mapOf(
                                "temperatures" to temps,
                                "source" to "auto"
                            )
                        )
                    } catch (e: Exception) {
                        result.error("TEMP_PARSE_FAIL", e.message, null)
                    } finally {
                        // 한 번 받고 콜백 정리
                        FileHandle.getInstance().clearCallback()
                    }
                }
            })

            FileHandle.getInstance().initRegister()
    
            FileHandle.getInstance().startObtainTemperatureSeries(days)
    
        } catch (e: Exception) {
            result.error("TEMP_FAIL", e.message, null)
        }
    }
    

    fun syncManualTemperature(offset: Int, result: MethodChannel.Result) {
        try {
            FileHandle.getInstance().startObtainTemperatureOnce(offset)
            result.success(true)
        } catch (t: Throwable) { result.error("TEMP_ONCE_FAIL", t.message, null) }
    }

    private object MethodResult : MethodChannel.Result {
        fun noop(): MethodChannel.Result = this
        override fun success(result: Any?) {}
        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
        override fun notImplemented() {}
    }

    private fun bytesToHex(bytes: ByteArray?): String {
        if (bytes == null) return ""
        val sb = StringBuilder(bytes.size * 2)
        for (b in bytes) {
            sb.append(String.format("%02X", b))
        }
        return sb.toString()
    }

    override suspend fun performCollect(context: Context) {
        collectAndQueue(context)
    }

    override fun notifyHealthDataReady() {
        healthEventSink?.invoke(mapOf("type" to "healthDataReady"))
    }

    suspend fun collectHealthIfIdle(context: Context, force: Boolean): Boolean =
        measurementSession.collectHealthIfIdle(context, force)

    fun executeManualMeasurement(typeWire: String, result: MethodChannel.Result) {
        when (ManualMeasureType.fromWire(typeWire)) {
            ManualMeasureType.HEART_RATE -> syncManualHeartRate(result)
            ManualMeasureType.BLOOD_OXYGEN -> syncManualSpO2(result)
            ManualMeasureType.STRESS -> syncManualPressure(result)
            null -> result.error("MEASURE_INVALID_TYPE", "unknown type $typeWire", null)
        }
    }

    val isMeasurementBusy: Boolean
        get() = measurementSession.isBusy

    fun resetMeasurementSession() {
        measurementSession.resetToIdle()
    }
}
