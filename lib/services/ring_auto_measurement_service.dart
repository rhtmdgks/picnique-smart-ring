import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/ring_measurement_policy.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/measurement_source.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_data_refresh_notifier.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_live_metrics.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_measurement_store.dart';

/// 연결 중 앱 주도 자동 측정.
///
/// 5분마다 심박 → 스트레스 → SpO₂ 를 순차 측정해 Drift DB에 저장한다.
/// 단일 BLE 링크를 공유하므로 세 측정은 반드시 직렬로 실행한다
/// (동시 실행 시 SDK 응답이 엉킨다). 개별 측정 실패는 사이클을 중단하지
/// 않고 다음 항목으로 넘어간다.
///
/// 수동 측정은 자동 측정보다 우선한다 — [pauseForManual]이 진행 중인
/// 사이클을 즉시 중단시키고, 수동 측정 완료 후 [resumeAfterManual]이
/// 그 시점부터 5분 간격으로 타이머를 다시 시작한다.
class RingAutoMeasurementService {
  RingAutoMeasurementService._();
  static final RingAutoMeasurementService instance =
      RingAutoMeasurementService._();

  static const Duration interval = RingMeasurementPolicy.autoMeasureInterval;

  Timer? _timer;
  bool _cycleInFlight = false;
  bool _abortRequested = false;
  bool _manualHold = false;
  // 수면 중 자동 측정 정지 — _manualHold 와 독립 (SleepGate 가 제어).
  bool _sleepHold = false;
  Ring? _ring;
  HealthDataRefreshNotifier? _refreshNotifier;
  HealthLiveMetrics? _liveMetrics;

  void bind(
    Ring ring, {
    HealthDataRefreshNotifier? refreshNotifier,
    HealthLiveMetrics? liveMetrics,
  }) {
    _ring = ring;
    _refreshNotifier = refreshNotifier;
    _liveMetrics = liveMetrics;
    _syncTimer();
  }

  void unbind() {
    _ring = null;
    _refreshNotifier = null;
    _liveMetrics = null;
    _stop();
  }

  /// 연결·sdkReady 상태가 바뀔 때마다 호출해 타이머를 켜거나 끈다.
  void onRingStateChanged() => _syncTimer();

