# RWFit SDK 이식 개발 기록 · 2차

## 참조 계약
ChatGPT Picnique Inc. 프로젝트 `pasted(1).txt`에 포함된 RWFitSDK/RW_flutter_plugin commit `be17a8f306e19aa3de2e306c044d94e5d76c691f`, SDK API/이력 자료형 문서, 한국어 RW Bluetooth MiniProgram Protocol DOCX 11페이지를 기준으로 작성했습니다.

## 실행 경로
- 기존 `lib/main.dart`: QRing UI/SDK/기존 db.sqlite 유지.
- 새 `lib/main_rwfit.dart`: 동일 Picnique 메인 UI/기존 차트/설정/묵주 화면을 RWFit 백엔드와 연결. 데이터는 rwfit_db.sqlite로 분리.
- Android/iOS의 picnique/backend 채널은 시작 시 한 번 선택하며 세션 내 변경을 거부합니다. RWFit 진입 시 QRing bridge를 생성하지 않습니다.
- 실제 실행/빌드는 하지 않았습니다. 소스만 작성했습니다.

## 구현
연결·스캔·iOS UUID 보존, functionMenu 기반 준비 완료, 재연결용 전체 장치 정보 로컬 저장 및 삭제, 배터리 이벤트와 Ring Provider, 단일 측정 및 결과 영구 저장, 역사자료 동기화 완료/실패 이벤트, 동기화 상태 Provider, 원래 차트의 새 SDK 갱신 경로, 건강설정의 심박/혈중산소/스트레스 읽기·변경·재조회, 단일 터치 기반 묵주 카운트를 연결했습니다.

## 데이터 매핑
- SDK 이력 time/beginTime/endTime: Unix 초. DateTime으로 변환할 때만 1000배. raw MiniProgram의 2000년 epoch 보정을 중복 적용하지 않습니다.
- hr → bpm, bo.bloodOxy → %, pressure → 장치 스트레스 값.
- SDK 역사 수면 0/1/2/3(각성/얕음/깊음/REM) → 기존 DB 5/2/3/4. 항목 len은 분이며 시작부터 누적합니다. 전체 길이와 종료가 맞지 않으면 차트 변환하지 않습니다.
- 활동은 SDK가 15분 간격을 명시하고 시각/정수 단위가 일치할 때만 기존 15분 차트에 반영합니다. 거리 m, 칼로리 cal. 기존 walkSteps 열에는 총 걸음 수를 보관하고 runSteps는 별도 분류가 없음을 나타내는 0으로 둡니다. 이는 보행/달리기 분류 측정이 아니며 해당 분류를 제공한다고 주장하지 않습니다.
- 원본 날짜 레코드는 device_id/kind/payload 기준 SQLite 테이블에 보관합니다. 이미 저장된 동일 레코드 재수신은 재삽입하지 않습니다. 형식이 맞지 않거나 기존 차트가 지원하지 않는 HRV/혈압/혈당/체온/카운트 등은 raw_only로 보존합니다. 추정값을 차트에 넣지 않습니다.
- 한 레코드의 원본과 차트 삽입을 같은 Drift transaction에 저장하며 SDK 동기화 종료 뒤 로컬 쓰기 큐까지 기다립니다. 시작 전에 저장 테이블 접근을 시도합니다.

## 제한 및 남은 검증
SDK 내부 삭제/ACK와 앱 로컬 저장 사이의 crash-safe 보장은 공개 API에서 확인되지 않았습니다. 단절/프로세스 종료 순간의 손실 가능성을 없앴다고 주장할 수 없습니다. 생산 장치 데이터를 사용하기 전 별도 검증이 필요합니다.
모니터링의 걸음·수면·활동 켜기/끄기 명령은 제공 계약에서 확인되지 않아 비활성 안내합니다. 미지원 장치 기능은 SDK 오류로 표시합니다. 수면 길이 불일치/15분 이외 활동 기록은 원본 보존만 하며 차트는 비어 있을 수 있습니다.
기존 QRing DB를 RWFit DB로 자동 이전하지 않습니다. 타 장치 데이터와 단위를 섞지 않기 위한 결정입니다. 자동 재연결 대신 저장된 기기를 사용자 버튼으로 재연결합니다.

## 문서 상충
DOCX CRC 테이블은 생략되어 있으며 장치 찾기 패킷을 시간 동기화 예시로 부르는 부분과 UTC+8/+9 표현 혼선이 있습니다. 직접 CRC/패킷을 추측하지 않고 SDK API를 사용했습니다. 역사 수면 코드와 raw 실시간 수면 코드를 구분합니다.

## 미실행
사용자 요청으로 테스트·분석기·빌드·시뮬레이터·실기기를 실행하지 않았습니다. pub get, lockfile 재생성, CocoaPods 설치도 하지 않았습니다. 두 SDK 포함 시 native 의존성 충돌, Android/iOS 콜백 순서, 수면/활동 장치별 데이터 형태는 확인되지 않았습니다. 커밋·푸시·배포 없이 Mac mini 작업 트리에 저장했습니다.


## Latest upstream integration (2026-11-15)
- Pulled 13 commits by fast-forward from cb6dd95 to ebfbd69; original dirty work is retained in a timestamped local backup and Git stash.
- Upstream has replaced its native legacy BLE bridge with a Dart-only BLE stack. This integration preserves that stack, new healthcare UI, schema v6, and legal/settings routes. It does not resurrect deleted native bridge initialization.
- `main.dart` remains the upstream backend. `main_rwfit.dart` selects the documented RWFit SDK; the two BLE coordinators are not started together.
- RWFit bypasses upstream auto-reconnect/background import coordinator, and uses explicit saved-device reconnect/history sync. Upstream automatic collection, charging push/live activity are not represented as RWFit capabilities.
- Upstream rosary screen API (start(ring:), increment, ringTouchActive) is preserved; RWFit uses SDK single-tap events rather than upstream raw accelerometer stream.
- Schema v6 source values distinguish RWFit manual samples from firmware history. Original local DB remains separate from rwfit_db.sqlite.
- Native backend-selection handshake, new chart refresh notifier, saved binding provider and six health screens were integrated by source inspection only.
- No dependency resolution, tests, analyzer, build, device validation, push or deployment was performed. pubspec.lock is the upstream lock; rwfit_ble remains unresolved until authorized dependency resolution.
