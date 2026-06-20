import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';

/// 수동 측정 종류 — SpO2는 터치 모드 전환·재개 타이밍이 더 길다.
enum ManualMeasurementType { heartRate, spo2, stress, other }

/// 반지 터치 제어 모드: 묵주 기록 중만 3, 그 외에는 주기적으로 8(심박 측정) 유지.
class RingTouchModeService {
  RingTouchModeService._();
  static final RingTouchModeService instance = RingTouchModeService._();

  static const int rosaryAppType = 3;
  static const int hrMeasureAppType = 8;
  static const int touchOffAppType = 0;

  static const Duration enforceInterval = Duration(seconds: 30);
  static const Duration _defaultResumeDelay = Duration(milliseconds: 800);
  static const Duration _spo2ResumeDelay = Duration(milliseconds: 1500);
  static const Duration _defaultPauseSettleDelay = Duration(milliseconds: 300);
  static const Duration _spo2PauseSettleDelay = Duration(milliseconds: 500);
  static const List<Duration> _touchModeRetryBackoff = [
    Duration.zero,
    Duration(milliseconds: 600),
    Duration(milliseconds: 1200),
  ];

  Timer? _enforceTimer;
  bool _connected = false;
  bool _chargingPaused = false;
  bool _rosaryRecording = false;
  int _manualMeasurementHold = 0;

  bool get isRosaryRecording => _rosaryRecording;

  void onConnected() {
    _connected = true;
    _startEnforceTimer();
    unawaited(_applyHrMeasureMode(reason: 'connect'));
  }

  void onDisconnected() {
    _connected = false;
    _chargingPaused = false;
    _rosaryRecording = false;
    _manualMeasurementHold = 0;
    _enforceTimer?.cancel();
    _enforceTimer = null;
  }

  void onChargingStarted() {
    _chargingPaused = true;
    _enforceTimer?.cancel();
    _enforceTimer = null;
  }

  Future<void> onChargingEnded() async {
    _chargingPaused = false;
    if (!_connected || _rosaryRecording || _manualMeasurementHold > 0) return;
    _startEnforceTimer();
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!_connected || _rosaryRecording || _manualMeasurementHold > 0) return;
    await _applyHrMeasureModeWithRetry(reason: 'charge_end');
  }

  void _startEnforceTimer() {
    _enforceTimer?.cancel();
    _enforceTimer = Timer.periodic(enforceInterval, (_) {
      if (_connected &&
          !_chargingPaused &&
          !_rosaryRecording &&
          _manualMeasurementHold == 0) {
        unawaited(_applyHrMeasureMode(reason: 'periodic'));
      }
    });
  }

  /// 수동 측정 버튼 — 주기적 모드 8 적용을 멈추고 터치 모드를 먼저 해제한다.
  /// 네이티브 prepareForManualMeasurement도 appType=0을 보내지만, 주기 enforce와의
  /// 레이스를 막기 위해 Dart에서 선행 해제 + 안정화 대기를 한다.
  Future<void> pauseForManualMeasurement({
    ManualMeasurementType type = ManualMeasurementType.other,
  }) async {
    _manualMeasurementHold++;
    _enforceTimer?.cancel();
    _enforceTimer = null;

    await _releaseTouchMode(reason: 'manual_measure_pause');
    final settleDelay = type == ManualMeasurementType.spo2
        ? _spo2PauseSettleDelay
        : _defaultPauseSettleDelay;
    await Future<void>.delayed(settleDelay);
  }

  /// 수동 측정 종료 후 모드 8 주기 적용 재개.
  /// SpO2는 링 측정 완전 종료까지 더 긴 대기 후, 실패 시 백오프 재시도한다.
  Future<void> resumeAfterManualMeasurement({
    ManualMeasurementType type = ManualMeasurementType.other,
  }) async {
    if (_manualMeasurementHold > 0) {
      _manualMeasurementHold--;
    }
    if (!_connected || _rosaryRecording || _manualMeasurementHold > 0) return;

    final resumeDelay = type == ManualMeasurementType.spo2
        ? _spo2ResumeDelay
        : _defaultResumeDelay;
    await Future<void>.delayed(resumeDelay);
    if (!_connected || _rosaryRecording || _manualMeasurementHold > 0) return;

    _startEnforceTimer();
    await _applyHrMeasureModeWithRetry(reason: 'manual_measure_resume');
  }

  Future<void> enterRosaryRecording() async {
    _rosaryRecording = true;
    _enforceTimer?.cancel();
    _enforceTimer = null;
    try {
      await BleCommandQueue.invoke<void>('enableSimpleTouchLogging');
      debugPrint('[TOUCH_MODE] rosary recording → appType=$rosaryAppType');
    } catch (e) {
      _rosaryRecording = false;
      _startEnforceTimer();
      rethrow;
    }
  }

  Future<void> exitRosaryRecording() async {
    _rosaryRecording = false;
    try {
      await BleCommandQueue.invoke<void>('disableSimpleTouchLogging');
    } catch (e) {
      debugPrint('[TOUCH_MODE] disable rosary touch failed: $e');
    }
    if (_connected && _manualMeasurementHold == 0) {
      _startEnforceTimer();
      await _applyHrMeasureMode(reason: 'rosary_end');
    }
  }

  Future<void> _applyHrMeasureMode({required String reason}) async {
    if (!_connected ||
        _chargingPaused ||
        _rosaryRecording ||
        _manualMeasurementHold > 0) {
      return;
    }
    await _setTouchMode(
      hrMeasureAppType,
      touchOn: true,
      reason: reason,
    );
  }

  Future<void> _applyHrMeasureModeWithRetry({required String reason}) async {
    for (var attempt = 0; attempt < _touchModeRetryBackoff.length; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_touchModeRetryBackoff[attempt]);
      }
      if (!_connected ||
          _chargingPaused ||
          _rosaryRecording ||
          _manualMeasurementHold > 0) {
        return;
      }

      final ok = await _setTouchMode(
        hrMeasureAppType,
        touchOn: true,
        reason: '$reason#${attempt + 1}',
      );
      if (ok) return;
    }
  }

  Future<void> _releaseTouchMode({required String reason}) async {
    if (!_connected) return;
    await _setTouchMode(
      touchOffAppType,
      touchOn: false,
      reason: reason,
    );
  }

  Future<bool> _setTouchMode(
    int appType, {
    required bool touchOn,
    required String reason,
  }) async {
    try {
      await BleCommandQueue.invoke<void>('setRingTouchMode', {
        'appType': appType,
        'touchOn': touchOn,
        'strength': 1,
      });
      debugPrint('[TOUCH_MODE] appType=$appType touchOn=$touchOn ($reason)');
      return true;
    } on PlatformException catch (e) {
      debugPrint(
        '[TOUCH_MODE] set $appType failed ($reason): ${e.code} — ${e.message}',
      );
      return false;
    } catch (e) {
      debugPrint('[TOUCH_MODE] set $appType failed ($reason): $e');
      return false;
    }
  }
}
