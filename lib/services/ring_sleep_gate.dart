import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/ring_measurement_policy.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_auto_measurement_service.dart';

/// SleepGate 상태.
enum SleepGateState { awake, candidate, sleeping }

/// 야간 수면 감지 게이트.
///
/// QCBandSDK 에는 실시간 수면 시작/종료 알림이 없어(심박·SpO₂·운동상태
/// 알림만 존재) 수면 데이터를 주기적으로 probe 해 근사한다:
///
/// ```
/// AWAKE ──(후보 시간대 21:00~11:00 진입)──▶ CANDIDATE
/// CANDIDATE: 30분마다 probe (syncSleepNew offset 0)
///   ├─ 진행 중 수면 세그먼트 발견(마지막 et 가 now 기준 30분 이내) → SLEEPING
///   ├─ 폴백: probe 2회 연속 빈 결과/실패 AND 현재 23:00~07:00 → SLEEPING
///   └─ 11:00 지나면 → AWAKE
/// SLEEPING: 자동 측정 pause (수동 측정은 계속 허용)
///   ├─ 마지막 세그먼트 종료 후 30분 경과 or sober 꼬리 → WAKE
///   ├─ 앱 foreground 복귀 + 07:00 이후 → WAKE
///   └─ WAKE → AWAKE + 자동 측정 재개 + onWake 콜백 (SleepSync 트리거)
/// ```
///
/// 미연결이면 probe 를 중단한다(상태는 유지).
class RingSleepGate {
  RingSleepGate._({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static final RingSleepGate instance = RingSleepGate._();

  /// 테스트 전용 — 시계 주입이 가능한 독립 인스턴스.
  @visibleForTesting
  factory RingSleepGate.forTest({DateTime Function()? now}) =>
      RingSleepGate._(now: now);

  final DateTime Function() _now;

  Ring? _ring;
  void Function()? _onWake;
  Timer? _timer;
  SleepGateState _state = SleepGateState.awake;
  bool _probing = false;

  /// CANDIDATE 상태에서 연속으로 빈 결과/실패한 probe 횟수 (폴백 판정용).
  int _failedProbeStreak = 0;

  /// 마지막으로 관측한 수면 종료 시각.
  DateTime? _lastSleepEnd;

  /// 마지막 명시적 기상 시각 — 기상 직후 stale 데이터로 재수면 판정 방지.
  DateTime? _lastWakeAt;

  SleepGateState get state => _state;

  void bind(Ring ring, {void Function()? onWake}) {
    _ring = ring;
    _onWake = onWake;
    _syncTimer();
  }

  void unbind() {
    _ring = null;
    _onWake = null;
    _stopTimer();
  }

  /// 연결·sdkReady 상태 변화 시 호출 — 미연결이면 probe 타이머 중단.
  void onRingStateChanged() => _syncTimer();

  /// 앱 foreground 복귀 — SLEEPING 이고 아침(07:00~21:00)이면 즉시 기상 처리.
  void onAppResumed() {
    if (_state != SleepGateState.sleeping) return;
    final hour = _now().hour;
    if (hour >= RingMeasurementPolicy.sleepFallbackEndHour &&
        hour < RingMeasurementPolicy.sleepCandidateStartHour) {
      _wake('foreground after morning');
    }
  }

  void _syncTimer() {
    final ring = _ring;
    if (ring != null && ring.isConnected && ring.sdkReady) {
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  void _startTimer() {
    if (_timer != null) return;
    _timer = Timer.periodic(
      RingMeasurementPolicy.sleepProbeInterval,
      (_) => unawaited(tick()),
    );
    unawaited(tick());
    debugPrint('[SLEEP_GATE] probe timer started');
  }

  void _stopTimer() {
    if (_timer == null) return;
    _timer?.cancel();
    _timer = null;
    debugPrint('[SLEEP_GATE] probe timer stopped');
  }

  /// 21:00 ~ 11:00 (자정 걸침) — 수면 후보 시간대.
  bool _inCandidateWindow(DateTime now) =>
      now.hour >= RingMeasurementPolicy.sleepCandidateStartHour ||
      now.hour < RingMeasurementPolicy.sleepCandidateEndHour;

  /// 23:00 ~ 07:00 — probe 실패 시 시간 기반 폴백 구간.
  bool _inFallbackWindow(DateTime now) =>
      now.hour >= RingMeasurementPolicy.sleepFallbackStartHour ||
      now.hour < RingMeasurementPolicy.sleepFallbackEndHour;

  /// 상태머신 1회 평가. 타이머가 30분마다 호출한다.
  @visibleForTesting
  Future<void> tick() async {
    if (_probing) return;
    final ring = _ring;
    if (ring == null || !ring.isConnected || !ring.sdkReady) return;

    _probing = true;
    try {
      final now = _now();
      switch (_state) {
        case SleepGateState.awake:
          if (_inCandidateWindow(now)) {
            _state = SleepGateState.candidate;
            _failedProbeStreak = 0;
            debugPrint('[SLEEP_GATE] AWAKE → CANDIDATE');
            await _probeCandidate(now);
          }
        case SleepGateState.candidate:
          if (!_inCandidateWindow(now)) {
            _state = SleepGateState.awake;
            _failedProbeStreak = 0;
            debugPrint('[SLEEP_GATE] CANDIDATE → AWAKE (window closed)');
            return;
          }
          await _probeCandidate(now);
        case SleepGateState.sleeping:
          await _probeSleeping(now);
      }
    } finally {
      _probing = false;
    }
  }

  Future<void> _probeCandidate(DateTime now) async {
    _SleepProbe? probe;
    try {
      final res = await BleCommandQueue.invokeAuto<dynamic>(
        'syncSleepNew',
        {'offset': 0},
      );
      probe = _SleepProbe.parse(res);
    } catch (e) {
      debugPrint('[SLEEP_GATE] probe failed: $e');
    }

    if (probe == null) {
      // 빈 결과·실패 — 2회 연속이고 폴백 강제 시간대면 시간 기반 SLEEPING.
      _failedProbeStreak++;
      if (_failedProbeStreak >= 2 && _inFallbackWindow(now)) {
        _enterSleep(now, end: null, reason: 'time-based fallback');
      }
      return;
    }
    _failedProbeStreak = 0;

    // 기상 직후의 stale 수면 데이터로 재수면 판정하지 않는다.
    final wakeAt = _lastWakeAt;
    if (wakeAt != null && !probe.end.isAfter(wakeAt)) return;

    // 진행 중 수면: 마지막 세그먼트 종료가 now 기준 30분 이내.
    if (now.difference(probe.end) <= RingMeasurementPolicy.sleepWakeConfirm) {
      _enterSleep(now, end: probe.end, reason: 'ongoing sleep segment');
    }
  }

  Future<void> _probeSleeping(DateTime now) async {
    _SleepProbe? probe;
    try {
      final res = await BleCommandQueue.invokeAuto<dynamic>(
        'syncSleepNew',
        {'offset': 0},
      );
      probe = _SleepProbe.parse(res);
    } catch (e) {
      // probe 실패 — 수면 유지, 다음 주기에 재시도.
      debugPrint('[SLEEP_GATE] sleeping probe failed: $e');
    }

    if (probe != null) {
      final prev = _lastSleepEnd;
      if (prev == null || probe.end.isAfter(prev)) {
        _lastSleepEnd = probe.end;
      }
      // sober(깨어 있음) 꼬리 — 반지가 기상을 감지한 것으로 본다.
      if (probe.lastType == 5) {
        _wake('sober tail segment');
        return;
      }
    }

    final lastEnd = _lastSleepEnd;
    if (lastEnd != null &&
        now.difference(lastEnd) >= RingMeasurementPolicy.sleepWakeConfirm) {
      _wake('sleep ended ${now.difference(lastEnd).inMinutes}m ago');
    }
  }

  void _enterSleep(DateTime now, {DateTime? end, required String reason}) {
    _state = SleepGateState.sleeping;
    _lastSleepEnd = end;
    RingAutoMeasurementService.instance.pauseForSleep();
    debugPrint('[SLEEP_GATE] → SLEEPING ($reason)');
  }

  void _wake(String reason) {
    _state = SleepGateState.awake;
    _failedProbeStreak = 0;
    _lastSleepEnd = null;
    _lastWakeAt = _now();
    RingAutoMeasurementService.instance.resumeAfterWake();
    debugPrint('[SLEEP_GATE] → AWAKE ($reason)');
    final onWake = _onWake;
    if (onWake != null) onWake();
  }
}

/// `syncSleepNew` 응답 파싱 결과 — 밤 전체의 시작/종료와 마지막 세그먼트 타입.
class _SleepProbe {
  _SleepProbe({required this.start, required this.end, required this.lastType});

  final DateTime start;
  final DateTime end;

  /// 마지막 세그먼트 타입 (2=light, 3=deep, 4=rem, 5=awake/sober).
  final int lastType;

  /// `{st, et, list}` 형식 파싱. list 원소는 `{d, t}`(iOS 누적 duration)와
  /// `{st, et, type}`(세그먼트 절대 시각) 두 형식을 모두 지원한다.
  static _SleepProbe? parse(dynamic res) {
    if (res is! Map) return null;
    final st = _asInt(res['st']);
    final et = _asInt(res['et']);
    final list = (res['list'] as List?) ?? const [];
    if (st == null || st <= 0 || list.isEmpty) return null;

    var cursor = st;
    var lastEnd = st;
    var lastType = 0;
    for (final e in list) {
      if (e is! Map) continue;
      final d = _asInt(e['d']);
      if (d != null && d > 0) {
        cursor += d;
        if (cursor >= lastEnd) {
          lastEnd = cursor;
          lastType = _asInt(e['t']) ?? 0;
        }
        continue;
      }
      final segEt = _asInt(e['et']);
      if (segEt != null && segEt > 0 && segEt >= lastEnd) {
        lastEnd = segEt;
        lastType = _asInt(e['type']) ?? 0;
      }
    }

    final endSec = math.max(et ?? 0, lastEnd);
    if (endSec <= st) return null;
    return _SleepProbe(
      start: DateTime.fromMillisecondsSinceEpoch(st * 1000),
      end: DateTime.fromMillisecondsSinceEpoch(endSec * 1000),
      lastType: lastType,
    );
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }
}
