import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';

// unit: 데이터 단위
// UnitX: 데이터의 x축의 단위 (시간, 일, 달)
// windowX: 데이터를 몇개 보여줄지
// intervalX: 데이터 몇개마다 x축 라벨을 보여줄지
// intervalYFunc: y축 간격을 조정하는 함수
// data: 그래프에서 보여줄 데이터
class ActivityBarGraph extends StatefulWidget {
  final String? unit;
  final String Function(double stress)? unitFunc;
  final Color? tooltipColor, graphColor;

  final UnitX unitX;
  final double windowX, intervalX;
  final double? limitedMinY, limitedMaxY;
  final double Function(double, double) intervalYFunc;
  final List<FlSpot> data;

  final bool isDataDouble;

  const ActivityBarGraph({
    super.key,
    this.unit,
    required this.unitX,
    required this.windowX,
    required this.intervalX,
    required this.intervalYFunc,
    required this.data,
    this.unitFunc,
    this.limitedMinY,
    this.limitedMaxY,
    this.tooltipColor,
    this.graphColor,
    required this.isDataDouble,
  });

  @override
  State<ActivityBarGraph> createState() => _ActivityBarGraphState();
}

class _ActivityBarGraphState extends State<ActivityBarGraph> {
  late double minX;
  late double maxX;

  late double minYLabel;
  late double maxYLabel;

  late double minY;
  late double maxY;
  late double averageY;

  late final List<FlSpot> allDateData;
  late final List<FlSpot> allData;

  late final double edgeBuffer;
  late double intervalY;

  late double labelStartX;
  late final double unitXDouble;

  List<LineChartBarData> buildBarSeries(double barWidth) {
    final visible = allData.where(
      (s) => s.x >= minX - edgeBuffer && s.x <= maxX + edgeBuffer,
    );

    return visible.map((s) {
      return LineChartBarData(
        spots: [FlSpot(s.x, s.y), FlSpot(s.x, minYLabel.toDouble())],
        isCurved: false,
        barWidth: barWidth,
        color: widget.graphColor ?? AppColors.purple,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      );
    }).toList();
  }

  // 2) 로컬 시간의 '시간 바닥' 정렬
  DateTime _hour0Local(DateTime d) => DateTime(d.year, d.month, d.day, d.hour);

  @override
  void initState() {
    super.initState();

    unitXDouble = Duration.millisecondsPerHour.toDouble();
    edgeBuffer = 0.3 * unitXDouble;

    allData = (widget.data..sort((a, b) => a.x.compareTo(b.x)));

    final firstLocal = DateTime.fromMillisecondsSinceEpoch(
      allData.first.x.toInt(),
      isUtc: true,
    ).toLocal();
    labelStartX = _hour0Local(firstLocal).millisecondsSinceEpoch.toDouble();

    minX = labelStartX - edgeBuffer;
    maxX = labelStartX + (widget.windowX - 1) * unitXDouble + edgeBuffer;

    _updateYAxis();
  }

  void _updateYAxis() {
    final visibleData = allData.where(
      (spot) => spot.x >= minX && spot.x <= maxX,
    );
    if (visibleData.isEmpty) return;

    averageY =
        visibleData.map((e) => e.y).reduce((a, b) => a + b) /
        visibleData.length;

    double localMinY = visibleData.map((e) => e.y).reduce(min);
    double localMaxY = visibleData.map((e) => e.y).reduce(max);

    intervalY = widget.intervalYFunc(localMinY, localMaxY);

    minYLabel = 0;
    maxYLabel = widget.limitedMaxY != null
        ? widget.limitedMaxY! + intervalY * 1 / 2
        : ((localMaxY + intervalY - 1) ~/ intervalY) * intervalY + intervalY;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth;
        final steps = (widget.windowX - 1).clamp(1, double.infinity);
        final pixelsPerStep = chartWidth / steps;
        const fillRatio = 0.4;
        final computedBarWidth = (pixelsPerStep * fillRatio).clamp(4.0, 20.0);

        return SizedBox(
          height: 300,
          width: double.infinity,
          child: LineChart(
            LineChartData(
              clipData: FlClipData.all(),
              minX: minX,
              maxX: maxX,
              minY: minYLabel,
              maxY: maxYLabel,
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return FlLine(color: AppColors.darkGray, strokeWidth: 1);
                },
                horizontalInterval: intervalY,
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  left: BorderSide.none,
                  right: BorderSide.none,
                  top: widget.limitedMaxY != null
                      ? BorderSide.none
                      : const BorderSide(color: AppColors.darkGray, width: 1),
                  bottom: const BorderSide(color: AppColors.darkGray, width: 1),
                ),
              ),
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchSpotThreshold: computedBarWidth,
                touchTooltipData: LineTouchTooltipData(
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  getTooltipColor: (_) =>
                      widget.tooltipColor ?? AppColors.mutePurple,
                  getTooltipItems: (touched) {
                    return touched.map((ts) {
                      if (ts.bar.spots.first.y < ts.y) return null;
                      final x = ts.x;
                      final topY = ts.bar.spots.first.y;
                      final date = DateTime.fromMillisecondsSinceEpoch(
                        x.toInt(),
                        isUtc: true,
                      ).toLocal();

                      return LineTooltipItem(
                        '',
                        const TextStyle(),
                        textAlign: TextAlign.left,
                        children: [
                          TextSpan(
                            text: '${date.day}일 ${date.hour}시\n',
                            style: TextStyle(
                              color: AppColors.lightGray,
                              fontSize: 12,
                              fontVariations: AppFontVariations.medium,
                            ),
                          ),
                          TextSpan(
                            text: widget.isDataDouble
                                ? '$topY '
                                : '${topY.toStringAsFixed(0)} ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontVariations: AppFontVariations.medium,
                            ),
                          ),
                          TextSpan(
                            text:
                                widget.unit ??
                                (widget.unitFunc != null
                                    ? widget.unitFunc!(topY)
                                    : ""),
                            style: TextStyle(
                              color: AppColors.lightGray,
                              fontSize: 12,
                              fontVariations: AppFontVariations.light,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
                getTouchedSpotIndicator: (barData, indexes) {
                  return indexes.map((i) {
                    return TouchedSpotIndicatorData(
                      FlLine(color: Colors.transparent),
                      FlDotData(
                        getDotPainter: (spot, percent, bar, idx) {
                          return FlDotCirclePainter(
                            radius: 2,
                            color: widget.graphColor ?? AppColors.purple,
                            strokeWidth: 1.0,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    );
                  }).toList();
                },
              ),
              titlesData: FlTitlesData(
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    interval: intervalY,
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (value, meta) {
                      if (widget.limitedMaxY != null &&
                          (value ==
                              (widget.limitedMaxY! + (intervalY * 1 / 2)))) {
                        return const SizedBox.shrink();
                      }

                      return Row(
                        children: [
                          SizedBox(width: 4),
                          Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: unitXDouble,
                    getTitlesWidget: (value, meta) {
                      if (((value - labelStartX) %
                                  (widget.intervalX * unitXDouble) !=
                              0) &&
                          ((value - labelStartX) !=
                              ((widget.windowX - 1) * unitXDouble))) {
                        return const SizedBox.shrink();
                      }
                      DateTime date = DateTime.fromMillisecondsSinceEpoch(
                        value.toInt(),
                        isUtc: true,
                      ).toLocal();
                      String label = "${date.hour}시";
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 8.0,
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: buildBarSeries(computedBarWidth),
            ),
          ),
        );
      },
    );
  }
}
