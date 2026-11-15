import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:rwfit_ble/rwfit_ble.dart';
import '../../db/app_db.dart';

/// SDK-normalized values, NOT raw MiniProgram packet values.
/// Unknown shapes are archived verbatim and are never guessed into chart rows.
class RwfitHistoryStore {
  RwfitHistoryStore(this.db);
  final AppDatabase db;
  Future<void>? _schema;
  Future<void> _ensureSchema() => _schema ??= db.customStatement('''
    CREATE TABLE IF NOT EXISTS rwfit_source_records (
      device_id TEXT NOT NULL, kind TEXT NOT NULL, payload TEXT NOT NULL,
      received_at INTEGER NOT NULL, projection TEXT NOT NULL,
      PRIMARY KEY(device_id, kind, payload))
  ''');
  Future<void> prepare() => _ensureSchema();
  int? _integer(dynamic value) => value is int ? value :
      value is num && value.isFinite && value == value.roundToDouble() ? value.toInt() : null;
  DateTime? _time(dynamic value) {
    final seconds = _integer(value);
    if (seconds == null || seconds <= 0 || seconds > 253402300799) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
  Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  Future<void> save(String deviceId, SyncResult result) async {
    await _ensureSchema();
    for (final record in result.data) {
      final payload = jsonEncode(_canonical(record));
      await db.transaction(() async {
        final existing = await db.customSelect(
          'SELECT 1 FROM rwfit_source_records WHERE device_id = ? AND kind = ? AND payload = ?',
          variables: [Variable.withString(deviceId), Variable.withString(result.type), Variable.withString(payload)],
        ).get();
        if (existing.isNotEmpty) return;
        final projected = await _project(result.type, record);
        await db.customStatement(
          'INSERT INTO rwfit_source_records(device_id, kind, payload, received_at, projection) VALUES (?, ?, ?, ?, ?)',
          [deviceId, result.type, payload, DateTime.now().millisecondsSinceEpoch ~/ 1000,
           projected ? 'chart' : 'raw_only'],
        );
      });
    }
  }

  Future<bool> _project(String type, Map<String, dynamic> record) async {
    final source = record['source'] == 'realtime' ? 'appManual' : 'firmwareAuto';
    final raw = record['items'];
    if (raw is! List || raw.isEmpty || raw.any((item) => item is! Map)) return false;
    final items = raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    if (const ['hr', 'bo', 'pressure'].contains(type)) {
      final field = {'hr': 'hr', 'bo': 'bloodOxy', 'pressure': 'pressure'}[type]!;
      if (items.any((item) => _time(item['time']) == null || _integer(item[field]) == null)) return false;
      for (final item in items) {
        final date = _time(item['time'])!;
        final value = _integer(item[field])!;
        // Zero is a missing/unworn value, not a valid measurement.
        if (value <= 0 || (type == 'bo' && value > 100)) continue;
        if (type == 'hr') {
          final found = await (db.select(db.heartDetails)..where((t) => t.date.equals(date) & t.bpm.equals(value))).get();
          if (found.isEmpty) await db.insertHeartDetail(HeartDetailsCompanion.insert(date: date, bpm: value, source: Value(source)));
        } else if (type == 'bo') {
          final found = await (db.select(db.bloodOxygenDetails)..where((t) => t.date.equals(date) & t.spo2.equals(value))).get();
          if (found.isEmpty) await db.insertSpO2(BloodOxygenDetailsCompanion.insert(date: date, spo2: value, source: Value(source)));
        } else {
          final found = await (db.select(db.stressDetails)..where((t) => t.date.equals(date) & t.stress.equals(value))).get();
          if (found.isEmpty) await db.insertStress(StressDetailsCompanion.insert(date: date, stress: value, source: Value(source)));
        }
      }
      return true;
    }
    if (type == 'sleep') {
      final start = _time(record['beginTime']);
      final end = _time(record['endTime']);
      const stages = {0: 5, 1: 2, 2: 3, 3: 4};
      if (start == null || end == null || !end.isAfter(start)) return false;
      if (items.any((item) => (_integer(item['len']) ?? 0) <= 0 || !stages.containsKey(_integer(item['sleepType'])))) return false;
      final minutes = items.fold<int>(0, (sum, item) => sum + _integer(item['len'])!);
      if (start.add(Duration(minutes: minutes)) != end) return false;
      var cursor = start;
      final day = DateTime(end.year, end.month, end.day);
      for (final item in items) {
        final next = cursor.add(Duration(minutes: _integer(item['len'])!));
        await db.into(db.sleepDetails).insert(SleepDetailsCompanion.insert(
          date: day, start: cursor, end: next, type: stages[_integer(item['sleepType'])]!),
          mode: InsertMode.insertOrIgnore);
        cursor = next;
      }
      return true;
    }
    // Existing charts assume 15-minute bins. Do not invent distribution for
    // devices whose SDK supplies a different activityDataInterval.
    if (type == 'step') {
      if (_integer(record['activityDataInterval']) != 15) return false;
      for (final item in items) {
        final time = _time(item['time']);
        if (time == null || time.minute % 15 != 0 || time.second != 0 ||
            ['steps', 'calorie', 'distance'].any((k) => _integer(item[k]) == null || _integer(item[k])! < 0)) return false;
      }
      for (final item in items) {
        final date = _time(item['time'])!;
        await db.insertSport(SportDetailsCompanion.insert(date: date,
          timeIndex: (date.hour * 60 + date.minute) ~/ 15,
          walkSteps: _integer(item['steps'])!, runSteps: 0,
          distance: _integer(item['distance'])!, calorie: _integer(item['calorie'])!));
      }
      return true;
    }
    return false;
  }
}
