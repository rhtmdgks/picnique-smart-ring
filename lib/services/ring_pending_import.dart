import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/db/app_db.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_data_refresh_notifier.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_battery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 네이티브 백그라운드 수집 큐 → 앱 DB·배터리 prefs 로 병합한다.
///
/// 앱이 종료된 동안 네이티브가 반지 저장소에서 pull 한 데이터가
/// pending 큐에 쌓이면, import 시 Drift DB에 insert 한다.
class RingPendingImport {
  static const MethodChannel _channel = MethodChannel(
    'com.example.picnique_ring/background_keepalive',
  );

  static Future<int> importAll({
    Ring? ring,
    HealthDataRefreshNotifier? refreshNotifier,
  }) async {
    try {
      await DbManager.I.open();

      final raw = await _channel.invokeMethod<List<dynamic>>(
        'fetchPendingHealthRecords',
      );
      if (raw == null || raw.isEmpty) return 0;

      var imported = 0;
      final remaining = <Map<String, dynamic>>[];
      final changedTypes = <DataType>{};

      for (final item in raw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(
          item.map((k, v) => MapEntry(k.toString(), v)),
        );
        final recordType = map['type']?.toString();
        if (await _importOne(map, ring: ring)) {
          imported++;
          final dt = HealthDataRefreshNotifier.dataTypeForImportRecord(recordType);
          if (dt != null) changedTypes.add(dt);
        } else {
          remaining.add(map);
        }
      }

      if (imported > 0 || remaining.length != raw.length) {
        await _channel.invokeMethod<void>('replacePendingHealthRecords', {
          'records': remaining,
        });
        debugPrint(
          '[PENDING_IMPORT] imported $imported, remaining ${remaining.length}',
        );
      }
      if (refreshNotifier != null) {
        for (final type in changedTypes) {
          refreshNotifier.notifyChanged(type);
        }
      }
      return imported;
    } catch (e, st) {
      debugPrint('[PENDING_IMPORT] failed: $e\n$st');
      return 0;
    }
  }

  static Future<bool> _importOne(
    Map<String, dynamic> record, {
    Ring? ring,
  }) async {
    final type = record['type']?.toString();
    if (type == null) return false;

    if (type == 'battery') {
      return _applyBattery(record, ring);
    }

    final date = _parseDate(record['date']);
    if (date == null) return false;

    switch (type) {
      case 'heart':
      case 'heart_sample':
        final bpm = _asInt(record['bpm']);
        if (bpm == null || bpm <= 0) return false;
        await DbManager.I.heartDB.into(DbManager.I.heartDB.heartDetails).insert(
          HeartDetailsCompanion.insert(date: date, bpm: bpm),
          mode: InsertMode.insertOrIgnore,
        );
        return true;
      case 'spo2':
      case 'spo2_sample':
        final spo2 = _asInt(record['spo2']);
        if (spo2 == null || spo2 <= 0) return false;
        await DbManager.I.appDB.into(DbManager.I.appDB.bloodOxygenDetails).insert(
          BloodOxygenDetailsCompanion.insert(date: date, spo2: spo2),
          mode: InsertMode.insertOrIgnore,
        );
        return true;
      case 'stress':
      case 'stress_sample':
        final stress = _asInt(record['stress']);
        if (stress == null || stress <= 0) return false;
        await DbManager.I.appDB.into(DbManager.I.appDB.stressDetails).insert(
          StressDetailsCompanion.insert(date: date, stress: stress),
          mode: InsertMode.insertOrIgnore,
        );
        return true;
      case 'steps':
        final steps = _asInt(record['steps']);
        if (steps == null || steps < 0) return false;
        await DbManager.I.appDB.into(DbManager.I.appDB.sportDetails).insert(
          SportDetailsCompanion.insert(
            date: DateTime(date.year, date.month, date.day),
            walkSteps: steps,
            runSteps: 0,
            calorie: 0,
            distance: 0,
            timeIndex: 0,
          ),
          mode: InsertMode.insertOrReplace,
        );
        return true;
      case 'sport_slot':
        final walkSteps = _asInt(record['walkSteps']) ?? 0;
        final runSteps = _asInt(record['runSteps']) ?? 0;
        if (walkSteps <= 0 && runSteps <= 0) return false;
        final timeIndex = _asInt(record['timeIndex']) ?? 0;
        await DbManager.I.appDB.into(DbManager.I.appDB.sportDetails).insert(
          SportDetailsCompanion.insert(
            date: date,
            walkSteps: walkSteps,
            runSteps: runSteps,
            calorie: _asInt(record['calorie']) ?? 0,
            distance: _asInt(record['distance']) ?? 0,
            timeIndex: timeIndex,
          ),
          mode: InsertMode.insertOrReplace,
        );
        return true;
      default:
        return false;
    }
  }

  static Future<bool> _applyBattery(
    Map<String, dynamic> record,
    Ring? ring,
  ) async {
    final level = RingBatteryService.normalizeLevel(
      record['battery'] ?? record['level'],
    );
    if (level == null) return false;

    final charging =
        record['charging'] == true || record['isCharging'] == true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ring_battery', level);

    if (ring != null) {
      ring.setBatteryAndCharging(level, charging, fromRealtime: true);
    }
    return true;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
