import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android/iOS Bluetooth permission helpers for flutter_blue_plus.
abstract final class RingPermissions {
  static Future<bool> ensureReady() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
      final denied = statuses.values.any((s) => s.isDenied || s.isPermanentlyDenied);
      if (denied) {
        debugPrint('[RING] BT permissions denied');
        return false;
      }
    }
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
