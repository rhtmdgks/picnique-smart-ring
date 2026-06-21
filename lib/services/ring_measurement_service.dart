import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_data_refresh_notifier.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_pending_import.dart';

/// 수동·자동 BLE 측정의 단일 Dart 진입점.
class RingMeasurementService {
  RingMeasurementService._();

  static const MethodChannel _bgChannel = MethodChannel(
    'com.example.picnique_ring/background_keepalive',
  );

  static const EventChannel _healthEvents = EventChannel(
    'com.example.picnique_ring/health_events',
  );

  static StreamSubscription<dynamic>? _healthSubscription;
  static bool _healthListenerStarted = false;

  static String _legacyMethod(DataType type) => switch (type) {
        DataType.HeartRate => 'syncManualHeartRate',
        DataType.Oxygen => 'syncManualBloodOxygen',
        DataType.Stress => 'syncManualPressure',
        _ => '',
      };

  static Future<Map<String, dynamic>> measureManual(DataType type) async {
    final method = _legacyMethod(type);
    if (method.isEmpty) {
      throw PlatformException(
        code: 'MEASURE_INVALID_TYPE',
        message: 'unsupported manual measure type',
      );
    }

    try {
      // iOS 수동 측정: reset 시 stopToMeasuring 이 측정 시작을 깨므로 SpO₂·심박·스트레스는 생략.
      if (!(Platform.isIOS &&
          (type == DataType.Oxygen ||
              type == DataType.HeartRate ||
              type == DataType.Stress))) {
        await _resetNativeSession();
      }

      final dynamic res = await BleCommandQueue.invoke<dynamic>(method);

      if (res is! Map) {
        debugPrint('[MEASURE] invalid response for $method: $res');
        throw PlatformException(
          code: 'MEASURE_INVALID_RESPONSE',
          message: 'invalid manual measurement response',
        );
      }
      return Map<String, dynamic>.from(res);
    } on PlatformException catch (e) {
      debugPrint('[MEASURE] manual $method failed: ${e.code} ${e.message}');
      if (e.code.contains('TIMEOUT') ||
          e.code == 'MEASURE_SESSION_TIMEOUT' ||
          e.code == 'MEASURE_CHANNEL_TIMEOUT') {
        await _resetNativeSession();
      }
      rethrow;
    }
  }
  static void ensureHealthDataListener({
    Ring? ring,
    HealthDataRefreshNotifier? refreshNotifier,
  }) {
    if (_healthListenerStarted) return;
    _healthListenerStarted = true;
    _healthSubscription = _healthEvents.receiveBroadcastStream().listen(
      (event) async {
        if (event is! Map) return;
        if (event['type'] != 'healthDataReady') return;
        try {
          await RingPendingImport.importAll(
            ring: ring,
            refreshNotifier: refreshNotifier,
          );
        } catch (e) {
          debugPrint('[MEASURE] healthDataReady import failed: $e');
        }
      },
      onError: (Object e) {
        debugPrint('[MEASURE] health event error: $e');
      },
    );
  }

  static Future<void> disposeHealthDataListener() async {
    await _healthSubscription?.cancel();
    _healthSubscription = null;
    _healthListenerStarted = false;
  }

  static Future<bool> isBusy() async {
    try {
      final busy = await BleCommandQueue.invoke<bool>('isMeasurementBusy');
      return busy ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _resetNativeSession() async {
    try {
      await BleCommandQueue.invoke<bool>('resetMeasurementSession');
    } catch (e) {
      debugPrint('[MEASURE] resetMeasurementSession failed: $e');
    }
  }

  /// 반지 저장소 pull → pending → DB.
  static Future<int> collectAndImport({
    bool force = false,
    Ring? ring,
    HealthDataRefreshNotifier? refreshNotifier,
  }) async {
    if (ring != null && !ring.isConnected) {
      debugPrint('[MEASURE] skip collect — not connected');
      return 0;
    }

    try {
      await BleCommandQueue.invoke<bool>(
        'collectHealthIfIdle',
        {'force': force},
      );
    } catch (e) {
      debugPrint('[MEASURE] collectHealthIfIdle failed: $e');
      try {
        await _bgChannel.invokeMethod<void>('collectPendingHealthNow');
      } catch (_) {}
    }

    return RingPendingImport.importAll(
      ring: ring,
      refreshNotifier: refreshNotifier,
    );
  }
}
