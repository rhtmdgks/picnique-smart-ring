import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_data_refresh_notifier.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_pending_import.dart';

/// 연결 상태에서 반지 저장소 → 앱 DB 축적을 한 번에 수행한다.
class RingHealthAccumulation {
  static const MethodChannel _channel = MethodChannel(
    'com.example.picnique_ring/background_keepalive',
  );

  /// 반지 내부 저장 데이터를 pending 큐로 pull 한 뒤 DB에 병합한다.
  static Future<int> flushConnectedToApp({
    Ring? ring,
    HealthDataRefreshNotifier? refreshNotifier,
  }) async {
    if (ring != null && !ring.isConnected) {
      debugPrint('[HEALTH_ACC] skip flush — not connected');
      return 0;
    }
    try {
      await _channel.invokeMethod<void>('collectPendingHealthNow');
    } catch (e) {
      debugPrint('[HEALTH_ACC] native collect failed: $e');
    }
    return RingPendingImport.importAll(
      ring: ring,
      refreshNotifier: refreshNotifier,
    );
  }
}
