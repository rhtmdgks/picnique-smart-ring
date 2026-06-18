// ignore_for_file: constant_identifier_names

import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';
import 'package:picnique_rosary_healthcare_smartring/util/graph.dart';

class DotGraph extends StatefulWidget {
  final DataType dataType;
  final ToggleRange selectedRange;
  final List<FlSpot> data;
  final Future<void> Function()? onRequestMoreLeft;
  final Function(String)? setWindowXLabel;
  final DateTime selectedDate;
  final Color? tooltipColor;
  final Color? graphColor;

  const DotGraph({
    super.key,
    required this.dataType,
    required this.selectedRange,
    required this.data,
    this.onRequestMoreLeft,
    this.setWindowXLabel,
    required this.selectedDate,
    this.tooltipColor,
    this.graphColor,
  });

  @override
  State<DotGraph> createState() => _DotGraphState();
}

class _DotGraphState extends State<DotGraph> {
  static const double GRAPH_HEIGHT = 300.0;
  static const Color GRID_LINE_COLOR = AppColors.darkGray;
  static const double GRID_LINE_WIDTH = 1.0;
  static const double RIGHT_AXIS_RESERVED_SIZE = 50.0;
  static const double BOTTOM_AXIS_RESERVED_SIZE = 50.0;
  static const double TOOLTIP_HORIZONTAL_PADDING = 8.0;
  static const double TOOLTIP_VERTICAL_PADDING = 4.0;
  static const double TOOLTIP_TITLE_FONT_SIZE = 14.0;
  static const double TOOLTIP_UNIT_FONT_SIZE = 12.0;
  static const double AXIS_LABEL_FONT_SIZE = 12.0;

  late num minX;
  late num maxX;
  late num minY;
  late num maxY;
  late num intervalY;
  late List<FlSpot> visibleData;
  late int windowX;
  late int window;
  late UnitX unitX;
  late num Function(num) calcMinY;
  late num Function(num) calcMaxY;
  late num Function(num) calcIntervalY;
  late String Function(num) dataUnitFunc;
  late Widget Function(double value, int lastX) bottomLabelFunc;
  late List<FlSpot> allData;
  late Color tooltipColor;

  bool get _isSelectedDateToday {
    final now = DateTime.now();
    return widget.selectedDate.year == now.year &&
        widget.selectedDate.month == now.month &&
        widget.selectedDate.day == now.day;
  }

  /// 오늘 날짜 + 일별 범위일 때, 현재 시간에 해당하는 x 슬롯 인덱스
  double get _currentSlotXForToday {
    if (widget.selectedRange != ToggleRange.day || !_isSelectedDateToday) {
      return double.infinity;
    }
    final startOfDay = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    final minutesFromStart = DateTime.now().difference(startOfDay).inMinutes;
    final slotIndex = minutesFromStart ~/ widget.dataType.dayUnitMins;
    return slotIndex.toDouble();
  }

