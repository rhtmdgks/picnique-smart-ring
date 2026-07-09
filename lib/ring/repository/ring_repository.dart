// Source: colmi_r02_client/colmi_r02_client/client.py facade (MIT)
// Source: colmi_r06_fbp/lib/main.dart connection flow (BSD-3-Clause)

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:picnique_rosary_healthcare_smartring/ring/capability/ring_capability_registry.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/capability/ring_device_matcher.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/commands/activity_command.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/commands/battery_command.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/commands/device_info_command.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/commands/hr_history_command.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/commands/raw_sensor_command.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/commands/realtime_hr_command.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/commands/phone_name_command.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/commands/ring_settings_command.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/commands/reboot_command.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/commands/set_time_command.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/commands/sleep_command.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/commands/spo2_command.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/ring_protocol_constants.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/transport/ring_command_queue.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/transport/ring_permissions.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/transport/ring_transport.dart';

export 'package:picnique_rosary_healthcare_smartring/ring/commands/activity_command.dart';
export 'package:picnique_rosary_healthcare_smartring/ring/commands/battery_command.dart';
export 'package:picnique_rosary_healthcare_smartring/ring/commands/device_info_command.dart';
export 'package:picnique_rosary_healthcare_smartring/ring/commands/hr_history_command.dart';
export 'package:picnique_rosary_healthcare_smartring/ring/commands/raw_sensor_command.dart';
export 'package:picnique_rosary_healthcare_smartring/ring/commands/realtime_hr_command.dart';
export 'package:picnique_rosary_healthcare_smartring/ring/commands/ring_settings_command.dart';
export 'package:picnique_rosary_healthcare_smartring/ring/commands/set_time_command.dart';
export 'package:picnique_rosary_healthcare_smartring/ring/commands/sleep_command.dart';
export 'package:picnique_rosary_healthcare_smartring/ring/commands/spo2_command.dart';
export 'package:picnique_rosary_healthcare_smartring/ring/capability/ring_capability_registry.dart';
export 'package:picnique_rosary_healthcare_smartring/ring/capability/ring_device_matcher.dart';
export 'package:picnique_rosary_healthcare_smartring/ring/capability/ring_probe_capabilities.dart';

/// High-level Colmi ring API — scan, connect, sync, measure.
class RingRepository {
  RingRepository._();
  static final RingRepository instance = RingRepository._();

  final RingTransport _transport = RingTransport();
  late final RingCommandQueue _queue = RingCommandQueue(_transport);

  late final SetTimeCommand setTime = SetTimeCommand(_queue);
  late final BatteryCommand battery = BatteryCommand(_queue);
  late final DeviceInfoCommand deviceInfo = DeviceInfoCommand(_transport);
  late final RealtimeHrCommand realtimeHr = RealtimeHrCommand(_queue);
  late final HrHistoryCommand hrHistory = HrHistoryCommand(_queue);
  late final ActivityCommand activity = ActivityCommand(_queue);
  late final Spo2Command spo2 = Spo2Command(_queue);
  late final SleepCommand sleep = SleepCommand(_queue);
  late final RawSensorCommand rawSensor = RawSensorCommand(_queue);
  late final RebootCommand reboot = RebootCommand(_queue);
  late final RingSettingsCommand settings = RingSettingsCommand(_queue);
  late final PhoneNameCommand phoneName = PhoneNameCommand(_queue);

  StreamSubscription<List<int>>? _notifSub;
  StreamSubscription<bool>? _connSub;

  final _batteryController = StreamController<BatteryStatus>.broadcast();
  final _liveActivityController =
      StreamController<LiveActivitySnapshot>.broadcast();
  final _disconnectController = StreamController<void>.broadcast();

  Stream<BatteryStatus> get batteryUpdates => _batteryController.stream;
  Stream<LiveActivitySnapshot> get liveActivityUpdates =>
      _liveActivityController.stream;
  Stream<void> get disconnectEvents => _disconnectController.stream;

  bool get isConnected => _transport.isConnected;
  bool get hasBigDataChannel => _transport.hasBigDataChannel;
  bool get isDiscoveryComplete => _transport.isDiscoveryComplete;
  String? get deviceName => _transport.deviceName;
  String? get deviceAddress => _transport.deviceAddress;

