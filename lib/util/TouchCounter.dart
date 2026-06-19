// ignore_for_file: file_names

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_live_activity.dart';

class RingTouchController with ChangeNotifier {
  static const _method = MethodChannel('com.example.picnique_ring/ble');

  bool _listening = false;
  Timer? _timer;
  RingLiveActivity? _liveActivity;
  VoidCallback? _liveListener;

  int tapCount = 0;
  String? lastGesture;
  int? lastCode;
  String? lastRaw;

  bool get isListening => _listening;

  /// 터치 모드 켜고 네이티브 카운트를 폴링한다.
  /// [liveActivity]가 있으면 BLE 이벤트(`ringTouch`)도 함께 수신한다.
  Future<void> start({
    RingLiveActivity? liveActivity,
    int appType = 2,
    int strength = 7,
  }) async {
    if (_listening) return;

    _liveActivity = liveActivity;
    if (_liveActivity != null) {
      if (!_liveActivity!.isTracking) {
        await _liveActivity!.start();
      }
      _liveListener = () {
        final count = _liveActivity!.touchCount;
        if (count != tapCount) {
          tapCount = count;
          notifyListeners();
        }
      };
      _liveActivity!.addListener(_liveListener!);
    }

    tapCount = 0;
    _liveActivity?.resetTouchCount();
    _listening = true;

    try {
      await _method.invokeMethod('enableSimpleTouchLogging');
      debugPrint('[TOUCH] enableSimpleTouchLogging ok');
    } catch (e) {
      debugPrint('[TOUCH] enableSimpleTouchLogging failed: $e');
      _listening = false;
      rethrow;
    }

    startPolling();
  }

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!_listening) return;
      try {
        final count = await _method.invokeMethod<int>('getRingTouchCount');
        if (count != null && count != tapCount) {
          tapCount = count;
          _liveActivity?.syncTouchCount(count);
          debugPrint('[TOUCH] polled count=$tapCount');
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[TOUCH] polling error: $e');
      }
    });
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> stop() async {
    if (!_listening) return;

    stopPolling();

    try {
      await _method.invokeMethod('disableSimpleTouchLogging');
    } catch (e) {
      debugPrint('[TOUCH] disableSimpleTouchLogging error: $e');
    }

    if (_liveListener != null) {
      _liveActivity?.removeListener(_liveListener!);
      _liveListener = null;
    }
    _liveActivity = null;

    _listening = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    if (_liveListener != null) {
      _liveActivity?.removeListener(_liveListener!);
    }
    super.dispose();
  }
}
