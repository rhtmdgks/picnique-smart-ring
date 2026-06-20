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
private val ISO = DateTimeFormatter.ISO_INSTANT

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

/** 반지 저장소에서 신규/갱신 측정값을 pending 큐에 적재한다. */
suspend fun BleBridge.collectAndQueue(context: Context) {
    val zone = ZoneId.systemDefault()
    val collectedAt = ISO.format(Instant.now())

    try {
        queueIncrementalHeartSamples(context, zone)
    } catch (t: Throwable) {
        Log.w(TAG, "heart samples failed", t)
    }

    try {
        queueSpo2Samples(context, zone)
    } catch (t: Throwable) {
        Log.w(TAG, "spo2 samples failed", t)
    }

    try {
        queueStressSamples(context, zone)
    } catch (t: Throwable) {
        Log.w(TAG, "stress samples failed", t)
    }

    try {
        queueSportSlots(context, zone)
    } catch (t: Throwable) {
        Log.w(TAG, "sport slots failed", t)
    }

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
        Log.w(TAG, "heart latest failed", t)
    }

    RingCollectionWatermark.markCollected(context)
    Log.i(TAG, "collectAndQueue done at $collectedAt")
}

private suspend fun BleBridge.queueIncrementalHeartSamples(
    context: Context,
    zone: ZoneId,
) {
    val dayStart = LocalDate.now(zone).atStartOfDay(zone).toInstant()
    val nowTimeSec = dayStart.epochSecond + 12 * 3600

    val raw = bleAwaitRaw("syncHeartRateToday") { result ->
        syncHeartRate(nowTimeSec, result)
    } ?: return

    val map = raw as? Map<*, *> ?: return
    val arrAny = map["heartRateArray"] as? List<*> ?: return
    val ints = arrAny.mapNotNull { (it as? Number)?.toInt() }
    if (ints.isEmpty()) return

    val through = RingCollectionWatermark.heartSampleThroughIndex(context)
    var maxIndex = through

    val count = ints.size.coerceAtMost(288)
    val slotSec = RingMeasurementPolicy.RING_AUTO_HEART_INTERVAL_MINUTES * 60L
    for (i in 0 until count) {
        if (i <= through) continue
        val bpm = ints[i]
        if (bpm <= 0) continue
        val sampleInstant = dayStart.plusSeconds(slotSec * i)
        PendingHealthQueue.append(
            context,
            mapOf(
                "type" to "heart_sample",
                "date" to ISO.format(sampleInstant),
                "bpm" to bpm,
            ),
        )
        maxIndex = i
    }

    if (maxIndex > through) {
        RingCollectionWatermark.setHeartSampleThroughIndex(context, maxIndex)
    }
}

private suspend fun BleBridge.queueSpo2Samples(context: Context, zone: ZoneId) {
    val raw = bleAwaitRaw("syncBloodOxygen") { result ->
        syncBloodOxygen(result)
    } ?: return

    val list = raw as? List<*> ?: return
    for (item in list) {
        val map = item as? Map<*, *> ?: continue
        val unix = (map["unix_time"] as? Number)?.toLong() ?: continue
        val dayStart = Instant.ofEpochSecond(unix).atZone(zone).toLocalDate()
            .atStartOfDay(zone).toInstant()

        val maxArr = (map["maxArray"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() }
            ?: emptyList()
        val minArr = (map["minArray"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() }
            ?: emptyList()

        for (hour in 0 until 24) {
            val candidate = maxArr.getOrNull(hour)?.takeIf { it > 0 }
                ?: minArr.getOrNull(hour)?.takeIf { it > 0 }
                ?: continue
            val sampleInstant = dayStart.plusSeconds(hour * 3600L)
            PendingHealthQueue.append(
                context,
                mapOf(
                    "type" to "spo2_sample",
                    "date" to ISO.format(sampleInstant),
                    "spo2" to candidate,
                ),
            )
        }
    }
}

private suspend fun BleBridge.queueStressSamples(context: Context, zone: ZoneId) {
    for (offset in 0..2) {
        val raw = bleAwaitRaw("syncPressure") { result ->
            syncPressure(offset.toByte(), result)
        } ?: continue

        val map = raw as? Map<*, *> ?: continue
        val rangeMin = ((map["range"] as? Number)?.toInt() ?: 30).coerceIn(1, 1440)
        val arr = (map["array"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() }
            ?: continue

        val todayMap = map["today"] as? Map<*, *>
        val baseDay = if (todayMap != null) {
            val y = (todayMap["year"] as? Number)?.toInt() ?: 0
            val m = (todayMap["month"] as? Number)?.toInt() ?: 0
            val d = (todayMap["day"] as? Number)?.toInt() ?: 0
            if (y > 0 && m > 0 && d > 0) LocalDate.of(y, m, d) else LocalDate.now(zone)
        } else {
            LocalDate.now(zone)
        }
        val dayStart = baseDay.minusDays(offset.toLong()).atStartOfDay(zone).toInstant()
        val dayEnd = dayStart.plusSeconds(86400)

        for (i in arr.indices) {
            val val_ = arr[i]
            if (val_ <= 0) continue
            val sampleInstant = dayStart.plusSeconds((rangeMin * 60 * i).toLong())
            if (!sampleInstant.isBefore(dayEnd)) break
            PendingHealthQueue.append(
                context,
                mapOf(
                    "type" to "stress_sample",
                    "date" to ISO.format(sampleInstant),
                    "stress" to val_,
                ),
            )
        }
    }
}

private suspend fun BleBridge.queueSportSlots(context: Context, zone: ZoneId) {
    for (offset in 0..2) {
        val raw = bleAwaitRaw("syncSportDetail") { result ->
            syncSportDetail(offset, result)
        } ?: continue

        val map = raw as? Map<*, *> ?: continue
        val details = map["details"] as? List<*> ?: continue

        for (item in details) {
            val row = item as? Map<*, *> ?: continue
            val year = (row["year"] as? Number)?.toInt() ?: continue
            val month = (row["month"] as? Number)?.toInt() ?: continue
            val day = (row["day"] as? Number)?.toInt() ?: continue
            val timeIndex = (row["timeIndex"] as? Number)?.toInt() ?: continue
            val walkSteps = (row["walkSteps"] as? Number)?.toInt() ?: 0
            val runSteps = (row["runSteps"] as? Number)?.toInt() ?: 0
            if (walkSteps <= 0 && runSteps <= 0) continue

            val slotInstant = LocalDate.of(year, month, day)
                .atStartOfDay(zone)
                .plusMinutes(timeIndex * 15L)
                .toInstant()

            PendingHealthQueue.append(
                context,
                mapOf(
                    "type" to "sport_slot",
                    "date" to ISO.format(slotInstant),
                    "timeIndex" to timeIndex,
                    "walkSteps" to walkSteps,
                    "runSteps" to runSteps,
                    "distance" to ((row["distance"] as? Number)?.toInt() ?: 0),
                    "calorie" to ((row["calorie"] as? Number)?.toInt() ?: 0),
                ),
            )
        }
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
