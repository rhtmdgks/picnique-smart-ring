import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';
import 'package:picnique_rosary_healthcare_smartring/util/date.dart';
import 'package:picnique_rosary_healthcare_smartring/util/graph.dart';

// unit: 데이터 단위
// UnitX: 데이터의 x축의 단위 (시간, 일, 달)
// windowX: 데이터를 몇개 보여줄지
// intervalX: 데이터 몇개마다 x축 라벨을 보여줄지
// intervalYFunc: y축 간격을 조정하는 함수
// data: 그래프에서 보여줄 데이터
class DotGraph extends StatefulWidget {
  final String unit;
  final UnitX unitX;
  final double windowX, intervalX;
  final double Function(double, double) intervalYFunc;
  final List<FlSpot> data;
  final DateTime? monthBaseStart;

  const DotGraph({
    super.key,
    required this.unit,
    required this.unitX,
    required this.windowX,
    required this.intervalX,
    required this.intervalYFunc,
    required this.data,
    this.monthBaseStart,
  });

  @override
  State<DotGraph> createState() => _DotGraphState();
}

class _DotGraphState extends State<DotGraph> {
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

  @override
  void initState() {
    super.initState();
    unitXDouble = switch (widget.unitX) {
      UnitX.fiveMin => (Duration.millisecondsPerMinute * 5).toDouble(),
      UnitX.halfHour => (Duration.millisecondsPerMinute * 30).toDouble(),
      UnitX.hour => Duration.millisecondsPerHour.toDouble(),
      UnitX.day => Duration.millisecondsPerDay.toDouble(),
      UnitX.month => 1.0,
    };
    // 점이 잘 보이도록 양끝에 버퍼 추가
    edgeBuffer = 0.3 * unitXDouble;
    // TODO(task): mock 전달 대신 DB/Provider 실측 데이터 주입 경로로 교체.
    allDateData = widget.data;
    allData = allDateData;

    if (allData.isEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayMillis = today.millisecondsSinceEpoch.toDouble();

      labelStartX = todayMillis - widget.windowX * unitXDouble + unitXDouble;
      minX = labelStartX - edgeBuffer;
      maxX =
          labelStartX + widget.windowX * unitXDouble - unitXDouble + edgeBuffer;
      minYLabel = 90;
      maxYLabel = 100;
      averageY = 95;
      intervalY = 5;
      labelStartX = 0;
    } else {
      labelStartX = allData.last.x - widget.windowX * unitXDouble + unitXDouble;
      minX = labelStartX - edgeBuffer;
      maxX =
          labelStartX + widget.windowX * unitXDouble - unitXDouble + edgeBuffer;
      _updateYAxis();
    }
  }

  void _updateYAxis() {
    final visibleData = allData.where(
      (spot) => spot.x >= minX && spot.x <= maxX,
    );
    if (visibleData.isEmpty) {
      minYLabel = 90;
      maxYLabel = 100;
      averageY = 95;
      intervalY = 5;
      return;
    }

    averageY =
        visibleData.map((e) => e.y).reduce((a, b) => a + b) /
        visibleData.length;

    double localMinY = visibleData.map((e) => e.y).reduce(min);
    double localMaxY = visibleData.map((e) => e.y).reduce(max);

    intervalY = widget.intervalYFunc(localMinY, localMaxY);

    minYLabel = (localMinY ~/ intervalY) * intervalY - intervalY;
    maxYLabel =
        ((localMaxY + intervalY - 1) ~/ intervalY) * intervalY + intervalY;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final dx = details.delta.dx;
        setState(() {
          final visibleRangeWithBuffer =
              ((widget.windowX - 1) * unitXDouble) + (edgeBuffer * 2);

          final pixelsPerStep = context.size!.width / visibleRangeWithBuffer;
          final shift = -dx / pixelsPerStep;

          double newMinX = minX + shift;
          double newMaxX = maxX + shift;

          final firstX = allData.first.x - edgeBuffer;
          final lastX = allData.last.x + edgeBuffer;

          if (newMinX < firstX) {
            newMinX = firstX;
            newMaxX = newMinX + visibleRangeWithBuffer;
          }
          if (newMaxX > lastX) {
            newMaxX = lastX;
            newMinX = newMaxX - visibleRangeWithBuffer;
          }

          minX = newMinX;
          maxX = newMaxX;
        });
      },
      // onHorizontalDragEnd: (details) {
      //   final currentStartX = minX + edgeBuffer;
      //   double getSnappedStartX(double currentStartX) {
      //     switch (widget.unitX) {
      //       case UnitX.fiveMin: // ✅ 추가
      //         final date = DateTime.fromMillisecondsSinceEpoch(
      //           currentStartX.toInt(),
      //           isUtc: true,
      //         ).toLocal();
      //         final minute5 = (date.minute ~/ 5) * 5;
      //         final snapped = DateTime(
      //           date.year,
      //           date.month,
      //           date.day,
      //           date.hour,
      //           minute5,
      //         );
      //         return snapped.millisecondsSinceEpoch.toDouble();
      //       case UnitX.hour:
      //         final date = DateTime.fromMillisecondsSinceEpoch(
      //           currentStartX.toInt(),
      //           isUtc: true,
      //         ).toLocal();
      //         final startOfHour = DateTime(
      //           date.year,
      //           date.month,
      //           date.day,
      //           date.hour,
      //         );
      //         return startOfHour.millisecondsSinceEpoch.toDouble();
      //       case UnitX.day:
      //         final DateTime date = DateTime.fromMillisecondsSinceEpoch(
      //           currentStartX.toInt(),
      //           isUtc: true,
      //         ).toLocal();
      //         final DateTime startOfDay = DateTime(
      //           date.year,
      //           date.month,
      //           date.day,
      //         );
      //         return startOfDay.millisecondsSinceEpoch.toDouble();
      //       case UnitX.month:
      //         return currentStartX.round().toDouble();
      //     }
      //   }

