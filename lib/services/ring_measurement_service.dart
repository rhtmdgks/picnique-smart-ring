import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/measurement_source.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_auto_measurement_service.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_measurement_store.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_session_arbiter.dart';

/// 수동 BLE 측정의 단일 Dart 진입점.
///
/// 수동 측정은 자동 측정보다 우선한다:
/// 1. 진행 중인 자동 사이클을 즉시 선점(대기분 취소 + 진행분 중단)
/// 2. 고우선순위로 측정 실행
/// 3. 결과를 자동 측정과 같은 경로(DB·UI 알림)로 저장
/// 4. 완료 시점부터 5분 간격으로 자동 측정 재개 — 실패해도 반드시 재개한다.
class RingMeasurementService {
  RingMeasurementService._();

  static bool _manualBusy = false;

  static Future<Map<String, dynamic>> measureManual(DataType type) async {
    final method = RingMeasurementStore.methodFor(type);
    if (method == null) {
      throw PlatformException(
        code: 'MEASURE_INVALID_TYPE',
        message: 'unsupported manual measure type',
      );
    }
    if (_manualBusy) {
      throw PlatformException(
        code: 'MEASURE_IN_PROGRESS',
        message: 'manual measurement already running',
      );
    }

    if (!RingSessionArbiter.instance.enter(RingSessionMode.manualMeasure)) {
      throw PlatformException(
        code: 'MEASURE_SESSION_BUSY',
        message: 'another ring session active',
      );
    }
    _manualBusy = true;
    final auto = RingAutoMeasurementService.instance;
    try {
      // 자동 측정 teardown(0x6a stop + drain) 완료 후 수동 시작.
      await auto.pauseForManual();

      if (Platform.isIOS) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      final dynamic res = await BleCommandQueue.invoke<dynamic>(method);
      if (res is! Map) {
        debugPrint('[MEASURE] invalid response for $method: $res');
        throw PlatformException(
          code: 'MEASURE_INVALID_RESPONSE',
          message: 'invalid manual measurement response',
        );
      }

      final value = RingMeasurementStore.extractValue(res, type);
      if (value != null) {
        // 자동 측정과 동일한 저장·알림 경로 재사용 — 출처만 수동으로 구분.
        await auto.recordMeasurement(
          type,
          value,
          source: MeasurementSource.appManual,
        );
        debugPrint('[MEASURE] manual $type = $value saved');
      } else {
        debugPrint('[MEASURE] manual $method no valid value: $res');
      }

      return Map<String, dynamic>.from(res);
    } on PlatformException catch (e) {
      debugPrint('[MEASURE] manual $method failed: ${e.code} ${e.message}');
      if (e.code.contains('TIMEOUT')) {
        // 측정 세션이 걸린 채 남지 않도록 초기화한다.
        try {
          await BleCommandQueue.invoke<dynamic>('resetMeasurementSession');
        } catch (_) {}
      }
      rethrow;
    } finally {
      _manualBusy = false;
      RingSessionArbiter.instance.exitToBackground();
      // 수동 완료(성공·실패 무관) 시점부터 5분 간격으로 자동 측정 재개.
      auto.resumeAfterManual();
      // 측정을 위해 pause 된 펌웨어 스케줄 복원 (큐 직렬 슬롯에서 실행).
      unawaited(BleCommandQueue.flushPendingScheduleRestores());
    }
  }
}
