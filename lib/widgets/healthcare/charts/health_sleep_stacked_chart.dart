import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/charts/health_chart_theme.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/graph/stacked_bar/_atomic/stacked_bar_graph.dart';

/// Sleep week/month/halfYear/year stacked bars — themed wrapper.
class HealthSleepStackedChart extends StatelessWidget {
  final ToggleRange range;
  final String unit;
  final double Function(double, double) intervalYFunc;
  final List<BarChartGroupData> data;
  final DateTime? monthBaseStart;

  const HealthSleepStackedChart({
    super.key,
    required this.range,
    required this.unit,
    required this.intervalYFunc,
    required this.data,
    this.monthBaseStart,
  });

  @override
  Widget build(BuildContext context) {
    final (windowX, intervalX, unitX) = switch (range) {
      ToggleRange.week => (7, 1, UnitX.day),
      ToggleRange.month => (30, 4, UnitX.day),
      ToggleRange.halfYear => (6, 1, UnitX.month),
      ToggleRange.year => (12, 2, UnitX.month),
      ToggleRange.day => (1, 1, UnitX.day),
    };

    return SizedBox(
      height: HealthChartTheme.chartHeight,
      child: StackedBarGraph(
        windowX: windowX.toDouble(),
        intervalX: intervalX.toDouble(),
        intervalYFunc: intervalYFunc,
        unitX: unitX,
        data: data,
        monthBaseStart: monthBaseStart,
        limitedMaxY: 600,
      ),
    );
  }
}