      //   final startOfX = getSnappedStartX(currentStartX);

      //   late final double lowerBound;
      //   final firstX = allData.first.x.toDouble();

      //   if (minX >= firstX) {
      //     lowerBound = allData.first.x.toDouble();
      //   } else {
      //     lowerBound = minX;
      //   }
      //   double upperBound =
      //       allData.last.x - ((widget.windowX - 1) * unitXDouble);

      //   if (upperBound < lowerBound) {
      //     upperBound = lowerBound;
      //   }

      //   final finalStartX = startOfX.clamp(lowerBound, upperBound);

      //   setState(() {
      //     labelStartX = finalStartX.toDouble();
      //     minX = finalStartX.toDouble() - edgeBuffer;
      //     maxX =
      //         (finalStartX + (widget.windowX - 1) * unitXDouble).toDouble() +
      //         edgeBuffer;

      //     _updateYAxis();
      //   });
      // },
      onHorizontalDragEnd: (_) {
        // X 관련 스냅/클램프/라벨 갱신 전부 제거
        // 드래그 중 변경 상태 그대로 두고, Y 축만 다시 계산
        setState(_updateYAxis);
        // 또는: setState(() { _updateYAxis(); });
      },
      child: SizedBox(
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
              border: const Border(
                left: BorderSide.none,
                right: BorderSide.none,
                top: BorderSide(color: AppColors.darkGray, width: 1),
                bottom: BorderSide(color: AppColors.darkGray, width: 1),
              ),
            ),
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                getTooltipColor: (spot) => AppColors.mutePurple,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    return LineTooltipItem(
                      '',
                      const TextStyle(),
                      textAlign: TextAlign.left,
                      children: [
                        renderTooltipLabel(
                          spot.x,
                          widget.unitX,
                          widget.monthBaseStart,
                        ),
                        TextSpan(
                          text: '${spot.y.toStringAsFixed(0)} ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontVariations: AppFontVariations.medium,
                          ),
                        ),
                        TextSpan(
                          text: widget.unit,
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
              getTouchedSpotIndicator: (barData, spotIndexes) {
                return spotIndexes.map((index) {
                  return TouchedSpotIndicatorData(
                    FlLine(
                      color: Colors.white,
                      strokeWidth: 2.0,
                      dashArray: [5, 5],
                    ),
                    FlDotData(
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4.0,
                          color: AppColors.purple,
                          strokeWidth: 2.0,
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
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
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
                  // ✅ 하루 뷰일 때만 1시간틱으로 바꿔서, 그 중 로컬 자정만 선택
                  interval: widget.unitX == UnitX.day
                      ? Duration.millisecondsPerHour.toDouble()
                      : unitXDouble,
                  getTitlesWidget: (value, meta) {
                    final v = value.round();

                    if (widget.unitX == UnitX.day) {
                      final dayMs = Duration.millisecondsPerDay; // int
                      // 이 틱이 "로컬 자정"인지 판별
                      final tzMs = DateTime.fromMillisecondsSinceEpoch(
                        v,
                        isUtc: true,
                      ).toLocal().timeZoneOffset.inMilliseconds;
                      final isLocalMidnight = ((v + tzMs) % dayMs) == 0;

                      // ⛳️ 앵커: 오른쪽(가장 최근) 눈금
                      final lastTickX =
                          (labelStartX +
                                  (widget.windowX - 1) * dayMs.toDouble())
                              .round();

                      // 오른쪽 끝으로부터 몇 일 떨어졌는지(정수 일수) 계산
                      final deltaDays = ((lastTickX - v) / dayMs).round();
                      final step = widget.intervalX.toInt(); // 예: 5

                      final shouldShow =
                          isLocalMidnight && (deltaDays % step == 0);
                      if (!shouldShow) return const SizedBox.shrink();
                    } else {
                      // (기존 시간/5분/월 뷰 로직 유지)
                      if (((value - labelStartX) %
                                  (widget.intervalX * unitXDouble) !=
                              0) &&
                          ((value - labelStartX) !=
                              ((widget.windowX - 1) * unitXDouble))) {
                        return const SizedBox.shrink();
                      }
                    }

                    // ✅ 라벨 텍스트는 KST 자정 기준으로 생성
                    final date = DateTime.fromMillisecondsSinceEpoch(
                      v,
                      isUtc: true,
                    ).toLocal();
                    final label = switch (widget.unitX) {
                      UnitX.fiveMin ||
                      UnitX.halfHour ||
                      UnitX.hour => '${date.hour}시',
                      UnitX.day =>
                        (date.day == 1 ||
                                value ==
                                    labelStartX +
                                        (widget.windowX - 1) *
                                            Duration.millisecondsPerDay
                                                .toDouble())
                            ? '${date.month}/${date.day}'
                            : '${date.day}',
                      UnitX.month => monthsFromBase(
                        value.toInt(),
                        widget.monthBaseStart!,
                      ).month.toString(),
                    };

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
            lineBarsData: allData.isEmpty
                ? []
                : [
                    LineChartBarData(
                      spots: allData,
                      isCurved: false,
                      color: AppColors.purple,
                      barWidth: 2,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 2.0,
                            color: AppColors.purple,
                            strokeWidth: 1.0,
                            strokeColor: Colors.white.withValues(alpha: 0.6),
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.purple.withValues(alpha: 0.6),
                            AppColors.purple.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}
