import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';

/// 반지 펌웨어 스케줄 측정(심박·SpO₂·스트레스·HRV) 건강 상태.
///
/// 펌웨어 스케줄은 연결 끊김 동안 반지 메모리에 축적하는 **백업 경로**다.
/// 연결 직후 write + read-back 검증으로 상태를 만들고, 깨진 스트림은
/// 오프라인 축적이 누락될 수 있으므로 로그·진단에 사용한다.
class RingMonitoringStatus {
  const RingMonitoringStatus({
    required this.hr,
    required this.spo2,
    required this.stress,
    required this.hrv,
  });

  /// 전부 정상 — 앱 주도 측정 불필요.
  static const RingMonitoringStatus healthy = RingMonitoringStatus(
    hr: true,
    spo2: true,
    stress: true,
    hrv: true,
  );

  /// 전부 비정상 — 검증 자체가 불가능했을 때(연결 불안정 등).
  static const RingMonitoringStatus allBroken = RingMonitoringStatus(
    hr: false,
    spo2: false,
    stress: false,
    hrv: false,
  );

  final bool hr;
  final bool spo2;
  final bool stress;
  final bool hrv;

  /// fallback 측정이 필요한 타입 집합.
  ///
  /// QC 링 스트레스는 HRV 스케줄 → 스트레스 산출 파이프라인이므로
  /// 둘 중 하나라도 깨지면 스트레스 fallback 이 필요하다.
  Set<DataType> get brokenMeasureTypes => {
        if (!hr) DataType.HeartRate,
        if (!spo2) DataType.Oxygen,
        if (!stress || !hrv) DataType.Stress,
      };

  bool get allHealthy => brokenMeasureTypes.isEmpty;

  @override
  String toString() =>
      'RingMonitoringStatus(hr=$hr, spo2=$spo2, stress=$stress, hrv=$hrv)';
}
