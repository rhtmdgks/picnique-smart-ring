import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 앱이 꺼져 있어도 네이티브에서 반지 연결·주기 측정을 유지한다.
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
