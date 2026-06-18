import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';
import 'package:picnique_rosary_healthcare_smartring/util/date.dart';
import 'package:picnique_rosary_healthcare_smartring/util/graph.dart';
import 'package:picnique_rosary_healthcare_smartring/util/sleep.dart';

String formatTotalHourMin(double sleepStartY, double sleepEndY) {
  final startTime = DateTime.fromMillisecondsSinceEpoch(
    sleepStartY.toInt(),
    isUtc: true,
  );
  final endTime = DateTime.fromMillisecondsSinceEpoch(
    sleepEndY.toInt(),
    isUtc: true,
  );

  // 차이는 절대값으로
  final Duration difference = endTime.difference(startTime).abs();

  final int totalHours = difference.inHours;
  final int remainingMinutes = difference.inMinutes % 60;

  return '평균 $totalHours시간 $remainingMinutes분';
}

String formatSleepHour(double value) {
  return "${(value / Duration.millisecondsPerHour).toInt()}h";
}

String formatDiffToHour(double value, minYLabel) {
  // ✅ 로컬 기준 18:00
  final baseTime = DateTime(1970, 1, 1, 18, 0, 0);

  final displayMinTime = baseTime.subtract(
    Duration(milliseconds: (minYLabel).toInt()),
  );

  final displayTime = displayMinTime.subtract(
    Duration(milliseconds: ((value - minYLabel).toInt())),
  );

  final hour = displayTime.hour.toString().padLeft(2, '0');
  return '$hour시';
}

