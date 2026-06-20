import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/charts/health_chart_models.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';

/// Apple Health–style fl_chart defaults for healthcare metrics.
class HealthChartTheme {
  HealthChartTheme._();

  static const chartHeight = 280.0;
  static const animationDuration = Duration(milliseconds: 250);
  static const rightAxisSize = 44.0;
  static const bottomAxisSize = 28.0;
  static const gridOpacity = 0.25;

  /// SpO₂ 80% 미만은 임상적으로 위험 구간으로 표시한다.
  static const oxygenDangerThreshold = 80.0;
  static const oxygenNormalReference = 95.0;
  static const oxygenChartMinY = 75.0;
  static const oxygenChartMaxY = 100.0;

  static Color lineColor(DataType type) {
    switch (type) {
      case DataType.HeartRate:
        return AppColors.purple;
      case DataType.Oxygen:
        return const Color(0xFF5AC8FA);
      case DataType.Stress:
        return AppColors.StressOrange;
      default:
        return AppColors.lightPurple;
    }
  }

  static Color barColorForStress(double value) {
    if (value < 20) return AppColors.StressBlue;
    if (value < 40) return AppColors.StressGreen;
    if (value < 60) return AppColors.StressYellow;
    if (value < 80) return AppColors.StressOrange;
    return AppColors.StressRed;
  }

  static ChartYBounds computeYBounds({
    required DataType dataType,
    required List<double> values,
    double? fixedMin,
    double? fixedMax,
  }) {
    if (fixedMin != null && fixedMax != null) {
      var interval = dataType.calcIntervalY(fixedMax);
      if (dataType == DataType.Oxygen) {
        interval = 5;
      }
      return ChartYBounds(
        minY: fixedMin,
        maxY: fixedMax,
        intervalY: interval.toDouble(),
      );
    }

    if (values.isEmpty) {
      final maxY = dataType.calcMaxY(10).toDouble();
      return ChartYBounds(
        minY: 0,
        maxY: maxY,
        intervalY: dataType.calcIntervalY(maxY).toDouble(),
      );
    }

    final localMin = values.reduce(math.min);
    final localMax = values.reduce(math.max);

    var minY = dataType.calcMinY(localMin).toDouble();
    var maxY = dataType.calcMaxY(localMax).toDouble();

    if (dataType == DataType.HeartRate) {
      minY = math.max(40, minY - 10);
      maxY = maxY + 10;
    }
    if (dataType == DataType.Oxygen) {
      minY = oxygenChartMinY;
      maxY = oxygenChartMaxY;
    }

    var interval = dataType.calcIntervalY(maxY).toDouble();
    if (dataType == DataType.Oxygen) {
      interval = 5;
    }
    return ChartYBounds(minY: minY, maxY: maxY, intervalY: interval);
  }

  static FlGridData grid({double? horizontalInterval}) {
    return FlGridData(
      show: true,
      drawHorizontalLine: true,
      drawVerticalLine: false,
      horizontalInterval: horizontalInterval,
      getDrawingHorizontalLine: (_) => FlLine(
        color: AppColors.darkGray.withValues(alpha: gridOpacity),
        strokeWidth: 1,
      ),
    );
  }

  static FlBorderData border() {
    return FlBorderData(
      show: true,
      border: Border(
        left: BorderSide.none,
        right: BorderSide.none,
        top: BorderSide(
          color: AppColors.darkGray.withValues(alpha: gridOpacity),
        ),
        bottom: BorderSide(
          color: AppColors.darkGray.withValues(alpha: gridOpacity),
        ),
      ),
    );
  }

  static SideTitles ySideTitles({
    required ChartYBounds bounds,
    required String unit,
    DataType? dataType,
  }) {
    return SideTitles(
      showTitles: true,
      reservedSize: rightAxisSize,
      interval: bounds.intervalY,
      getTitlesWidget: (value, meta) {
        if (value < bounds.minY || value > bounds.maxY) {
          return const SizedBox.shrink();
        }
        final isOxygenDangerTick =
            dataType == DataType.Oxygen &&
            (value - oxygenDangerThreshold).abs() < 0.01;
        return Text(
          value.toInt().toString(),
          style: TextStyle(
            color: isOxygenDangerTick ? AppColors.StressRed : AppColors.lightGray,
            fontSize: isOxygenDangerTick ? 12 : 11,
            fontWeight: isOxygenDangerTick
                ? AppFontWeight.semiBold
                : AppFontWeight.regular,
          ),
        );
      },
    );
  }

  static TextStyle axisLabelStyle() => TextStyle(
    color: AppColors.lightGray,
    fontSize: 11,
    fontWeight: AppFontWeight.regular,
  );

  static List<Color> areaGradientColors(DataType type) {
    final c = lineColor(type);
    return [c.withValues(alpha: 0.12), c.withValues(alpha: 0.0)];
  }

  /// Subtle single-tone fill (no multi-segment rainbow).
  static Color areaFillColor(DataType type) =>
      lineColor(type).withValues(alpha: 0.08);

  static ExtraLinesData? referenceLine({
    required double y,
    Color color = AppColors.lightGray,
    String? label,
    double strokeWidth = 1,
    List<int>? dashArray,
  }) {
    return ExtraLinesData(
      horizontalLines: [
        HorizontalLine(
          y: y,
          color: color.withValues(alpha: dashArray == null ? 0.6 : 0.85),
          strokeWidth: strokeWidth,
          dashArray: dashArray ?? [6, 4],
          label: HorizontalLineLabel(
            show: label != null,
            alignment: Alignment.topRight,
            style: axisLabelStyle(),
            labelResolver: (_) => label ?? y.toInt().toString(),
          ),
        ),
      ],
    );
  }

  static ExtraLinesData oxygenReferenceLines() {
    return ExtraLinesData(
      horizontalLines: [
        HorizontalLine(
          y: oxygenDangerThreshold,
          color: AppColors.StressRed.withValues(alpha: 0.9),
          strokeWidth: 2,
          dashArray: [8, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            style: TextStyle(
              color: AppColors.StressRed,
              fontSize: 11,
              fontWeight: AppFontWeight.semiBold,
            ),
            labelResolver: (_) => '80% 미만 주의',
          ),
        ),
        HorizontalLine(
          y: oxygenNormalReference,
          color: const Color(0xFF5AC8FA).withValues(alpha: 0.45),
          strokeWidth: 1,
          dashArray: [4, 6],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            style: axisLabelStyle(),
            labelResolver: (_) => '95',
          ),
        ),
      ],
    );
  }

  static Color oxygenSpotColor(double value) {
    if (value < oxygenDangerThreshold) return AppColors.StressRed;
    if (value < 90) return AppColors.StressOrange;
    return lineColor(DataType.Oxygen);
  }

  static Color oxygenLineColorForSegment(List<FlSpot> spots) {
    if (spots.any((s) => s.y > 0 && s.y < oxygenDangerThreshold)) {
      return AppColors.StressRed;
    }
    if (spots.any((s) => s.y > 0 && s.y < 90)) {
      return AppColors.StressOrange;
    }
    return lineColor(DataType.Oxygen);
  }
}
