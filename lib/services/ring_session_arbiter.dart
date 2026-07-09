import 'dart:async';

import 'package:flutter/foundation.dart';

/// 링 세션 모드 — 한 번에 하나만 활성.
///
/// - [background]: 평상시. 자동 측정·백그라운드 sync·모니터링 설정 허용.
/// - [manualMeasure]: 사용자 수동 측정 중.
/// - [rosaryTouch]: 묵주기도 터치 기록 중.
enum RingSessionMode { background, manualMeasure, rosaryTouch }

/// 기능 모듈(수동 측정·묵주 터치)의 배타 실행을 중앙에서 조정한다.
///
/// 모듈이 세션에 진입하면 백그라운드 작업(자동 모니터링 설정 쓰기,
/// 수면 sync 등)은 [backgroundOpsAllowed]가 false 인 동안 시작하지 않는다.
/// 자동 측정 pause/resume 은 각 모듈이 기존 hold API 로 직접 수행한다 —
/// arbiter 는 "지금 어떤 세션인가"의 단일 진실 공급원.
class RingSessionArbiter with ChangeNotifier {
  RingSessionArbiter._();
  static final RingSessionArbiter instance = RingSessionArbiter._();

  RingSessionMode _mode = RingSessionMode.background;

  RingSessionMode get mode => _mode;

  bool get backgroundOpsAllowed => _mode == RingSessionMode.background;

  /// 세션 진입. 이미 다른 세션이면 false (호출측에서 거부 처리).
  bool enter(RingSessionMode mode) {
    assert(mode != RingSessionMode.background, 'exitToBackground() 사용');
    if (_mode != RingSessionMode.background && _mode != mode) {
      debugPrint('[SESSION] enter($mode) rejected — busy with $_mode');
      return false;
    }
    if (_mode == mode) return true;
    _mode = mode;
    debugPrint('[SESSION] → $mode');
    notifyListeners();
    return true;
  }

  void exitToBackground() {
    if (_mode == RingSessionMode.background) return;
    debugPrint('[SESSION] $_mode → background');
    _mode = RingSessionMode.background;
    notifyListeners();
  }

  /// 백그라운드 모드가 될 때까지 대기. 타임아웃 시 false.
  Future<bool> waitUntilBackground({
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (backgroundOpsAllowed) return true;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (backgroundOpsAllowed) return true;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return backgroundOpsAllowed;
  }
}
