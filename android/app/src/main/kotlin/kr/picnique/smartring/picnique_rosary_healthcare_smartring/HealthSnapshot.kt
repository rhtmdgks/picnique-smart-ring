package kr.picnique.smartring.picnique_rosary_healthcare_smartring

import android.util.Log
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.suspendCancellableCoroutine
import java.time.Instant
import kotlin.coroutines.resume

// -----------------------------
// 데이터 클래스들
// -----------------------------

data class BloodPressureSnapshot(
    val systolic: Int,
    val diastolic: Int
)

data class SportSnapshot(
    val stepCount: Int,
    val sportsTimeSec: Int
)

data class HealthSnapshot(
    val userId: String,
    val heartRate: Int,
    val spo2: Int,
    val stepCount: Int,
    val bodyTemperature: Double,
    val bloodPressure: BloodPressureSnapshot,
    val bloodSugar: Int,
    val battery: Int,
    val chargingState: Int,
    val sleepHours: Double,
    val sportsTime: Int,
    val screenStatus: Int,
    val timestamp: String
)

// -----------------------------
// 공통: BleBridge 비동기 → suspend 래핑
// -----------------------------

private suspend fun BleBridge.bleAwaitRaw(
    tag: String,
    call: (MethodChannel.Result) -> Unit
): Any? = suspendCancellableCoroutine { cont ->
    try {
        call(
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (!cont.isCompleted) {
                        cont.resume(result)
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e("HealthSnapshot", "[$tag] error: $errorCode, $errorMessage")
                    if (!cont.isCompleted) {
                        cont.resume(null)
                    }
                }

                override fun notImplemented() {
                    Log.e("HealthSnapshot", "[$tag] not implemented")
                    if (!cont.isCompleted) {
                        cont.resume(null)
                    }
                }
            }
        )
    } catch (t: Throwable) {
        Log.e("HealthSnapshot", "[$tag] exception: ${t.message}", t)
        if (!cont.isCompleted) {
            cont.resume(null)
        }
    }
}

// -----------------------------
// 각 항목별 “저장값 중 최신” 뽑는 함수들
// -----------------------------

// 1) 심박: syncHeartRate(nowTime=null) → heartRateArray 마지막 값
suspend fun BleBridge.getLatestStoredHeartRate(): Int {
    val raw = bleAwaitRaw("syncHeartRate") { result ->
        // nowTime = null → BleBridge 내부에서 현재 시간 기준으로 히스토리 HR 요청
        syncHeartRate(null, result)
    } ?: return 0

    val map = raw as? Map<*, *> ?: return 0
    val arrAny = map["heartRateArray"] as? List<*> ?: return 0
    val ints = arrAny.mapNotNull { (it as? Number)?.toInt() }

    // 마지막으로 기록된 유효한 값(>0) → 없으면 그냥 마지막 값
    return ints.lastOrNull { it > 0 } ?: ints.lastOrNull() ?: 0
}

// 2) SpO2: syncBloodOxygen() → unix_time 가장 큰 데이터의 max/min 배열 마지막 값
suspend fun BleBridge.getLatestStoredSpo2(): Int {
    val raw = bleAwaitRaw("syncBloodOxygen") { result ->
        syncBloodOxygen(result)
    } ?: return 0

    val list = raw as? List<*> ?: return 0

    var bestValue = 0
    var bestUnix = Long.MIN_VALUE

    for (item in list) {
        val map = item as? Map<*, *> ?: continue

        val unixAny = map["unix_time"]
        val unix = (unixAny as? Number)?.toLong() ?: continue

        val maxArrAny = map["maxArray"]
        val maxArr: List<Int> = when (maxArrAny) {
            is List<*> -> maxArrAny.mapNotNull { (it as? Number)?.toInt() }
            else -> emptyList()
        }
        val minArrAny = map["minArray"]
        val minArr: List<Int> = when (minArrAny) {
            is List<*> -> minArrAny.mapNotNull { (it as? Number)?.toInt() }
            else -> emptyList()
        }

        val candidate = maxArr.lastOrNull { it > 0 } ?: maxArr.lastOrNull()
            ?: minArr.lastOrNull { it > 0 } ?: minArr.lastOrNull()

        if (candidate != null && unix >= bestUnix) {
            bestUnix = unix
            bestValue = candidate
        }
    }

    return bestValue
}

