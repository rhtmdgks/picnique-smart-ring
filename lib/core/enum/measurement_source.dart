/// 측정값의 출처 — DB `source` 컬럼(TEXT)에 [name] 그대로 저장한다.
///
/// - [firmwareAuto]: 반지 펌웨어 자동 측정 (pending 큐 → import)
/// - [appManual]: 사용자 수동 측정
/// - [appTimerFallback]: 앱 주도 주기 자동 측정 (연결 중 5분 사이클)
/// - [sleepDerived]: 수면 sync 과정에서 파생된 값
enum MeasurementSource { firmwareAuto, appManual, appTimerFallback, sleepDerived }
