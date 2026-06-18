import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/models/sleep.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/sleep.dart';

SleepType getRandomSleepType(Random random) {
  int index = random.nextInt(SleepType.values.length);
  return SleepType.values[index];
}

List<SleepMonthData> generateMockSleepDataMonthly(int days) {
  List<SleepMonthData> allSleepData = [];
  DateTime startMockDate = DateTime(2025, 7, 18);
  Random random = Random();

  for (int i = 0; i < days; i++) {
    DateTime date = startMockDate.add(Duration(days: 2 * i));

    DateTime current = DateTime(date.year, date.month, date.day, 0, 0, 0);

    int stageCount = 3;

    List<SleepStage> stages = [];

    for (int j = 0; j < stageCount; j++) {
      int durationMinutes = 30 + random.nextInt(150);
      DateTime end = current.add(Duration(minutes: durationMinutes));

      if (end.day != current.day) {
        end = DateTime(date.year, date.month, date.day, 23, 59, 59);
      }

      stages.add(
        SleepStage(
          startTime: current,
          endTime: end,
          sleepType: getRandomSleepType(random),
        ),
      );

      current = end;

      if (j == stageCount - 1 || current.hour == 23) {
        break;
      }
    }

    allSleepData.add(SleepMonthData(date: i, sleep: stages));
  }

  return allSleepData;
}

List<SleepMonthData> generateEmptySleepDataMonthly(int days) {
  final now = DateTime.now();

  final target = DateTime(2025, 7, 1);
  final start = DateTime(now.year, now.month, 1);

  final todayIndex =
      (start.year - target.year) * 12 + (start.month - target.month);

  List<SleepMonthData> allSleepData = [];

  for (int i = 0; i < days; i++) {
    allSleepData.add(
      SleepMonthData(date: todayIndex - (days - i - 1), sleep: []),
    );
  }

  return allSleepData;
}

List<SleepData> generateMockSleepDataDaily(int days) {
  List<SleepData> allSleepData = [];
  DateTime startMockDate = DateTime(2025, 7, 18);
  Random random = Random();

  for (int i = 0; i < days; i++) {
    DateTime date = startMockDate.add(Duration(days: 2 * i));

    List<SleepStage> stages = [];

    int startHour = 22 + random.nextInt(2);
    DateTime current = DateTime(
      date.year,
      date.month,
      date.day,
      18,
    ).add(Duration(hours: startHour - 18));

    int stageCount = 2 + random.nextInt(3);

    for (int j = 0; j < stageCount; j++) {
      int duration = 30 * random.nextInt(6);
      DateTime end = current.add(Duration(minutes: duration));

      stages.add(
        SleepStage(
          startTime: current,
          endTime: end,
          sleepType: getRandomSleepType(random),
        ),
      );

      current = end;

      if (random.nextBool() && j != stageCount - 1) {
        current = current.add(Duration(minutes: 60 * random.nextInt(1)));
      }
    }

    allSleepData.add(SleepData(date: date, sleep: stages));
  }

  return allSleepData;
}

// SleepType별 색상 매핑
Color sleepColor(SleepType type) {
  switch (type) {
    case SleepType.awake:
      return AppColors.lightGray;
    case SleepType.shallow:
      return AppColors.lightPurple;
    case SleepType.rem:
      return AppColors.purple;
    case SleepType.deep:
      return AppColors.darkPurple;
  }
}

double toSleepTimeY(DateTime date) {
  final base = DateTime(date.year, date.month, date.day, 18, 0, 0);

  DateTime adjustedBase = date.isBefore(base)
      ? base.subtract(const Duration(days: 1))
      : base;

  return -date.difference(adjustedBase).inMilliseconds.toDouble();
}

double toSleepTimeYMonth(DateTime date) {
  final base = DateTime(date.year, date.month, date.day, 0, 0, 0);
  return date.difference(base).inMilliseconds.toDouble();
}

List<BarChartGroupData> convertToDailyChartData(
  List<SleepData> dataList,
  double width,
) {
  final groups = <BarChartGroupData>[];

  for (final day in dataList) {
    final yStart = toSleepTimeY(day.sleep.first.startTime);
    final yEnd = toSleepTimeY(day.sleep.last.endTime);
    final rodFrom = min(yStart, yEnd);
    final rodTo = max(yStart, yEnd);

    final stacks = day.sleep.map((stage) {
      final a = toSleepTimeY(stage.startTime);
      final b = toSleepTimeY(stage.endTime);
      final from = min(a, b);
      final to = max(a, b);
      return (from: from, to: to, color: sleepColor(stage.sleepType));
    }).toList()..sort((x, y) => x.from.compareTo(y.from));
    groups.add(
      BarChartGroupData(
        x: day.date.millisecondsSinceEpoch,
        barRods: [
          BarChartRodData(
            fromY: rodFrom,
            toY: rodTo,
            rodStackItems: [
              for (final s in stacks)
                BarChartRodStackItem(s.from, s.to, s.color),
            ],
            width: width,
            borderRadius: BorderRadius.circular(4),
            color: Colors.transparent,
          ),
        ],
      ),
    );
  }
  return groups;
}

List<BarChartGroupData> convertToMonthlyChartData(
  List<SleepMonthData> dataList,
  double width,
) {
  final groups = <BarChartGroupData>[];

  for (final day in dataList) {
    if (day.sleep.isEmpty) {
      groups.add(BarChartGroupData(x: day.date, barRods: [
      ],
    ));
      continue;
    }

    final yStart = toSleepTimeYMonth(day.sleep.first.startTime);
    final yEnd = toSleepTimeYMonth(day.sleep.last.endTime);
    final rodFrom = min(yStart, yEnd);
    final rodTo = max(yStart, yEnd);

    final stacks = day.sleep.map((stage) {
      final a = toSleepTimeYMonth(stage.startTime);
      final b = toSleepTimeYMonth(stage.endTime);
      final from = min(a, b);
      final to = max(a, b);
      return (from: from, to: to, color: sleepColor(stage.sleepType));
    }).toList()..sort((x, y) => x.from.compareTo(y.from));

    groups.add(
      BarChartGroupData(
        x: day.date,
        barRods: [
          BarChartRodData(
            fromY: rodFrom,
            toY: rodTo,
            rodStackItems: [
              for (final s in stacks)
                BarChartRodStackItem(s.from, s.to, s.color),
            ],
            width: width,
            borderRadius: BorderRadius.circular(4),
            color: Colors.transparent,
          ),
        ],
      ),
    );
  }

  return groups;
}
