import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/graph/stacked_bar/_atomic/stacked_bar_graph.dart';

class StackedBarMonthlyGraph extends StatelessWidget {
  final String unit;
  final double Function(double, double) intervalYFunc;
  final List<BarChartGroupData> data;

  const StackedBarMonthlyGraph({
    super.key,
    required this.unit,
    required this.intervalYFunc,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    // TODO(task): 월 길이(28/29/30/31일)에 맞춰 windowX/라벨 간격을 동적으로 계산.
    return StackedBarGraph(
      windowX: 31,
      intervalX: 5,
      intervalYFunc: intervalYFunc,
      unitX: UnitX.day,
      data: data,
    );
  }
}
