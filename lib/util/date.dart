import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';

String getWeekday(DateTime date) {
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  return days[date.weekday - 1];
}

// datetime 타입을 utc로 통일
List<FlSpot> convertToUTC(List<FlSpot> dateData) {
  return dateData.map((spot) {
    final localDate = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());

    final utcDate = DateTime.utc(
      localDate.year,
      localDate.month,
      localDate.day,
      localDate.hour,
      localDate.minute,
      localDate.second,
      localDate.millisecond,
      localDate.microsecond,
    );

    return FlSpot(utcDate.millisecondsSinceEpoch.toDouble(), spot.y);
  }).toList();
}

// DateTime monthsFromBase(int monthsOffset) {
//   // Base는 2025년 7월로 임의 설정 (UTC)
//   DateTime baseDate = DateTime.utc(2025, 7, 1);

//   int newYear = baseDate.year + ((baseDate.month - 1 + monthsOffset) ~/ 12);
//   int newMonth = ((baseDate.month - 1 + monthsOffset) % 12) + 1;

//   return DateTime.utc(newYear, newMonth, 1);
// }

DateTime monthsFromBase(int monthsOffset, DateTime baseMonthStartUtc) {
  // baseMonthStartUtc는 반드시 해당 달의 1일 00:00 (UTC or local 상관X) 이어야 함
  // Dart DateTime은 month에 +offset을 넣으면 자동으로 overflow를 처리함
  // (예: 2025-07 + 6 → 2026-01)
  return DateTime.utc(
    baseMonthStartUtc.year,
    baseMonthStartUtc.month + monthsOffset,
    1,
  );
}

final Random random = Random();

// mock data 생성 함수
List<FlSpot> generateMockDataHourly(int hours, int min, int gap) {
  List<FlSpot> allHourData = [];
  DateTime startMockDate = DateTime.utc(2025, 7, 18);
  Random random = Random();

  for (int i = 0; i < hours; i++) {
    DateTime date = startMockDate.add(Duration(hours: i));
    double x = date.millisecondsSinceEpoch.toDouble();
    double y = min + random.nextDouble() * gap;
    allHourData.add(FlSpot(x, y));
  }

  return allHourData;
}

List<FlSpot> generateMockDataDaily(int days, int min, int gap) {
  List<FlSpot> allDateData = [];
  DateTime startMockDate = DateTime.utc(2025, 7, 18);

  for (int i = 0; i < days; i++) {
    DateTime date = startMockDate.add(Duration(days: i));
    double x = date.millisecondsSinceEpoch.toDouble();
    double y = min + random.nextDouble() * gap;
    allDateData.add(FlSpot(x, y));
  }

  return allDateData;
}

List<FlSpot> generateMockDataMonthly(int months, int min, int gap) {
  List<FlSpot> allMonthData = [];
  Random random = Random();

  for (int i = 0; i < months; i++) {
    double x = i.toDouble();
    double y = min + random.nextDouble() * gap;
    allMonthData.add(FlSpot(x, y));
  }
  return allMonthData;
}

int tzMsAt(int msUtc) => DateTime.fromMillisecondsSinceEpoch(
  msUtc,
  isUtc: true,
).toLocal().timeZoneOffset.inMilliseconds;

int alignLocalBucketMs(int msUtc, UnitX unit) {
  final d = DateTime.fromMillisecondsSinceEpoch(msUtc, isUtc: true).toLocal();
  switch (unit) {
    case UnitX.fiveMin:
      final m5 = (d.minute ~/ 5) * 5;
      return DateTime(
        d.year,
        d.month,
        d.day,
        d.hour,
        m5,
      ).millisecondsSinceEpoch;
    case UnitX.halfHour:
    case UnitX.hour:
      return DateTime(d.year, d.month, d.day, d.hour).millisecondsSinceEpoch;
    case UnitX.day:
      return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
    case UnitX.month:
      // 필요 시 월 바닥 구현
      return DateTime(d.year, d.month, 1).millisecondsSinceEpoch;
  }
}

DateTime labelLocalFromTickMs(int msUtc) {
  final shifted = msUtc - tzMsAt(msUtc);
  return DateTime.fromMillisecondsSinceEpoch(shifted, isUtc: true).toLocal();
}

bool isLocalTick({
  required double value,
  required double labelStartX,
  required double unitXDouble,
  required double intervalX,
  required double windowX,
}) {
  final int v = value.round();
  final int s = labelStartX.round();
  final int step = (intervalX * unitXDouble).round();

  // UTC→로컬 앵커로 이동 (DST 안전: 각 시점의 오프셋 개별 적용)
  final int vAdj = v + tzMsAt(v);
  final int sAdj = s + tzMsAt(s);

  final int diff = vAdj - sAdj;
  final int endAdj = sAdj + ((windowX - 1) * unitXDouble).round();

  // 작은 경계 오차 허용 (1~2ms 정도)
  bool approxMultiple(int a, int m, [int tol = 2]) {
    final r = a % m;
    return r == 0 || r <= tol || r >= m - tol;
  }

  return approxMultiple(diff, step) || ((diff - (endAdj - sAdj)).abs() <= 2);
}
