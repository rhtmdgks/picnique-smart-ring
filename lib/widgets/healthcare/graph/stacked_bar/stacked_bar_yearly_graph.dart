import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/graph/stacked_bar/_atomic/stacked_bar_graph.dart';

class StackedBarYearlyGraph extends StatelessWidget {
  final String unit;
  final double Function(double, double) intervalYFunc;
  final List<BarChartGroupData> data;
  final DateTime monthBaseStart;

  const StackedBarYearlyGraph({
    super.key,
    required this.unit,
    required this.intervalYFunc,
    required this.data,
    required this.monthBaseStart,
  });

  @override
  Widget build(BuildContext context) {
    return StackedBarGraph(
      windowX: 12,
      intervalX: 1,
      intervalYFunc: intervalYFunc,
      unitX: UnitX.month,
      data: data,
      limitedMinY: 0,
      monthBaseStart: monthBaseStart,
    );
  }
}
