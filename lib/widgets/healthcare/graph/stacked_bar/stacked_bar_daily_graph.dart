import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/sleep.dart';
import 'package:picnique_rosary_healthcare_smartring/core/models/sleep.dart';
import 'package:picnique_rosary_healthcare_smartring/util/sleep.dart';

double sleepTypeToY(SleepType type) {
  switch (type) {
    case SleepType.deep:
      return 1;
    case SleepType.rem:
      return 2;
    case SleepType.shallow:
      return 3;
    case SleepType.awake:
      return 4;
  }
}

DateTime _alignHourDownUtc(DateTime t) {
  final u = t;
  return DateTime(u.year, u.month, u.day, u.hour);
}

List<LineChartBarData> _toBars(List<SleepStage> stages) {
  return stages.map((s) {
    final y = sleepTypeToY(s.sleepType);
    final startX = s.startTime.millisecondsSinceEpoch.toDouble();
    final endX = s.endTime.millisecondsSinceEpoch.toDouble();
    debugPrint("${s.startTime}, ${s.endTime}");
    List<FlSpot> spots = [];
    for (double x = startX; x < endX; x += 1000 * 60 * 1) {
      spots.add(FlSpot(x, y));
    }
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      barWidth: 16, // 밴드 두께
      color: sleepColor(s.sleepType),
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }).toList();
}

DateTime _alignHourUpUtc(DateTime t) {
  final u = t;
  final base = DateTime(u.year, u.month, u.day, u.hour);
  return (u.minute > 0 || u.second > 0 || u.millisecond > 0)
      ? base.add(const Duration(hours: 1))
      : base;
}

class StackedBarDailyGraph extends StatelessWidget {
  final SleepData data;
  const StackedBarDailyGraph({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    late double minX;
    late double maxX;
    late List<LineChartBarData> bars;
    if (data.sleep.isEmpty) {
      final now = DateTime.now();

      final minStart = DateTime(now.year, now.month, now.day, 22, 0, 0);
      final maxEnd = DateTime(now.year, now.month, now.day + 1, 6, 0, 0);

      final minXDt = _alignHourDownUtc(minStart);
      final maxXDt = _alignHourUpUtc(maxEnd);

      minX =
          minXDt.millisecondsSinceEpoch.toDouble() -
          Duration.millisecondsPerHour.toDouble();
      maxX =
          maxXDt.millisecondsSinceEpoch.toDouble() +
          Duration.millisecondsPerHour.toDouble();

      bars = _toBars(data.sleep);
    } else {
      final minStart = data.sleep.first.startTime;
      final maxEnd = data.sleep.last.endTime;

      final minXDt = _alignHourDownUtc(minStart);
      final maxXDt = _alignHourUpUtc(maxEnd);

      minX =
          minXDt.millisecondsSinceEpoch.toDouble() -
          Duration.millisecondsPerHour.toDouble();
      maxX =
          maxXDt.millisecondsSinceEpoch.toDouble() +
          Duration.millisecondsPerHour.toDouble();

      bars = _toBars(data.sleep);
    }

    return SizedBox(
      height: 300,
      width: double.infinity,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: 0,
          maxY: 5,
          lineBarsData: bars,
          clipData: const FlClipData.all(),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: const BorderSide(color: AppColors.darkGray, width: 1),
              right: BorderSide.none,
              top: BorderSide.none,
              bottom: const BorderSide(color: AppColors.darkGray, width: 1),
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: const Duration(hours: 2).inMilliseconds.toDouble(),
                getTitlesWidget: (value, meta) {
                  final t = DateTime.fromMillisecondsSinceEpoch(
                    value.toInt(),
                    isUtc: true,
                  ).toLocal();
                  final hh = t.hour.toString().padLeft(2, '0');
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$hh시',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 36,
                getTitlesWidget: (v, _) {
                  switch (v.round()) {
                    case 1:
                      return const Text(
                        '깊은',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      );
                    case 2:
                      return const Text(
                        '렘',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      );
                    case 3:
                      return const Text(
                        '얕은',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      );
                    case 4:
                      return const Text(
                        '깸',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      );
                    default:
                      return const SizedBox.shrink();
                  }
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          lineTouchData: LineTouchData(
            touchSpotThreshold: 1,
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              getTooltipColor: (spot) => AppColors.mutePurple,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final bar = spot.bar;
                  final startX = bar.spots.first.x.toInt();
                  final endX = bar.spots.last.x.toInt();
                  final startDt = DateTime.fromMillisecondsSinceEpoch(
                    startX,
                    isUtc: true,
                  ).toLocal();
                  final endDt = DateTime.fromMillisecondsSinceEpoch(
                    endX,
                    isUtc: true,
                  ).toLocal();

                  final y = bar.spots.first.y.round();
                  String stageName;
                  switch (y) {
                    case 1:
                      stageName = '깊은 수면';
                      break;
                    case 2:
                      stageName = '렘 수면';
                      break;
                    case 3:
                      stageName = '얕은 수면';
                      break;
                    case 4:
                      stageName = '깸';
                      break;
                    default:
                      stageName = '';
                  }

                  return LineTooltipItem(
                    '',
                    const TextStyle(),
                    textAlign: TextAlign.left,
                    children: [
                      TextSpan(
                        text: '$stageName\n',
                        style: TextStyle(
                          color: AppColors.lightGray,
                          fontSize: 12,
                          fontVariations: AppFontVariations.medium,
                        ),
                      ),
                      TextSpan(
                        text:
                            '${startDt.hour.toString().padLeft(2, '0')}:${startDt.minute.toString().padLeft(2, '0')}'
                            ' ~ '
                            '${endDt.hour.toString().padLeft(2, '0')}:${endDt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontVariations: AppFontVariations.medium,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return spotIndexes.map((index) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: Colors.transparent,
                    strokeWidth: 0,
                    dashArray: [5, 5],
                  ),
                  FlDotData(
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 0,
                        color: Colors.transparent,
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      );
                    },
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
