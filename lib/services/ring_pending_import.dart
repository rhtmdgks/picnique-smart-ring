import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/measurement_source.dart';
import 'package:picnique_rosary_healthcare_smartring/db/app_db.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_data_refresh_notifier.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_battery_service.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_measurement_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 네이티브 pending 큐(append-only JSONL) → Drift DB 병합.
///
/// 반지가 오프라인 동안 내부 메모리에 쌓은 측정값을 네이티브가 pull 해
/// pending 큐에 적재하면, 여기서 앱 DB로 옮긴다. 프로토콜:
///
/// 1. `fetchPendingHealthSnapshot` — 큐 스냅샷 + 라인 수 (읽기만으로는 큐 불변)
/// 2. DB 기존 값과 대조해 **중복 제거** 후 청크 단위 트랜잭션 insert
/// 3. 저장 성공·무효 레코드를 제외한 나머지만 `replacePendingHealthRecords`
///    로 되써서 **ACK**. 실패분은 큐에 남아 다음 import 때 resume 된다.
///    스냅샷 이후 네이티브가 append 한 tail 은 네이티브가 보존한다.
///
/// 대량 전송 안전장치: 재진입 방지, 청크 트랜잭션(부분 실패 시 해당
/// 청크만 큐 잔류), 레코드 단위 검증(무효 데이터는 폐기해 큐 무한 증식 방지),
/// ACK 시 스냅샷 이후 유입분 유실 방지(fetchedLineCount 기준 tail 보존).
class RingPendingImport {
  static const MethodChannel _channel = MethodChannel(
    'com.example.picnique_ring/background_keepalive',
  );

  /// 한 트랜잭션에 넣는 레코드 수. 수천 건 유입 시 UI 블로킹 방지.
  static const int _chunkSize = 200;

  static bool _importing = false;

  static Future<int> importAll({
    Ring? ring,
    HealthDataRefreshNotifier? refreshNotifier,
  }) async {
    if (_importing) {
      debugPrint('[PENDING_IMPORT] skipped — already importing');
      return 0;
    }
    _importing = true;
    try {
      return await _importAllInner(
        ring: ring,
        refreshNotifier: refreshNotifier,
      );
    } catch (e, st) {
      debugPrint('[PENDING_IMPORT] failed: $e\n$st');
      return 0;
    } finally {
      _importing = false;
    }
  }

  static Future<int> _importAllInner({
    Ring? ring,
    HealthDataRefreshNotifier? refreshNotifier,
  }) async {
    await DbManager.I.open();

    final snap = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'fetchPendingHealthSnapshot',
    );
    final raw = (snap?['records'] as List<dynamic>?) ?? const <dynamic>[];
    final fetchedLineCount =
        (snap?['fetchedLineCount'] as int?) ?? raw.length;
    if (raw.isEmpty) return 0;

