import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 앱이 종료·백그라운드여도 네이티브에서 BLE 연결을 유지하고,
/// 반지 주기 측정값을 pending 큐에 쌓는다 (10분 주기).
/// Android: 포그라운드 서비스 · iOS: keepalive + BGTask
/// 앱 DB 병합: [RingPendingImport] + [RingBackgroundImportScheduler]
class RingBackgroundKeepalive {
  static const MethodChannel _channel = MethodChannel(
    'com.example.picnique_ring/background_keepalive',
  );

  static Future<void> start({
    required String address,
    String? name,
  }) async {
    try {
      await _channel.invokeMethod('startBackgroundKeepalive', {
        'address': address,
        'name': name ?? '',
      });
      debugPrint('[KEEPALIVE] started for $address');
    } catch (e) {
      debugPrint('[KEEPALIVE] start failed: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopBackgroundKeepalive');
      debugPrint('[KEEPALIVE] stopped');
    } catch (e) {
      debugPrint('[KEEPALIVE] stop failed: $e');
    }
  }
}
