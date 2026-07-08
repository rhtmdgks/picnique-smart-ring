import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// BLE 작업 우선순위 — 낮은 index 가 높은 우선순위.
///
/// - [connection]: 연결·설정 등 즉시성 높은 호출 (기본값)
/// - [manual]: 사용자 수동 측정 (선점 주체)
/// - [uiFresh]: 화면 진입 시 최신화 등 사용자 체감 호출
/// - [backgroundSync]: 자동 측정·백그라운드 pull (선점 대상)
enum BleOpPriority { connection, manual, uiFresh, backgroundSync }

/// QCBandSDK / Oudmon SDK는 동시 MethodChannel 호출 시 응답이 엉킨다.
/// 모든 BLE `invokeMethod`를 iOS·Android 공통 직렬 실행한다.
/// 수동 측정(`executeManualMeasurement`, legacy `syncManual*`)은 우선 처리한다.
///
/// 자동 측정은 [invokeAuto]로 등록한다 — [BleOpPriority.backgroundSync]
/// (최저 우선순위)이며, 수동 측정 요청 시 [preemptAutoForManual]로
/// 대기분 취소·진행분 강제 중단(선점)이 가능하다.
class BleCommandQueue {
  BleCommandQueue._();

  static const MethodChannel channel = MethodChannel(
    'com.example.picnique_ring/ble',
  );

  /// 자동 측정 선점 시 취소된 호출에 쓰는 에러 코드.
  static const String autoCancelledCode = 'AUTO_MEASURE_CANCELLED';

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
  static _QueuedBleCall? _inFlightCall;
  static Completer<void>? _inFlightAbort;

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

  /// 기본 [BleOpPriority.connection] 우선순위 호출.
  ///
  /// 수동 측정 메서드([_manualMethods])는 자동으로 [BleOpPriority.manual]
  /// 로 승격된다. 화면 최신화 등은 [priority]에 [BleOpPriority.uiFresh]를
  /// 지정한다. (Dart 는 optional positional 과 named 를 섞을 수 없어
  /// [priority]도 optional positional 이다.)
  static Future<T?> invoke<T>(
    String method, [
    dynamic arguments,
    BleOpPriority? priority,
  ]) {
    final resolved = _manualMethods.contains(method)
        ? BleOpPriority.manual
        : (priority ?? BleOpPriority.connection);
    return _enqueue<T>(method, arguments, priority: resolved);
  }

  /// 자동 측정 전용 — [BleOpPriority.backgroundSync] 별칭.
  /// 수동 측정이 들어오면 취소·선점될 수 있다.
  static Future<T?> invokeAuto<T>(String method, [dynamic arguments]) {
    return _enqueue<T>(method, arguments, priority: BleOpPriority.backgroundSync);
  }

