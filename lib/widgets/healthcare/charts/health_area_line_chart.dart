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

/// SpO₂ Y축 위험·주의·정상 구간 배경 (80% 미만 강조).
class SpO2ZonePainter extends CustomPainter {
  final double minY;
  final double maxY;

  const SpO2ZonePainter({
    required this.minY,
    required this.maxY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double yFor(double value) {
      final span = maxY - minY;
      if (span <= 0) return size.height;
      final t = (value - minY) / span;
      return size.height * (1 - t.clamp(0.0, 1.0));
    }

    final zones = <(double, double, Color, double)>[
      (
        minY,
        HealthChartTheme.oxygenDangerThreshold,
        AppColors.StressRed,
        0.28,
      ),
      (
        HealthChartTheme.oxygenDangerThreshold,
        90,
        AppColors.StressOrange,
        0.12,
      ),
      (90, maxY, const Color(0xFF5AC8FA), 0.07),
    ];

    for (final (lo, hi, color, alpha) in zones) {
      final top = yFor(hi);
      final bottom = yFor(lo);
      canvas.drawRect(
        Rect.fromLTRB(0, top, size.width, bottom),
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SpO2ZonePainter oldDelegate) =>
      oldDelegate.minY != minY || oldDelegate.maxY != maxY;
}

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
      fixedMin: dataType == DataType.Oxygen
          ? HealthChartTheme.oxygenChartMinY
          : null,
      fixedMax: dataType == DataType.Oxygen
          ? HealthChartTheme.oxygenChartMaxY
          : null,
    );

    final isOxygen = dataType == DataType.Oxygen;

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
      final segmentColor = isOxygen
          ? HealthChartTheme.oxygenLineColorForSegment(spotsForLine)
          : lineColor;

      return LineChartBarData(
        spots: spotsForLine,
        isCurved: spotsForLine.length > 2,
        curveSmoothness: 0.22,
        preventCurveOverShooting: true,
        color: segmentColor,
        barWidth: isOxygen &&
                spotsForLine.any(
                  (s) => s.y > 0 && s.y < HealthChartTheme.oxygenDangerThreshold,
                )
            ? 3.2
            : 2.5,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: isOxygen,
          getDotPainter: (spot, percent, bar, index) {
            if (spot.y <= 0) {
              return FlDotCirclePainter(radius: 0, color: Colors.transparent);
            }
            final dotColor = HealthChartTheme.oxygenSpotColor(spot.y);
            final radius = spot.y < HealthChartTheme.oxygenDangerThreshold
                ? 4.5
                : 3.0;
            return FlDotCirclePainter(
              radius: radius,
              color: dotColor,
              strokeWidth: 1.5,
              strokeColor: Colors.white.withValues(alpha: 0.85),
            );
          },
        ),
        belowBarData: BarAreaData(
          show: isPrimary,
          applyCutOffY: true,
          cutOffY: bounds.minY,
          gradient: isPrimary
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isOxygen
                      ? [
                          segmentColor.withValues(alpha: 0.18),
                          segmentColor.withValues(alpha: 0.02),
                        ]
                      : gradientColors,
                )
              : null,
        ),
      );
    }).toList();

    final chart = LineChart(
          LineChartData(
            minX: xMin,
            maxX: xMax,
            minY: bounds.minY,
            maxY: bounds.maxY,
            gridData: HealthChartTheme.grid(
              horizontalInterval: bounds.intervalY,
            ),
            borderData: HealthChartTheme.border(),
            extraLinesData: isOxygen
                ? HealthChartTheme.oxygenReferenceLines()
                : (referenceLineY != null
                      ? HealthChartTheme.referenceLine(y: referenceLineY!)
                      : null),
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
                  dataType: dataType,
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
                          HealthChartTooltip.touchedDot(
                            isOxygen
                                ? HealthChartTheme.oxygenSpotColor(spot.y)
                                : lineColor,
                          ),
                    ),
                  );
                }).toList();
              },
            ),
            lineBarsData: lineBars,
          ),
          duration: HealthChartTheme.animationDuration,
        );

    return Semantics(
      label: '${dataType.name} chart',
      child: SizedBox(
        height: HealthChartTheme.chartHeight,
        child: isOxygen
            ? Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: SpO2ZonePainter(
                      minY: bounds.minY,
                      maxY: bounds.maxY,
                    ),
                  ),
                  chart,
                ],
              )
            : chart,
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