// 3) 운동(걸음/운동시간): syncSportDetail(dayOffset=0) 오늘 디테일 기반
suspend fun BleBridge.getLatestStoredSport(): SportSnapshot {
    val raw = bleAwaitRaw("syncSportDetail") { result ->
        // dayOffset = 0 → 오늘 데이터
        syncSportDetail(0, result)
    } ?: return SportSnapshot(stepCount = 0, sportsTimeSec = 0)

    val map = raw as? Map<*, *> ?: return SportSnapshot(0, 0)
    val detailsAny = map["details"]
    val details = detailsAny as? List<*> ?: return SportSnapshot(0, 0)

    var stepCount = 0
    var minIdx = Int.MAX_VALUE
    var maxIdx = -1

    for (item in details) {
        val r = item as? Map<*, *> ?: continue
        val walk = (r["walkSteps"] as? Number)?.toInt() ?: 0
        val run = (r["runSteps"] as? Number)?.toInt() ?: 0
        stepCount += walk + run

        val idx = (r["timeIndex"] as? Number)?.toInt() ?: continue
        if (idx < minIdx) minIdx = idx
        if (idx > maxIdx) maxIdx = idx
    }

    // timeIndex 0..95 기준으로 1칸 ≈ 15분(900초)라고 가정
    val sportsTimeSec = if (maxIdx >= minIdx && minIdx != Int.MAX_VALUE) {
        val slots = (maxIdx - minIdx + 1).coerceAtLeast(1)
        slots * 900
    } else {
        0
    }

    return SportSnapshot(stepCount = stepCount, sportsTimeSec = sportsTimeSec)
}

// 4) 수면: syncSleepNew(0) 그대로 사용 (최근 수면)
suspend fun BleBridge.getLatestSleepHours(): Double {
    val raw = bleAwaitRaw("syncSleepNew") { result ->
        // offset 0 → BLEUtil에서도 “오늘/최근 수면”으로 쓰는 값
        syncSleepNew(0, result)
    } ?: return 0.0

    val map = raw as? Map<*, *> ?: return 0.0
    val st = (map["st"] as? Number)?.toLong() ?: return 0.0
    val et = (map["et"] as? Number)?.toLong() ?: return 0.0

    val durSec = (et - st).coerceAtLeast(0L)
    return durSec.toDouble() / 3600.0
}

// 5) 배터리: getBatteryLevel()
suspend fun BleBridge.getBatteryPercent(): Int {
    val raw = bleAwaitRaw("getBatteryLevel") { result ->
        getBatteryLevel(result)
    } ?: return 0

    return (raw as? Number)?.toInt() ?: 0
}

// -----------------------------
// 최종 HealthSnapshot / JSON Map
// -----------------------------

suspend fun BleBridge.buildStoredHealthSnapshot(
    userId: String
): HealthSnapshot {
    val battery = getBatteryPercent()
    val hr = getLatestStoredHeartRate()
    val spo2 = getLatestStoredSpo2()
    val sport = getLatestStoredSport()
    val sleepHours = getLatestSleepHours()

    val bp = BloodPressureSnapshot(
        systolic = 120, // 저장된 혈압 히스토리 연동 시 교체 가능
        diastolic = 80
    )

    val bodyTemperature = 36.5   // 온도 히스토리 연동하면 여기 채우기
    val bloodSugar = 0          // 혈당 센서 없으면 0
    val chargingState = 0       // 실시간 이벤트로 관리하고 싶으면 교체
    val screenStatus = 0        // 마찬가지

    val timestamp = Instant.now().toString()

    return HealthSnapshot(
        userId = userId,
        heartRate = hr,
        spo2 = spo2,
        stepCount = sport.stepCount,
        bodyTemperature = bodyTemperature,
        bloodPressure = bp,
        bloodSugar = bloodSugar,
        battery = battery,
        chargingState = chargingState,
        sleepHours = sleepHours,
        sportsTime = sport.sportsTimeSec,
        screenStatus = screenStatus,
        timestamp = timestamp
    )
}

// 너가 요청한 JSON 꼴(Map)로 바로 쓰고 싶을 때
suspend fun BleBridge.buildStoredHealthJsonMap(
    userId: String
): Map<String, Any?> {
    val snap = buildStoredHealthSnapshot(userId)
    return mapOf(
        "user_id" to snap.userId,
        "heart_rate" to snap.heartRate,
        "spo2" to snap.spo2,
        "step_count" to snap.stepCount,
        "body_temperature" to snap.bodyTemperature,
        "blood_pressure" to mapOf(
            "systolic" to snap.bloodPressure.systolic,
            "diastolic" to snap.bloodPressure.diastolic
        ),
        "blood_sugar" to snap.bloodSugar,
        "battery" to snap.battery,
        "charging_state" to snap.chargingState,
        "sleep_hours" to snap.sleepHours,
        "sports_time" to snap.sportsTime,
        "screen_status" to snap.screenStatus,
        "timestamp" to snap.timestamp
    )
}
