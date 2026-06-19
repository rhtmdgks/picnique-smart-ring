import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/core/charts/health_chart_formatters.dart';
import 'package:picnique_rosary_healthcare_smartring/core/charts/health_chart_models.dart';
import 'package:picnique_rosary_healthcare_smartring/core/charts/health_chart_theme.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/charts/health_chart_empty.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/charts/health_chart_tooltip.dart';

/// Area + line chart for HR, SpO2, stress (day view).
class HealthAreaLineChart extends StatelessWidget {
  final List<FlSpot> spots;
  final DataType dataType;
  final ToggleRange range;
  final String unit;
  final double? minX;
  final double? maxX;
  final double? referenceLineY;

  const HealthAreaLineChart({
    super.key,
    required this.spots,
    required this.dataType,
    required this.range,
    required this.unit,
    this.minX,
    this.maxX,
    this.referenceLineY,
  });

  @override
  Widget build(BuildContext context) {
    final segments = segmentLineSpots(spots);
    if (segments.isEmpty) {
      return const SizedBox(
        height: HealthChartTheme.chartHeight,
        child: HealthChartEmpty(),
      );
    }

    final validSpots = segments.expand((s) => s).toList();
    final values = validSpots.map((s) => s.y).toList();
    final bounds = HealthChartTheme.computeYBounds(
      dataType: dataType,
      values: values,
      fixedMin: dataType == DataType.Oxygen ? 85 : null,
      fixedMax: dataType == DataType.Oxygen ? 100 : null,
    );

    final xMin = minX ?? validSpots.first.x;
    final xMax = maxX ?? validSpots.last.x;
    final lineColor = HealthChartTheme.lineColor(dataType);

    final lineBars = segments.map((segmentSpots) {
      return LineChartBarData(
        spots: segmentSpots.length == 1
            ? [
                segmentSpots.first,
                FlSpot(segmentSpots.first.x + 0.01, segmentSpots.first.y),
              ]
            : segmentSpots,
        isCurved: segmentSpots.length > 2,
        curveSmoothness: 0.25,
        color: lineColor,
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: FlDotData(show: segmentSpots.length == 1),
        belowBarData: BarAreaData(
          show: true,
          applyCutOffY: true,
          cutOffY: bounds.minY,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: HealthChartTheme.areaGradientColors(dataType),
          ),
        ),
      );
    }).toList();

    return Semantics(
      label: '${dataType.name} chart',
      child: SizedBox(
      height: HealthChartTheme.chartHeight,
      child: LineChart(
        LineChartData(
          minX: xMin,
          maxX: xMax,
          minY: bounds.minY,
          maxY: bounds.maxY,
          gridData: HealthChartTheme.grid(
            horizontalInterval: bounds.intervalY,
          ),
          borderData: HealthChartTheme.border(),
          extraLinesData: referenceLineY != null
              ? HealthChartTheme.referenceLine(y: referenceLineY!)
              : null,
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: HealthChartTheme.ySideTitles(
                bounds: bounds,
                unit: unit,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: HealthChartTheme.bottomAxisSize,
                interval: _bottomInterval(xMin, xMax, validSpots.length),
                getTitlesWidget: (v, _) {
                  if (v < xMin || v > xMax) return const SizedBox.shrink();
                  return Text(
                    formatTooltipX(v, range),
                    style: HealthChartTheme.axisLabelStyle(),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchCallback: (event, _) {
              if (event is FlTapUpEvent || event is FlLongPressEnd) {
                HapticFeedback.selectionClick();
              }
            },
            touchTooltipData: LineTouchTooltipData(
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              getTooltipColor: (_) => AppColors.mutePurple,
              getTooltipItems: (touched) {
                return touched.map((spot) {
                  return HealthChartTooltip.lineItem(
                    title: formatTooltipX(spot.x, range),
                    value: spot.y.toStringAsFixed(0),
                    unit: unit,
                  );
                }).toList();
              },
            ),
            getTouchedSpotIndicator: (_, indexes) {
              return indexes.map((_) {
                return TouchedSpotIndicatorData(
                  HealthChartTooltip.crosshairLine(),
                  FlDotData(
                    getDotPainter: (spot, percent, bar, index) =>
                        HealthChartTooltip.touchedDot(lineColor),
                  ),
                );
              }).toList();
            },
          ),
          lineBarsData: lineBars,
        ),
        duration: HealthChartTheme.animationDuration,
      ),
      ),
    );
  }

  double _bottomInterval(double min, double max, int spotCount) {
    final span = max - min;
    if (span <= 0) return 1;
    if (range == ToggleRange.day) {
      return span / 4;
    }
    return span / math.min(6, spotCount.toDouble());
  }
}
