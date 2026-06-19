import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/util/BLEUtil.dart';

/// 반지에서 오늘 활동(걸음/칼로리/거리)을 실시간으로 받아 UI에 반영한다.
///
/// - Android: BLE 실시간 이벤트(`rtSportSummary`) + 주기적 `syncTodaySport` 폴링
/// - iOS: SDK `currentStepInfo` 콜백 + 주기적 `syncTodaySport` 폴링
class RingLiveActivity with ChangeNotifier {
  static const MethodChannel _ble = MethodChannel(
    'com.example.picnique_ring/ble',
  );
  static const EventChannel _events = EventChannel(
    'com.example.picnique_ring/ble_events',
  );

  int _steps = 0;
  int _calories = 0;
  int _distanceM = 0;
  int _touchCount = 0;
  bool _tracking = false;

  StreamSubscription<dynamic>? _subscription;
  Timer? _pollTimer;

  int get steps => _steps;
  int get calories => _calories;
  int get distanceMeters => _distanceM;
  int get touchCount => _touchCount;
  bool get isTracking => _tracking;

  void resetTouchCount() {
    _touchCount = 0;
    notifyListeners();
  }

  void syncTouchCount(int count) {
    if (count == _touchCount) return;
    _touchCount = count;
    notifyListeners();
  }

  Future<void> start() async {
    if (_subscription != null) return;

    try {
      await _ble.invokeMethod('enableRealtimeNotifications');
    } catch (e) {
      debugPrint('[LIVE_ACTIVITY] enableRealtime failed: $e');
    }

    _subscription = _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (error) {
        debugPrint('[LIVE_ACTIVITY] event error: $error');
      },
    );

    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(refresh()),
    );

    await refresh();
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _pollTimer?.cancel();
    _pollTimer = null;

    try {
      await _ble.invokeMethod('disableRealtimeNotifications');
    } catch (_) {}

    _steps = 0;
    _calories = 0;
    _distanceM = 0;
    _tracking = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    final data = await fetchTodaySportFromRing(_ble);
    if (data == null) return;

    _apply(
      steps: data['totalSteps'] ?? 0,
      calories: data['calorie'] ?? 0,
      distanceM: data['walkDistance'] ?? 0,
    );
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;

    switch (event['type']) {
      case 'ringTouch':
        final count = _asInt(event['count']);
        if (count > 0 && count != _touchCount) {
          _touchCount = count;
          notifyListeners();
        }
        break;
      case 'rtSportSummary':
        _apply(
          steps: _asInt(event['steps']),
          calories: _asInt(event['calorie']),
          distanceM: _asInt(event['distance']),
        );
        break;
      case 'disconnected':
        unawaited(stop());
        break;
    }
  }

  void _apply({
    required int steps,
    required int calories,
    required int distanceM,
  }) {
    _tracking = true;
    if (steps == _steps && calories == _calories && distanceM == _distanceM) {
      return;
    }
    _steps = steps;
    _calories = calories;
    _distanceM = distanceM;
    notifyListeners();
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
