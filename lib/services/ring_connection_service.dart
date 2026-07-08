import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';
import 'package:picnique_rosary_healthcare_smartring/services/battery_notification_service.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_connection_coordinator.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_health_accumulation.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_background_keepalive.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_background_sync.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_live_activity.dart';
import 'package:picnique_rosary_healthcare_smartring/util/BLEUtil.dart';

/// 저장된 반지 주소로 BLE 연결·실시간 추적을 수행한다.
class RingConnectionService {
  static const MethodChannel platform = BleCommandQueue.channel;
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
      await BleCommandQueue
          .invoke('connectDirectly', <String, dynamic>{
            'deviceAddress': address,
          })
          .timeout(const Duration(seconds: 60));
      debugPrint('[CONNECT] connectDirectly done');

      if (Platform.isIOS) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }

      var sdkReady = await syncTimeAfterConnect();
      if (!sdkReady && Platform.isIOS) {
        await Future<void>.delayed(const Duration(seconds: 2));
        sdkReady = await syncTimeAfterConnect();
      }
      // 이미 ready 였다면 유지 — 큐 정체로 인한 syncTime 거짓 실패가
      // 자동 측정을 죽이지 않게 한다.
      if (!sdkReady && ring.sdkReady) {
        debugPrint('[CONNECT] syncTime timed out but SDK already ready — keep');
        sdkReady = true;
      }

      await ring.markConnected(name: deviceName, address: address);
      ring.setSdkReady(sdkReady);

      if (!sdkReady) {
        debugPrint('[CONNECT] SDK not ready after setTime — skip auto monitoring');
        return true;
      }

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

      if (Platform.isIOS) {
        unawaited(
          Future<void>.delayed(const Duration(seconds: 15), () async {
            try {
              await BleCommandQueue.waitUntilManualIdle();
              await enableRingAutoMonitoring();
            } catch (e) {
              debugPrint('[CONNECT] delayed auto monitoring failed: $e');
            }
          }),
        );
      } else {
        await enableRingAutoMonitoring();
      }

      await RingBackgroundKeepalive.start(
        address: address,
        name: deviceName,
      );
      await BatteryNotificationService.ensureReadyForBackgroundAlerts();
      await RingHealthAccumulation.flushConnectedToApp(
        ring: ring,
        refreshNotifier:
            RingConnectionCoordinator.instance.healthRefresh,
      );
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
      await BleCommandQueue.invoke('disconnect');
    } catch (_) {}
    ring.setIsConnected(false);
    if (clearPersistOnFailure) {
      ring.resetRing();
      await ring.clearPersist();
    }
  }

  static Future<bool> syncTimeAfterConnect() async {
    try {
      final features = await BleCommandQueue
          .invoke<dynamic>('syncTimeAndGetCoreFeatures')
          .timeout(const Duration(seconds: 15));
      debugPrint('[CONNECT] syncTime done');
      if (features is Map) {
        final keys = features.keys.map((k) => k.toString()).toList();
        String? featureValue(String token) {
          for (final entry in features.entries) {
            final key = entry.key.toString();
            if (key.contains(token)) return entry.value?.toString();
          }
          return null;
        }

        final stress = featureValue('Stress') ?? featureValue('stress');
        final hrv = featureValue('HRV') ?? featureValue('Hrv');
        debugPrint('[CONNECT] ring features stress=$stress hrv=$hrv keys=$keys');
      }
      return true;
    } catch (e) {
      debugPrint('[CONNECT] syncTime failed (non-fatal): $e');
      return false;
    }
  }

  /// 연결은 됐지만 SDK(setTime) 준비가 안 된 경우 — 측정 전 재시도.
  static Future<bool> ensureSdkReady(Ring ring) async {
    if (!ring.isConnected) return false;
    if (ring.sdkReady) return true;

    if (Platform.isIOS) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }

    var ok = await syncTimeAfterConnect();
    if (!ok && Platform.isIOS) {
      await Future<void>.delayed(const Duration(seconds: 1));
      ok = await syncTimeAfterConnect();
    }
    ring.setSdkReady(ok);
    return ok;
  }

  static Future<bool> _waitDeviceReady() async {
    const attempts = 12;
    for (var i = 0; i < attempts; i++) {
      try {
        final battery = await BleCommandQueue
            .invoke('getBatteryLevel')
            .timeout(const Duration(seconds: 3));
        if (battery != null) return true;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 700));
    }
    return false;
  }
}
