import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/ring_measurement_policy.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_data_refresh_notifier.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_health_accumulation.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_pending_import.dart';

/// 앱 프로세스가 살아 있는 동안 반지 메모리 → pending 큐 → Drift DB 자동 병합.
///
/// - 연결 + sdkReady: 주기적으로 반지 저장분 pull + import
/// - 미연결: 네이티브 keepalive 가 쌓아둔 pending 큐만 import
/// - 네이티브가 수집을 마치면 `healthDataReady` 이벤트로 즉시 import
class RingBackgroundImportScheduler {
  RingBackgroundImportScheduler._();
  static final RingBackgroundImportScheduler instance =
      RingBackgroundImportScheduler._();

  static const Duration interval = RingMeasurementPolicy.appCollectInterval;

  static const EventChannel _healthEvents = EventChannel(
    'com.example.picnique_ring/health_events',
  );

  Timer? _timer;
  bool _tickInFlight = false;
  Ring? _ring;
  HealthDataRefreshNotifier? _refreshNotifier;
  StreamSubscription<dynamic>? _healthSubscription;

  void bind(Ring ring, {HealthDataRefreshNotifier? refreshNotifier}) {
    _ring = ring;
    _refreshNotifier = refreshNotifier;
    _ensureHealthDataListener();
    _syncTimer();
  }

  void unbind() {
    _ring = null;
    _refreshNotifier = null;
    _stop();
    unawaited(_healthSubscription?.cancel());
    _healthSubscription = null;
  }

  void onRingStateChanged() => _syncTimer();

  /// 네이티브 백그라운드 수집 완료 알림 → 즉시 DB 병합.
  void _ensureHealthDataListener() {
    if (_healthSubscription != null) return;
    _healthSubscription = _healthEvents.receiveBroadcastStream().listen(
      (event) {
        if (event is! Map) return;
        if (event['type'] != 'healthDataReady') return;
        unawaited(
          RingPendingImport.importAll(
            ring: _ring,
            refreshNotifier: _refreshNotifier,
          ),
        );
      },
      onError: (Object e) {
        debugPrint('[BG_IMPORT] health event error: $e');
      },
    );
  }

  void _syncTimer() {
    final ring = _ring;
    if (ring != null && ring.hasSavedDevice) {
      _start();
    } else {
      _stop();
    }
  }

  void _start() {
    if (_timer != null) return;
    unawaited(_tick());
    _timer = Timer.periodic(interval, (_) => unawaited(_tick()));
    debugPrint('[BG_IMPORT] scheduler started (${interval.inMinutes}m)');
  }

  void _stop() {
    if (_timer == null) return;
    _timer?.cancel();
    _timer = null;
    debugPrint('[BG_IMPORT] scheduler stopped');
  }

  Future<void> _tick() async {
    if (_tickInFlight) return;
    if (BleCommandQueue.manualInFlight) {
      debugPrint('[BG_IMPORT] deferred — manual measurement busy');
      return;
    }
    _tickInFlight = true;
    try {
      final ring = _ring;
      if (ring != null && ring.isConnected && ring.sdkReady) {
        await RingHealthAccumulation.flushConnectedToApp(
          ring: ring,
          refreshNotifier: _refreshNotifier,
        );
      } else {
        await RingPendingImport.importAll(
          ring: ring,
          refreshNotifier: _refreshNotifier,
        );
      }
    } finally {
      _tickInFlight = false;
    }
  }
}
