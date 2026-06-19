import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';

class HealthChartTooltip {
  HealthChartTooltip._();

  static LineTooltipItem lineItem({
    required String title,
    required String value,
    required String unit,
  }) {
    return LineTooltipItem(
      '',
      const TextStyle(),
      children: [
        TextSpan(
          text: '$title\n',
          style: TextStyle(
            color: AppColors.lightGray,
            fontSize: 11,
            fontVariations: AppFontVariations.regular,
          ),
        ),
        TextSpan(
          text: value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontVariations: AppFontVariations.semiBold,
          ),
        ),
        TextSpan(
          text: ' $unit',
          style: TextStyle(
            color: AppColors.lightGray,
            fontSize: 12,
            fontVariations: AppFontVariations.regular,
          ),
        ),
      ],
    );
  }

  static BarTooltipItem barItem({
    required String title,
    required String value,
    required String unit,
  }) {
    return BarTooltipItem(
      '',
      const TextStyle(),
      children: [
        TextSpan(
          text: '$title\n',
          style: TextStyle(
            color: AppColors.lightGray,
            fontSize: 11,
            fontVariations: AppFontVariations.regular,
          ),
        ),
        TextSpan(
          text: value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontVariations: AppFontVariations.semiBold,
          ),
        ),
        TextSpan(
          text: ' $unit',
          style: TextStyle(
            color: AppColors.lightGray,
            fontSize: 12,
            fontVariations: AppFontVariations.regular,
          ),
        ),
      ],
    );
  }

  static FlLine crosshairLine() => FlLine(
    color: Colors.white.withValues(alpha: 0.7),
    strokeWidth: 1.5,
    dashArray: [5, 4],
  );

  static FlDotCirclePainter touchedDot(Color color) => FlDotCirclePainter(
    radius: 5,
    color: color,
    strokeWidth: 2,
    strokeColor: Colors.white,
  );
}
