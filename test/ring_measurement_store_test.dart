import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/measurement_source.dart';
import 'package:picnique_rosary_healthcare_smartring/db/app_db.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_measurement_store.dart';

void main() {
  group('RingMeasurementStore.methodFor', () {
    test('측정 타입별 네이티브 메서드 매핑', () {
      expect(
        RingMeasurementStore.methodFor(DataType.HeartRate),
        'syncManualHeartRate',
      );
      expect(
        RingMeasurementStore.methodFor(DataType.Stress),
        'syncManualPressure',
      );
      expect(
        RingMeasurementStore.methodFor(DataType.Oxygen),
        'syncManualBloodOxygen',
      );
      expect(RingMeasurementStore.methodFor(DataType.Sleep), isNull);
      expect(RingMeasurementStore.methodFor(DataType.Steps), isNull);
    });
  });

  group('RingMeasurementStore.extractValue', () {
    test('심박 — Android 응답 (hr 키)', () {
      final res = {'type': 1, 'errCode': 0, 'hr': 72, 'value': 72, 'rri': 830};
      expect(
        RingMeasurementStore.extractValue(res, DataType.HeartRate),
        72,
      );
    });

    test('심박 — iOS 응답 (value 키만)', () {
      expect(
        RingMeasurementStore.extractValue({'value': 68}, DataType.HeartRate),
        68,
      );
    });

    test('SpO2 — 정상 범위', () {
      expect(
        RingMeasurementStore.extractValue(
          {'errCode': 0, 'spo2': 98, 'value': 98},
          DataType.Oxygen,
        ),
        98,
      );
    });

    test('SpO2 — 100 초과 값 거부', () {
      expect(
        RingMeasurementStore.extractValue(
          {'spo2': 127, 'value': 127},
          DataType.Oxygen,
        ),
        isNull,
      );
    });

    test('스트레스 — pressure 키 우선', () {
      expect(
        RingMeasurementStore.extractValue(
          {'errCode': 0, 'pressure': 34, 'value': 34},
          DataType.Stress,
        ),
        34,
      );
    });

    test('errCode != 0 이면 거부 (미착용 등)', () {
      expect(
        RingMeasurementStore.extractValue(
          {'errCode': 2, 'hr': 72},
          DataType.HeartRate,
        ),
        isNull,
      );
    });

    test('0 이하 값 거부', () {
      expect(
        RingMeasurementStore.extractValue(
          {'hr': 0, 'value': 0},
          DataType.HeartRate,
        ),
        isNull,
      );
      expect(
        RingMeasurementStore.extractValue(
          {'hr': -1},
          DataType.HeartRate,
        ),
        isNull,
      );
    });

    test('첫 키가 무효면 다음 키로 폴백', () {
      expect(
        RingMeasurementStore.extractValue(
          {'hr': 0, 'value': 75},
          DataType.HeartRate,
        ),
        75,
      );
    });

    test('Map 이 아니면 null', () {
      expect(RingMeasurementStore.extractValue(null, DataType.HeartRate), isNull);
      expect(RingMeasurementStore.extractValue(42, DataType.HeartRate), isNull);
      expect(
        RingMeasurementStore.extractValue('ok', DataType.HeartRate),
        isNull,
      );
    });

    test('문자열 숫자 허용 (채널 직렬화 편차)', () {
      expect(
        RingMeasurementStore.extractValue(
          {'hr': '77'},
          DataType.HeartRate,
        ),
        77,
      );
    });
  });

  group('RingMeasurementStore.buildDedupeKey', () {
    test('형식: {deviceAddress}|{stream}|{epochMs}|{source.name}', () {
      final date = DateTime.fromMillisecondsSinceEpoch(1751900000000);
      expect(
        RingMeasurementStore.buildDedupeKey(
          deviceAddress: 'AA:BB:CC',
          stream: 'heart',
          date: date,
          source: MeasurementSource.appManual,
        ),
        'AA:BB:CC|heart|1751900000000|appManual',
      );
    });

    test('deviceAddress 없으면 unknown', () {
      final date = DateTime.fromMillisecondsSinceEpoch(1751900000000);
      expect(
        RingMeasurementStore.buildDedupeKey(
          deviceAddress: null,
          stream: 'spo2',
          date: date,
          source: MeasurementSource.firmwareAuto,
        ),
        'unknown|spo2|1751900000000|firmwareAuto',
      );
    });
  });

  group('RingMeasurementStore.save — source 구분 저장', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      DbManager.I.setForTesting(db);
    });

    tearDown(() async {
      DbManager.I.setForTesting(null);
      await db.close();
    });

    test('수동/자동 측정이 source 로 구분되어 저장된다', () async {
      final date = DateTime(2026, 7, 8, 9, 0);
      await RingMeasurementStore.save(
        DataType.HeartRate,
        72,
        date,
        source: MeasurementSource.appManual,
        deviceAddress: 'AA:BB',
      );
      await RingMeasurementStore.save(
        DataType.HeartRate,
        75,
        date.add(const Duration(minutes: 5)),
        source: MeasurementSource.appTimerFallback,
        deviceAddress: 'AA:BB',
      );

      final rows = await db.select(db.heartDetails).get();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.source).toSet(), {
        'appManual',
        'appTimerFallback',
      });
      expect(
        rows.first.dedupeKey,
        'AA:BB|heart|${date.millisecondsSinceEpoch}|appManual',
      );
    });

    test('같은 dedupeKey 는 UNIQUE 인덱스가 중복 insert 를 차단한다', () async {
      final date = DateTime(2026, 7, 8, 9, 0);
      for (var i = 0; i < 2; i++) {
        await RingMeasurementStore.save(
          DataType.Oxygen,
          98,
          date,
          source: MeasurementSource.appManual,
          deviceAddress: 'AA:BB',
        );
      }

      final rows = await db.select(db.bloodOxygenDetails).get();
      expect(rows, hasLength(1));
    });

    test('같은 시각이라도 source 가 다르면 별도 행 (dedupeKey 상이)', () async {
      final date = DateTime(2026, 7, 8, 9, 0);
      await RingMeasurementStore.save(
        DataType.Stress,
        30,
        date,
        source: MeasurementSource.appManual,
      );
      await RingMeasurementStore.save(
        DataType.Stress,
        30,
        date,
        source: MeasurementSource.firmwareAuto,
      );

      final rows = await db.select(db.stressDetails).get();
      expect(rows, hasLength(2));
    });
  });
}