String formatDiffToHourMinute(double value, DateTime date) {
  // ✅ 로컬 기준 day의 18:00
  final baseTime = DateTime(date.year, date.month, date.day, 18, 0, 0);

  final displayTime = baseTime.subtract(
    Duration(milliseconds: (value.toInt())),
  );

  final hour = displayTime.hour.toString().padLeft(2, '0');
  final minute = displayTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class StackedBarGraph extends StatefulWidget {
  final UnitX unitX;
  final double windowX, intervalX;
  final double? limitedMinY, limitedMaxY;
  final double Function(double, double) intervalYFunc;
  final List<BarChartGroupData> data;
  final DateTime? monthBaseStart;

  const StackedBarGraph({
    super.key,
    required this.unitX,
    required this.windowX,
    required this.intervalX,
    required this.intervalYFunc,
    required this.data,
    this.limitedMinY,
    this.limitedMaxY,
    this.monthBaseStart,
  });

  @override
  State<StackedBarGraph> createState() => _StackedBarGraphState();
}

class _StackedBarGraphState extends State<StackedBarGraph> {
  late double minX;
  late double maxX;

  late double minYLabel;
  late double maxYLabel;

  late double intervalY;

  late double labelStartX;
  late final double unitXDouble;

  late double firstX;
  late double lastX;
  late double windowXDataSize;

  late final List<BarChartGroupData> allData;

  @override
  void initState() {
    super.initState();

    unitXDouble = switch (widget.unitX) {
      UnitX.fiveMin => (Duration.millisecondsPerMinute * 5).toDouble(),
      UnitX.halfHour => Duration.millisecondsPerHour.toDouble(),
      UnitX.hour => Duration.millisecondsPerHour.toDouble(),
      UnitX.day => Duration.millisecondsPerDay.toDouble(),
      UnitX.month => 1.0,
    };

    if (widget.data.isEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      switch (widget.unitX) {
        case UnitX.fiveMin:
        case UnitX.halfHour:
        case UnitX.hour:
        case UnitX.day:
          final todayLocal = DateTime(now.year, now.month, now.day);
          final todayUtcMidnight = DateTime.utc(
            todayLocal.year,
            todayLocal.month,
            todayLocal.day,
          );
          final todayMillis = todayUtcMidnight.millisecondsSinceEpoch
              .toDouble();

          DateTime min, max;
          labelStartX =
              todayMillis - widget.windowX * unitXDouble + unitXDouble;
          minX = labelStartX;
          maxX = (labelStartX + widget.windowX * unitXDouble - unitXDouble)
              .toDouble();

          List<BarChartGroupData> paddedData = [];

          final int paddingCount = (widget.windowX).toInt();
          final double firstDataX = labelStartX.toDouble();

          for (int i = paddingCount; i > 0; i--) {
            final double placeholderX = firstDataX - (i * unitXDouble);
            paddedData.add(
              BarChartGroupData(x: placeholderX.toInt(), barRods: []),
            );
          }

          allData = paddedData;

          min = DateTime(today.year, today.month, today.day, 22, 0, 0);
          max = DateTime(today.year, today.month, today.day + 1, 6, 0, 0);
          minYLabel = toSleepTimeY(max);
          maxYLabel = toSleepTimeY(min);
        case UnitX.month:
          final tmpEmptyData = generateEmptySleepDataMonthly(7);
          allData = convertToMonthlyChartData(tmpEmptyData, 8);

          windowXDataSize = (widget.windowX - 1) * unitXDouble;

          labelStartX = allData.last.x - (widget.windowX - 1) * unitXDouble;

          firstX = allData.first.x.toDouble();
          lastX = allData.last.x.toDouble();

          maxX = lastX;

          minX = maxX - windowXDataSize;

          final min = DateTime(today.year, today.month, today.day, 10, 0, 0);
          final max = DateTime(today.year, today.month, today.day + 1, 0, 0, 0);

          minYLabel = toSleepTimeYMonth(max);
          maxYLabel = toSleepTimeYMonth(min);
      }

      intervalY = Duration.millisecondsPerHour.toDouble() * 2;
    } else {
      List<BarChartGroupData> originalData = widget.data;
      List<BarChartGroupData> paddedData = [];

      if (originalData.length < widget.windowX) {
        final int paddingCount = (widget.windowX - originalData.length).toInt();
        final double firstDataX = originalData.first.x.toDouble();

        for (int i = paddingCount; i > 0; i--) {
          final double placeholderX = firstDataX - (i * unitXDouble);
          paddedData.add(
            BarChartGroupData(x: placeholderX.toInt(), barRods: []),
          );
        }
        allData = [...paddedData, ...originalData];
      } else {
        allData = originalData;
      }

      if (allData.isEmpty) return;

      windowXDataSize = (widget.windowX - 1) * unitXDouble;

      labelStartX = allData.last.x - (widget.windowX - 1) * unitXDouble;

      firstX = allData.first.x.toDouble();
      lastX = allData.last.x.toDouble();

      maxX = lastX;

      minX = maxX - windowXDataSize;

      _updateYAxis();
    }
  }

  void _updateYAxis() {
    final visibleData = allData.where(
      (spot) => spot.x >= minX && spot.x <= maxX,
    );

    if (visibleData.isEmpty) {
      final today = DateTime.now();

      // ✅ 먼저 intervalY 설정
      intervalY = Duration.millisecondsPerHour.toDouble() * 2;

      // ✅ 로컬 기준 22:00 ~ (다음날) 06:00
      final min = DateTime(today.year, today.month, today.day, 22, 0, 0);
      final max = DateTime(today.year, today.month, today.day + 1, 6, 0, 0);

      minYLabel = toSleepTimeY(max);
      maxYLabel = toSleepTimeY(min);

      if (widget.limitedMinY == null) minYLabel -= intervalY;
      if (widget.limitedMaxY == null) maxYLabel += intervalY;
      return;
    }

    // (이하 기존 동일)
    double localMinY = visibleData
        .expand((group) => group.barRods)
        .map((rod) => rod.fromY)
        .reduce(min);

    double localMaxY = visibleData
        .expand((group) => group.barRods)
        .map((rod) => rod.toY)
        .reduce(max);

    intervalY = widget.intervalYFunc(localMinY, localMaxY);
    if (intervalY <= 0) {
      intervalY = (localMaxY - localMinY).abs() / 5;
      if (intervalY <= 0) intervalY = 1;
    }

    minYLabel =
        widget.limitedMinY ??
        (localMinY / intervalY).floorToDouble() * intervalY;
    maxYLabel =
        widget.limitedMaxY ??
        (localMaxY / intervalY).ceilToDouble() * intervalY;

    if (widget.limitedMinY == null) minYLabel -= intervalY;
    if (widget.limitedMaxY == null) maxYLabel += intervalY;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tmpVisibleData = allData.where((group) {
          return group.x >= minX && group.x <= maxX;
        }).toList();

        final existingDates = tmpVisibleData.map((group) {
          final dt = DateTime.fromMillisecondsSinceEpoch(
            group.x.toInt(),
            isUtc: true,
          ).toLocal();
          return DateTime(
            dt.year,
            dt.month,
            dt.day,
          ).toUtc().millisecondsSinceEpoch;
        }).toSet();

        final List<BarChartGroupData> finalVisibleData = List.from(
          tmpVisibleData,
        );

        var currentDate = DateTime.fromMillisecondsSinceEpoch(
          minX.toInt(),
          isUtc: true,
        ).toLocal();
        final endDate = DateTime.fromMillisecondsSinceEpoch(
          maxX.toInt(),
          isUtc: true,
        ).toLocal();

        while (currentDate.isBefore(endDate) ||
            currentDate.isAtSameMomentAs(endDate)) {
          final dateOnly = DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
          );

          if (!existingDates.contains(dateOnly.millisecondsSinceEpoch)) {
            finalVisibleData.add(
              BarChartGroupData(
                x: DateTime(
                  dateOnly.year,
                  dateOnly.month,
                  dateOnly.day,
                ).toUtc().millisecondsSinceEpoch,
                barRods: [],
              ),
            );
          }
          currentDate = currentDate.add(const Duration(days: 1));
        }

        finalVisibleData.sort((a, b) => a.x.compareTo(b.x));

        final visibleGroups = finalVisibleData;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            final dx = details.delta.dx;
            setState(() {
              final visibleRangeWithBuffer =
                  ((widget.windowX - 1) * unitXDouble);

              final pixelsPerStep =
                  context.size!.width / visibleRangeWithBuffer;
              final shift = -dx / pixelsPerStep;

              double newMinX = minX + shift;
              double newMaxX = maxX + shift;

              final firstX = allData.first.x;
              final lastX = allData.last.x;

              if (newMinX < firstX) {
                newMinX = firstX.toDouble();
                newMaxX = newMinX + visibleRangeWithBuffer;
              }
              if (newMaxX >= lastX) {
                newMaxX = lastX.toDouble();
                newMinX = newMaxX - visibleRangeWithBuffer;
              }

              minX = newMinX;
              maxX = newMaxX;
            });
          },
          onHorizontalDragEnd: (details) {
            final currentStartX = minX;
            double getSnappedStartX(double currentStartX) {
              switch (widget.unitX) {
                case UnitX.fiveMin: // ✅ 추가
                  final date = DateTime.fromMillisecondsSinceEpoch(
                    currentStartX.toInt(),
                    isUtc: true,
                  ).toLocal();
                  final minute5 = (date.minute ~/ 5) * 5;
                  final snappedLocal = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    date.hour,
                    minute5,
                  );
                  return snappedLocal.toUtc().millisecondsSinceEpoch.toDouble();
                case UnitX.halfHour:
                case UnitX.hour:
                  final date = DateTime.fromMillisecondsSinceEpoch(
                    currentStartX.toInt(),
                    isUtc: true,
                  ).toLocal();
                  final startOfHourLocal = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    date.hour,
                  );
                  return startOfHourLocal
                      .toUtc()
                      .millisecondsSinceEpoch
                      .toDouble();
                case UnitX.day:
                  final DateTime date = DateTime.fromMillisecondsSinceEpoch(
                    currentStartX.toInt(),
                    isUtc: true,
                  ).toLocal();
                  final startOfDayLocal = DateTime(
                    date.year,
                    date.month,
                    date.day,
                  );
                  return startOfDayLocal
                      .toUtc()
                      .millisecondsSinceEpoch
                      .toDouble();
                case UnitX.month:
                  return currentStartX.round().toDouble();
              }
            }

            final startOfX = getSnappedStartX(currentStartX);

            late final double lowerBound;
            final firstX = allData.first.x.toDouble();

            if (minX >= firstX) {
              lowerBound = allData.first.x.toDouble();
            } else {
              lowerBound = minX;
            }
            double upperBound =
                allData.last.x - ((widget.windowX - 1) * unitXDouble);

            if (upperBound < lowerBound) {
              upperBound = lowerBound;
            }

            final finalStartX = startOfX.clamp(lowerBound, upperBound);

            setState(() {
              labelStartX = finalStartX.toDouble();
              minX = finalStartX.toDouble();
              maxX = (finalStartX + (widget.windowX - 1) * unitXDouble)
                  .toDouble();

              _updateYAxis();
            });
          },
          child: SizedBox(
            height: 300,
            width: double.infinity,
            child: BarChart(
              BarChartData(
                barGroups: allData.isEmpty ? [] : visibleGroups,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) =>
                      const FlLine(color: AppColors.darkGray, strokeWidth: 1),
                  horizontalInterval: intervalY,
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    left: BorderSide.none,
                    right: BorderSide.none,
                    top: widget.limitedMaxY != null
                        ? BorderSide.none
                        : const BorderSide(color: AppColors.darkGray, width: 1),
                    bottom: const BorderSide(
                      color: AppColors.darkGray,
                      width: 1,
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    getTooltipColor: (_) => AppColors.mutePurple,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final date = DateTime.fromMillisecondsSinceEpoch(
                        group.x.toInt(),
                        isUtc: true,
                      ).toLocal();
                      final weekday = getWeekday(date);
                      String dateString;
                      if (widget.unitX == UnitX.day) {
                        dateString = '${date.month}/${date.day}($weekday)\n';
                      } else {
                        final indexDate = monthsFromBase(
                          group.x.toInt(),
                          widget.monthBaseStart!,
                        );
                        dateString =
                            '${(indexDate.year % 100).toString().padLeft(2, '0')}년 ${indexDate.month}월\n';
                      }

                      final Map<Color, String> sleepStageNames = {
                        AppColors.lightGray: "깸",
                        AppColors.lightPurple: '얕은 수면',
                        AppColors.purple: '렘 수면',
                        AppColors.darkPurple: '깊은 수면',
                      };

                      final Map<String, int> stageDurations = {};
                      for (final barRod in group.barRods) {
                        for (final stackItem in barRod.rodStackItems) {
                          final stageName = sleepStageNames[stackItem.color];
                          if (stageName != null) {
                            final duration = (stackItem.toY - stackItem.fromY)
                                .abs()
                                .toInt();
                            stageDurations.update(
                              stageName,
                              (value) => value + duration,
                              ifAbsent: () => duration,
                            );
                          }
                        }
                      }

                      double sleepStartY = group.barRods
                          .map((rod) => rod.toY)
                          .reduce(max);
                      double sleepEndY = group.barRods
                          .map((rod) => rod.fromY)
                          .reduce(min);

                      final startTimeString = formatDiffToHourMinute(
                        sleepStartY,
                        date,
                      );

                      final endTimeString = formatDiffToHourMinute(
                        sleepEndY,
                        date,
                      );

                      final timeRangeString =
                          '$startTimeString ~ $endTimeString\n';

                      String formatDuration(int ms) {
                        if (ms <= 0) return '0m';
                        final d = Duration(milliseconds: ms);
                        final h = d.inHours;
                        final m = d.inMinutes.remainder(60);
                        return '${h}h ${m}m';
                      }

                      const dateStyle = TextStyle(
                        color: AppColors.lightGray,
                        fontSize: 12,
                        fontVariations: AppFontVariations.medium,
                      );
                      const timeRangeStyle = TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontVariations: AppFontVariations.medium,
                      );
                      const stageStyle = TextStyle(
                        color: AppColors.lightGray,
                        fontSize: 12,
                        fontVariations: AppFontVariations.light,
                      );
                      const durationStyle = TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontVariations: AppFontVariations.medium,
                      );

                      final children = <TextSpan>[
                        TextSpan(text: dateString, style: dateStyle),
                      ];

                      if (widget.unitX == UnitX.month) {
                        final shallow = stageDurations['얕은 수면'] ?? 0;
                        final rem = stageDurations['렘 수면'] ?? 0;
                        final deep = stageDurations['깊은 수면'] ?? 0;
                        final awake = stageDurations['깸'] ?? 0;
                        final totalSleep = shallow + rem + deep;

                        String addLine(String label, int ms) {
                          final d = formatDuration(ms);
                          return '\n$label: $d';
                        }

                        final tooltipText = StringBuffer()
                          ..write(addLine('평균 총 수면시간', totalSleep))
                          ..write(addLine('평균 깸 시간', awake))
                          ..write(addLine('평균 얕은수면시간', shallow))
                          ..write(addLine('평균 렘수면 시간', rem))
                          ..write(addLine('평균 깊은수면시간', deep));

                        children.add(
                          TextSpan(
                            text: tooltipText.toString(),
                            style: durationStyle,
                          ),
                        );
                      } else {
                        children.add(
                          TextSpan(
                            text: timeRangeString,
                            style: timeRangeStyle,
                          ),
                        );

                        sleepStageNames.forEach((color, name) {
                          final duration = stageDurations[name] ?? 0;
                          if (duration > 0) {
                            final durationStr = formatDuration(duration);
                            children.add(
                              TextSpan(text: '\n$name: ', style: stageStyle),
                            );
                            children.add(
                              TextSpan(text: durationStr, style: durationStyle),
                            );
                          }
                        });
                      }

                      return BarTooltipItem(
                        '',
                        TextStyle(),
                        children: children,
                        textAlign: TextAlign.left,
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: intervalY,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          widget.unitX == UnitX.day
                              ? formatDiffToHour(value, minYLabel)
                              : formatSleepHour(value),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: unitXDouble,
                      getTitlesWidget: (value, meta) {
                        if (((value - labelStartX) %
                                    (widget.intervalX * unitXDouble) !=
                                0) &&
                            ((value - labelStartX) !=
                                ((widget.windowX) * unitXDouble))) {
                          return const SizedBox.shrink();
                        }
                        return renderXLabelOfStackedBar(
                          meta.axisSide,
                          minX,
                          value,
                          widget.windowX,
                          widget.unitX,
                          widget.monthBaseStart,
                        );
                      },
                    ),
                  ),
                ),
                minY: minYLabel,
                maxY: maxYLabel,
              ),
            ),
          ),
        );
      },
    );
  }
}
