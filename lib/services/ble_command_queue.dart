// Facade over lib/ring/ — replaces native MethodChannel BLE bridge.
// Source: colmi_r02_client Client queues (MIT) + prior BleCommandQueue priority model.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/commands/sleep_command.dart'
    show SleepSessionRaw;
import 'package:picnique_rosary_healthcare_smartring/ring/repository/ring_repository.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/transport/ring_command_queue.dart'
    as ring_queue;

enum BleOpPriority { connection, manual, uiFresh, backgroundSync }

class BleCommandQueue {
  BleCommandQueue._();

  /// Legacy — Dart-only stack; kept for API compat.
  static const MethodChannel channel = MethodChannel(
    'com.example.picnique_ring/ble',
  );

  static const String autoCancelledCode = 'AUTO_MEASURE_CANCELLED';

  static int _manualInFlight = 0;
  static int _autoMeasureDepth = 0;
  static bool _autoAborted = false;
  static final RingRepository _repo = RingRepository.instance;

  static bool get manualInFlight => _manualInFlight > 0;
  static bool get autoMeasureInFlight => _autoMeasureDepth > 0;

  static void clearAutoAbort() => _autoAborted = false;

  static ring_queue.RingCommandPriority _mapPriority(BleOpPriority p) =>
      switch (p) {
        BleOpPriority.connection => ring_queue.RingCommandPriority.connection,
        BleOpPriority.manual => ring_queue.RingCommandPriority.manual,
        BleOpPriority.uiFresh => ring_queue.RingCommandPriority.uiFresh,
        BleOpPriority.backgroundSync =>
          ring_queue.RingCommandPriority.backgroundSync,
      };

