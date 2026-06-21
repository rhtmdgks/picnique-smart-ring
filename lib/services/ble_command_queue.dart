import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// QCBandSDK / Oudmon SDK는 동시 MethodChannel 호출 시 응답이 엉킨다.
/// 모든 BLE `invokeMethod`를 iOS·Android 공통 직렬 실행한다.
/// 수동 측정(`executeManualMeasurement`, legacy `syncManual*`)은 우선 처리한다.
class BleCommandQueue {
  BleCommandQueue._();

  static const MethodChannel channel = MethodChannel(
    'com.example.picnique_ring/ble',
  );

  static const Set<String> _manualMethods = {
    'executeManualMeasurement',
    'resetMeasurementSession',
    'syncManualHeartRate',
    'syncManualPressure',
    'syncManualBloodOxygen',
    'syncManualHrv',
    'syncManualBp',
    'syncManualTemperature',
  };

  static bool _draining = false;
  static int _manualInFlight = 0;
  static final List<_QueuedBleCall> _pending = [];

  static bool get manualInFlight => _manualInFlight > 0;

  /// 자동 모니터링·설정 쓰기 전 — 수동 측정이 끝날 때까지 대기.
  static Future<void> waitUntilManualIdle({
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (_manualInFlight > 0 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    if (Platform.isIOS) {
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  static Future<T?> invoke<T>(String method, [dynamic arguments]) {
    final isManual = _manualMethods.contains(method);
    final completer = Completer<T?>();

    _pending.add(
      _QueuedBleCall(
        method: method,
        arguments: arguments,
        priority: isManual,
        completer: completer,
      ),
    );
    _drain();
    return completer.future;
  }

  static void _drain() {
    if (_draining) return;
    _draining = true;
    unawaited(_drainLoop());
  }

  static Future<void> _drainLoop() async {
    while (_pending.isNotEmpty) {
      final idx = _pending.indexWhere((call) => call.priority);
      final call = _pending.removeAt(idx >= 0 ? idx : 0);
      await _execute(call);
    }
    _draining = false;
  }

  static Duration _timeoutFor(String method, bool isManual) {
    if (isManual) {
      return const Duration(seconds: 95);
    }
    return const Duration(seconds: 50);
  }

  static Future<void> _execute(_QueuedBleCall call) async {
    final isManual = call.priority;
    final timeout = _timeoutFor(call.method, isManual);
    if (isManual) {
      _manualInFlight++;
    }
    try {
      final result = await channel
          .invokeMethod<dynamic>(call.method, call.arguments)
          .timeout(timeout);
      if (!call.completer.isCompleted) {
        call.completer.complete(result);
      }
    } on TimeoutException {
      if (!call.completer.isCompleted) {
        call.completer.completeError(
          PlatformException(
            code: call.priority ? 'MEASURE_CHANNEL_TIMEOUT' : 'BLE_CHANNEL_TIMEOUT',
            message: '${call.method} timed out after ${timeout.inSeconds}s',
          ),
        );
      }
    } catch (e, st) {
      if (!call.completer.isCompleted) {
        call.completer.completeError(e, st);
      }
    } finally {
      if (isManual) {
        _manualInFlight--;
        if (Platform.isIOS) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    }
  }
}

class _QueuedBleCall {
  _QueuedBleCall({
    required this.method,
    required this.arguments,
    required this.priority,
    required this.completer,
  });

  final String method;
  final dynamic arguments;
  final bool priority;
  final Completer<dynamic> completer;
}
