// Source: colmi_r06_fbp/lib/main.dart (BSD-3-Clause)
// Source: Gadgetbridge YawellRingConstants.java (AGPL-3.0)
// Big-data: separate service de5bf728 (NOT 6e40fff0) — QRing btsnoop handle 0x0016/0x0018

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../capability/ring_device_matcher.dart';
import '../ring_protocol_constants.dart';

/// Low-level flutter_blue_plus transport for Yawell/Colmi RF03 rings.
class RingTransport {
  RingTransport();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _mainWrite;
  BluetoothCharacteristic? _mainNotify;
  BluetoothCharacteristic? _bigDataWrite;
  BluetoothCharacteristic? _bigDataNotify;

  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _mainNotifySub;
  StreamSubscription<List<int>>? _bigDataNotifySub;

  final _mainNotifyController = StreamController<List<int>>.broadcast();
  final _bigDataNotifyController = StreamController<List<int>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Completer<void>? _discoveryReady;
  bool _discoveryComplete = false;

  Stream<List<int>> get notifyMain => _mainNotifyController.stream;
  Stream<List<int>> get notifyBigData => _bigDataNotifyController.stream;

  @Deprecated('Use notifyMain')
  Stream<List<int>> get notifyV1 => notifyMain;

  @Deprecated('Use notifyBigData')
  Stream<List<int>> get notifyV2 => notifyBigData;

  Stream<bool> get connectionState => _connectionController.stream;

  BluetoothDevice? get device => _device;
  bool get isConnected => _device?.isConnected ?? false;
  bool get isDiscoveryComplete => _discoveryComplete;
  String? get deviceName => _device?.platformName;
  String? get deviceAddress => _device?.remoteId.str;
  bool get hasBigDataChannel => _bigDataWrite != null && _bigDataNotify != null;

  /// Blocks until GATT discovery + notify subscription finished.
  Future<void> awaitDiscovery() async {
    if (_discoveryComplete) return;
    final pending = _discoveryReady;
    if (pending != null) await pending.future;
  }

  static Stream<List<ScanResult>> scan({
    Duration timeout = const Duration(seconds: 8),
  }) {
    // No withServices — R08 advertises fee7 only; 6e40/de5bf appear after connect.
    FlutterBluePlus.startScan(timeout: timeout);
    return FlutterBluePlus.scanResults;
  }

  static Future<void> stopScan() => FlutterBluePlus.stopScan();

  static bool isYawellRingAdvertisement(ScanResult result) =>
      RingDeviceMatcher.isYawellRing(result);

  Future<bool> connect(BluetoothDevice device) async {
    await disconnect();
    _device = device;
    _discoveryComplete = false;
    _discoveryReady = Completer<void>();

    _connSub = device.connectionState.listen((state) {
      final connected = state == BluetoothConnectionState.connected;
      _connectionController.add(connected);
      if (state == BluetoothConnectionState.disconnected) {
        _discoveryComplete = false;
        debugPrint('[RING] disconnected: ${device.disconnectReason}');
      }
    });

    try {
      await device.connect(autoConnect: false, mtu: null);
    } catch (e) {
      debugPrint('[RING] connect error: $e');
      _completeDiscovery();
      return false;
    }

    if (!device.isConnected) {
      _completeDiscovery();
      return false;
    }

    final ok = await _discoverServices();
    _completeDiscovery();
    if (!ok) {
      await disconnect();
      return false;
    }
    return true;
  }

  void _completeDiscovery() {
    if (_discoveryReady != null && !_discoveryReady!.isCompleted) {
      _discoveryReady!.complete();
    }
  }

  Future<bool> connectByAddress(String address) async {
    final dev = BluetoothDevice.fromId(address);
    return connect(dev);
  }

  Future<bool> _discoverServices() async {
    final device = _device;
    if (device == null || !device.isConnected) return false;

    List<BluetoothService> services;
    try {
      services = await device.discoverServices();
    } catch (e) {
      debugPrint('[RING] discoverServices error: $e');
      return false;
    }

    _clearCharacteristics();
    _resolveCharacteristics(services);

    if (_mainWrite == null || _mainNotify == null) {
      debugPrint('[RING] missing main write/notify characteristics');
      _logGattTable(services);
      return false;
    }

    await _subscribeNotifies();

    if (!hasBigDataChannel) {
      debugPrint('[RING] big-data channel not found — retry discover once');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      try {
        services = await device.discoverServices();
        _bigDataWrite = null;
        _bigDataNotify = null;
        _resolveBigDataChannel(services);
        if (_bigDataNotify != null) {
          await _bigDataNotifySub?.cancel();
          _bigDataNotifySub =
              _bigDataNotify!.onValueReceived.listen(_bigDataNotifyController.add);
          await _bigDataNotify!.setNotifyValue(true);
        }
      } catch (e) {
        debugPrint('[RING] big-data rediscover failed: $e');
      }
    }

    if (!hasBigDataChannel) {
      debugPrint('[RING] big-data write/notify unavailable (sleep/SpO2 history off)');
      _logGattTable(services);
    } else {
      debugPrint(
        '[RING] big-data ready write=${_bigDataWrite!.uuid.str128} '
        'notify=${_bigDataNotify!.uuid.str128}',
      );
    }

    _discoveryComplete = true;
    return true;
  }

