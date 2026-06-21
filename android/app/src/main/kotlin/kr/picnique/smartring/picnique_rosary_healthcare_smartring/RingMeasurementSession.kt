package kr.picnique.smartring.picnique_rosary_healthcare_smartring

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

enum class ManualMeasureType(val wireName: String) {
    HEART_RATE("heartRate"),
    BLOOD_OXYGEN("bloodOxygen"),
    STRESS("stress");

    companion object {
        fun fromWire(name: String): ManualMeasureType? =
            entries.firstOrNull { it.wireName == name }
    }
}

private enum class SessionState {
    IDLE,
    MANUAL,
    AUTO_COLLECT,
    CONFIGURE,
}

interface RingMeasurementSessionHost {
    suspend fun performCollect(context: Context)
    fun notifyHealthDataReady()
    fun runManualHeartRate(result: MethodChannel.Result, onComplete: () -> Unit)
    fun runManualSpO2(result: MethodChannel.Result, onComplete: () -> Unit)
    fun runManualPressure(result: MethodChannel.Result, onComplete: () -> Unit)
}

class RingMeasurementSession(private val host: RingMeasurementSessionHost) {
    private val lock = Any()
    private val main = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    @Volatile
    private var state = SessionState.IDLE

    @Volatile
    private var pendingCatchUpContext: Context? = null

    val isBusy: Boolean
        get() = synchronized(lock) { state != SessionState.IDLE }

    fun executeManual(type: ManualMeasureType, result: MethodChannel.Result) {
        synchronized(lock) {
            if (state != SessionState.IDLE) {
                main.post { result.error("SESSION_BUSY", "measurement session busy", null) }
                return
            }
            state = SessionState.MANUAL
        }

        val onComplete = { finishManual() }

        when (type) {
            ManualMeasureType.HEART_RATE -> host.runManualHeartRate(result, onComplete)
            ManualMeasureType.BLOOD_OXYGEN -> host.runManualSpO2(result, onComplete)
            ManualMeasureType.STRESS -> host.runManualPressure(result, onComplete)
        }
    }

    suspend fun collectHealthIfIdle(context: Context, force: Boolean): Boolean {
        synchronized(lock) {
            if (state != SessionState.IDLE) {
                pendingCatchUpContext = context
                return false
            }
            if (!force) {
                val now = System.currentTimeMillis()
                if (now - RingCollectionWatermark.lastCollectMs(context)
                    < RingMeasurementPolicy.MIN_COLLECT_GAP_MS
                ) {
                    return false
                }
            }
            state = SessionState.AUTO_COLLECT
        }

        return try {
            host.performCollect(context)
            RingCollectionWatermark.markCollected(context)
            host.notifyHealthDataReady()
            true
        } finally {
            synchronized(lock) { state = SessionState.IDLE }
        }
    }

    fun resetToIdle() {
        synchronized(lock) { state = SessionState.IDLE }
    }

    private fun finishManual() {
        val ctx: Context?
        synchronized(lock) {
            state = SessionState.IDLE
            ctx = pendingCatchUpContext
            pendingCatchUpContext = null
        }
        if (ctx != null) {
            scope.launch {
                collectHealthIfIdle(ctx, force = true)
            }
        }
    }
}
