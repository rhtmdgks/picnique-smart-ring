package kr.picnique.smartring.picnique_rosary_healthcare_smartring

import android.content.Context

object RingBackgroundPrefs {
    private const val PREFS = "ring_background_prefs"
    private const val KEY_ENABLED = "keepalive_enabled"
    private const val KEY_ADDRESS = "ring_address"
    private const val KEY_NAME = "ring_name"

    fun setKeepalive(context: Context, enabled: Boolean, address: String?, name: String?) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
            putBoolean(KEY_ENABLED, enabled)
            if (enabled && !address.isNullOrBlank()) {
                putString(KEY_ADDRESS, address)
                putString(KEY_NAME, name ?: "")
            }
            if (!enabled) {
                remove(KEY_ADDRESS)
                remove(KEY_NAME)
            }
            apply()
        }
    }

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_ENABLED, false)

    fun ringAddress(context: Context): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_ADDRESS, null)

    fun ringName(context: Context): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_NAME, null)
}