  void _resolveCharacteristics(List<BluetoothService> services) {
    _resolveMainChannel(services);
    _resolveBigDataChannel(services);
  }

  void _resolveMainChannel(List<BluetoothService> services) {
    _mainWrite = _findCharacteristic(
      services,
      RingProtocolConstants.cmdWriteChar,
    );
    _mainNotify = _findCharacteristic(
      services,
      RingProtocolConstants.cmdNotifyCharV1,
    );

    if (_mainWrite != null && _mainNotify != null) return;

    for (final service in services) {
      if (!_uuidEq(service.uuid.str128, RingProtocolConstants.cmdServiceV1)) {
        continue;
      }
      for (final c in service.characteristics) {
        final id = _normUuid(c.uuid.str128);
        if (_mainWrite == null && id.contains('6e400002')) {
          _mainWrite = c;
        }
        if (_mainNotify == null && id.contains('6e400003') && c.properties.notify) {
          _mainNotify = c;
        }
      }
    }
  }

  /// Big-data lives on [cmdServiceV2] (de5bf728), not 6e40fff0 — btsnoop R08.
  void _resolveBigDataChannel(List<BluetoothService> services) {
    _bigDataWrite = _findCharacteristic(
      services,
      RingProtocolConstants.cmdWriteCharV2,
    );
    _bigDataNotify = _findCharacteristic(
      services,
      RingProtocolConstants.cmdNotifyCharV2,
    );
    if (_bigDataWrite != null && _bigDataNotify != null) return;

    for (final service in services) {
      if (!_uuidEq(service.uuid.str128, RingProtocolConstants.cmdServiceV2)) {
        continue;
      }
      for (final c in service.characteristics) {
        final id = _normUuid(c.uuid.str128);
        if (_bigDataWrite == null &&
            id.contains('de5bf72a') &&
            (c.properties.writeWithoutResponse || c.properties.write)) {
          _bigDataWrite = c;
        }
        if (_bigDataNotify == null &&
            id.contains('de5bf729') &&
            c.properties.notify) {
          _bigDataNotify = c;
        }
      }
    }

    if (_bigDataWrite != null && _bigDataNotify != null) return;

    _resolveBigDataOnV1ServiceExtras(services);

    if (_bigDataWrite != null && _bigDataNotify != null) return;

    _bigDataWrite ??= _findCharacteristicByProperties(
      services,
      excludeUuids: {
        RingProtocolConstants.cmdWriteChar,
        RingProtocolConstants.cmdNotifyCharV1,
      },
      wantNotify: false,
    );
    _bigDataNotify ??= _findCharacteristicByProperties(
      services,
      excludeUuids: {
        RingProtocolConstants.cmdWriteChar,
        RingProtocolConstants.cmdNotifyCharV1,
        if (_bigDataWrite != null) _bigDataWrite!.uuid.str128.toLowerCase(),
      },
      wantNotify: true,
    );
  }

  /// Extra write/notify on 6e40fff0 (handles 0x0016/0x0018 on some R08 firmware).
  void _resolveBigDataOnV1ServiceExtras(List<BluetoothService> services) {
    for (final service in services) {
      if (!_uuidEq(service.uuid.str128, RingProtocolConstants.cmdServiceV1)) {
        continue;
      }
      BluetoothCharacteristic? extraWrite;
      BluetoothCharacteristic? extraNotify;
      for (final c in service.characteristics) {
        final id = _normUuid(c.uuid.str128);
        if (id.contains('6e400002') || id.contains('6e400003')) continue;
        if (extraWrite == null &&
            (c.properties.writeWithoutResponse || c.properties.write)) {
          extraWrite = c;
        } else if (extraNotify == null && c.properties.notify) {
          extraNotify = c;
        }
      }
      if (extraWrite != null && extraNotify != null) {
        _bigDataWrite ??= extraWrite;
        _bigDataNotify ??= extraNotify;
        debugPrint(
          '[RING] big-data on V1 extras write=${extraWrite.uuid.str128} '
          'notify=${extraNotify.uuid.str128}',
        );
        return;
      }
    }
  }

  BluetoothCharacteristic? _findCharacteristic(
    List<BluetoothService> services,
    String uuid,
  ) {
    for (final service in services) {
      for (final c in service.characteristics) {
        if (_uuidEq(c.uuid.str128, uuid)) return c;
      }
    }
    return null;
  }

