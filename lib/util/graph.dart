// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:drift/drift.dart' hide Column;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/date.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';
import 'package:picnique_rosary_healthcare_smartring/util/date.dart';

TextSpan renderTooltipLabel(double x, UnitX unitX, DateTime? monthBaseStart) {
  switch (unitX) {
    case UnitX.fiveMin:
    case UnitX.halfHour:
      final date = DateTime.fromMillisecondsSinceEpoch(
        x.toInt(),
        isUtc: true,
      ).toLocal();
      final mm = date.minute.toString().padLeft(2, '0');
      return TextSpan(
        text: '${date.hour}:$mm\n',
        style: TextStyle(
          color: AppColors.lightGray,
          fontSize: 12,
          fontWeight: AppFontWeight.medium,
        ),
      );
    case UnitX.hour:
      final date = DateTime.fromMillisecondsSinceEpoch(
        x.toInt(),
        isUtc: true,
      ).toLocal();
      return TextSpan(
        text: '${date.day}일 ${date.hour}시\n',
        style: TextStyle(
          color: AppColors.lightGray,
          fontSize: 12,
          fontWeight: AppFontWeight.medium,
        ),
      );
    case UnitX.day:
      final date = DateTime.fromMillisecondsSinceEpoch(
        x.toInt(),
        isUtc: true,
      ).toLocal();
      String weekday = getWeekday(date);
      return TextSpan(
        text: '${date.month}/${date.day} ($weekday)\n',
        style: TextStyle(
          color: AppColors.lightGray,
          fontSize: 12,
          fontWeight: AppFontWeight.medium,
        ),
      );
    case UnitX.month:
      final date = monthsFromBase(x.toInt(), monthBaseStart!);
      return TextSpan(
        text:
            '${(date.year % 100).toString().padLeft(2, '0')}년 ${date.month}월\n',
        style: TextStyle(
          color: AppColors.lightGray,
          fontSize: 12,
          fontWeight: AppFontWeight.medium,
        ),
      );
  }
}

TextSpan renderBarTooltipLabel(
  int index,
  ToggleRange range,
  DataType dataType,
) {
  final unitX = getUnitX(range, dataType);
  switch (unitX) {
    case UnitX.fiveMin:
    case UnitX.halfHour:
    case UnitX.hour:
      final date = DateTime(BASE_DATE.year, BASE_DATE.month, BASE_DATE.day);
      final labelDate = date.add(
        Duration(minutes: index * dataType.dayUnitMins),
      );
      return TextSpan(
        text:
            "${labelDate.hour.toString().padLeft(2, '0')}:${labelDate.minute.toString().padLeft(2, '0')}\n",
        style: TextStyle(
          color: AppColors.lightGray,
          fontSize: 12,
          fontWeight: AppFontWeight.medium,
        ),
      );
    case UnitX.month:
      final date = DateTime(BASE_DATE.year, BASE_DATE.month + index);
      return TextSpan(
        text: "${date.year % 100}년 ${date.month}월\n",
        style: TextStyle(
          color: AppColors.lightGray,
          fontSize: 12,
          fontWeight: AppFontWeight.medium,
        ),
      );

    case UnitX.day:
      final DateTime date = BASE_DATE.add(Duration(days: index));
      return TextSpan(
        text: "${date.month}/${date.day} (${weekdayKor[date.weekday - 1]})\n",
        style: TextStyle(
          color: AppColors.lightGray,
          fontSize: 12,
          fontWeight: AppFontWeight.medium,
        ),
      );
  }
}

