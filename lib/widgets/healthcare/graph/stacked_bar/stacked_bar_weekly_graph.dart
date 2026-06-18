import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/graph/stacked_bar/_atomic/stacked_bar_graph.dart';

class StackedBarWeeklyGraph extends StatelessWidget {
  final String unit;
  final double Function(double, double) intervalYFunc;
  final List<BarChartGroupData> data;

  const StackedBarWeeklyGraph({
    super.key,
    required this.unit,
    required this.intervalYFunc,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return StackedBarGraph(
      windowX: 7,
      intervalX: 1,
      intervalYFunc: intervalYFunc,
      unitX: UnitX.day,
      data: data,
    );
  }
}
