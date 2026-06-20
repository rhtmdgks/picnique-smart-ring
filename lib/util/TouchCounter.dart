// ignore_for_file: file_names

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_live_activity.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_touch_mode_service.dart';

class RingTouchController with ChangeNotifier {
  bool _listening = false;
  Timer? _timer;
  RingLiveActivity? _liveActivity;
  VoidCallback? _liveListener;

  int tapCount = 0;
  String? lastGesture;
  int? lastCode;
  String? lastRaw;

  bool get isListening => _listening;

  /// 묵주 기록용 터치 모드(3) 켜고 네이티브 카운트를 폴링한다.
  Future<void> start({RingLiveActivity? liveActivity}) async {
    if (_listening) return;

    tapCount = 0;
    _listening = true;

    try {
      await RingTouchModeService.instance.enterRosaryRecording();
      debugPrint('[TOUCH] rosary touch mode (3) enabled');
    } catch (e) {
      debugPrint('[TOUCH] enterRosaryRecording failed: $e');
      _listening = false;
      rethrow;
    }

    _liveActivity = liveActivity;
    if (_liveActivity != null) {
      if (!_liveActivity!.isTracking) {
        await _liveActivity!.start();
      }
      try {
        await RingTouchModeService.instance.enterRosaryRecording();
        debugPrint('[TOUCH] re-enabled rosary mode after live activity');
      } catch (e) {
        debugPrint('[TOUCH] re-enable after live activity failed: $e');
      }

      _liveActivity!.resetTouchCount();
      _liveListener = () {
        final count = _liveActivity!.touchCount;
        if (count != tapCount) {
          tapCount = count;
          notifyListeners();
        }
      };
      _liveActivity!.addListener(_liveListener!);
    }

    startPolling();
  }

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!_listening) return;
      try {
        final count = await BleCommandQueue.invoke<int>('getRingTouchCount');
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
      await RingTouchModeService.instance.exitRosaryRecording();
    } catch (e) {
      debugPrint('[TOUCH] exitRosaryRecording error: $e');
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
