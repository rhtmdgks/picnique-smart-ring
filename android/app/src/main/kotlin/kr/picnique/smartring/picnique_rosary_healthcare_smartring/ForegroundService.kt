// ForegroundService.kt
package kr.picnique.smartring.picnique_rosary_healthcare_smartring

import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.oudmon.ble.base.bluetooth.BleOperateManager
import kotlinx.coroutines.*
import java.util.concurrent.TimeUnit

class MyForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "com.example.picnique_ring/foreground_service_channel"
        const val FOREGROUND_NOTI_ID = 1
        private const val TAG = "RingKeepaliveService"
        private val COLLECT_INTERVAL_MS = RingMeasurementPolicy.APP_COLLECT_INTERVAL_MS
        private const val CONNECT_CHECK_INTERVAL_MS = 30_000L
        private const val MIN_COLLECT_GAP_MS = RingMeasurementPolicy.MIN_COLLECT_GAP_MS
        private val BATTERY_CHECK_INTERVAL_MS = TimeUnit.MINUTES.toMillis(3)
    }

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private lateinit var bridge: BleBridge
    private var connectionJob: Job? = null
    private var collectJob: Job? = null
    private var batteryJob: Job? = null
    @Volatile
    private var lastConnected = false
    @Volatile
    private var lastCollectMs = 0L
    @Volatile
    private var lastBatteryLevel: Int? = null
    @Volatile
    private var lastBatteryCharging = false

    override fun onCreate() {
        super.onCreate()
        val app = applicationContext as Application
        BleOperateManager.getInstance(app).init()
        bridge = BleBridge(applicationContext)

        createNotificationChannel()
        startAsForeground()
        startConnectionMaintenance()
        startDataCollectionLoop()
        startBatteryMonitoring()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!connectionJob?.isActive.orFalse()) {
            startConnectionMaintenance()
        }
        if (!collectJob?.isActive.orFalse()) {
            startDataCollectionLoop()
        }
        if (!batteryJob?.isActive.orFalse()) {
            startBatteryMonitoring()
        }
        return START_STICKY
    }

    private fun Boolean?.orFalse() = this == true

    private fun enableSdkAutoReconnect() {
        val app = applicationContext as Application
        try {
            BleOperateManager.getInstance(app).setNeedConnect(true)
        } catch (t: Throwable) {
            Log.w(TAG, "setNeedConnect(true) failed", t)
        }
    }

    private fun disableSdkAutoReconnect() {
        if (RingBackgroundPrefs.isEnabled(this)) return
        val app = applicationContext as Application
        try {
            BleOperateManager.getInstance(app).setNeedConnect(false)
        } catch (t: Throwable) {
            Log.w(TAG, "setNeedConnect(false) failed", t)
        }
    }

    /// 앱 종료 후에도 BLE 연결을 유지·복구한다 (30초마다 확인).
    private fun startConnectionMaintenance() {
        connectionJob?.cancel()
        connectionJob = serviceScope.launch {
            delay(2_000)
            while (isActive) {
                if (!RingBackgroundPrefs.isEnabled(this@MyForegroundService)) {
                    delay(CONNECT_CHECK_INTERVAL_MS)
                    continue
                }

                val address = RingBackgroundPrefs.ringAddress(this@MyForegroundService)
                if (address.isNullOrBlank()) {
                    delay(CONNECT_CHECK_INTERVAL_MS)
                    continue
                }

                try {
                    enableSdkAutoReconnect()
                    val connected = bridge.ensureConnected(address)
                    if (connected != lastConnected) {
                        lastConnected = connected
                        updateNotification(
                            RingBackgroundPrefs.ringName(this@MyForegroundService)
                                ?: "스마트링",
                            connected = connected,
                        )
                        if (connected) {
                            maybeCollectHealthData(force = true)
                            maybeCheckBattery(force = true)
                        }
                    } else if (connected) {
                        maybeCheckBattery(force = false)
                    }
                } catch (t: Throwable) {
                    Log.e(TAG, "connection maintenance failed", t)
                    lastConnected = false
                    updateNotification(
                        RingBackgroundPrefs.ringName(this@MyForegroundService)
                            ?: "스마트링",
                        connected = false,
                    )
                }

                delay(CONNECT_CHECK_INTERVAL_MS)
            }
        }
    }

    /// 연결이 유지된 상태에서 주기적으로 반지 저장 데이터를 큐에 적재한다.
    private fun startDataCollectionLoop() {
        collectJob?.cancel()
        collectJob = serviceScope.launch {
            delay(5_000)
            while (isActive) {
                if (!RingBackgroundPrefs.isEnabled(this@MyForegroundService)) {
                    delay(COLLECT_INTERVAL_MS)
                    continue
                }

                val address = RingBackgroundPrefs.ringAddress(this@MyForegroundService)
                if (address.isNullOrBlank()) {
                    delay(COLLECT_INTERVAL_MS)
                    continue
                }

                try {
                    if (bridge.ensureConnected(address)) {
                        maybeCollectHealthData(force = false)
                    }
                } catch (t: Throwable) {
                    Log.e(TAG, "data collection cycle failed", t)
                }

                delay(COLLECT_INTERVAL_MS)
            }
        }
    }

    /// 3분마다 배터리 %·충전 상태를 확인해 pending 큐에 적재한다.
    private fun startBatteryMonitoring() {
        batteryJob?.cancel()
        batteryJob = serviceScope.launch {
            delay(4_000)
            while (isActive) {
                if (!RingBackgroundPrefs.isEnabled(this@MyForegroundService)) {
                    delay(BATTERY_CHECK_INTERVAL_MS)
                    continue
                }

                val address = RingBackgroundPrefs.ringAddress(this@MyForegroundService)
                if (address.isNullOrBlank()) {
                    delay(BATTERY_CHECK_INTERVAL_MS)
                    continue
                }

                try {
                    if (bridge.ensureConnected(address)) {
                        maybeCheckBattery(force = true)
                    }
                } catch (t: Throwable) {
                    Log.e(TAG, "battery monitoring failed", t)
                }

                delay(BATTERY_CHECK_INTERVAL_MS)
            }
        }
    }

    @Volatile
    private var lastBatteryCheckMs = 0L

    private suspend fun maybeCheckBattery(force: Boolean) {
        val now = System.currentTimeMillis()
        if (!force && now - lastBatteryCheckMs < BATTERY_CHECK_INTERVAL_MS) return
        lastBatteryCheckMs = now

        val level = bridge.checkAndQueueBattery(this@MyForegroundService) ?: return
        lastBatteryLevel = level.first
        lastBatteryCharging = level.second
        updateNotification(
            RingBackgroundPrefs.ringName(this@MyForegroundService) ?: "스마트링",
            connected = true,
        )
    }

    private suspend fun maybeCollectHealthData(force: Boolean) {
        val ok = bridge.collectHealthIfIdle(this@MyForegroundService, force)
        if (ok) {
            lastCollectMs = System.currentTimeMillis()
            maybeCheckBattery(force = true)
            Log.i(TAG, "background health data queued")
        }
    }

    private fun startAsForeground() {
        val notification = buildNotification("스마트링 연결 준비 중", "백그라운드에서 연결을 유지합니다.")
        startForeground(FOREGROUND_NOTI_ID, notification)
    }

    private fun updateNotification(name: String, connected: Boolean) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val status = when {
            !connected -> "재연결 시도 중"
            lastBatteryLevel != null && lastBatteryCharging ->
                "연결됨 · 충전 중 ${lastBatteryLevel}%"
            lastBatteryLevel != null ->
                "연결됨 · 배터리 ${lastBatteryLevel}%"
            else -> "연결 유지 중 · 5분마다 건강 데이터 수집"
        }
        manager.notify(FOREGROUND_NOTI_ID, buildNotification(name, status))
    }

    private fun buildNotification(title: String, text: String): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                CHANNEL_ID,
                "스마트링 백그라운드 연결",
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.description = "앱이 꺼져 있어도 스마트링 연결과 데이터 수집을 유지합니다."
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        connectionJob?.cancel()
        collectJob?.cancel()
        batteryJob?.cancel()
        disableSdkAutoReconnect()
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
