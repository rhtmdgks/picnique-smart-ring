// ignore_for_file: recursive_getters

part of 'app_db.dart';

class SleepDetails extends Table {
  // 상세 구간 ID
  IntColumn get id => integer().autoIncrement()();

  // 해당 구간이 속한 날짜(필요 시)
  DateTimeColumn get date => dateTime()();

  // 수면 구간 시작/끝
  DateTimeColumn get start => dateTime().named('start')();
  DateTimeColumn get end => dateTime().named('end')();

  // 타입: 3=deep, 2=light, 5=awake, 4=rem
  IntColumn get type =>
      integer().named('type').check(type.isIn([2, 3, 4, 5]))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {date, start, end, type}, // 🔒 유니크 보장
  ];
}

class HeartDetails extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get date => dateTime()();

  IntColumn get bpm => integer().named("bpm")();
}

class StressDetails extends Table {
  IntColumn get id => integer().autoIncrement()(); // PK

  // 기록 시각 (로컬 DateTime)
  DateTimeColumn get date => dateTime()();

  // 스트레스 값 (예: 0~100 권장, 필요시 체크 추가 가능)
  IntColumn get stress => integer().named('stress')();
}

// ── 산소포화도: id / date / spo2 ─────────────────────────
class BloodOxygenDetails extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()(); // 측정 시각
  IntColumn get spo2 =>
      integer().named('spo2') // 0~100 권장
      // .check(spo2.isBetweenValues(0, 100))        // 필요시 활성화
      ();
}

// ── 스포츠(걸음/뛰기/거리/칼로리) 15분 단위: id / date / timeIndex / walkSteps / runSteps / distance / calorie
//   - timeIndex: 0..95 (15분 슬롯)
//   - date: 슬롯의 실제 시각(= dayStart + timeIndex*15분)
class SportDetails extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()(); // 해당 15분 슬롯 시작 시각 (로컬)
  IntColumn get timeIndex =>
      integer().named('time_index') // 0..95
      // .check(timeIndex.isBetweenValues(0, 95))     // 필요시 활성화
      ();

  IntColumn get walkSteps => integer().named('walk_steps')(); // 보행 걸음수
  IntColumn get runSteps => integer().named('run_steps')(); // 달리기 걸음수
  IntColumn get distance => integer().named('distance')(); // (m)로 가정
  IntColumn get calorie => integer().named('calorie')(); // (cal)로 가정

  // 같은 date(시각) 중복 입력 방지를 위해 유니크 키 권장
  @override
  List<Set<Column>> get uniqueKeys => [
    {date, timeIndex},
  ];
}

class RosarySessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startAt => dateTime()(); // 기록 시작 시각
  DateTimeColumn get endAt => dateTime()(); // 기록 종료 시각
  IntColumn get tapCount => integer()(); // 세션 동안 감지된 터치 개수
  BoolColumn get wydDedicated =>
      boolean().withDefault(const Constant(false))(); // WYD 봉헌 여부
}
