// ignore_for_file: file_names

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// BLE 실시간 이벤트 로깅 전용 파일
/// 앱에서 백그라운드 없이 단순히 링이 보내주는 이벤트를 받아 로그 출력만 합니다.
/// 사용법:
///   BleRealtimeLogger.start();
///   BleRealtimeLogger.stop();
class BleRealtimeLogger {
  static const EventChannel _eventChannel = EventChannel(
    'com.example.picnique_ring/ble_events',
  );
  static const MethodChannel _channel = MethodChannel(
    'com.example.picnique_ring/ble',
  );

  static StreamSubscription<dynamic>? _subscription;

  /// 실시간 이벤트 로깅 시작.
  /// [onDisconnected]: 링이 끊기면(이벤트 type == 'disconnected') 호출된다.
  /// 단일 EventChannel을 공유하므로 끊김 감지는 이 구독에서 함께 처리한다.
  static Future<void> start({VoidCallback? onDisconnected}) async {
    // 이미 구독 중이면 제거
    await stop();

    await _channel.invokeMethod('enableRealtimeNotifications');

    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map && event['type'] == 'disconnected') {
          debugPrint('[RING EVENT] disconnected');
          onDisconnected?.call();
        }
      },
      onError: (error) {
        debugPrint('[RING EVENT ERROR] -> $error');
      },
    );
  }

  /// 로깅 중지
  static Future<void> stop() async {
    await _subscription?.cancel();
    await _channel.invokeMethod('disableRealtimeNotifications');
    _subscription = null;
  }
}