  RingCapabilities? _capabilities;
  RingCapabilities? get capabilities => _capabilities;

  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  String? _savedAddress;
  bool _manualDisconnect = false;

  static Stream<List<ScanResult>> scan({
    Duration timeout = const Duration(seconds: 8),
  }) =>
      RingTransport.scan(timeout: timeout);

  static Future<void> stopScan() => RingTransport.stopScan();

  static bool isYawellRingDevice(ScanResult result) =>
      RingDeviceMatcher.isYawellRing(result);

  /// @deprecated Use [isYawellRingDevice]
  static bool isColmiDevice(ScanResult result) => isYawellRingDevice(result);

  Future<bool> ensurePermissions() => RingPermissions.ensureReady();

  Future<bool> connect(BluetoothDevice device) async {
    _manualDisconnect = false;
    _savedAddress = device.remoteId.str;
    final ok = await _connectInternal(device);
    if (ok) _reconnectAttempt = 0;
    return ok;
  }

  Future<bool> connectByAddress(String address) async {
    _manualDisconnect = false;
    _savedAddress = address;
    final dev = BluetoothDevice.fromId(address);
    return _connectInternal(dev);
  }

  Future<bool> _connectInternal(BluetoothDevice device) async {
    if (!await ensurePermissions()) return false;

    _queue.startListening();
    _bindNotificationRouter();

    final ok = await _transport.connect(device);
    if (!ok) return false;

    debugPrint(
      '[RING][connect] discovery done main=ok bigData=${_transport.hasBigDataChannel}',
    );

    _capabilities = RingCapabilityRegistry.resolve(device.platformName);
    _bindConnectionWatcher();

    try {
      final probe = await setTime.execute();
      if (probe != null) {
        _capabilities = RingCapabilityRegistry.resolveWithProbe(
          device.platformName,
          probe,
        );
      }
      await phoneName.send(Platform.localHostname);
    } catch (e) {
      debugPrint('[RING] connect handshake failed (non-fatal): $e');
    }

    try {
      final status = await battery.query();
      _batteryController.add(status);
    } catch (e) {
      debugPrint('[RING] initial battery failed: $e');
    }

    return true;
  }

  void _bindNotificationRouter() {
    _notifSub?.cancel();
    _notifSub = _queue.pushStream(RingProtocolConstants.cmdNotification).listen((packet) {
      final batt = BatteryCommand.parseNotification(packet);
      if (batt != null) _batteryController.add(batt);

      final live = ActivityCommand.parseLiveNotification(packet);
      if (live != null) _liveActivityController.add(live);
    });
  }

  void _bindConnectionWatcher() {
    _connSub?.cancel();
    _connSub = _transport.connectionState.listen((connected) {
      if (!connected) {
        _disconnectController.add(null);
        if (!_manualDisconnect && _savedAddress != null) {
          _scheduleReconnect();
        }
      }
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    const backoffMs = [1000, 2000, 4000, 8000, 16000, 32000, 60000];
    final delay = backoffMs[_reconnectAttempt.clamp(0, backoffMs.length - 1)];
    _reconnectAttempt++;
    debugPrint('[RING] reconnect in ${delay}ms attempt=$_reconnectAttempt');
    _reconnectTimer = Timer(Duration(milliseconds: delay), () async {
      if (_manualDisconnect || _savedAddress == null) return;
      if (_transport.isConnected) return;
      await connectByAddress(_savedAddress!);
    });
  }

  Future<void> disconnect({bool manual = true}) async {
    _manualDisconnect = manual;
    _reconnectTimer?.cancel();
    await _notifSub?.cancel();
    await _connSub?.cancel();
    await _queue.stopListening();
    await _transport.disconnect();
    if (manual) _savedAddress = null;
  }

  Future<void> dispose() async {
    await disconnect(manual: true);
    await _batteryController.close();
    await _liveActivityController.close();
    await _disconnectController.close();
    await _transport.dispose();
  }

  /// Convenience: scan → connect → setTime → measure HR once.
  Future<LiveHrResult?> demoConnectAndMeasureHr(BluetoothDevice device) async {
    if (!await connect(device)) return null;
    return realtimeHr.measureOnce();
  }
}