  static Future<void> waitUntilManualIdle({
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (_manualInFlight > 0 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  static Future<void> waitUntilQueueIdle({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_repo.isConnected) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  static Future<void> awaitAutoMeasureDrain({
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (_autoMeasureDepth > 0 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  static Future<void> preemptAutoForManual() async {
    _autoAborted = true;
    _repo.realtimeHr.requestCancel();
    try {
      await _repo.realtimeHr.teardownAll();
    } catch (_) {}
    await awaitAutoMeasureDrain();
  }

  static Future<void> flushPendingScheduleRestores() async {}

  static Future<T?> invoke<T>(
    String method, [
    dynamic arguments,
    BleOpPriority priority = BleOpPriority.connection,
  ]) async {
    final isManual = _isManualMethod(method);
    if (isManual) _manualInFlight++;
    try {
      final result = await _dispatch(method, arguments, priority);
      return result as T?;
    } on ring_queue.RingCommandException catch (e) {
      throw PlatformException(code: e.code, message: e.message);
    } finally {
      if (isManual) _manualInFlight--;
    }
  }

  static Future<T?> invokeAuto<T>(
    String method, [
    dynamic arguments,
  ]) async {
    if (_autoAborted) {
      throw PlatformException(code: autoCancelledCode);
    }
    _autoMeasureDepth++;
    try {
      if (_autoAborted) {
        throw PlatformException(code: autoCancelledCode);
      }
      return await invoke<T>(method, arguments, BleOpPriority.backgroundSync);
    } finally {
      _autoMeasureDepth--;
    }
  }

  static Future<T?> runWithSessionRetry<T>(
    Future<T?> Function() action, {
    int maxAttempts = 3,
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      try {
        return await action();
      } catch (e) {
        if (i == maxAttempts - 1) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 400 * (i + 1)));
      }
    }
    return null;
  }

  static bool _isManualMethod(String method) => const {
        'executeManualMeasurement',
        'resetMeasurementSession',
        'syncManualHeartRate',
        'syncManualPressure',
        'syncManualBloodOxygen',
        'enableRosaryTouch',
        'disableRosaryTouch',
      }.contains(method);

  static Future<dynamic> _dispatch(
    String method,
    dynamic arguments,
    BleOpPriority priority,
  ) async {
    _mapPriority(priority); // reserved for future queue priority wiring
    switch (method) {
      case 'connectDirectly':
      case 'reconnectKnownDevice':
        final addr = (arguments as Map?)?['deviceAddress'] as String?;
        if (addr == null) throw PlatformException(code: 'NO_ADDRESS');
        return _repo.connectByAddress(addr);
      case 'disconnect':
        await _repo.disconnect();
        return true;
      case 'getBatteryLevel':
        final b = await _repo.battery.query();
        return {'level': b.level, 'charging': b.charging};
      case 'syncTimeAndGetCoreFeatures':
        await _repo.setTime.execute();
        return {'Stress': 'supported', 'HRV': 'supported'};
      case 'enableRealtimeNotifications':
      case 'enableRealtime':
        return true;
      case 'disableRealtimeNotifications':
      case 'disableRealtime':
        return true;
      case 'syncManualHeartRate':
      case 'executeManualMeasurement':
        if (method == 'executeManualMeasurement') {
          final type = (arguments as Map?)?['type'] as String? ?? 'heart';
          if (type.contains('oxygen') || type.contains('spo2')) {
            return _measureSpo2Map();
          }
          if (type.contains('stress') || type.contains('pressure')) {
            return _measureStressMap();
          }
        }
        return _measureHrMap();
      case 'syncManualBloodOxygen':
        return _measureSpo2Map();
      case 'syncManualPressure':
        return _measureStressMap();
      case 'resetMeasurementSession':
        await _repo.realtimeHr.stop();
        return true;
      case 'enableRosaryTouch':
        return true;
      case 'disableRosaryTouch':
        return true;
      case 'syncTodaySport':
        if (!_repo.isConnected || !_repo.isDiscoveryComplete) {
          throw PlatformException(code: 'NOT_CONNECTED');
        }
        final samples = await _repo.activity.fetchHistory(daysAgo: 0);
        var steps = 0;
        var cal = 0;
        var dist = 0;
        for (final s in samples) {
          steps += s.steps;
          cal += s.calories;
          dist += s.distanceMeters;
        }
        debugPrint(
          '[SPORT] syncTodaySport slots=${samples.length} '
          'steps=$steps cal=$cal dist=$dist',
        );
        return {
          'totalSteps': steps,
          'calorie': cal,
          'walkDistance': dist,
        };
      case 'syncSportDetail':
        if (!_repo.isConnected || !_repo.isDiscoveryComplete) {
          throw PlatformException(code: 'NOT_CONNECTED');
        }
        final dayOffset = _asInt(
          (arguments is Map ? arguments['dayOffset'] : null),
        );
        final details =
            await _repo.activity.fetchDetailMaps(daysAgo: dayOffset);
        debugPrint(
          '[SPORT] syncSportDetail offset=$dayOffset slots=${details.length}',
        );
        return {'details': details};
      case 'syncSleepNew':
      case 'syncSleepDisplay':
        if (!_repo.isConnected || !_repo.isDiscoveryComplete) {
          throw PlatformException(code: 'NOT_CONNECTED');
        }
        if (!_repo.hasBigDataChannel) {
          throw PlatformException(
            code: 'BIG_DATA_UNAVAILABLE',
            message: 'de5bf728 big-data GATT not discovered',
          );
        }
        final args = arguments is Map ? arguments : const <dynamic, dynamic>{};
        final offset = method == 'syncSleepNew'
            ? _asInt(args['offset'])
            : _asInt(args['dayOffset']);
        final sessions = await _repo.sleep.fetchHistory();
        final session = _sleepSessionForOffset(sessions, offset);
        if (session == null) return {'list': []};

        if (method == 'syncSleepDisplay') {
          // Legacy display shape: [{sleepStart, sleepEnd, type}]
          // type: 1=deep, 2=light/rem, 3=awake
          final list = <Map<String, dynamic>>[];
          for (final stage in session.stages) {
            final startSec = stage.start.millisecondsSinceEpoch ~/ 1000;
            final endSec = startSec + stage.durationMinutes * 60;
            final displayType = switch (stage.stageByte) {
              3 => 1, // deep
              2 || 4 => 2, // light / rem
              5 => 3, // awake
              _ => 0,
            };
            if (displayType == 0) continue;
            list.add({
              'sleepStart': startSec,
              'sleepEnd': endSec,
              'type': displayType,
            });
          }
          return {'list': list};
        }

        // syncSleepNew shape: {st, et, list:[{d,t}]}
        final list = <Map<String, dynamic>>[];
        for (final stage in session.stages) {
          list.add({
            'd': stage.durationMinutes * 60,
            't': stage.stageByte,
          });
        }
        return {
          'st': session.start.toUtc().millisecondsSinceEpoch ~/ 1000,
          'et': session.end.toUtc().millisecondsSinceEpoch ~/ 1000,
          'list': list,
        };
      case 'syncSleepAll':
        // One 0xBC/0x27 pull → every night in the packet (native offset loop replaced).
        if (!_repo.isConnected || !_repo.isDiscoveryComplete) {
          throw PlatformException(code: 'NOT_CONNECTED');
        }
        if (!_repo.hasBigDataChannel) {
          throw PlatformException(
            code: 'BIG_DATA_UNAVAILABLE',
            message: 'de5bf728 big-data GATT not discovered',
          );
        }
        final allSessions = await _repo.sleep.fetchHistory();
        final nights = <Map<String, dynamic>>[];
        for (final session in allSessions) {
          final stages = <Map<String, dynamic>>[];
          for (final stage in session.stages) {
            stages.add({
              'd': stage.durationMinutes * 60,
              't': stage.stageByte,
            });
          }
          nights.add({
            'st': session.start.toUtc().millisecondsSinceEpoch ~/ 1000,
            'et': session.end.toUtc().millisecondsSinceEpoch ~/ 1000,
            'daysAgo': _sleepDaysAgo(session.start, session.end),
            'list': stages,
          });
        }
        return {'nights': nights};
      case 'syncHeartRate':
        final day = DateTime.now().toUtc();
        final log = await _repo.hrHistory.fetchDayLog(day);
        return {'samples': log?.samples.length ?? 0};
      case 'collectHealthIfIdle':
        if (_manualInFlight > 0 || _autoAborted) return false;
        try {
          await _repo.hrHistory.fetchDay(DateTime.now().toUtc());
          await _repo.activity.fetchHistory(daysAgo: 0);
        } catch (_) {}
        return true;
      case 'getBluetoothState':
        final on = await _repo.ensurePermissions();
        return on ? 'on' : 'off';
      case 'startScan':
      case 'stopScan':
        return true;
      case 'readHw':
        final info = await _repo.deviceInfo.read();
        return info.hwVersion;
      case 'readFw':
        final info = await _repo.deviceInfo.read();
        return info.fwVersion;
      case 'writeHrSetting': {
        final args = Map<String, dynamic>.from((arguments as Map?) ?? {});
        final status = await _repo.settings.writeHrSetting(
          enabled: args['isEnable'] == true,
          intervalMinutes: (args['interval'] as num?)?.toInt() ?? 10,
        );
        return {'isEnable': status.enabled, 'interval': status.intervalMinutes};
      }
      case 'readHrSetting': {
        final status = await _repo.settings.readHrSetting();
        return {'isEnable': status.enabled, 'interval': status.intervalMinutes};
      }
      case 'writeSpo2Setting': {
        final args = Map<String, dynamic>.from((arguments as Map?) ?? {});
        final status = await _repo.settings.writeSpo2Setting(
          enabled: args['isEnable'] == true,
        );
        return {'isEnable': status.enabled};
      }
      case 'readSpo2Setting': {
        final status = await _repo.settings.readSpo2Setting();
        return {'isEnable': status.enabled};
      }
      case 'writePressureSetting': {
        final args = Map<String, dynamic>.from((arguments as Map?) ?? {});
        final status = await _repo.settings.writeStressSetting(
          enabled: args['isEnable'] == true,
        );
        return {'isEnable': status.enabled};
      }
      case 'readPressureSetting': {
        final status = await _repo.settings.readStressSetting();
        return {'isEnable': status.enabled};
      }
      case 'writeHrvSetting': {
        final args = Map<String, dynamic>.from((arguments as Map?) ?? {});
        final status = await _repo.settings.writeHrvSetting(
          enabled: args['isEnable'] == true,
        );
        return {'isEnable': status.enabled};
      }
      case 'readHrvSetting': {
        final status = await _repo.settings.readHrvSetting();
        return {'isEnable': status.enabled};
      }
      default:
        debugPrint('[BLE] unimplemented method: $method');
        throw PlatformException(code: 'NOT_IMPLEMENTED', message: method);
    }
  }

  /// Pick sleep session whose wake-day matches [offset] days ago (local).
  static SleepSessionRaw? _sleepSessionForOffset(
    List<SleepSessionRaw> sessions,
    int offset,
  ) {
    for (final session in sessions) {
      final daysAgo = _sleepDaysAgo(session.start, session.end);
      if (daysAgo == offset) return session;
    }
    // Fallback: packet order often newest-first; offset 0 → first with stages.
    if (offset == 0 && sessions.isNotEmpty) {
      for (final session in sessions) {
        if (session.stages.isNotEmpty) return session;
      }
      return sessions.first;
    }
    return null;
  }

  static int _sleepDaysAgo(DateTime start, DateTime end) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Protocol daysAgo = calendar day of wake (session end).
    final wakeDay = DateTime(end.year, end.month, end.day);
    final byEnd = today.difference(wakeDay).inDays;
    if (byEnd >= 0) return byEnd;
    final startDay = DateTime(start.year, start.month, start.day);
    return today.difference(startDay).inDays.clamp(0, 30);
  }

  static int _asInt(dynamic v, {int def = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? def;
  }

  static Future<Map<String, dynamic>> _measureHrMap() async {
    _throwIfAutoCancelled();
    final r = await _repo.realtimeHr.measureOnce();
    return {
      'hr': r.bpm,
      'value': r.bpm,
      'errCode': r.errorCode,
    };
  }

  static Future<Map<String, dynamic>> _measureSpo2Map() async {
    _throwIfAutoCancelled();
    final r = await _repo.spo2.measureOnce();
    return {
      'spo2': r.bpm,
      'value': r.bpm,
      'errCode': r.errorCode,
    };
  }

  static Future<Map<String, dynamic>> _measureStressMap() async {
    _throwIfAutoCancelled();
    final r = await _repo.realtimeHr.measureStressOnce();
    return {
      'pressure': r.bpm,
      'stress': r.bpm,
      'value': r.bpm,
      'errCode': r.errorCode,
    };
  }

  static void _throwIfAutoCancelled() {
    if (_autoMeasureDepth > 0 && _autoAborted) {
      throw PlatformException(code: autoCancelledCode);
    }
  }
}
