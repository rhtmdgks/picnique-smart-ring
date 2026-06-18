import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/graph/dot/_atomic/dot_graph.dart';

class DotDailyGraph extends StatelessWidget {
  final String unit;
  final double Function(double, double) intervalYFunc;
  final List<FlSpot> data;

  const DotDailyGraph({
    super.key,
    required this.unit,
    required this.intervalYFunc,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return DotGraph(
      unit: unit,
      windowX: 24,
      intervalX: 12,
      intervalYFunc: intervalYFunc,
      data: data,
      unitX: UnitX.fiveMin,
    );
  }
}
