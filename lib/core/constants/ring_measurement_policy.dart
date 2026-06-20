/// 반지·앱 건강 데이터 축적 정책.
///
/// - **연결 끊김·앱 종료**: 반지 펌웨어 자동 측정 ON → 반지 내부 메모리에 저장
/// - **연결 유지**: 네이티브 5분 주기 pull → pending 큐 → Drift DB
abstract final class RingMeasurementPolicy {
  /// 반지 자동 심박 측정 간격(분). SpO₂·스트레스는 SDK가 on/off만 지원(펌웨어 주기).
  static const int ringAutoHeartIntervalMinutes = 5;

  /// 연결 중 앱 DB로 병합하는 주기(분).
  static const int appCollectIntervalMinutes = 5;

  static const Duration appCollectInterval = Duration(
    minutes: appCollectIntervalMinutes,
  );
}
