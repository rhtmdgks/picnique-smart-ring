import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/repository/ring_repository.dart';
import 'package:picnique_rosary_healthcare_smartring/services/battery_notification_service.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_connection_coordinator.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_health_accumulation.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_background_keepalive.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_background_sync.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_live_activity.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/transport/ring_permissions.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';
import 'package:flutter/services.dart';

/// Colmi ring connect via pure Dart flutter_blue_plus ([RingRepository]).
class RingConnectionService {
  static const MethodChannel fgChannel = MethodChannel(
    'com.example.picnique_ring/foreground_service_channel',
  );

  static final RingRepository _repo = RingRepository.instance;

  static bool _connecting = false;
  static bool get isConnecting => _connecting;

  static Future<bool> isBluetoothReady() => RingPermissions.ensureReady();

  static Future<bool> reconnectSavedRing({
    required Ring ring,
    required RingLiveActivity liveActivity,
    RingSyncController? sync,
  }) async {
    await ring.loadFromPrefs();
    final address = ring.address?.trim() ?? ring.savedAddress?.trim();
    if (address == null || address.isEmpty) return false;
    if (ring.isConnected) return true;
    if (_connecting) return false;

    final name = (ring.name?.trim().isNotEmpty ?? false)
        ? ring.name!.trim()
        : (ring.savedName ?? '스마트링');

    for (var i = 0; i < 2; i++) {
      if (i > 0) await Future<void>.delayed(const Duration(seconds: 2));
      final ok = await connect(
        address: address,
        deviceName: name,
        ring: ring,
        liveActivity: liveActivity,
        sync: sync,
      );
      if (ok) return true;
    }
    return false;
  }

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

      debugPrint('[CONNECT] connectByAddress begin ($address)');
      final ok = await _repo.connectByAddress(address)
          .timeout(const Duration(seconds: 60));
      if (!ok) {
        await _cleanupFailedConnect(ring, clearPersistOnFailure);
        return false;
      }
      debugPrint('[CONNECT] connected');

      if (Platform.isIOS) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }

      var sdkReady = await syncTimeAfterConnect();
      if (!sdkReady && ring.sdkReady) sdkReady = true;

      await ring.markConnected(name: deviceName, address: address);
      ring.setSdkReady(sdkReady);

      if (!sdkReady) {
        debugPrint('[CONNECT] SDK not ready — partial connect');
        return true;
      }

      try {
        final b = await _repo.battery.query();
        ring.setBatteryAndCharging(b.level, b.charging);
      } catch (_) {}

      await liveActivity.start();

      try {
        await fgChannel.invokeMethod('startService');
      } catch (_) {}

      await RingBackgroundKeepalive.start(address: address, name: deviceName);
      await BatteryNotificationService.ensureReadyForBackgroundAlerts();
      await RingHealthAccumulation.flushConnectedToApp(
        ring: ring,
        refreshNotifier:
            RingConnectionCoordinator.instance.healthRefresh,
      );

      if (runBackgroundSync && sync != null && !Platform.isIOS) {
        unawaited(sync.run(BleCommandQueue.channel));
      }

      debugPrint('[CONNECT] done');
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
      await _repo.disconnect();
    } catch (_) {}
    ring.setIsConnected(false);
    if (clearPersistOnFailure) {
      ring.resetRing();
      await ring.clearPersist();
    }
  }

  static Future<bool> syncTimeAfterConnect() async {
    try {
      await _repo.setTime.execute().timeout(const Duration(seconds: 15));
      return true;
    } catch (e) {
      debugPrint('[CONNECT] syncTime failed: $e');
      return false;
    }
  }

  static Future<bool> ensureSdkReady(Ring ring) async {
    if (!ring.isConnected) return false;
    if (ring.sdkReady) return true;
    final ok = await syncTimeAfterConnect();
    ring.setSdkReady(ok);
    return ok;
  }
}
