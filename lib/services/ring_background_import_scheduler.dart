import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/ring_measurement_policy.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_data_refresh_notifier.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_health_accumulation.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_pending_import.dart';

/// 앱 프로세스가 살아 있는 동안 네이티브 pending 큐 → Drift DB 자동 병합.
/// (연결 끊김·앱 완전 종료 시에는 반지 내부 메모리에 쌓였다가 재연결 시 flush)
class RingBackgroundImportScheduler {
  RingBackgroundImportScheduler._();
  static final RingBackgroundImportScheduler instance =
      RingBackgroundImportScheduler._();

  static const Duration interval = RingMeasurementPolicy.appCollectInterval;

  Timer? _timer;
  Ring? _ring;
  HealthDataRefreshNotifier? _refreshNotifier;

  void bind(Ring ring, {HealthDataRefreshNotifier? refreshNotifier}) {
    _ring = ring;
    _refreshNotifier = refreshNotifier;
    _syncTimer();
  }

  void unbind() {
    _ring = null;
    _refreshNotifier = null;
    _stop();
  }

  void onRingStateChanged() => _syncTimer();

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
    unawaited(_collectAndImport());
    _timer = Timer.periodic(interval, (_) {
      unawaited(_collectAndImport());
    });
    debugPrint('[BG_IMPORT] scheduler started (${interval.inMinutes}m)');
  }

  Future<void> _collectAndImport() async {
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
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }
}
