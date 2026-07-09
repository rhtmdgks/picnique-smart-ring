import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android/iOS Bluetooth permission helpers for flutter_blue_plus.
abstract final class RingPermissions {
  /// Android 12+: BLUETOOTH_SCAN + BLUETOOTH_CONNECT only (neverForLocation manifest).
  static Future<bool> ensurePermissions() async {
    if (!Platform.isAndroid) return true;

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    for (final entry in statuses.entries) {
      if (entry.value.isDenied || entry.value.isPermanentlyDenied) {
        debugPrint('[RING] BT permission denied: ${entry.key} → ${entry.value}');
        return false;
      }
    }
    return true;
  }

  static Future<bool> ensureReady() async {
    if (!await ensurePermissions()) return false;
    return isAdapterOn();
  }

  static Future<bool> isAdapterOn() async {
    try {
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (e) {
      debugPrint('[RING] adapter state error: $e');
      return false;
    }
  }

  static Future<void> turnOnAdapter() async {
    if (Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        debugPrint('[RING] turnOn failed: $e');
      }
    }
  }
}
