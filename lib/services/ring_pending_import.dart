import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/db/app_db.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';

/// 네이티브 백그라운드 수집 큐를 앱 DB로 병합한다.
class RingPendingImport {
  static const MethodChannel _channel = MethodChannel(
    'com.example.picnique_ring/background_keepalive',
  );

  static Future<int> importAll() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'fetchPendingHealthRecords',
      );
      if (raw == null || raw.isEmpty) return 0;

      var imported = 0;
      for (final item in raw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(
          item.map((k, v) => MapEntry(k.toString(), v)),
        );
        if (await _importOne(map)) imported++;
      }

      if (imported > 0) {
        await _channel.invokeMethod('clearPendingHealthRecords');
        debugPrint('[PENDING_IMPORT] imported $imported records');
      }
      return imported;
    } catch (e, st) {
      debugPrint('[PENDING_IMPORT] failed: $e\n$st');
      return 0;
    }
  }

  static Future<bool> _importOne(Map<String, dynamic> record) async {
    final type = record['type']?.toString();
    final date = _parseDate(record['date']);
    if (type == null || date == null) return false;

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
        final spo2 = _asInt(record['spo2']);
        if (spo2 == null || spo2 <= 0) return false;
        await DbManager.I.appDB.into(DbManager.I.appDB.bloodOxygenDetails).insert(
          BloodOxygenDetailsCompanion.insert(date: date, spo2: spo2),
          mode: InsertMode.insertOrIgnore,
        );
        return true;
      case 'stress':
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
      default:
        return false;
    }
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
