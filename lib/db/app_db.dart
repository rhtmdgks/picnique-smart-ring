import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'app_db.g.dart'; // drift 생성 파일
part 'table.dart'; // 테이블 정의 (SleepOveralls, SleepDetails, HeartDetails, StressDetails, BloodOxygenDetails, SportDetails)

@DriftDatabase(
  tables: [
    SleepDetails,
    HeartDetails,
    StressDetails, // ← 추가
    BloodOxygenDetails, // ← 추가
    SportDetails, // ← 추가
    RosarySessions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // 스키마 버전 ↑ (v2 → v3)
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // v1 → v2: HeartDetails 신설
      if (from < 2) {
        await m.createTable(heartDetails);
      }
      // v2 → v3: Stress/BloodOxygen/Sport 신설
      if (from < 3) {
        await m.createTable(stressDetails);
        await m.createTable(bloodOxygenDetails);
        await m.createTable(sportDetails);

        // 필요 시 인덱스 (선택)
        // await customStatement('CREATE INDEX IF NOT EXISTS idx_sport_date ON sport_details(date)');
        // await customStatement('CREATE INDEX IF NOT EXISTS idx_bloodoxygen_date ON blood_oxygen_details(date)');
      }
      if (from < 4) {
        await m.createTable(rosarySessions);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA journal_mode=WAL;');
      await customStatement('PRAGMA busy_timeout=5000;');
      await customStatement('PRAGMA foreign_keys=ON;');
    },
  );
  // ------------------------------
  // SleepDetails CRUD / Query
  // ------------------------------
  Future<List<SleepDetail>> getAllDetails() => select(sleepDetails).get();

  Future<List<SleepDetail>> fetchDetailsByDate(DateTime date) =>
      (select(sleepDetails)..where((t) => t.date.equals(date))).get();

  Future<List<SleepDetail>> fetchDetailsByType(int typeValue) =>
      (select(sleepDetails)..where((t) => t.type.equals(typeValue))).get();

  Future<int> insertDetail(SleepDetailsCompanion detail) =>
      into(sleepDetails).insert(detail);

  Future<bool> updateDetail(SleepDetail detail) =>
      update(sleepDetails).replace(detail);

  Future<int> deleteDetail(int id) =>
      (delete(sleepDetails)..where((t) => t.id.equals(id))).go();

  Stream<List<SleepDetail>> watchAllDetails() => select(sleepDetails).watch();

  // ------------------------------
  // HeartDetails CRUD / Query
  // ------------------------------
  Future<List<HeartDetail>> getAllHeartDetails() => select(heartDetails).get();

  Future<List<HeartDetail>> getAllHeartDetailsByDate(DateTime date) =>
      (select(heartDetails)..where((t) => t.date.equals(date))).get();

  Future<int> insertHeartDetail(HeartDetailsCompanion detail) =>
      into(heartDetails).insert(detail);

  Future<int> deleteHeartDetailsInRange(DateTime from, DateTime to) => (delete(
    heartDetails,
  )..where((t) => t.date.isBetweenValues(from, to))).go();

  // ------------------------------
  // StressDetails CRUD / Query
  // ------------------------------
  Future<int> insertStress(StressDetailsCompanion row) =>
      into(stressDetails).insert(row);

  Future<StressDetail?> latestStress() {
    final q = select(stressDetails)
      ..orderBy([
        (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
      ])
      ..limit(1);
    return q.getSingleOrNull();
  }

  Future<int> deleteStressInRange(DateTime from, DateTime to) => (delete(
    stressDetails,
  )..where((t) => t.date.isBetweenValues(from, to))).go();

  // ------------------------------
  // BloodOxygenDetails (SpO₂) CRUD / Query
  // ------------------------------
  Future<int> insertSpO2(BloodOxygenDetailsCompanion row) =>
      into(bloodOxygenDetails).insert(row);

  Future<List<BloodOxygenDetail>> fetchSpO2InRange(
    DateTime from,
    DateTime to,
  ) => (select(
    bloodOxygenDetails,
  )..where((t) => t.date.isBetweenValues(from, to))).get();

  Future<int> deleteSpO2InRange(DateTime from, DateTime to) => (delete(
    bloodOxygenDetails,
  )..where((t) => t.date.isBetweenValues(from, to))).go();

  // ------------------------------
  // SportDetails (걸음/거리/칼로리) CRUD / Query
  // ------------------------------
  Future<int> insertSport(SportDetailsCompanion row) =>
      into(sportDetails).insert(row, mode: InsertMode.insertOrIgnore);

  Future<List<SportDetail>> fetchSportByDay(DateTime dayStart) {
    final nextDay = DateTime(dayStart.year, dayStart.month, dayStart.day + 1);
    return (select(sportDetails)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(dayStart) &
                t.date.isSmallerThanValue(nextDay),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.timeIndex, mode: OrderingMode.asc),
          ]))
        .get();
  }

  Future<int> deleteSportByDay(DateTime dayStart) {
    final nextDay = DateTime(dayStart.year, dayStart.month, dayStart.day + 1);
    return (delete(sportDetails)..where(
          (t) =>
              t.date.isBiggerOrEqualValue(dayStart) &
              t.date.isSmallerThanValue(nextDay),
        ))
        .go();
  }

  /// 네이티브에서 받은 `syncSportDetail` 결과를 그대로 저장하는 유틸
  /// details 원소 예:
  /// {year, month, day, timeIndex, calorie, walkSteps, distance, runSteps}
  Future<void> saveSportDetailsFromNative(
    List<Map<String, dynamic>> details,
  ) async {
    if (details.isEmpty) return;

    int asInt(dynamic v, {int def = 0}) {
      if (v == null) return def;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? def;
      return def;
    }

    final y = asInt(details.first['year']);
    final m = asInt(details.first['month']);
    final d = asInt(details.first['day']);
    final dayStart = DateTime(y, m, d);

    // 당일 데이터 싹 지우고(중복 방지) 다시 넣음
    await deleteSportByDay(dayStart);

    await batch((b) {
      for (final e in details) {
        final ti = asInt(e['timeIndex']);
        final cal = asInt(e['calorie']);
        final walk = asInt(e['walkSteps']);
        final dist = asInt(e['distance']);
        final run = asInt(e['runSteps']);

        final slotTime = dayStart.add(Duration(minutes: ti * 15));

        b.insert(
          sportDetails,
          SportDetailsCompanion.insert(
            date: slotTime,
            timeIndex: ti,
            walkSteps: walk,
            runSteps: run,
            distance: dist,
            calorie: cal,
          ),
          // date+timeIndex UNIQUE일 때 덮어쓰기 원하면 InsertMode.insertOrReplace 사용
          // mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  // ------------------------------
  // RosarySessions CRUD / Query
  // ------------------------------
  Future<int> insertRosarySession(RosarySessionsCompanion row) =>
      into(rosarySessions).insert(row);

  Future<List<RosarySession>> fetchRosarySessions({
    DateTime? from,
    DateTime? to,
  }) {
    final q = select(rosarySessions);
    if (from != null && to != null) {
      q.where(
        (t) =>
            t.startAt.isBiggerOrEqualValue(from) &
            t.endAt.isSmallerThanValue(to),
      );
    }
    q.orderBy([(t) => OrderingTerm(expression: t.startAt)]);
    return q.get();
  }
}

// DB 파일 경로 설정
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}
