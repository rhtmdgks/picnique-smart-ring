package kr.picnique.smartring.picnique_rosary_healthcare_smartring

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.time.format.DateTimeFormatter
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

private const val TAG = "BgBatteryMonitor"
private val ISO = DateTimeFormatter.ISO_INSTANT

/** 앱 종료·백그라운드에서 반지 배터리를 주기 확인해 pending 큐에 적재한다. */
suspend fun BleBridge.checkAndQueueBattery(context: Context): Pair<Int, Boolean>? {
    val raw = bleAwaitBatteryRaw("getBatteryStatus") { result ->
        getBatteryStatus(result)
    } ?: return null

    val map = raw as? Map<*, *> ?: return null
    val level = (map["level"] as? Number)?.toInt()
        ?: (map["battery"] as? Number)?.toInt()
        ?: return null
    if (level <= 0) return null

    val charging = map["charging"] == true
    val collectedAt = ISO.format(Instant.now())

    PendingHealthQueue.append(
        context,
        mapOf(
            "type" to "battery",
            "date" to collectedAt,
            "battery" to level,
            "level" to level,
            "charging" to charging,
        ),
    )
    BatteryLowNotifier.maybeNotify(context, level)
    Log.i(TAG, "battery queued: $level% charging=$charging")
    return level to charging
}

private suspend fun BleBridge.bleAwaitBatteryRaw(
    tag: String,
    call: (MethodChannel.Result) -> Unit,
): Any? = suspendCancellableCoroutine { cont ->
    try {
        call(
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (!cont.isCompleted) cont.resume(result)
                }

                override fun error(
                    errorCode: String,
                    errorMessage: String?,
                    errorDetails: Any?,
                ) {
                    Log.w(TAG, "[$tag] $errorCode $errorMessage")
                    if (!cont.isCompleted) cont.resume(null)
                }

                override fun notImplemented() {
                    if (!cont.isCompleted) cont.resume(null)
                }
            },
        )
    } catch (t: Throwable) {
        if (!cont.isCompleted) cont.resume(null)
    }
}
