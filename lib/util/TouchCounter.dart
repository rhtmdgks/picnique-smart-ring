// ignore_for_file: file_names

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RingTouchController with ChangeNotifier {
  static const _method = MethodChannel('com.example.picnique_ring/ble');

  StreamSubscription? _sub;
  bool _listening = false;

  // 노출할 상태들
  int tapCount = 0;
  String? lastGesture; // 'single', 'double', 'unknown'
  int? lastCode;
  String? lastRaw; // hex string

  bool get isListening => _listening;
  Timer? _timer;
  void startPolling() {
    notifyListeners();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      try {
        final count = await _method.invokeMethod<int>("getRingTouchCount");
        if (count != null && count != tapCount) {
          tapCount++;
          debugPrint("Touch #$tapCount (polled)");
          notifyListeners();
        }
      } catch (e) {
        debugPrint("polling error: $e");
      }
    });
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  /// 터치 모드 켜고, 이벤트 구독 시작
  Future<void> start({int appType = 2, int strength = 7}) async {
    if (_listening) return;

    // 1) 네이티브에 터치 모드 활성화 요청
    // 지금 MainActivity에서는 인자 안 넘기고 bridge.enableRingTouch()만 호출 중이니까
    // 인자 쓰고 싶으면 MainActivity에서 call.argument로 꺼내는 코드 추가하면 됨.
    _listening = true;
    await _method.invokeMethod('enableSimpleTouchLogging');
    debugPrint("object enableSimpleTouchLogging called");

    // 2) 이벤트 구독
    startPolling();
  }

  /// 터치 모드 끄고, 이벤트 구독 해제
  Future<void> stop() async {
    if (!_listening) return;

    try {
      await _method.invokeMethod('disableSimpleTouchLogging');
    } catch (e) {
      debugPrint('disableRingTouch error: $e');
    }

    await _sub?.cancel();
    _sub = null;
    _listening = false;
    tapCount = 0;
    stopPolling();
    notifyListeners();
  }

  @override
  void dispose() {
    // dispose에서는 최소한 타이머랑 스트림은 바로 끊어줌
    stopPolling();
    _sub?.cancel();
    _sub = null;
    _listening = false;

    // (네이티브에 disable 호출은 dispose에서 굳이 안 해도 되거나,
    //  필요하면 fire-and-forget으로 호출)
    super.dispose();
  }
}
