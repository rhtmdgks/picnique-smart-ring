import 'package:fl_chart/fl_chart.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';
import 'package:picnique_rosary_healthcare_smartring/core/models/sleep.dart';

/// Single time-series point (x = epoch ms, y = value).
class ChartPoint {
  final double x;
  final double y;

  const ChartPoint(this.x, this.y);

  FlSpot toSpot() => FlSpot(x, y);

  static ChartPoint fromSpot(FlSpot s) => ChartPoint(s.x, s.y);
}

/// Splits spots into contiguous segments (break when x gap exceeds [maxGap]).
List<List<FlSpot>> segmentLineSpots(
  List<FlSpot> spots, {
  double maxGap = 1.01,
}) {
  final valid = spots.where((s) => s.y > 0).toList()
    ..sort((a, b) => a.x.compareTo(b.x));
  if (valid.isEmpty) return const [];

  final segments = <List<FlSpot>>[];
  var current = <FlSpot>[valid.first];

  for (var i = 1; i < valid.length; i++) {
    if (valid[i].x - valid[i - 1].x > maxGap) {
      segments.add(current);
      current = [valid[i]];
    } else {
      current.add(valid[i]);
    }
  }
  if (current.isNotEmpty) segments.add(current);
  return segments;
}

/// Bar bucket for native BarChart.
class ChartBarBucket {
  final int xIndex;
  final double value;
  final DateTime? date;

  const ChartBarBucket({
    required this.xIndex,
    required this.value,
    this.date,
  });
}

/// Y-axis bounds after padding.
class ChartYBounds {
  final double minY;
  final double maxY;
  final double intervalY;

  const ChartYBounds({
    required this.minY,
    required this.maxY,
    required this.intervalY,
  });
}

/// Config passed into chart widgets.
class HealthChartConfig {
  final DataType dataType;
  final ToggleRange range;
  final String unit;
  final DateTime selectedDate;
  final DateTime? monthBaseStart;

  const HealthChartConfig({
    required this.dataType,
    required this.range,
    required this.unit,
    required this.selectedDate,
    this.monthBaseStart,
  });
}

/// Sleep stacked summary row.
class SleepStackBar {
  final DateTime x;
  final int deep;
  final int light;
  final int rem;
  final int awake;

  const SleepStackBar({
    required this.x,
    required this.deep,
    required this.light,
    required this.rem,
    required this.awake,
  });

  int get total => deep + light + rem + awake;

  SleepStackBar operator +(SleepStackBar other) {
    return SleepStackBar(
      x: x,
      deep: deep + other.deep,
      light: light + other.light,
      rem: rem + other.rem,
      awake: awake + other.awake,
    );
  }
}

/// Cached sleep graph payload.
class SleepGraphData {
  final List<SleepData> daily;
  final List<SleepMonthData> monthLike;

  const SleepGraphData({
    this.daily = const [],
    this.monthLike = const [],
  });
}
