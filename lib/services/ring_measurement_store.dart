import 'package:drift/drift.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/measurement_source.dart';
import 'package:picnique_rosary_healthcare_smartring/db/app_db.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';

/// 수동·자동 측정 공용 — 네이티브 응답 파싱과 Drift DB 저장.
class RingMeasurementStore {
  RingMeasurementStore._();

  /// 측정 타입 → 네이티브 MethodChannel 메서드.
  static String? methodFor(DataType type) => switch (type) {
        DataType.HeartRate => 'syncManualHeartRate',
        DataType.Stress => 'syncManualPressure',
        DataType.Oxygen => 'syncManualBloodOxygen',
        _ => null,
      };

  static List<String> _valueKeysFor(DataType type) => switch (type) {
        DataType.HeartRate => const ['hr', 'value'],
        DataType.Stress => const ['pressure', 'stress', 'value'],
        DataType.Oxygen => const ['spo2', 'value'],
        _ => const ['value'],
      };

  /// 네이티브 응답에서 유효한 측정값을 뽑는다. 실패 시 null.
  static int? extractValue(dynamic res, DataType type) {
    if (res is! Map) return null;
    final errCode = asInt(res['errCode']);
    if (errCode != null && errCode != 0) return null;
    for (final key in _valueKeysFor(type)) {
      final v = asInt(res[key]);
      if (v == null || v <= 0) continue;
      if (type == DataType.Oxygen && v > 100) continue;
      return v;
    }
    return null;
  }

  /// dedupeKey 의 stream 식별자.
  static String? streamNameFor(DataType type) => switch (type) {
        DataType.HeartRate => 'heart',
        DataType.Stress => 'stress',
        DataType.Oxygen => 'spo2',
        _ => null,
      };

  /// 중복 방지 키: '{deviceAddress}|{stream}|{epochMs}|{source.name}'.
  static String buildDedupeKey({
    required String? deviceAddress,
    required String stream,
    required DateTime date,
    required MeasurementSource source,
  }) {
    final address = (deviceAddress == null || deviceAddress.trim().isEmpty)
        ? 'unknown'
        : deviceAddress.trim();
    return '$address|$stream|${date.millisecondsSinceEpoch}|${source.name}';
  }

  static Future<void> save(
    DataType type,
    int value,
    DateTime date, {
    required MeasurementSource source,
    String? deviceAddress,
  }) async {
    await DbManager.I.open();
    final db = DbManager.I.appDB;
    final stream = streamNameFor(type);
    final dedupeKey = stream == null
        ? null
        : buildDedupeKey(
            deviceAddress: deviceAddress,
            stream: stream,
            date: date,
            source: source,
          );
    // dedupeKey UNIQUE 인덱스가 중복을 차단하므로 insertOrIgnore 유지.
    switch (type) {
      case DataType.HeartRate:
        await db.into(db.heartDetails).insert(
              HeartDetailsCompanion.insert(
                date: date,
                bpm: value,
                source: Value(source.name),
                dedupeKey: Value(dedupeKey),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      case DataType.Stress:
        await db.into(db.stressDetails).insert(
              StressDetailsCompanion.insert(
                date: date,
                stress: value,
                source: Value(source.name),
                dedupeKey: Value(dedupeKey),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      case DataType.Oxygen:
        await db.into(db.bloodOxygenDetails).insert(
              BloodOxygenDetailsCompanion.insert(
                date: date,
                spo2: value,
                source: Value(source.name),
                dedupeKey: Value(dedupeKey),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      default:
        break;
    }
  }

  static int? asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
