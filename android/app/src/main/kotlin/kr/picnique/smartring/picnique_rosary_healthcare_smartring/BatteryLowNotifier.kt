package kr.picnique.smartring.picnique_rosary_healthcare_smartring

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

object BatteryLowNotifier {
    private const val CHANNEL_ID = "battery_low_alert"
    private const val NOTIFICATION_ID = 1001
    private const val PREFS = "FlutterSharedPreferences"
    private const val ENABLED_KEY = "flutter.battery_low_alert_enabled"

    private var lastNotifiedLevel: Int? = null

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "배터리 부족 알림",
            NotificationManager.IMPORTANCE_HIGH,
        )
        channel.description = "스마트링 배터리가 부족할 때 알려줍니다."
        manager.createNotificationChannel(channel)
    }

    fun maybeNotify(context: Context, battery: Int) {
        val enabled = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(ENABLED_KEY, false)
        if (!enabled) return

        if (battery > 20) {
            if (battery >= 25) lastNotifiedLevel = null
            return
        }

        if (lastNotifiedLevel != null && battery >= lastNotifiedLevel!!) return

        ensureChannel(context)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("스마트링 배터리 부족")
            .setContentText("배터리가 ${battery}%입니다. 충전해 주세요.")
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        manager.notify(NOTIFICATION_ID, notification)
        lastNotifiedLevel = battery
    }
}
