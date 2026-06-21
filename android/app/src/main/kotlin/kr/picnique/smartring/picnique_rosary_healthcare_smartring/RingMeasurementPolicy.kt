package kr.picnique.smartring.picnique_rosary_healthcare_smartring

/** 반지·앱 건강 데이터 축적 정책 (Dart [RingMeasurementPolicy]와 동일). */
object RingMeasurementPolicy {
    const val RING_AUTO_HEART_INTERVAL_MINUTES = 10
    const val APP_COLLECT_INTERVAL_MS = RING_AUTO_HEART_INTERVAL_MINUTES * 60 * 1000L
    const val MIN_COLLECT_GAP_MS = APP_COLLECT_INTERVAL_MS
}
