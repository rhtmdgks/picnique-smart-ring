package kr.picnique.smartring.picnique_rosary_healthcare_smartring

import android.content.Context
import java.time.LocalDate

/** 백그라운드 건강 데이터 수집 시 중복 큐잉을 줄인다. */
object RingCollectionWatermark {
    private const val PREFS = "ring_collection_watermark"
    private const val KEY_HEART_DAY = "heart_sample_day"
    private const val KEY_HEART_THROUGH_INDEX = "heart_sample_through_index"
    private const val KEY_LAST_COLLECT_MS = "last_collect_ms"

    fun heartSampleThroughIndex(context: Context): Int {
        val day = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_HEART_DAY, null)
        val today = LocalDate.now().toString()
        if (day != today) return -1
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getInt(KEY_HEART_THROUGH_INDEX, -1)
    }

    fun setHeartSampleThroughIndex(context: Context, index: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_HEART_DAY, LocalDate.now().toString())
            .putInt(KEY_HEART_THROUGH_INDEX, index)
            .apply()
    }

    fun lastCollectMs(context: Context): Long =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getLong(KEY_LAST_COLLECT_MS, 0L)

    fun markCollected(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_LAST_COLLECT_MS, System.currentTimeMillis())
            .apply()
    }
}
