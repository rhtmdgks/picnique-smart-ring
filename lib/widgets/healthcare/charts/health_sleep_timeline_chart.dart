import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/core/charts/health_chart_formatters.dart';
import 'package:picnique_rosary_healthcare_smartring/core/charts/health_chart_theme.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/sleep.dart';
import 'package:picnique_rosary_healthcare_smartring/core/models/sleep.dart';
import 'package:picnique_rosary_healthcare_smartring/util/sleep.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/charts/health_chart_empty.dart';

double _sleepStageY(SleepType type) {
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

/// Sleep day timeline
class HealthSleepTimelineChart extends StatelessWidget {
  final SleepData data;

  const HealthSleepTimelineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.sleep.isEmpty) {
      return const SizedBox(
        height: HealthChartTheme.chartHeight,
        child: HealthChartEmpty(message: '수면 데이터 없음'),
      );
    }

    final bars = <LineChartBarData>[];
    for (final s in data.sleep) {
      final y = _sleepStageY(s.sleepType);
      final startX = s.startTime.millisecondsSinceEpoch.toDouble();
      final endX = s.endTime.millisecondsSinceEpoch.toDouble();
      if (endX <= startX) continue;
      bars.add(
        LineChartBarData(
          spots: [FlSpot(startX, y), FlSpot(endX, y)],
          isCurved: false,
          barWidth: 14,
          color: sleepColor(s.sleepType),
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    if (bars.isEmpty) {
      return const SizedBox(
        height: HealthChartTheme.chartHeight,
        child: HealthChartEmpty(message: '수면 데이터 없음'),
      );
    }

    final allX = data.sleep
        .expand((s) => [s.startTime, s.endTime])
        .map((d) => d.millisecondsSinceEpoch.toDouble());
    final minX = allX.reduce((a, b) => a < b ? a : b);
    final maxX = allX.reduce((a, b) => a > b ? a : b);
    final pad = Duration.millisecondsPerHour.toDouble();

    return Semantics(
      label: 'Sleep timeline chart',
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: HealthChartTheme.chartHeight,
          child: LineChart(
            LineChartData(
              minX: minX - pad,
              maxX: maxX + pad,
              minY: 0.5,
              maxY: 4.5,
              clipData: const FlClipData.all(),
              gridData: HealthChartTheme.grid(horizontalInterval: 1),
              borderData: HealthChartTheme.border(),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final labels = {
                        1.0: '깊은',
                        2.0: 'REM',
                        3.0: '얕은',
                        4.0: '깨어',
                      };
                      final t = labels[v];
                      if (t == null) return const SizedBox.shrink();
                      return Text(
                        t,
                        style: HealthChartTheme.axisLabelStyle(),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: HealthChartTheme.bottomAxisSize,
                    interval: (maxX - minX) / 4,
                    getTitlesWidget: (v, _) => Text(
                      formatChartTime(
                        DateTime.fromMillisecondsSinceEpoch(v.toInt()),
                      ),
                      style: HealthChartTheme.axisLabelStyle(),
                    ),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchCallback: (event, _) {
                  if (event is FlTapUpEvent) {
                    HapticFeedback.selectionClick();
                  }
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.mutePurple,
                  getTooltipItems: (touched) {
                    return touched.map((spot) {
                      return LineTooltipItem(
                        formatChartTime(
                          DateTime.fromMillisecondsSinceEpoch(spot.x.toInt()),
                        ),
                        TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: AppFontWeight.medium,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: bars,
            ),
            duration: HealthChartTheme.animationDuration,
          ),
        ),
        const SizedBox(height: 8),
        _SleepLegend(),
      ],
      ),
    );
  }
}

class _SleepLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      (SleepType.deep, '깊은'),
      (SleepType.rem, 'REM'),
      (SleepType.shallow, '얕은'),
      (SleepType.awake, '깨어'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: items.map((e) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: sleepColor(e.$1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              e.$2,
              style: TextStyle(
                color: AppColors.lightGray,
                fontSize: 11,
                fontWeight: AppFontWeight.regular,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
