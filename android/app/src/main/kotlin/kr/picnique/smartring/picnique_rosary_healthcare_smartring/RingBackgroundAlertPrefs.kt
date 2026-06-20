package kr.picnique.smartring.picnique_rosary_healthcare_smartring

import android.content.Context

/** Flutter SharedPreferences와 동기화되는 백그라운드 알림 설정. */
object RingBackgroundAlertPrefs {
    private const val PREFS = "FlutterSharedPreferences"
    private const val ENABLED_KEY = "flutter.battery_low_alert_enabled"

    /** 설정값이 없으면 배터리 부족 알림을 켠 것으로 본다. */
    fun isBatteryLowAlertEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.contains(ENABLED_KEY)) return true
        return prefs.getBoolean(ENABLED_KEY, true)
    }
}
