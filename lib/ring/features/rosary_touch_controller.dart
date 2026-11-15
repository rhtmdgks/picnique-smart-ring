import '../../integrations/rwfit/ring_backend.dart';
// Source: colmi_r06_fbp parseRawAccelerometerSensorData + tap logic (BSD-3-Clause)
// Adapted from lib/util/TouchCounter.dart rosary tap debounce

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_auto_measurement_service.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_session_arbiter.dart';

import '../commands/raw_sensor_command.dart';
import '../repository/ring_repository.dart';

/// Rosary bead tap counter using raw accelerometer stream (0xA1/0x03).
class RosaryTouchController with ChangeNotifier {
  static const Duration _tapDebounce = Duration(milliseconds: 400);
  static const double _impactThresholdG = 0.2;

  final RingRepository _repo = RingRepository.instance;

  StreamSubscription<AccelerometerSample>? _accelSub;
  bool _listening = false;
  bool _ringTouchActive = false;
  DateTime? _lastTapAt;

  int tapCount = 0;
  int _lastRwfitCount = 0;
  void _onRwfitTouch() {
    final session = RingBackend.rwfit;
    if (!_listening || session == null) return;
    _ringTouchActive = session.ready;
    final count = session.singleTaps;
    if (count > _lastRwfitCount) tapCount += count - _lastRwfitCount;
    _lastRwfitCount = count;
    notifyListeners();
  }

  bool get isListening => _listening;
  bool get ringTouchActive => _ringTouchActive;

  Future<void> start({Object? ring}) async {
    if (_listening) return;
    if (RingBackend.rwfit?.busy == true) return;
    if (!RingSessionArbiter.instance.enter(RingSessionMode.rosaryTouch)) {
      debugPrint('[ROSARY] start rejected — another ring session active');
      return;
    }
    tapCount = 0;
    _listening = true;
    notifyListeners();

    if (RingBackend.isRwfit) {
      final session = RingBackend.rwfit!;
      _lastRwfitCount = session.singleTaps;
      _ringTouchActive = session.ready;
      session.addListener(_onRwfitTouch);
      notifyListeners();
      return;
    }
    await RingAutoMeasurementService.instance.pauseForTouch();

    if (!_repo.isConnected) {
      debugPrint('[ROSARY] ring not connected — screen tap only');
      return;
    }

    try {
      await _repo.rawSensor.enableStream(true);
      _accelSub = _repo.rawSensor.accelerometerStream().listen(_onAccel);
      _ringTouchActive = true;
      debugPrint('[ROSARY] accel touch enabled');
      notifyListeners();
    } catch (e) {
      debugPrint('[ROSARY] accel enable failed: $e');
    }
  }

  void increment() {
    if (!_listening) return;
    tapCount++;
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_listening) return;
    _listening = false;
    if (RingBackend.isRwfit) {
      RingBackend.rwfit!.removeListener(_onRwfitTouch);
      _ringTouchActive = false;
      RingSessionArbiter.instance.exitToBackground();
      notifyListeners();
      return;
    }
    await _accelSub?.cancel();
    _accelSub = null;
    _lastTapAt = null;

    if (_ringTouchActive) {
      _ringTouchActive = false;
      try {
        await _repo.rawSensor.enableStream(false);
      } catch (e) {
        debugPrint('[ROSARY] accel disable failed: $e');
      }
    }
    RingSessionArbiter.instance.exitToBackground();
    RingAutoMeasurementService.instance.resumeAfterTouch();
    notifyListeners();
  }

  @override
  void dispose() {
    RingBackend.rwfit?.removeListener(_onRwfitTouch);
    _accelSub?.cancel();
    super.dispose();
  }

  void _onAccel(AccelerometerSample sample) {
    if (!_listening) return;

    final gX = sample.rawX / 512.0;
    final gY = sample.rawY / 512.0;
    final gZ = sample.rawZ / 512.0;
    final netG = sqrt(gX * gX + gY * gY + gZ * gZ);
    final impact = (netG - 1.0).abs();

    if (impact < _impactThresholdG) return;

    final now = DateTime.now();
    if (_lastTapAt != null &&
        now.difference(_lastTapAt!) < _tapDebounce) {
      return;
    }
    _lastTapAt = now;
    tapCount++;
    debugPrint('[ROSARY] ring tap count=$tapCount impact=${impact.toStringAsFixed(2)}');
    notifyListeners();
  }
}
