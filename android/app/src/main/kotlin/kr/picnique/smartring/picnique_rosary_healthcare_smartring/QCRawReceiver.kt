// QCRawReceiver.kt
package kr.picnique.smartring.picnique_rosary_healthcare_smartring

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class QcRawReceiver(
    private val bridge: BleBridge
) : BroadcastReceiver() {

    companion object {
        var touchCount: Int = 0

        /** MSL 묵주(0x7a) 또는 레거시(0x73 0x25) 터치 패킷 */
        fun isTouchPacket(value: ByteArray): Boolean {
            if (value.isEmpty()) return false
            val b0 = value[0].toInt() and 0xFF
            if (b0 == 0x7a) return true // ODM_DFU_Operation_MSLPrayer
            if (value.size >= 2) {
                val b1 = value[1].toInt() and 0xFF
                if (b0 == 0x73 && b1 == 0x25) return true
            }
            return false
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent == null) return
        if (intent.action != "com.qc.characteristic_changed_qc") return
        if (!bridge.isSimpleTouchLoggingEnabled) return

        val value = intent.getByteArrayExtra("VALUE") ?: return
        if (!isTouchPacket(value)) return

        touchCount += 1

        val hex = value.joinToString(" ") { String.format("%02X", it) }
        Log.d("QcRawReceiver", "RAW = $hex, touchCount = $touchCount")
        bridge.onRingTouched(touchCount, hex)
    }
}