  void updateYAxis() {
    if (allData.isEmpty) {
      return;
    }

    visibleData = allData
        .where((spot) => spot.x >= minX && spot.x <= maxX && spot.y != 0)
        .toList();

    final ys = visibleData.map((s) => s.y).toList();
    final localMinY = ys.isEmpty ? 0.0 : ys.reduce(min);
    final localMaxY = ys.isEmpty ? 0.0 : ys.reduce(max);

    minY = calcMinY(localMinY);
    maxY = calcMaxY(localMaxY);
    intervalY = calcIntervalY(localMaxY);
    if (visibleData.isEmpty) {
      return;
    }

    final startDate = widget.selectedRange == ToggleRange.day
        ? widget.selectedDate
        : getDateTimeFromIndex(
            visibleData.first.x.toInt(),
            widget.selectedRange,
            widget.dataType,
          );

    final label = getWindowXLabel(
      startDate,
      windowX - 1,
      widget.selectedRange,
      widget.dataType,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.setWindowXLabel?.call(label);
      }
    });
  }

  @override
  void initState() {
    super.initState();

    windowX = getWindowX(widget.selectedRange, widget.dataType);
    window = windowX - 1;
    unitX = getUnitX(widget.selectedRange, widget.dataType);
    calcMinY = widget.dataType.calcMinY;
    calcMaxY = widget.dataType.calcMaxY;
    calcIntervalY = widget.dataType.calcIntervalY;
    dataUnitFunc = widget.dataType.dataUnitFunc;
    bottomLabelFunc = renderBottomTitle(widget.selectedRange, widget.dataType);
    tooltipColor = widget.tooltipColor ?? AppColors.mutePurple;
    allData = widget.data;

    if (allData.isEmpty) {
      visibleData = [];
      return;
    }

    if (widget.selectedRange == ToggleRange.day && _isSelectedDateToday) {
      maxX = min(allData.last.x, _currentSlotXForToday);
      minX = max(allData.first.x, maxX - windowX + 1);
    } else {
      maxX = allData.last.x;
      minX = max(allData.first.x, maxX - windowX + 1);
    }

    updateYAxis();
  }

  @override
  void didUpdateWidget(covariant DotGraph oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.data.length != widget.data.length ||
        widget.selectedDate != oldWidget.selectedDate) {
      allData = widget.data;

      if (allData.isEmpty) {
        return;
      }

      if (widget.selectedRange == ToggleRange.day && _isSelectedDateToday) {
        maxX = min(allData.last.x, _currentSlotXForToday);
        minX = max(allData.first.x, maxX - windowX + 1);
      } else if (widget.selectedRange == ToggleRange.day &&
          !_isSelectedDateToday) {
        maxX = allData.last.x;
        minX = max(allData.first.x, maxX - windowX + 1);
      } else {
        minX = minX.clamp(allData.first.x, allData.last.x - window);
        maxX = (minX + window).clamp(
          allData.first.x + window,
          allData.last.x + 1,
        );
      }

      updateYAxis();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (allData.isEmpty) {
      return buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onHorizontalDragUpdate: handleDragUpdate,
          onHorizontalDragEnd: handleDragEnd,
          child: SizedBox(
            height: GRAPH_HEIGHT,
            width: double.infinity,
            child: buildLineChart(),
          ),
        );
      },
    );
  }

  Widget buildEmptyState() {
    return SizedBox(
      height: GRAPH_HEIGHT,
      width: double.infinity,
      child: const Center(
        child: Text(
          "데이터가 아직 없습니다.",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void handleDragUpdate(DragUpdateDetails details) {
    final dx = details.delta.dx;
    final screenWidth = context.size!.width;
    final shift = (dx / screenWidth) * (windowX - 1);

    setState(() {
      if (dx < 0) {
        minX = (minX - shift).clamp(allData.first.x, allData.last.x - window);
        maxX = minX + windowX;
      } else {
        maxX = (maxX - shift).clamp(
          allData.first.x + window,
          allData.last.x + 1,
        );
        minX = maxX - windowX;
      }
      if (widget.selectedRange == ToggleRange.day && _isSelectedDateToday) {
        maxX = min(maxX, _currentSlotXForToday);
        minX = max(allData.first.x, maxX - windowX + 1);
      }
      updateYAxis();
    });
  }

  void handleDragEnd(DragEndDetails details) {
    setState(() {
      int snappedMin = minX.round();
      final maxMinForSnap =
          widget.selectedRange == ToggleRange.day && _isSelectedDateToday
          ? max(
              allData.first.x.toInt(),
              (_currentSlotXForToday - window).toInt(),
            )
          : (allData.last.x - window).toInt();
      snappedMin = snappedMin
          .clamp(allData.first.x.toInt(), maxMinForSnap)
          .toInt();

      minX = snappedMin.toDouble();
      maxX = (snappedMin + window).toDouble();
      if (widget.selectedRange == ToggleRange.day && _isSelectedDateToday) {
        maxX = min(maxX, _currentSlotXForToday);
        minX = max(allData.first.x, maxX - windowX + 1);
      }
      updateYAxis();

      if (minX <= allData.first.x + windowX &&
          widget.onRequestMoreLeft != null) {
        widget.onRequestMoreLeft!();
      }
    });
  }

  Widget buildLineChart() {
    final color = widget.graphColor ?? AppColors.purple;

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: TOOLTIP_HORIZONTAL_PADDING,
              vertical: TOOLTIP_VERTICAL_PADDING,
            ),
            getTooltipColor: (_) => tooltipColor,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '',
                  const TextStyle(),
                  textAlign: TextAlign.left,
                  children: [
                    renderBarTooltipLabel(
                      spot.x.toInt(),
                      widget.selectedRange,
                      widget.dataType,
                    ),
                    TextSpan(
                      text: '${spot.y.toStringAsFixed(0)} ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: TOOLTIP_TITLE_FONT_SIZE,
                        fontVariations: AppFontVariations.medium,
                      ),
                    ),
                    TextSpan(
                      text: dataUnitFunc(spot.y),
                      style: TextStyle(
                        color: AppColors.lightGray,
                        fontSize: TOOLTIP_UNIT_FONT_SIZE,
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
                      color: color,
                      strokeWidth: 2.0,
                      strokeColor: Colors.white,
                    );
                  },
                ),
              );
            }).toList();
          },
        ),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: GRID_LINE_COLOR,
            strokeWidth: GRID_LINE_WIDTH,
          ),
          horizontalInterval: intervalY.toDouble(),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            left: BorderSide.none,
            right: BorderSide.none,
            top: BorderSide(color: GRID_LINE_COLOR, width: GRID_LINE_WIDTH),
            bottom: BorderSide(color: GRID_LINE_COLOR, width: GRID_LINE_WIDTH),
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: RIGHT_AXIS_RESERVED_SIZE,
              interval: intervalY.toDouble(),
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AXIS_LABEL_FONT_SIZE,
                  ),
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
              reservedSize: BOTTOM_AXIS_RESERVED_SIZE,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final lastX = visibleData.isEmpty ? 0.0 : visibleData.last.x;
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: bottomLabelFunc(value, lastX.toInt()),
                );
              },
            ),
          ),
        ),
        minX: minX.toDouble(),
        maxX: maxX.toDouble(),
        minY: minY.toDouble(),
        maxY: maxY.toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: visibleData,
            isCurved: false,
            color: color,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 2.0,
                  color: color,
                  strokeWidth: 1.0,
                  strokeColor: Colors.white.withValues(alpha: 0.6),
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.6),
                  color.withValues(alpha: 0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
