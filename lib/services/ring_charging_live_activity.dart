import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS Dynamic Island / Live Activity 충전 표시 (iOS 16.2+).
class RingChargingLiveActivity {
  RingChargingLiveActivity._();

  static const MethodChannel _channel = MethodChannel(
    'com.example.picnique_ring/charging_live_activity',
  );

  static Future<void> sync({
    required bool isCharging,
    int? battery,
  }) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod('syncChargingActivity', {
        'isCharging': isCharging,
        'battery': battery ?? 0,
      });
    } catch (e) {
      debugPrint('[CHARGING_LIVE_ACTIVITY] sync failed: $e');
    }
  }
}