    final records = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      records.add(
        Map<String, dynamic>.from(
          item.map((k, v) => MapEntry(k.toString(), v)),
        ),
      );
    }
    debugPrint('[PENDING_IMPORT] queue size: ${records.length}');

    var imported = 0;
    var dropped = 0;
    final remaining = <Map<String, dynamic>>[];
    final changedTypes = <DataType>{};

    // 배터리 레코드는 DB가 아닌 prefs/provider 로 간다.
    final health = <_ParsedRecord>[];
    for (final record in records) {
      final type = record['type']?.toString();
      if (type == 'battery') {
        if (await _applyBattery(record, ring)) {
          imported++;
        } else {
          dropped++;
        }
        continue;
      }
      final parsed = _ParsedRecord.tryParse(record);
      if (parsed == null) {
        // 무효 레코드는 폐기 — 큐에 영원히 남는 것을 방지.
        dropped++;
        continue;
      }
      health.add(parsed);
    }

    // 종류별로 묶어 DB 기존값과 한 번에 대조(중복 제거).
    final byKind = <_RecordKind, List<_ParsedRecord>>{};
    for (final r in health) {
      byKind.putIfAbsent(r.kind, () => []).add(r);
    }

    for (final entry in byKind.entries) {
      final kind = entry.key;
      final list = entry.value;
      List<_ParsedRecord> fresh;
      try {
        final existing = await _existingKeys(kind, list);
        final seen = <String>{};
        fresh = list
            .where((r) => !existing.contains(r.dedupeKey) && seen.add(r.dedupeKey))
            .toList();
        final dupes = list.length - fresh.length;
        if (dupes > 0) {
          debugPrint(
            '[PENDING_IMPORT] ${kind.name}: $dupes duplicates skipped',
          );
          dropped += dupes;
        }
      } catch (e) {
        // 대조 실패 — 이 종류 전체를 큐에 남기고 다음 기회에 재시도.
        debugPrint('[PENDING_IMPORT] ${kind.name} dedupe failed: $e');
        remaining.addAll(list.map((r) => r.raw));
        continue;
      }

      // 청크 단위 트랜잭션 — 실패한 청크만 큐에 잔류(resume 단위).
      for (var i = 0; i < fresh.length; i += _chunkSize) {
        final chunk = fresh.sublist(
          i,
          i + _chunkSize > fresh.length ? fresh.length : i + _chunkSize,
        );
        try {
          await _insertChunk(kind, chunk, deviceAddress: ring?.savedAddress);
          imported += chunk.length;
          if (chunk.isNotEmpty) changedTypes.add(kind.dataType);
        } catch (e) {
          debugPrint('[PENDING_IMPORT] ${kind.name} chunk insert failed: $e');
          remaining.addAll(chunk.map((r) => r.raw));
        }
      }
    }

    // ACK: 처리(성공+폐기)된 만큼 큐를 줄여서 되쓴다.
    // fetchedLineCount 이후 네이티브가 append 한 tail 은 네이티브가 보존.
    if (imported > 0 || dropped > 0 || remaining.length != records.length) {
      await _channel.invokeMethod<void>('replacePendingHealthRecords', {
        'records': remaining,
        'fetchedLineCount': fetchedLineCount,
      });
      debugPrint(
        '[PENDING_IMPORT] imported $imported, dropped $dropped, '
        'remaining ${remaining.length}',
      );
    }

    if (refreshNotifier != null) {
      for (final type in changedTypes) {
        refreshNotifier.notifyChanged(type);
      }
    }
    return imported;
  }

  /// DB에 이미 있는 레코드 키(epochMs 또는 epochMs|timeIndex) 집합.
  static Future<Set<String>> _existingKeys(
    _RecordKind kind,
    List<_ParsedRecord> list,
  ) async {
    final db = DbManager.I.appDB;
    var min = list.first.date;
    var max = list.first.date;
    for (final r in list) {
      if (r.date.isBefore(min)) min = r.date;
      if (r.date.isAfter(max)) max = r.date;
    }
    final from = min.subtract(const Duration(seconds: 1));
    final to = max.add(const Duration(seconds: 1));

    switch (kind) {
      case _RecordKind.heart:
        final rows = await (db.select(db.heartDetails)
              ..where((t) => t.date.isBetweenValues(from, to)))
            .get();
        return rows
            .map((r) => r.date.millisecondsSinceEpoch.toString())
            .toSet();
      case _RecordKind.spo2:
        final rows = await (db.select(db.bloodOxygenDetails)
              ..where((t) => t.date.isBetweenValues(from, to)))
            .get();
        return rows
            .map((r) => r.date.millisecondsSinceEpoch.toString())
            .toSet();
      case _RecordKind.stress:
        final rows = await (db.select(db.stressDetails)
              ..where((t) => t.date.isBetweenValues(from, to)))
            .get();
        return rows
            .map((r) => r.date.millisecondsSinceEpoch.toString())
            .toSet();
      case _RecordKind.sport:
        final rows = await (db.select(db.sportDetails)
              ..where((t) => t.date.isBetweenValues(from, to)))
            .get();
        return rows
            .map((r) => '${r.date.millisecondsSinceEpoch}|${r.timeIndex}')
            .toSet();
    }
  }

  static Future<void> _insertChunk(
    _RecordKind kind,
    List<_ParsedRecord> chunk, {
    String? deviceAddress,
  }) async {
    if (chunk.isEmpty) return;
    final db = DbManager.I.appDB;
    // 반지 축적분은 펌웨어 자동 측정 — source·dedupeKey 를 기록한다.
    const source = MeasurementSource.firmwareAuto;
    String? dbKey(String stream, _ParsedRecord r) =>
        RingMeasurementStore.buildDedupeKey(
          deviceAddress: deviceAddress,
          stream: stream,
          date: r.date,
          source: source,
        );
    await db.transaction(() async {
      for (final r in chunk) {
        switch (kind) {
          case _RecordKind.heart:
            await db.into(db.heartDetails).insert(
                  HeartDetailsCompanion.insert(
                    date: r.date,
                    bpm: r.value,
                    source: Value(source.name),
                    dedupeKey: Value(dbKey('heart', r)),
                    ringSeq: Value(r.ringSeq),
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
          case _RecordKind.spo2:
            await db.into(db.bloodOxygenDetails).insert(
                  BloodOxygenDetailsCompanion.insert(
                    date: r.date,
                    spo2: r.value,
                    source: Value(source.name),
                    dedupeKey: Value(dbKey('spo2', r)),
                    ringSeq: Value(r.ringSeq),
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
          case _RecordKind.stress:
            await db.into(db.stressDetails).insert(
                  StressDetailsCompanion.insert(
                    date: r.date,
                    stress: r.value,
                    source: Value(source.name),
                    dedupeKey: Value(dbKey('stress', r)),
                    ringSeq: Value(r.ringSeq),
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
          case _RecordKind.sport:
            await db.into(db.sportDetails).insert(
                  SportDetailsCompanion.insert(
                    date: r.date,
                    walkSteps: r.walkSteps,
                    runSteps: r.runSteps,
                    calorie: r.calorie,
                    distance: r.distance,
                    timeIndex: r.timeIndex,
                  ),
                );
        }
      }
    });
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

    ring?.setBatteryAndCharging(level, charging, fromRealtime: true);
    return true;
  }
}

enum _RecordKind {
  heart(DataType.HeartRate),
  spo2(DataType.Oxygen),
  stress(DataType.Stress),
  sport(DataType.Steps);

  const _RecordKind(this.dataType);
  final DataType dataType;
}

class _ParsedRecord {
  _ParsedRecord({
    required this.raw,
    required this.kind,
    required this.date,
    required this.value,
    this.timeIndex = 0,
    this.walkSteps = 0,
    this.runSteps = 0,
    this.calorie = 0,
    this.distance = 0,
  });

  final Map<String, dynamic> raw;
  final _RecordKind kind;
  final DateTime date;
  final int value;
  final int timeIndex;
  final int walkSteps;
  final int runSteps;
  final int calorie;
  final int distance;

  /// 반지 펌웨어가 부여한 시퀀스 — 레코드에 있을 때만.
  String? get ringSeq {
    final seq = raw['seq'] ?? raw['ringSeq'];
    return seq?.toString();
  }

  String get dedupeKey => kind == _RecordKind.sport
      ? '${date.millisecondsSinceEpoch}|$timeIndex'
      : date.millisecondsSinceEpoch.toString();

  static _ParsedRecord? tryParse(Map<String, dynamic> record) {
    final type = record['type']?.toString();
    final date = _parseDate(record['date']);
    if (type == null || date == null) return null;

    switch (type) {
      case 'heart':
      case 'heart_sample':
        final bpm = _asInt(record['bpm']);
        if (bpm == null || bpm <= 0 || bpm > 250) return null;
        return _ParsedRecord(
          raw: record,
          kind: _RecordKind.heart,
          date: date,
          value: bpm,
        );
      case 'spo2':
      case 'spo2_sample':
        final spo2 = _asInt(record['spo2']);
        if (spo2 == null || spo2 <= 0 || spo2 > 100) return null;
        return _ParsedRecord(
          raw: record,
          kind: _RecordKind.spo2,
          date: date,
          value: spo2,
        );
      case 'stress':
      case 'stress_sample':
        final stress = _asInt(record['stress']);
        if (stress == null || stress <= 0) return null;
        return _ParsedRecord(
          raw: record,
          kind: _RecordKind.stress,
          date: date,
          value: stress,
        );
      case 'steps':
        final steps = _asInt(record['steps']);
        if (steps == null || steps < 0) return null;
        return _ParsedRecord(
          raw: record,
          kind: _RecordKind.sport,
          date: DateTime(date.year, date.month, date.day),
          value: steps,
          walkSteps: steps,
        );
      case 'sport_slot':
        final walkSteps = _asInt(record['walkSteps']) ?? 0;
        final runSteps = _asInt(record['runSteps']) ?? 0;
        if (walkSteps <= 0 && runSteps <= 0) return null;
        return _ParsedRecord(
          raw: record,
          kind: _RecordKind.sport,
          date: date,
          value: walkSteps + runSteps,
          timeIndex: _asInt(record['timeIndex']) ?? 0,
          walkSteps: walkSteps,
          runSteps: runSteps,
          calorie: _asInt(record['calorie']) ?? 0,
          distance: _asInt(record['distance']) ?? 0,
        );
      default:
        return null;
    }
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final parsed = DateTime.tryParse(value.toString());
    return parsed?.toLocal();
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
