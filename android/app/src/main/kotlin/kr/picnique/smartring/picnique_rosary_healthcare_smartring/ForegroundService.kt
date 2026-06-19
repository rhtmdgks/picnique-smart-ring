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
        private val COLLECT_INTERVAL_MS = TimeUnit.MINUTES.toMillis(15)
    }

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private lateinit var bridge: BleBridge
    private var collectJob: Job? = null

    override fun onCreate() {
        super.onCreate()
        val app = applicationContext as Application
        BleOperateManager.getInstance(app).init()
        bridge = BleBridge(applicationContext)

        createNotificationChannel()
        startAsForeground()
        startKeepaliveLoop()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!collectJob?.isActive.orFalse()) {
            startKeepaliveLoop()
        }
        return START_STICKY
    }

    private fun Boolean?.orFalse() = this == true

    private fun startKeepaliveLoop() {
        collectJob?.cancel()
        collectJob = serviceScope.launch {
            delay(2_000)
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
                    val connected = bridge.ensureConnected(address)
                    if (connected) {
                        bridge.collectAndQueue(this@MyForegroundService)
                        val battery = bridge.getBatteryPercent()
                        BatteryLowNotifier.maybeNotify(this@MyForegroundService, battery)
                        updateNotification(
                            RingBackgroundPrefs.ringName(this@MyForegroundService)
                                ?: "스마트링",
                            connected = true,
                        )
                    } else {
                        updateNotification(
                            RingBackgroundPrefs.ringName(this@MyForegroundService)
                                ?: "스마트링",
                            connected = false,
                        )
                    }
                } catch (t: Throwable) {
                    Log.e(TAG, "keepalive cycle failed", t)
                }

                delay(COLLECT_INTERVAL_MS)
            }
        }
    }

    private fun startAsForeground() {
        val notification = buildNotification("스마트링 연결 준비 중", "백그라운드에서 연결을 유지합니다.")
        startForeground(FOREGROUND_NOTI_ID, notification)
    }

    private fun updateNotification(name: String, connected: Boolean) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val status = if (connected) "연결됨 · 15분마다 건강 데이터 수집" else "재연결 시도 중"
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
        collectJob?.cancel()
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
