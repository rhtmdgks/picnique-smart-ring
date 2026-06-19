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
      final interval = dataType.calcIntervalY(fixedMax);
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
      minY = 85;
      maxY = 100;
    }

    final interval = dataType.calcIntervalY(maxY).toDouble();
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
  }) {
    return SideTitles(
      showTitles: true,
      reservedSize: rightAxisSize,
      interval: bounds.intervalY,
      getTitlesWidget: (value, meta) {
        if (value < bounds.minY || value > bounds.maxY) {
          return const SizedBox.shrink();
        }
        return Text(
          value.toInt().toString(),
          style: TextStyle(
            color: AppColors.lightGray,
            fontSize: 11,
            fontVariations: AppFontVariations.regular,
          ),
        );
      },
    );
  }

  static TextStyle axisLabelStyle() => TextStyle(
    color: AppColors.lightGray,
    fontSize: 11,
    fontVariations: AppFontVariations.regular,
  );

  static List<Color> areaGradientColors(DataType type) {
    final c = lineColor(type);
    return [c.withValues(alpha: 0.22), c.withValues(alpha: 0.0)];
  }

  static ExtraLinesData? referenceLine({
    required double y,
    Color color = AppColors.lightGray,
  }) {
    return ExtraLinesData(
      horizontalLines: [
        HorizontalLine(
          y: y,
          color: color.withValues(alpha: 0.6),
          strokeWidth: 1,
          dashArray: [6, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            style: axisLabelStyle(),
            labelResolver: (_) => y.toInt().toString(),
          ),
        ),
      ],
    );
  }
}