  /// iOS: 측정을 위해 pause 된 펌웨어 스케줄(HR·SpO₂·스트레스·HRV)을
  /// 큐 직렬 슬롯에서 복원한다. 네이티브 즉시 write 는 큐가 실행 중인
  /// 다른 BLE 명령과 인터리브되어 거부되므로, 반드시 이 경로로만 복원.
  /// 실패분은 네이티브 pending 에 남아 다음 호출에서 재시도된다.
  static Future<void> flushPendingScheduleRestores() async {
    if (!Platform.isIOS) return;
    try {
      final remaining = await invokeAuto<dynamic>('restorePendingSchedules');
      if (remaining is int && remaining > 0) {
        debugPrint('[SCHEDULE] restore flush — $remaining still pending');
      }
    } on PlatformException catch (e) {
      if (e.code == autoCancelledCode) return; // 수동 선점 — 다음 기회에.
      debugPrint('[SCHEDULE] restore flush failed: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('[SCHEDULE] restore flush error: $e');
    }
  }

  static Future<T?> _enqueue<T>(
    String method,
    dynamic arguments, {
    required BleOpPriority priority,
  }) {
    final completer = Completer<T?>();

    _pending.add(
      _QueuedBleCall(
        method: method,
        arguments: arguments,
        priority: priority,
        completer: completer,
      ),
    );
    _drain();
    return completer.future;
  }

  /// 세션 충돌·타임아웃성 실패를 지수 backoff(5초 → 10초 → 20초)로
  /// 재시도한다. 마지막 시도 실패 시 그대로 rethrow.
  ///
  /// 재시도 대상: [PlatformException] 중 code 에 'SESSION_BUSY',
  /// 'MEASURE_IN_PROGRESS' 또는 'TIMEOUT' 이 포함된 경우.
  static Future<T> runWithSessionRetry<T>(
    Future<T> Function() task, {
    int maxAttempts = 3,
  }) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await task();
      } on PlatformException catch (e) {
        final retryable = e.code.contains('SESSION_BUSY') ||
            e.code.contains('MEASURE_IN_PROGRESS') ||
            e.code.contains('TIMEOUT');
        if (!retryable || attempt >= maxAttempts) rethrow;
        final delay = Duration(seconds: 5 * math.pow(2, attempt - 1).toInt());
        debugPrint(
          '[BLE_QUEUE] retryable failure (${e.code}) — '
          'retry $attempt/$maxAttempts in ${delay.inSeconds}s',
        );
        await Future<void>.delayed(delay);
      }
    }
  }

  /// 수동 측정 선점: 대기 중인 backgroundSync 호출은 즉시 취소하고, 진행
  /// 중인 backgroundSync 호출은 네이티브 세션을 중단시킨 뒤 강제로
  /// 끝낸다(응답은 버린다).
  static Future<void> preemptAutoForManual() async {
    // 1) 큐에서 대기 중인 자동 호출 제거.
    final queued = _pending.where((c) => c.isAuto).toList();
    _pending.removeWhere((c) => c.isAuto);
    for (final call in queued) {
      if (!call.completer.isCompleted) {
        call.completer.completeError(
          PlatformException(
            code: autoCancelledCode,
            message: '${call.method} cancelled — preempted by manual measurement',
          ),
        );
      }
    }

    // 2) 진행 중인 자동 호출 중단.
    final inFlight = _inFlightCall;
    final abort = _inFlightAbort;
    if (inFlight != null && inFlight.isAuto && abort != null) {
      // 네이티브 측정 세션 정리 — 큐가 막혀 있으므로 채널 직접 호출.
      // (iOS: stopToMeasuring 으로 측정 자체를 중단, Android: 세션 상태 초기화)
      try {
        await channel
            .invokeMethod<void>('resetMeasurementSession')
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('[BLE_QUEUE] preempt reset failed: $e');
      }
      if (!abort.isCompleted) abort.complete();
    }
  }

  static void _drain() {
    if (_draining) return;
    _draining = true;
    unawaited(_drainLoop());
  }

  static Future<void> _drainLoop() async {
    while (_pending.isNotEmpty) {
      await _execute(_takeNext());
    }
    _draining = false;
  }

  /// 우선순위(enum index)가 가장 높은 호출을 꺼낸다.
  /// 같은 우선순위끼리는 큐 삽입 순서(FIFO)를 유지한다.
  static _QueuedBleCall _takeNext() {
    var bestIdx = 0;
    for (var i = 1; i < _pending.length; i++) {
      if (_pending[i].priority.index < _pending[bestIdx].priority.index) {
        bestIdx = i;
      }
    }
    return _pending.removeAt(bestIdx);
  }

  static Duration _timeoutFor(String method, bool isManual) {
    if (isManual) {
      return const Duration(seconds: 95);
    }
    return const Duration(seconds: 50);
  }

  static Future<void> _execute(_QueuedBleCall call) async {
    final isManual = call.isManual;
    // 자동 측정도 측정 명령 자체는 오래 걸리므로 수동과 같은 타임아웃을 쓴다.
    final timeout = _timeoutFor(call.method, isManual || call.isAuto);
    if (isManual) {
      _manualInFlight++;
    }
    _inFlightCall = call;
    final abort = call.isAuto ? Completer<void>() : null;
    _inFlightAbort = abort;
    try {
      final channelFuture = channel
          .invokeMethod<dynamic>(call.method, call.arguments)
          .timeout(timeout);

      dynamic result;
      var aborted = false;
      if (abort != null) {
        result = await Future.any<dynamic>([
          channelFuture,
          abort.future.then((_) {
            aborted = true;
            return null;
          }),
        ]);
      } else {
        result = await channelFuture;
      }

      if (aborted) {
        // 늦게 도착할 네이티브 응답·에러는 버린다.
        unawaited(channelFuture.then<dynamic>(
          (_) => null,
          onError: (_) => null,
        ));
        if (!call.completer.isCompleted) {
          call.completer.completeError(
            PlatformException(
              code: autoCancelledCode,
              message:
                  '${call.method} aborted — preempted by manual measurement',
            ),
          );
        }
        return;
      }

      if (!call.completer.isCompleted) {
        call.completer.complete(result);
      }
    } on TimeoutException {
      if (!call.completer.isCompleted) {
        call.completer.completeError(
          PlatformException(
            code: isManual ? 'MEASURE_CHANNEL_TIMEOUT' : 'BLE_CHANNEL_TIMEOUT',
            message: '${call.method} timed out after ${timeout.inSeconds}s',
          ),
        );
      }
    } catch (e, st) {
      if (!call.completer.isCompleted) {
        call.completer.completeError(e, st);
      }
    } finally {
      _inFlightCall = null;
      _inFlightAbort = null;
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
  final BleOpPriority priority;
  final Completer<dynamic> completer;

  bool get isManual => priority == BleOpPriority.manual;

  /// 기존 `isAuto` 의미 = backgroundSync (선점 대상).
  bool get isAuto => priority == BleOpPriority.backgroundSync;
}
