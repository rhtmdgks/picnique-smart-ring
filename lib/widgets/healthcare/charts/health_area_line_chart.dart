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

/// Area + line chart for HR, SpO2 (Apple Health–style smooth line, no stray dots).
class HealthAreaLineChart extends StatelessWidget {
  final List<FlSpot> spots;
  final DataType dataType;
  final ToggleRange range;
  final String unit;
  final double? minX;
  final double? maxX;
  final double? referenceLineY;
  final DateTime? dayAnchor;

  const HealthAreaLineChart({
    super.key,
    required this.spots,
    required this.dataType,
    required this.range,
    required this.unit,
    this.minX,
    this.maxX,
    this.referenceLineY,
    this.dayAnchor,
  });

  double _segmentMaxGap() {
    switch (range) {
      case ToggleRange.day:
        // 5분 슬롯 기준 ~1시간 공백까지 한 줄로 연결
        return dataType.dayUnitMins == 5 ? 12 : 2;
      case ToggleRange.week:
      case ToggleRange.month:
        return 2;
      case ToggleRange.halfYear:
      case ToggleRange.year:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final segments = segmentLineSpots(
      spots,
      maxGap: _segmentMaxGap(),
    );
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
    final xTicks = computeSparseXTicks(
      minX: xMin,
      maxX: xMax,
      range: range,
      dataType: dataType,
    );
    final xInterval = _xTitleInterval(xTicks);
    final gradientColors = HealthChartTheme.areaGradientColors(dataType);

    final primaryIndex = _longestSegmentIndex(segments);
    final lineBars = segments.asMap().entries.map((entry) {
      final i = entry.key;
      final segmentSpots = entry.value;
      final isPrimary = i == primaryIndex;
      final spotsForLine = _lineSpotsForSegment(segmentSpots);

      return LineChartBarData(
        spots: spotsForLine,
        isCurved: spotsForLine.length > 2,
        curveSmoothness: 0.22,
        preventCurveOverShooting: true,
        color: lineColor,
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: isPrimary,
          applyCutOffY: true,
          cutOffY: bounds.minY,
          gradient: isPrimary
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: gradientColors,
                )
              : null,
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
                  interval: xInterval,
                  getTitlesWidget: (v, meta) {
                    if (!isNearChartTick(v, xTicks)) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 4,
                      child: Text(
                        formatAxisX(
                          v,
                          range,
                          dataType: dataType,
                          dayAnchor: dayAnchor,
                        ),
                        style: HealthChartTheme.axisLabelStyle(),
                      ),
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
                getTooltipColor: (_) => AppColors.darkGray,
                getTooltipItems: (touched) {
                  return touched.map((spot) {
                    return HealthChartTooltip.lineItem(
                      title: formatTooltipX(
                        spot.x,
                        range,
                        dataType: dataType,
                        dayAnchor: dayAnchor,
                      ),
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

  /// 단일 샘플은 짧은 수평 막대로 표시 (둥근 점 대신).
  List<FlSpot> _lineSpotsForSegment(List<FlSpot> segmentSpots) {
    if (segmentSpots.length >= 2) return segmentSpots;
    final s = segmentSpots.first;
    final halfWidth = range == ToggleRange.day ? 0.45 : 0.2;
    return [
      FlSpot(s.x - halfWidth, s.y),
      FlSpot(s.x + halfWidth, s.y),
    ];
  }

  double _xTitleInterval(List<double> ticks) {
    if (ticks.length < 2) return 1;
    return ticks[1] - ticks[0];
  }

  int _longestSegmentIndex(List<List<FlSpot>> segments) {
    var best = 0;
    var bestLen = 0;
    for (var i = 0; i < segments.length; i++) {
      if (segments[i].length > bestLen) {
        bestLen = segments[i].length;
        best = i;
      }
    }
    return best;
  }
}
