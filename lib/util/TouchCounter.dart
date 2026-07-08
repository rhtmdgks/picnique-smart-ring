// ignore_for_file: file_names

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';

/// 묵주 단수 카운터 — 기록 중에만 링 터치 센서를 활성화한다.
///
/// - [start]: 링 터치 컨트롤 ON (연결돼 있을 때) + 탭 이벤트 구독.
///   링 탭 1회 = 1단. 화면 탭([increment])도 병행 지원.
/// - [stop]: 링 터치 컨트롤 OFF + 구독 해제.
///
/// 자동 측정과의 충돌 없음:
/// - 터치 on/off 는 BLE 큐로 직렬화된 설정 쓰기 1회 — 측정 명령과
///   인터리브되지 않는다.
/// - 탭 이벤트는 링 → 폰 단방향 알림이라 진행 중인 측정 BLE 명령과
///   무관하게 도착하며, 측정 세션 상태를 건드리지 않는다.
class RingTouchController with ChangeNotifier {
  static const EventChannel _touchEvents = EventChannel(
    'com.example.picnique_ring/touch_events',
  );

  /// 링 탭 중복(더블 리포트) 방지 최소 간격.
  static const Duration _tapDebounce = Duration(milliseconds: 400);

  bool _listening = false;
  bool _ringTouchActive = false;
  StreamSubscription<dynamic>? _tapSubscription;
  DateTime? _lastRingTapAt;

  int tapCount = 0;

  bool get isListening => _listening;

  /// 링 터치 센서가 실제 활성화됐는지 (미연결 시 화면 탭만 동작).
  bool get ringTouchActive => _ringTouchActive;

  Future<void> start({Ring? ring}) async {
    if (_listening) return;
    tapCount = 0;
    _listening = true;
    notifyListeners();

    _tapSubscription = _touchEvents.receiveBroadcastStream().listen(
      _onTouchEvent,
      onError: (Object e) {
        debugPrint('[ROSARY] touch event error: $e');
      },
    );

    if (ring != null && ring.isConnected && ring.sdkReady) {
      try {
        await BleCommandQueue.invoke<dynamic>('enableRosaryTouch', {
          'strength': 5,
        });
        _ringTouchActive = true;
        debugPrint('[ROSARY] ring touch enabled');
        notifyListeners();
      } catch (e) {
        debugPrint('[ROSARY] ring touch enable failed: $e');
      }
    } else {
      debugPrint('[ROSARY] ring not ready — screen tap only');
    }
  }

  /// 화면 탭 — 링 미연결 시 대체 입력, 연결 시에도 병행 허용.
  void increment() {
    if (!_listening) return;
    tapCount++;
    debugPrint('[ROSARY] tap count=$tapCount (screen)');
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_listening) return;
    _listening = false;
    await _tapSubscription?.cancel();
    _tapSubscription = null;
    _lastRingTapAt = null;

    if (_ringTouchActive) {
      _ringTouchActive = false;
      try {
        await BleCommandQueue.invoke<dynamic>('disableRosaryTouch');
        debugPrint('[ROSARY] ring touch disabled');
      } catch (e) {
        debugPrint('[ROSARY] ring touch disable failed: $e');
      }
    }
    notifyListeners();
  }

  void _onTouchEvent(dynamic event) {
    if (!_listening) return;
    if (event is! Map || event['type'] != 'ringTap') return;

    final now = DateTime.now();
    final last = _lastRingTapAt;
    if (last != null && now.difference(last) < _tapDebounce) return;
    _lastRingTapAt = now;

    tapCount++;
    debugPrint('[ROSARY] tap count=$tapCount (ring)');
    notifyListeners();
  }

  @override
  void dispose() {
    _tapSubscription?.cancel();
    _tapSubscription = null;
    if (_ringTouchActive) {
      _ringTouchActive = false;
      // dispose 시점엔 await 불가 — best effort off.
      unawaited(
        BleCommandQueue.invoke<dynamic>('disableRosaryTouch').then<void>(
          (_) {},
          onError: (_) {},
        ),
      );
    }
    _listening = false;
    super.dispose();
  }
}
