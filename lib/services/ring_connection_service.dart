import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_background_keepalive.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_background_sync.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_live_activity.dart';
import 'package:picnique_rosary_healthcare_smartring/util/BLEUtil.dart';

/// 저장된 반지 주소로 BLE 연결·실시간 추적을 수행한다.
class RingConnectionService {
  static const MethodChannel platform = MethodChannel(
    'com.example.picnique_ring/ble',
  );
  static const MethodChannel fgChannel = MethodChannel(
    'com.example.picnique_ring/foreground_service_channel',
  );

  static bool _connecting = false;
  static bool get isConnecting => _connecting;

  /// 마지막으로 연결했던 기기가 있으면 앱 시작 시 자동 재연결한다.
  static Future<bool> reconnectSavedRing({
    required Ring ring,
    required RingLiveActivity liveActivity,
    RingSyncController? sync,
  }) async {
    await ring.loadFromPrefs();
    final address = ring.address?.trim();
    if (address == null || address.isEmpty) return false;
    if (ring.isConnected) return true;
    if (_connecting) return false;

    final name = (ring.name?.trim().isNotEmpty ?? false)
        ? ring.name!.trim()
        : '스마트링';

    const attempts = 2;
    for (var i = 0; i < attempts; i++) {
      if (i > 0) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      final ok = await connect(
        address: address,
        deviceName: name,
        ring: ring,
        liveActivity: liveActivity,
        sync: sync,
        runBackgroundSync: true,
      );
      if (ok) return true;
    }
    return false;
  }

  /// 주소로 반지에 연결하고 실시간 알림·포그라운드 서비스를 시작한다.
  static Future<bool> connect({
    required String address,
    required String deviceName,
    required Ring ring,
    required RingLiveActivity liveActivity,
    RingSyncController? sync,
    bool runBackgroundSync = true,
    bool clearPersistOnFailure = false,
  }) async {
    if (_connecting) return false;
    _connecting = true;

    try {
      if (!await isBluetoothReady()) {
        debugPrint('[CONNECT] bluetooth not ready');
        return false;
      }

      debugPrint('[CONNECT] connectDirectly begin ($address)');
      await platform
          .invokeMethod('connectDirectly', <String, dynamic>{
            'deviceAddress': address,
          })
          .timeout(const Duration(seconds: 60));
      debugPrint('[CONNECT] connectDirectly done');

      await syncTimeAfterConnect();

      await ring.markConnected(name: deviceName, address: address);

      final ready = await _waitDeviceReady();
      if (!ready) {
        debugPrint('[CONNECT] device ready check failed, keeping connection');
      }

      await printBattery(platform, ring);

      debugPrint('[CONNECT] realtime start');
      await liveActivity.start();

      try {
        await fgChannel.invokeMethod('startService');
      } catch (_) {}

      await RingBackgroundKeepalive.start(
        address: address,
        name: deviceName,
      );
      await enableRingAutoMonitoring();
      debugPrint('[CONNECT] done');

      if (runBackgroundSync && sync != null && !Platform.isIOS) {
        unawaited(sync.run(platform));
      } else if (runBackgroundSync && Platform.isIOS) {
        debugPrint('[CONNECT] skip post-connect auto sync on iOS');
      }

      return true;
    } on TimeoutException {
      debugPrint('[CONNECT] timeout');
      await _cleanupFailedConnect(ring, clearPersistOnFailure);
      return false;
    } catch (e) {
      debugPrint('[CONNECT] error: $e');
      await _cleanupFailedConnect(ring, clearPersistOnFailure);
      return false;
    } finally {
      _connecting = false;
    }
  }

  static Future<void> _cleanupFailedConnect(
    Ring ring,
    bool clearPersistOnFailure,
  ) async {
    try {
      await platform.invokeMethod('disconnect');
    } catch (_) {}
    ring.setIsConnected(false);
    if (clearPersistOnFailure) {
      ring.resetRing();
      await ring.clearPersist();
    }
  }

  static Future<void> syncTimeAfterConnect() async {
    try {
      await platform
          .invokeMethod('syncTimeAndGetCoreFeatures')
          .timeout(const Duration(seconds: 15));
      debugPrint('[CONNECT] syncTime done');
    } catch (e) {
      debugPrint('[CONNECT] syncTime failed (non-fatal): $e');
    }
  }

  static Future<bool> _waitDeviceReady() async {
    const attempts = 12;
    for (var i = 0; i < attempts; i++) {
      try {
        final battery = await platform
            .invokeMethod('getBatteryLevel')
            .timeout(const Duration(seconds: 3));
        if (battery != null) return true;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 700));
    }
    return false;
  }
}