SideTitleWidget renderXLabel(
  AxisSide axisSide,
  double labelStartX,
  double value,
  double windowX,
  UnitX unitX,
  DateTime? monthBaseStart,
) {
  switch (unitX) {
    case UnitX.fiveMin: // ✅ 추가
      final date = DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
        isUtc: true,
      ).toLocal();
      // intervalX가 12면 라벨은 매 정시(=60분)만 나오므로 'HH시'만 보여주면 깔끔
      final label = '${date.hour}시';
      return SideTitleWidget(
        axisSide: axisSide,
        space: 8.0,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
    case UnitX.halfHour:
    case UnitX.hour:
      DateTime date = DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
        isUtc: true,
      ).toLocal();
      String label = "${date.hour}시";
      return SideTitleWidget(
        axisSide: axisSide,
        space: 8.0,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
    case UnitX.day:
      final date = labelLocalFromTickMs(value.toInt());
      String label =
          (date.day == 1 ||
              value ==
                  labelStartX +
                      (windowX - 1) * Duration.millisecondsPerDay.toDouble())
          ? "${date.month}/${date.day}"
          : "${date.day}";

      return SideTitleWidget(
        axisSide: axisSide,
        space: 8.0,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
    case UnitX.month:
      final idx = value.toInt(); // x = 0..n-1
      final base = monthBaseStart ?? DateTime.utc(1970, 1, 1); // 안전장치
      // UTC 기준으로 생성 후 필요 시 toLocal()
      final dateUtc = monthsFromBase(
        idx,
        DateTime.utc(base.year, base.month, 1),
      );
      final date = dateUtc.toLocal();
      final label = "${date.month}";

      return SideTitleWidget(
        axisSide: axisSide,
        space: 8.0,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
  }
}

SideTitleWidget renderXLabelOfStackedBar(
  AxisSide axisSide,
  double labelStartX,
  double value,
  double windowX,
  UnitX unitX,
  DateTime? monthBaseStart,
) {
  switch (unitX) {
    case UnitX.fiveMin:
      final date = DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
        isUtc: true,
      ).toLocal();
      final label = '${date.hour}시';
      return SideTitleWidget(
        axisSide: axisSide,
        space: 8.0,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
    case UnitX.halfHour:
    case UnitX.hour:
      DateTime date = DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
        isUtc: true,
      ).toLocal();
      String label = "${date.hour}시";
      return SideTitleWidget(
        axisSide: axisSide,
        space: 8.0,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
    case UnitX.day:
      DateTime date = DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
        isUtc: true,
      ).toLocal();
      String label =
          (date.day == 1 ||
              value ==
                  labelStartX +
                      (windowX - 1.0) * Duration.millisecondsPerDay.toDouble())
          ? "${date.month}/${date.day}"
          : "${date.day}";
      return SideTitleWidget(
        axisSide: axisSide,
        space: 8.0,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
    case UnitX.month:
      final idx = value.toInt(); // x = 0..n-1
      final base = monthBaseStart ?? DateTime.utc(1970, 1, 1); // 안전장치
      // UTC 기준으로 생성 후 필요 시 toLocal()
      final dateUtc = monthsFromBase(
        idx,
        DateTime.utc(base.year, base.month, 1),
      );
      final date = dateUtc.toLocal();
      final label = "${date.month}";

      return SideTitleWidget(
        axisSide: axisSide,
        space: 8.0,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
  }
}

Widget Function(double, int) renderBottomTitle(
  ToggleRange range,
  DataType dataType,
) {
  if (range == ToggleRange.day && dataType == DataType.HeartRate) {
    return ((value, lastX) {
      final int offset = value.toInt();
      final date = DateTime(BASE_DATE.year, BASE_DATE.month, BASE_DATE.day);
      final labelDate = date.add(Duration(minutes: offset * 5));
      if (offset % 6 != 0) return const Text("");
      return Text(
        "${labelDate.hour.toString().padLeft(2, '0')}:${labelDate.minute.toString().padLeft(2, '0')}",
        style: const TextStyle(color: Colors.white, fontSize: 12),
      );
    });
  }

  var intervalX = range.intervalX;
  var unitX = getUnitX(range, dataType);
  var windowX = getWindowX(range, dataType);

  switch (unitX) {
    case UnitX.fiveMin:
    case UnitX.halfHour:
    case UnitX.hour:
      return ((value, lastX) {
        final int offset = value.toInt();
        final date = DateTime(BASE_DATE.year, BASE_DATE.month, BASE_DATE.day);
        final labelDate = date.add(
          Duration(minutes: offset * dataType.dayUnitMins),
        );
        // [ ]: stress 하드코딩
        if ((labelDate.minute != 0) || (offset % (windowX / 8) != 0)) {
          return Text("");
        }
        return Text(
          "${labelDate.hour.toString().padLeft(2, '0')} ",
          style: const TextStyle(color: Colors.white, fontSize: 12),
        );
      });

    case UnitX.day:
      return ((value, lastX) {
        final int offset = value.toInt();
        if (((offset - lastX) % intervalX) != 0) return Text("");
        final date = BASE_DATE.add(Duration(days: offset));
        if (date.day == 1 || offset == lastX) {
          return Column(
            children: [
              Text(
                "${date.month}/${date.day}",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          );
        }

        return Text(
          "${date.day}",
          style: const TextStyle(color: Colors.white, fontSize: 12),
        );
      });

    case UnitX.month:
      return ((value, lastX) {
        final int offset = value.toInt();
        if (((offset - lastX) % intervalX) != 0) return Text("");

        final date = DateTime(BASE_DATE.year, BASE_DATE.month + offset);
        if (date.month == 1) {
          return Column(
            children: [
              Text(
                "${date.month}",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                "${date.year}",
                style: const TextStyle(
                  color: AppColors.lightGray,
                  fontSize: 10,
                ),
              ),
            ],
          );
        }
        return Text(
          "${date.month}",
          style: const TextStyle(color: Colors.white, fontSize: 12),
        );
      });
  }
}

DateTime getDateTimeFromIndex(int index, ToggleRange range, DataType dataType) {
  switch (getUnitX(range, dataType)) {
    case UnitX.fiveMin:
    case UnitX.halfHour:
    case UnitX.hour:
      {
        final baseDate = DateTime(
          BASE_DATE.year,
          BASE_DATE.month,
          BASE_DATE.day,
        );
        final date = baseDate.add(
          Duration(minutes: index * dataType.dayUnitMins),
        );
        return date;
      }
    case UnitX.day:
      return BASE_DATE.add(Duration(days: index));
    case UnitX.month:
      return DateTime(BASE_DATE.year, BASE_DATE.month + index);
  }
}

Future<List<MapEntry<DateTime, int>>> _fetchRawRange({
  required DataType dataType,
  DateTime? start,
  DateTime? end,
}) async {
  final db = DbManager.I.heartDB;

  // 범위 where 절 공통 적용을 위해 헬퍼
  // Drift의 select(builder) 패턴이 타입마다 달라서 case별로 처리
  switch (dataType) {
    case DataType.HeartRate:
      {
        final q = db.select(db.heartDetails);
        if (start != null && end != null) {
          q.where((t) => t.date.isBetweenValues(start, end));
        }
        final rows = await q.get();
        return rows.map((r) => MapEntry(r.date, (r.bpm))).toList();
      }
    case DataType.Rosary:
      {
        final q = DbManager.I.appDB.select(DbManager.I.appDB.rosarySessions);
        if (start != null && end != null) {
          q.where((t) => t.startAt.isBetweenValues(start, end));
        }
        final rows = await q.get();
        return rows.map((r) => MapEntry(r.startAt, r.tapCount)).toList();
      }
    case DataType.Stress:
      {
        final q = db.select(db.stressDetails);
        if (start != null && end != null) {
          q.where((t) => t.date.isBetweenValues(start, end));
        }
        final rows = await q.get();
        return rows.map((r) => MapEntry(r.date, r.stress)).toList();
      }
    case DataType.Oxygen:
      {
        final q = db.select(db.bloodOxygenDetails);
        if (start != null && end != null) {
          q.where((t) => t.date.isBetweenValues(start, end));
        }
        final rows = await q.get();
        return rows.map((r) => MapEntry(r.date, r.spo2)).toList();
      }
    case DataType.Sleep:
      {
        // 주의: sleepDetails가 heartDB에 포함되어 있다고 가정합니다.
        // 만약 별도 DB라면 DbManager.I.sleepDB로 바꿔주세요.
        final q = db.select(db.sleepDetails);
        if (start != null && end != null) {
          q.where((t) => t.date.isBetweenValues(start, end));
        }
        final rows = await q.get();

        // 날짜(로컬 00:00 기준)별 총 수면 분을 누적
        final Map<DateTime, int> totalSleepMinByDay = {};
        for (final r in rows) {
          // r.date: 해당 세그먼트가 속한 '날짜'(로컬 00:00), DB 설계상 이미 start의 로컬 날짜로 저장되어 있다고 가정
          final dayKey = DateTime(r.date.year, r.date.month, r.date.day);

          // 세그먼트 길이(분)
          final segMin = r.end.difference(r.start).inMinutes;
          if (segMin <= 0) continue;

          // 타입: 2=Light, 3=Deep, 4=Rem, 5=Awake
          // 총 수면 시간에는 Awake(5)는 제외합니다.
          final addMin = (r.type == 2 || r.type == 3 || r.type == 4)
              ? segMin
              : 0;

          if (addMin > 0) {
            totalSleepMinByDay.update(
              dayKey,
              (prev) => prev + addMin,
              ifAbsent: () => addMin,
            );
          } else {
            totalSleepMinByDay.putIfAbsent(
              dayKey,
              () => totalSleepMinByDay[dayKey] ?? 0,
            );
          }
        }

        // 그래프 공통 파이프라인(MapEntry<DateTime,int>)에 맞춰 반환
        return totalSleepMinByDay.entries.toList();
      }
    // [ ]: 백엔드 로직 확인 필요
    case DataType.Kcal:
    case DataType.Steps:
    case DataType.Distance:
      {
        final q = db.select(db.sportDetails);
        if (start != null && end != null) {
          q.where((t) => t.date.isBetweenValues(start, end));
        }
        final rows = await q.get();

        // 시간(h) 단위 누적 버킷 (원래 단위로 누적)
        final Map<DateTime, int> hourlyAccRaw = {};

        // 시간 단위로 버킷팅하는 헬퍼 함수
        DateTime hour0(DateTime d) => DateTime(d.year, d.month, d.day, d.hour);

        for (final r in rows) {
          final hourKey = hour0(r.date); // 로컬 시각 기준 시간 바닥

          switch (dataType) {
            case DataType.Kcal:
              // calorie를 원래 단위(cal)로 누적
              hourlyAccRaw[hourKey] = (hourlyAccRaw[hourKey] ?? 0) + r.calorie;
              break;
            case DataType.Steps:
              // walkSteps + runSteps
              hourlyAccRaw[hourKey] =
                  (hourlyAccRaw[hourKey] ?? 0) + (r.walkSteps + r.runSteps);
              break;
            case DataType.Distance:
              // distance를 원래 단위(m)로 누적
              hourlyAccRaw[hourKey] = (hourlyAccRaw[hourKey] ?? 0) + r.distance;
              break;
            default:
              break;
          }
        }

        // 변환된 값으로 MapEntry 생성
        final result = <MapEntry<DateTime, int>>[];
        for (final entry in hourlyAccRaw.entries) {
          int value;
          switch (dataType) {
            case DataType.Kcal:
              // calorie를 kcal로 변환 (1000으로 나눔, 정수로 반올림)
              value = (entry.value / 1000).round();
              break;
            case DataType.Steps:
              // 그대로 사용
              value = entry.value;
              break;
            case DataType.Distance:
              // distance를 km로 변환 (1000으로 나눔, 정수로 반올림)
              value = (entry.value).round();
              break;
            default:
              value = 0;
              break;
          }
          result.add(MapEntry(entry.key, value));
        }

        // 그래프 공통 파이프라인(MapEntry<DateTime,int>)에 맞춰 반환
        return result;
      }
  }
}

// 바 그래프
const BAR_COLOR = AppColors.purple;
final BORDER_RADIUS = BorderRadius.circular(4);

BarChartRodData _createRod({
  required double value,
  required double width,
  required Color color,
}) {
  return BarChartRodData(
    toY: value,
    width: width,
    color: color,
    borderRadius: BORDER_RADIUS,
  );
}

Future<List<BarChartGroupData>> fetchDayBarGroups({
  required DataType dataType,
  required DateTime anchor,
  required ToggleRange selectedRange,
  required int baseStartHour,
  required int baseStartMinute,
  int? baseEndHour,
  int? baseEndMinute,
  Color? color,
}) async {
  final barWidth = getBarWidth(selectedRange, dataType);
  final start = DateTime(
    anchor.year,
    anchor.month,
    anchor.day,
    baseStartHour,
    baseStartMinute,
  );
  final end = (baseEndHour != null && baseEndMinute != null)
      ? DateTime(
          anchor.year,
          anchor.month,
          anchor.day,
          baseEndHour,
          baseEndMinute,
        )
      : start.add(const Duration(days: 1));

  final dataPairs = await _fetchRawRange(
    dataType: dataType,
    start: start,
    end: end,
  );
  dataPairs.sort((a, b) => a.key.compareTo(b.key));

  final rodsByIndex = <int, List<BarChartRodData>>{};

  for (final entry in dataPairs) {
    final value = entry.value;
    if (value <= 0) continue;

    final dateTime = entry.key;
    if (dateTime.isBefore(start) || !dateTime.isBefore(end)) {
      continue;
    }

    final diffMinutes = dateTime.difference(start).inMinutes;
    final slotIndex = diffMinutes ~/ dataType.dayUnitMins;

    final rod = _createRod(
      value: value.toDouble(),
      width: barWidth,
      color: color ?? BAR_COLOR,
    );
    rodsByIndex.putIfAbsent(slotIndex, () => <BarChartRodData>[]).add(rod);
  }

  final totalMinutes = end.difference(start).inMinutes;
  final slotCount = totalMinutes ~/ dataType.dayUnitMins;

  final groups = <BarChartGroupData>[];
  for (int slotIndex = 0; slotIndex < slotCount; slotIndex++) {
    final rods = rodsByIndex[slotIndex] ?? <BarChartRodData>[];

    final finalRods = rods.isEmpty
        ? [_createRod(value: 0, width: barWidth, color: color ?? BAR_COLOR)]
        : rods;

    groups.add(BarChartGroupData(x: slotIndex, barRods: finalRods));
  }

  return groups;
}

Future<List<BarChartGroupData>> fetchDailyBarGroups({
  required DataType dataType,
  required DateTime endDate,
  required ToggleRange selectedRange,
}) async {
  DateTime startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  final days = 3 * getWindowX(selectedRange, dataType);
  final width = getBarWidth(selectedRange, dataType);

  final todayStart = startOfDay(endDate);
  final start = todayStart.subtract(Duration(days: days - 1));
  final end = todayStart.add(const Duration(days: 1));

  final dataPairs = await _fetchRawRange(
    dataType: dataType,
    start: start,
    end: end,
  );

  final valuesByDay = <DateTime, List<int>>{};
  for (final entry in dataPairs) {
    final value = entry.value;
    if (value <= 0) continue;

    final dayKey = startOfDay(entry.key);
    valuesByDay.putIfAbsent(dayKey, () => []).add(value);
  }

  final groups = <BarChartGroupData>[];
  for (int dayIndex = 0; dayIndex < days; dayIndex++) {
    final currentDay = start.add(Duration(days: dayIndex));
    final dayKey = startOfDay(currentDay);
    final diffDays = dayKey.difference(BASE_DATE).inDays;

    final dayValues = valuesByDay[dayKey];
    final barRods = dayValues != null
        ? [
            _createRod(
              value: dayValues.reduce((a, b) => a + b) / dayValues.length,
              width: width,
              color: BAR_COLOR,
            ),
          ]
        : <BarChartRodData>[];

    groups.add(BarChartGroupData(x: diffDays, barRods: barRods));
  }

  return groups;
}

Future<List<BarChartGroupData>> fetchMonthlyBarGroups({
  required DataType dataType,
  required ToggleRange selectedRange,
  required DateTime endDate,
}) async {
  final months = 3 * getWindowX(selectedRange, dataType);
  final width = getBarWidth(selectedRange, dataType);

  int monthDiff(DateTime a, DateTime b) =>
      (a.year - b.year) * 12 + (a.month - b.month);

  String monthKey0(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  final latestMonthStart = DateTime(endDate.year, endDate.month);
  final oldestMonthStart = DateTime(
    latestMonthStart.year,
    latestMonthStart.month - (months - 1),
  );
  final end = DateTime(latestMonthStart.year, latestMonthStart.month + 1);
  final dataPairs = await _fetchRawRange(
    start: oldestMonthStart,
    end: end,
    dataType: dataType,
  );

  final orderedMonthKeys = <String>[];
  for (int monthIndex = 0; monthIndex < months; monthIndex++) {
    final monthStart = DateTime(
      oldestMonthStart.year,
      oldestMonthStart.month + monthIndex,
    );
    orderedMonthKeys.add(monthKey0(monthStart));
  }

  final valuesByMonth = <String, List<int>>{};
  for (final entry in dataPairs) {
    final value = entry.value;
    if (value <= 0) continue;

    final monthKey = monthKey0(DateTime(entry.key.year, entry.key.month));
    if (!orderedMonthKeys.contains(monthKey)) continue;

    valuesByMonth.putIfAbsent(monthKey, () => []).add(value);
  }

  final groups = <BarChartGroupData>[];
  for (int monthIndex = 0; monthIndex < orderedMonthKeys.length; monthIndex++) {
    final monthKey = orderedMonthKeys[monthIndex];
    final monthValues = valuesByMonth[monthKey] ?? const [];

    final monthStartDate = DateTime(
      oldestMonthStart.year,
      oldestMonthStart.month + monthIndex,
    );
    final diffMonths = monthDiff(monthStartDate, BASE_DATE);

    final barRods = monthValues.isNotEmpty
        ? [
            _createRod(
              value: monthValues.reduce((a, b) => a + b) / monthValues.length,
              width: width,
              color: BAR_COLOR,
            ),
          ]
        : <BarChartRodData>[];

    groups.add(BarChartGroupData(x: diffMonths, barRods: barRods));
  }

  return groups;
}

// 공통...
List<BarChartGroupData> mergeAndSortByX(
  List<BarChartGroupData> older,
  List<BarChartGroupData> current,
) {
  final map = <int, BarChartGroupData>{};

  for (final g in older) {
    map[g.x] = g;
  }
  for (final g in current) {
    map[g.x] = g;
  }

  final xs = map.keys.toList()..sort();
  return [for (final x in xs) map[x]!];
}

int getWindowX(ToggleRange range, DataType dataType) {
  switch (range) {
    case ToggleRange.day:
      switch (dataType) {
        case DataType.Rosary:
        case DataType.Stress:
          return 48;
        case DataType.HeartRate:
        case DataType.Oxygen:
        case DataType.Sleep:
        case DataType.Kcal:
        case DataType.Distance:
        case DataType.Steps:
          return 24;
      }

    case ToggleRange.week:
      return 7;

    case ToggleRange.month:
      return 31;

    case ToggleRange.halfYear:
      return 3;
  }
}

double getBarWidth(ToggleRange range, DataType dataType) {
  switch (range) {
    case ToggleRange.day:
      switch (dataType) {
        case DataType.Rosary:
        case DataType.Stress:
          return 6;
        case DataType.HeartRate:
        case DataType.Oxygen:
        case DataType.Sleep:
          return 6;
        case DataType.Kcal:
        case DataType.Distance:
        case DataType.Steps:
          return 14;
      }

    case ToggleRange.week:
      return 14;

    case ToggleRange.month:
      return 6;

    case ToggleRange.halfYear:
      return 16;
  }
}

UnitX getUnitX(ToggleRange range, DataType dataType) {
  switch (range) {
    case ToggleRange.day:
      switch (dataType) {
        case DataType.HeartRate:
          return UnitX.fiveMin;
        case DataType.Oxygen:
        case DataType.Sleep:
        case DataType.Kcal:
        case DataType.Distance:
        case DataType.Steps:
          return UnitX.hour;
        case DataType.Rosary:
        case DataType.Stress:
          return UnitX.halfHour;
      }

    case ToggleRange.week:
      return UnitX.day;

    case ToggleRange.month:
      return UnitX.day;

    case ToggleRange.halfYear:
      return UnitX.month;
  }
}

String getWindowXLabel(
  DateTime start,
  int index,
  ToggleRange range,
  DataType dataType,
) {
  String fmtYMD(DateTime d) =>
      "${d.year.toString().substring(2)}년 ${d.month.toString().padLeft(2, '0')}월 ${d.day.toString().padLeft(2, '0')}일";
  String fmtYM(DateTime d) =>
      "${d.year.toString().substring(2)}년 ${d.month.toString().padLeft(2, '0')}월";
  String fmtMD(DateTime d) =>
      "${d.month.toString().padLeft(2, '0')}월 ${d.day.toString().padLeft(2, '0')}일";

  late DateTime end;

  switch (range) {
    case ToggleRange.day:
      // 1일 뷰: 해당 날짜만 표시
      return fmtMD(start);
    case ToggleRange.week:
    case ToggleRange.month:
      end = start.add(Duration(days: index));
      break;
    case ToggleRange.halfYear:
      end = DateTime(start.year, start.month + index);
      break;
  }

  switch (range) {
    case ToggleRange.day:
      return fmtMD(start);
    case ToggleRange.week:
    case ToggleRange.month:
      return "${fmtYMD(start)} ~ ${fmtYMD(end)}";
    case ToggleRange.halfYear:
      return "${fmtYM(start)} ~ ${fmtYM(end)}";
  }
}
