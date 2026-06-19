package kr.picnique.smartring.picnique_rosary_healthcare_smartring

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.delay
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

private const val TAG = "BgHealthCollector"

suspend fun BleBridge.ensureConnected(address: String): Boolean {
    val battery = getBatteryPercent()
    if (battery > 0) return true

    val connected = suspendCancellableCoroutine<Boolean> { cont ->
        connectDirectly(address, object : MethodChannel.Result {
            override fun success(result: Any?) {
                if (!cont.isCompleted) cont.resume(true)
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                Log.w(TAG, "connect error: $errorCode $errorMessage")
                if (!cont.isCompleted) cont.resume(false)
            }

            override fun notImplemented() {
                if (!cont.isCompleted) cont.resume(false)
            }
        })
    }
    if (!connected) return false

    repeat(8) {
        delay(800)
        if (getBatteryPercent() > 0) return true
    }
    return false
}

suspend fun BleBridge.collectAndQueue(context: Context) {
    val iso = DateTimeFormatter.ISO_INSTANT
    val now = Instant.now()
    val collectedAt = iso.format(now)

    try {
        val hr = getLatestStoredHeartRate()
        if (hr > 0) {
            PendingHealthQueue.append(
                context,
                mapOf(
                    "type" to "heart",
                    "date" to collectedAt,
                    "bpm" to hr,
                ),
            )
        }
    } catch (t: Throwable) {
        Log.w(TAG, "heart collect failed", t)
    }

    try {
        val spo2 = getLatestStoredSpo2()
        if (spo2 > 0) {
            PendingHealthQueue.append(
                context,
                mapOf(
                    "type" to "spo2",
                    "date" to collectedAt,
                    "spo2" to spo2,
                ),
            )
        }
    } catch (t: Throwable) {
        Log.w(TAG, "spo2 collect failed", t)
    }

    try {
        val sport = getLatestStoredSport()
        if (sport.stepCount > 0) {
            PendingHealthQueue.append(
                context,
                mapOf(
                    "type" to "steps",
                    "date" to collectedAt,
                    "steps" to sport.stepCount,
                    "sports_time" to sport.sportsTimeSec,
                ),
            )
        }
    } catch (t: Throwable) {
        Log.w(TAG, "sport collect failed", t)
    }

    try {
        val stress = getLatestStoredStress()
        if (stress > 0) {
            PendingHealthQueue.append(
                context,
                mapOf(
                    "type" to "stress",
                    "date" to collectedAt,
                    "stress" to stress,
                ),
            )
        }
    } catch (t: Throwable) {
        Log.w(TAG, "stress collect failed", t)
    }

    // 오늘 5분 간격 심박 샘플도 큐에 적재 (앱 DB 병합용)
    try {
        queueTodayHeartSamples(context)
    } catch (t: Throwable) {
        Log.w(TAG, "heart samples failed", t)
    }
}

private suspend fun BleBridge.queueTodayHeartSamples(context: Context) {
    val zone = ZoneId.systemDefault()
    val dayStart = LocalDate.now(zone).atStartOfDay(zone).toInstant()
    val nowTimeSec = dayStart.epochSecond + 12 * 3600

    val raw = bleAwaitRaw("syncHeartRateToday") { result ->
        syncHeartRate(nowTimeSec, result)
    } ?: return

    val map = raw as? Map<*, *> ?: return
    val arrAny = map["heartRateArray"] as? List<*> ?: return
    val ints = arrAny.mapNotNull { (it as? Number)?.toInt() }
    if (ints.isEmpty()) return

    val iso = DateTimeFormatter.ISO_INSTANT
    val count = ints.size.coerceAtMost(288)
    for (i in 0 until count) {
        val bpm = ints[i]
        if (bpm <= 0) continue
        val sampleInstant = dayStart.plusSeconds((5 * 60 * i).toLong())
        PendingHealthQueue.append(
            context,
            mapOf(
                "type" to "heart_sample",
                "date" to iso.format(sampleInstant),
                "bpm" to bpm,
            ),
        )
    }
}

private suspend fun BleBridge.getLatestStoredStress(): Int {
    val raw = bleAwaitRaw("syncPressure") { result ->
        syncPressure(0.toByte(), result)
    } ?: return 0

    val map = raw as? Map<*, *> ?: return 0
    val arrAny = map["array"]
    val ints: List<Int> = when (arrAny) {
        is List<*> -> arrAny.mapNotNull { (it as? Number)?.toInt() }
        else -> emptyList()
    }
    return ints.lastOrNull { it > 0 } ?: ints.lastOrNull() ?: 0
}

private suspend fun BleBridge.bleAwaitRaw(
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
