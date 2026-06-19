import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/core/charts/health_chart_theme.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';
import 'package:picnique_rosary_healthcare_smartring/util/graph.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/charts/health_chart_empty.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/charts/health_chart_tooltip.dart';

/// Stress zone background (0–100).
class StressZonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final zones = [
      (0.0, 20.0, AppColors.StressBlue),
      (20.0, 40.0, AppColors.StressGreen),
      (40.0, 60.0, AppColors.StressYellow),
      (60.0, 80.0, AppColors.StressOrange),
      (80.0, 100.0, AppColors.StressRed),
    ];
    for (final (lo, hi, color) in zones) {
      final top = size.height * (1 - hi / 100);
      final bottom = size.height * (1 - lo / 100);
      canvas.drawRect(
        Rect.fromLTRB(0, top, size.width, bottom),
        Paint()..color = color.withValues(alpha: 0.12),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Native BarChart for stress, activity, rosary aggregates.
class HealthBarChart extends StatelessWidget {
  final List<BarChartGroupData> data;
  final DataType dataType;
  final ToggleRange range;
  final String unit;
  final double? goalLineY;
  final bool showStressZones;
  final Future<void> Function()? onRequestMoreLeft;
  final void Function(String)? setWindowXLabel;
  final DateTime selectedDate;

  const HealthBarChart({
    super.key,
    required this.data,
    required this.dataType,
    required this.range,
    required this.unit,
    this.goalLineY,
    this.showStressZones = false,
    this.onRequestMoreLeft,
    this.setWindowXLabel,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: HealthChartTheme.chartHeight,
        child: HealthChartEmpty(),
      );
    }

    final rods = data.expand((g) => g.barRods).map((r) => r.toY).toList();
    final bounds = HealthChartTheme.computeYBounds(
      dataType: dataType,
      values: rods,
      fixedMin: showStressZones ? 0 : null,
      fixedMax: showStressZones ? 100 : null,
    );

    final chart = BarChart(
      BarChartData(
        minY: bounds.minY,
        maxY: bounds.maxY,
        gridData: HealthChartTheme.grid(
          horizontalInterval: bounds.intervalY,
        ),
        borderData: HealthChartTheme.border(),
        extraLinesData: goalLineY != null
            ? HealthChartTheme.referenceLine(
                y: goalLineY!,
                color: AppColors.lightOrange,
              )
            : null,
        alignment: BarChartAlignment.spaceAround,
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
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                return Text(
                  _bottomLabel(idx),
                  style: HealthChartTheme.axisLabelStyle(),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchCallback: (event, _) {
            if (event is FlTapUpEvent) {
              HapticFeedback.selectionClick();
            }
          },
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            getTooltipColor: (_) => AppColors.mutePurple,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return HealthChartTooltip.barItem(
                title: _bottomLabel(group.x.toInt()),
                value: rod.toY.toStringAsFixed(0),
                unit: unit,
              );
            },
          ),
        ),
        barGroups: data.map((g) {
          if (g.barRods.isEmpty) return g;
          final rod = g.barRods.first;
          final color = dataType == DataType.Stress
              ? HealthChartTheme.barColorForStress(rod.toY)
              : (rod.color ?? HealthChartTheme.lineColor(dataType));
          return BarChartGroupData(
            x: g.x,
            barRods: [
              BarChartRodData(
                toY: rod.toY,
                fromY: rod.fromY,
                color: color,
                width: rod.width,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
      duration: HealthChartTheme.animationDuration,
    );

    return Semantics(
      label: '${dataType.name} bar chart',
      child: SizedBox(
      height: HealthChartTheme.chartHeight,
      child: Stack(
        children: [
          if (showStressZones)
            Positioned.fill(
              child: CustomPaint(painter: StressZonePainter()),
            ),
          chart,
        ],
      ),
      ),
    );
  }

  String _bottomLabel(int xIndex) {
    if (range == ToggleRange.day) {
      return '${xIndex}h';
    }
    try {
      final dt = getDateTimeFromIndex(xIndex, range, dataType);
      if (range == ToggleRange.halfYear || range == ToggleRange.year) {
        return '${dt.month}월';
      }
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '$xIndex';
    }
  }
}
