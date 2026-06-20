import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// iOS QCBandSDK는 동시 MethodChannel 호출 시 응답이 엉키거나 실패한다.
/// BLE 채널 `invokeMethod`를 iOS에서만 직렬 실행한다.
class BleCommandQueue {
  BleCommandQueue._();

  static const MethodChannel channel = MethodChannel(
    'com.example.picnique_ring/ble',
  );

  static Future<void> _tail = Future<void>.value();

  static Future<T?> invoke<T>(String method, [dynamic arguments]) {
    if (!Platform.isIOS) {
      return channel.invokeMethod<T>(method, arguments);
    }

    final completer = Completer<T?>();
    _tail = _tail.then((_) async {
      try {
        final result = await channel.invokeMethod<T>(method, arguments);
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
