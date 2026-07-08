/// 반지·앱 건강 데이터 축적 정책.
///
/// - **연결 끊김·앱 종료**: 반지 펌웨어 자동 측정 ON → 반지 내부 메모리에 저장
/// - **연결 유지**: 네이티브 10분 주기 pull → pending 큐 → Drift DB
abstract final class RingMeasurementPolicy {
  /// 연결 중 앱 주도 자동 측정 주기(분). 심박·스트레스·SpO₂ 순차 측정.
  static const int autoMeasureIntervalMinutes = 5;

  static const Duration autoMeasureInterval = Duration(
    minutes: autoMeasureIntervalMinutes,
  );

  /// 반지 자동 심박 측정 간격(분). SpO₂·스트레스는 SDK가 on/off만 지원(펌웨어 주기).
  static const int ringAutoHeartIntervalMinutes = 10;

  /// 연결 중 앱 DB로 병합하는 주기(분).
  static const int appCollectIntervalMinutes = 10;

  static const Duration appCollectInterval = Duration(
    minutes: appCollectIntervalMinutes,
  );

  // ── 수면 감지(SleepGate) 정책 ─────────────────────────────
  /// 수면 후보 시간대 시작 시각(시). 21:00 부터 probe 후보.
  static const int sleepCandidateStartHour = 21;

  /// 수면 후보 시간대 종료 시각(시). 11:00 지나면 AWAKE 확정.
  static const int sleepCandidateEndHour = 11;

  /// probe 실패 시 시간 기반 폴백으로 SLEEPING 처리하는 구간 시작(시).
  static const int sleepFallbackStartHour = 23;

  /// 시간 기반 폴백 구간 종료(시).
  static const int sleepFallbackEndHour = 7;

  /// 수면 probe(syncSleepNew offset 0) 간격.
  static const Duration sleepProbeInterval = Duration(minutes: 30);

  /// 마지막 수면 세그먼트 종료 후 이 시간이 지나면 기상으로 판정.
  static const Duration sleepWakeConfirm = Duration(minutes: 30);
}