  BluetoothCharacteristic? _findCharacteristicByProperties(
    List<BluetoothService> services, {
    required Set<String> excludeUuids,
    required bool wantNotify,
  }) {
    for (final service in services) {
      if (_uuidEq(service.uuid.str128, RingProtocolConstants.cmdServiceV1)) {
        continue;
      }
      for (final c in service.characteristics) {
        final id = c.uuid.str128.toLowerCase();
        if (excludeUuids.any((u) => _uuidEq(id, u))) continue;
        if (wantNotify) {
          if (c.properties.notify) return c;
        } else if (c.properties.writeWithoutResponse || c.properties.write) {
          return c;
        }
      }
    }
    return null;
  }

  Future<void> _subscribeNotifies() async {
    await _mainNotifySub?.cancel();
    _mainNotifySub =
        _mainNotify!.onValueReceived.listen(_mainNotifyController.add);
    await _mainNotify!.setNotifyValue(true);

    if (_bigDataNotify != null) {
      await _bigDataNotifySub?.cancel();
      _bigDataNotifySub =
          _bigDataNotify!.onValueReceived.listen(_bigDataNotifyController.add);
      await _bigDataNotify!.setNotifyValue(true);
    }
  }

  Future<bool> ensureBigDataChannel() async {
    await awaitDiscovery();
    if (hasBigDataChannel) return true;
    final device = _device;
    if (device == null || !device.isConnected) return false;

    debugPrint('[RING] ensureBigDataChannel: rediscovering…');
    try {
      final services = await device.discoverServices();
      _bigDataWrite = null;
      _bigDataNotify = null;
      _resolveBigDataChannel(services);
      if (_bigDataNotify != null) {
        await _bigDataNotifySub?.cancel();
        _bigDataNotifySub =
            _bigDataNotify!.onValueReceived.listen(_bigDataNotifyController.add);
        await _bigDataNotify!.setNotifyValue(true);
      }
    } catch (e) {
      debugPrint('[RING] ensureBigDataChannel failed: $e');
    }
    return hasBigDataChannel;
  }

  Future<void> writeMainPacket(List<int> packet) async {
    await awaitDiscovery();
    final write = _mainWrite;
    if (write == null) throw StateError('main write char not ready');
    await write.write(packet, withoutResponse: false);
  }

  Future<void> writeBigDataCommand(List<int> data) async {
    await awaitDiscovery();
    if (!hasBigDataChannel) {
      final ok = await ensureBigDataChannel();
      if (!ok) throw StateError('big-data write char not ready');
    }
    final write = _bigDataWrite;
    if (write == null) throw StateError('big-data write char not ready');
    await write.write(data, withoutResponse: true);
  }

  @Deprecated('Use writeMainPacket')
  Future<void> writePacket(List<int> packet) => writeMainPacket(packet);

  @Deprecated('Use writeBigDataCommand')
  Future<void> writeCommandV2(List<int> data) => writeBigDataCommand(data);

  Future<Map<String, String>> readDeviceInfo() async {
    await awaitDiscovery();
    final device = _device;
    if (device == null) return {};
    final services = device.servicesList;
    BluetoothService? infoService;
    for (final s in services) {
      if (_uuidEq(s.uuid.str128, RingProtocolConstants.deviceInfoService)) {
        infoService = s;
        break;
      }
    }
    if (infoService == null) return {};

    String? hw;
    String? fw;
    for (final c in infoService.characteristics) {
      final cu = c.uuid.str128.toLowerCase();
      if (_uuidEq(cu, RingProtocolConstants.deviceHwChar)) {
        final v = await c.read();
        hw = String.fromCharCodes(v);
      } else if (_uuidEq(cu, RingProtocolConstants.deviceFwChar)) {
        final v = await c.read();
        fw = String.fromCharCodes(v);
      }
    }
    return {
      if (hw != null) 'hw_version': hw,
      if (fw != null) 'fw_version': fw,
    };
  }

  void _logGattTable(List<BluetoothService> services) {
    final buf = StringBuffer('[RING] GATT table:\n');
    for (final s in services) {
      buf.writeln('  service ${s.uuid.str128}');
      for (final c in s.characteristics) {
        final p = c.properties;
        buf.writeln(
          '    char ${c.uuid.str128} '
          'w=${p.write} wnr=${p.writeWithoutResponse} n=${p.notify}',
        );
      }
    }
    debugPrint(buf.toString());
  }

  static String _normUuid(String uuid) => uuid.toLowerCase();

  static bool _uuidEq(String a, String b) =>
      _normUuid(a) == _normUuid(b);

  void _clearCharacteristics() {
    _mainWrite = null;
    _mainNotify = null;
    _bigDataWrite = null;
    _bigDataNotify = null;
  }

  Future<void> disconnect() async {
    await _mainNotifySub?.cancel();
    await _bigDataNotifySub?.cancel();
    _mainNotifySub = null;
    _bigDataNotifySub = null;
    _clearCharacteristics();
    _discoveryComplete = false;

    await _connSub?.cancel();
    _connSub = null;

    try {
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    _completeDiscovery();
  }

  Future<void> dispose() async {
    await disconnect();
    await _mainNotifyController.close();
    await _bigDataNotifyController.close();
    await _connectionController.close();
  }
}
