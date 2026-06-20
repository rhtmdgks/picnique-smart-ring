import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';

/// 반지 배터리 조회·정규화.
class RingBatteryService {
  RingBatteryService._();

  /// SDK 응답을 1~100 정수로 정규화. 유효하지 않으면 null.
  static int? normalizeLevel(dynamic raw) {
    if (raw == null) return null;
    final v = raw is num ? raw.toInt() : int.tryParse(raw.toString());
    if (v == null || v < 1 || v > 100) return null;
    return v;
  }

  /// 링에서 배터리를 읽어 [ring]에 반영한다. 성공 시 퍼센트 반환.
  static Future<int?> refresh(Ring ring) async {
    if (!ring.isConnected) return null;
    try {
      final result = await BleCommandQueue.invoke<dynamic>('getBatteryLevel')
          .timeout(const Duration(seconds: 12));
      return applyFromNative(ring, result);
    } on TimeoutException {
      debugPrint('[BATTERY] getBatteryLevel timeout');
    } on PlatformException catch (e) {
      debugPrint('[BATTERY] getBatteryLevel error: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('[BATTERY] getBatteryLevel unexpected: $e');
    }
    return null;
  }

  /// 연결 직후 BLE 스택 준비를 기다리며 여러 번 재시도한다.
  static Future<int?> refreshWithRetry(
    Ring ring, {
    int maxAttempts = 5,
    Duration initialDelay = const Duration(seconds: 2),
    bool sdkReady = true,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!ring.isConnected) return null;
      if (attempt == 0 && initialDelay > Duration.zero) {
        await Future.delayed(initialDelay);
      } else if (attempt > 0) {
        final backoffMs = 1500 * attempt;
        await Future.delayed(Duration(milliseconds: backoffMs));
      }
      if (!ring.isConnected) return null;

      final level = await refresh(ring);
      if (level != null) {
        debugPrint('[BATTERY] refresh ok attempt=${attempt + 1} level=$level');
        return level;
      }
      if (sdkReady) {
        debugPrint('[BATTERY] refresh retry attempt=${attempt + 1}/$maxAttempts');
      } else if (kDebugMode) {
        debugPrint(
          '[BATTERY] refresh retry (pre-sdk) attempt=${attempt + 1}/$maxAttempts',
        );
      }
    }
    return null;
  }

  /// 네이티브 응답을 [ring]에 반영. 연결 직후 검증용으로도 사용.
  static int? applyFromNative(Ring ring, dynamic result) {
    if (result is Map) {
      final level = normalizeLevel(result['level'] ?? result['battery']);
      final charging = result['charging'] == true;
      if (level != null) {
        ring.setBatteryAndCharging(level, charging);
        return level;
      }
      if (charging) {
        ring.setCharging(true);
      }
      return null;
    }
    final level = normalizeLevel(result);
    if (level != null) {
      ring.setBattery(level);
      return level;
    }
    return null;
  }
}
