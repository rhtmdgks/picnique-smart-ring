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

// 바 그래프 위젯
class BarGraph extends StatefulWidget {
  final DataType dataType;
  final ToggleRange selectedRange;
  final List<BarChartGroupData> data;
  final Future<void> Function()? onRequestMoreLeft;
  final Function(String)? setWindowXLabel;
  final DateTime selectedDate;
  final Color? tooltipColor;
  final Color? graphColor;

  const BarGraph({
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
  State<BarGraph> createState() => _BarGraphState();
}

class _BarGraphState extends State<BarGraph> {
  // 상수
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

  // 상태 변수
  late num minX;
  late num maxX;
  late num maxY;
  late num intervalY;
  late List<BarChartGroupData> visibleData;
  late int windowX;
  late int window;
  late UnitX unitX;
  late num Function(num) calcMaxY;
  late num Function(num) calcIntervalY;
  late String Function(num) dataUnitFunc;
  late Widget Function(double value, int lastX) bottomLabelFunc;
  late List<BarChartGroupData> allData;
  late Color tooltipColor;

  void updateYAxis() {
    if (allData.isEmpty) {
      return;
    }

    visibleData = allData
        .where((spot) => spot.x >= minX && spot.x <= maxX)
        .toList();

    final rods = visibleData
        .expand((group) => group.barRods)
        .map((rod) => rod.toY)
        .toList();

    final localMaxY = rods.isEmpty ? 0.0 : rods.reduce(max);

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

    // 초깃값 세팅
    windowX = getWindowX(widget.selectedRange, widget.dataType);
    window = windowX - 1;
    unitX = getUnitX(widget.selectedRange, widget.dataType);
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

    maxX = allData.last.x;
    minX = max(allData.first.x, maxX - windowX + 1);

    updateYAxis();
  }

  @override
  void didUpdateWidget(covariant BarGraph oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.data.length != widget.data.length ||
        widget.selectedDate != oldWidget.selectedDate) {
      allData = widget.data;

      if (allData.isEmpty) {
        return;
      }

      minX = minX.clamp(allData.first.x, allData.last.x - window);
      maxX = (minX + window).clamp(allData.first.x + window, allData.last.x);

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
            child: buildBarChart(),
          ),
        );
      },
    );
  }

  // [ ]: 빈 리스트는 에러. 추후 처리. 데이터 패칭 로딩 로직이랑 같이.
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

      updateYAxis();
    });
  }

  void handleDragEnd(DragEndDetails details) {
    setState(() {
      int snappedMin = minX.round();
      snappedMin = snappedMin.clamp(allData.first.x, allData.last.x - window);

      minX = snappedMin.toDouble();
      maxX = (snappedMin + window).toDouble();

      updateYAxis();

      if (minX <= allData.first.x + windowX &&
          widget.onRequestMoreLeft != null) {
        widget.onRequestMoreLeft!();
      }
    });
  }

  Widget buildBarChart() {
    return BarChart(
      BarChartData(
        barGroups: visibleData,
        alignment: BarChartAlignment.spaceAround,
        gridData: buildGridData(),
        borderData: buildBorderData(),
        barTouchData: buildBarTouchData(),
        titlesData: buildTitlesData(),
        minY: 0,
        maxY: maxY.toDouble(),
      ),
    );
  }

  FlGridData buildGridData() {
    return FlGridData(
      show: true,
      drawHorizontalLine: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) =>
          const FlLine(color: GRID_LINE_COLOR, strokeWidth: GRID_LINE_WIDTH),
      horizontalInterval: intervalY.toDouble(),
    );
  }

  FlBorderData buildBorderData() {
    return FlBorderData(
      show: true,
      border: const Border(
        left: BorderSide.none,
        right: BorderSide.none,
        top: BorderSide(color: GRID_LINE_COLOR, width: GRID_LINE_WIDTH),
        bottom: BorderSide(color: GRID_LINE_COLOR, width: GRID_LINE_WIDTH),
      ),
    );
  }

  BarTouchData buildBarTouchData() {
    return BarTouchData(
      handleBuiltInTouches: true,
      touchTooltipData: BarTouchTooltipData(
        tooltipPadding: const EdgeInsets.symmetric(
          horizontal: TOOLTIP_HORIZONTAL_PADDING,
          vertical: TOOLTIP_VERTICAL_PADDING,
        ),
        getTooltipColor: (_) => tooltipColor,
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          return buildTooltipItem(group, rod);
        },
      ),
    );
  }

  BarTooltipItem buildTooltipItem(
    BarChartGroupData group,
    BarChartRodData rod,
  ) {
    return BarTooltipItem(
      "",
      const TextStyle(),
      textAlign: TextAlign.left,
      children: [
        renderBarTooltipLabel(group.x, widget.selectedRange, widget.dataType),
        TextSpan(
          text: '${rod.toY.toStringAsFixed(0)} ',
          style: TextStyle(
            color: Colors.white,
            fontSize: TOOLTIP_TITLE_FONT_SIZE,
            fontVariations: AppFontVariations.medium,
          ),
        ),
        TextSpan(
          text: dataUnitFunc(rod.toY),
          style: TextStyle(
            color: AppColors.lightGray,
            fontSize: TOOLTIP_UNIT_FONT_SIZE,
            fontVariations: AppFontVariations.light,
          ),
        ),
      ],
    );
  }

  FlTitlesData buildTitlesData() {
    return FlTitlesData(
      rightTitles: buildRightTitles(),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: buildBottomTitles(),
    );
  }

  AxisTitles buildRightTitles() {
    return AxisTitles(
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
    );
  }

  AxisTitles buildBottomTitles() {
    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: BOTTOM_AXIS_RESERVED_SIZE,
        interval: 1,
        getTitlesWidget: (value, meta) {
          final lastX = visibleData.last.x;
          return SideTitleWidget(
            axisSide: meta.axisSide,
            child: bottomLabelFunc(value, lastX),
          );
        },
      ),
    );
  }
}