  /// 수동 측정 선점 — 진행 중인 자동 사이클을 즉시 중단하고 타이머를 멈춘다.
  ///
  /// 대기 중인 자동 BLE 호출은 취소되고, 진행 중인 호출은 네이티브 세션
  /// 중단 후 강제 종료된다. 사이클이 풀릴 때까지(짧게) 기다린다.
  Future<void> pauseForManual() async {
    _manualHold = true;
    _stop();
    if (!_cycleInFlight) return;

    _abortRequested = true;
    await BleCommandQueue.preemptAutoForManual();

    // 선점된 호출의 future 가 정리될 때까지 잠깐 대기.
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (_cycleInFlight && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (_cycleInFlight) {
      debugPrint('[AUTO_MEASURE] pauseForManual — cycle still draining');
    }
  }

  /// 수동 측정 완료 — 완료 시점부터 5분 간격으로 자동 측정을 재개한다.
  void resumeAfterManual() {
    _manualHold = false;
    _abortRequested = false;
    _syncTimer(runImmediately: false);
  }

  /// 수면 감지(SleepGate) — 자동 측정 타이머를 멈춘다. 수동 측정은 계속 허용.
  void pauseForSleep() {
    if (_sleepHold) return;
    _sleepHold = true;
    _stop();
    debugPrint('[AUTO_MEASURE] paused — sleep detected');
  }

  /// 기상 감지 — 자동 측정을 재개한다.
  void resumeAfterWake() {
    if (!_sleepHold) return;
    _sleepHold = false;
    _syncTimer(runImmediately: false);
    debugPrint('[AUTO_MEASURE] resumed — wake detected');
  }

  @visibleForTesting
  bool get sleepHold => _sleepHold;

  /// 수동 측정 결과 저장용 공용 진입점 — 자동 측정과 같은 DB·알림 경로.
  Future<void> recordMeasurement(
    DataType type,
    int value, {
    MeasurementSource source = MeasurementSource.appTimerFallback,
  }) async {
    await RingMeasurementStore.save(
      type,
      value,
      DateTime.now(),
      source: source,
      deviceAddress: _ring?.savedAddress,
    );
    _liveMetrics?.record(type, value);
    _refreshNotifier?.notifyChanged(type);
  }

  void _syncTimer({bool runImmediately = true}) {
    if (_manualHold || _sleepHold) return;
    final ring = _ring;
    if (ring != null && ring.isConnected && ring.sdkReady) {
      _start(runImmediately: runImmediately);
    } else {
      _stop();
    }
  }

  void _start({required bool runImmediately}) {
    if (_timer != null) return;
    if (runImmediately) {
      unawaited(_runCycle());
    }
    _timer = Timer.periodic(interval, (_) => unawaited(_runCycle()));
    debugPrint(
      '[AUTO_MEASURE] started (${interval.inMinutes}m, immediate=$runImmediately)',
    );
  }

  void _stop() {
    if (_timer == null) return;
    _timer?.cancel();
    _timer = null;
    debugPrint('[AUTO_MEASURE] stopped');
  }

  Future<void> _runCycle() async {
    if (_cycleInFlight) {
      debugPrint('[AUTO_MEASURE] cycle skipped — previous still running');
      return;
    }
    if (_manualHold || _sleepHold) return;
    final ring = _ring;
    if (ring == null || !ring.isConnected || !ring.sdkReady) return;

    // 사용자 수동 측정이 진행 중이면 이번 사이클은 양보한다.
    if (BleCommandQueue.manualInFlight) {
      debugPrint('[AUTO_MEASURE] cycle deferred — manual measurement busy');
      return;
    }

    _cycleInFlight = true;
    try {
      for (final type in const [
        DataType.HeartRate,
        DataType.Stress,
        DataType.Oxygen,
      ]) {
        if (_abortRequested || _manualHold || _sleepHold) {
          debugPrint('[AUTO_MEASURE] cycle aborted — manual/sleep hold');
          return;
        }
        await _measureAndSave(type);
      }
    } finally {
      _cycleInFlight = false;
      // 사이클 중 pause 된 펌웨어 스케줄 복원 (큐 직렬 슬롯에서 실행).
      unawaited(BleCommandQueue.flushPendingScheduleRestores());
    }
  }

  Future<void> _measureAndSave(DataType type) async {
    final ring = _ring;
    if (ring == null || !ring.isConnected) return;
    final method = RingMeasurementStore.methodFor(type);
    if (method == null) return;

    final int value;
    try {
      final dynamic res = await BleCommandQueue.invokeAuto<dynamic>(method);
      final parsed = RingMeasurementStore.extractValue(res, type);
      if (parsed == null) {
        debugPrint('[AUTO_MEASURE] $method invalid result: $res');
        return;
      }
      value = parsed;
    } on PlatformException catch (e) {
      if (e.code == BleCommandQueue.autoCancelledCode ||
          e.code.endsWith('_ABORTED')) {
        // 큐 취소 또는 네이티브 선점 종료 — 정상 선점 흐름.
        debugPrint('[AUTO_MEASURE] $method cancelled by manual measurement');
        return;
      }
      debugPrint('[AUTO_MEASURE] $method failed: ${e.code} ${e.message}');
      if (e.code.contains('TIMEOUT')) {
        // 세션이 측정 중 상태로 남으면 다음 측정이 막히므로 초기화한다.
        try {
          await BleCommandQueue.invoke<dynamic>('resetMeasurementSession');
        } catch (_) {}
      }
      return;
    } catch (e) {
      debugPrint('[AUTO_MEASURE] $method error: $e');
      return;
    }

    await recordMeasurement(type, value);
    debugPrint('[AUTO_MEASURE] $type = $value saved');
  }
}
