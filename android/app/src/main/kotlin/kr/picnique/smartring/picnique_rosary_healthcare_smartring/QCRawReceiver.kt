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
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent == null) return

        if (intent.action != "com.qc.characteristic_changed_qc") return

        val value = intent.getByteArrayExtra("VALUE") ?: return

        // 🔥 여기 조건만 추가하면 됨
        if (value[0] != 0x73.toByte() || value[1] != 0x25.toByte()) {
            // 73 25로 시작하지 않으면 무시
            return
        }
        touchCount += 1

        // 그냥 원본 확인용 로그
        val hex = value.joinToString(" ") { String.format("%02X", it) }
        Log.d("QcRawReceiver", "RAW = $hex, touchCount = $touchCount")
        bridge.onRingTouched(touchCount, hex)
    }
}
