import 'dart:math';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';

class GoalGraph extends StatelessWidget {
  const GoalGraph({
    super.key,
    required this.caloriePercent,
    required this.stepsPercent,
    required this.distancePercent,
    required this.isMini,
  });

  /// percent is between 0 and 100
  final double caloriePercent, stepsPercent, distancePercent;
  final bool isMini;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2, // 반원 비율
      child: CustomPaint(
        painter: GoalGraphPainter(
          caloriePercent: caloriePercent,
          stepsPercent: stepsPercent,
          distancePercent: distancePercent,
          isMini: isMini,
        ),
      ),
    );
  }
}

class GoalGraphPainter extends CustomPainter {
  GoalGraphPainter({
    required this.caloriePercent,
    required this.stepsPercent,
    required this.distancePercent,
    required this.isMini,
  });

  final double caloriePercent;
  final double stepsPercent;
  final double distancePercent;
  final bool isMini;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radiusBase = size.width / 2;

    // 공통 계산식
    void drawArcRing(
      double percent,
      Color color,
      Color backgroundColor,
      double radiusOffset,
      double strokeWidth,
    ) {
      final radius = radiusBase - radiusOffset;

      final fullArcPainter = Paint()
        ..color = backgroundColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final angleWithRoundStroke = pi - strokeWidth / radius;
      final offsetAngle = pi + (strokeWidth / (2 * radius));

      // background arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        offsetAngle,
        angleWithRoundStroke,
        false,
        fullArcPainter,
      );

      // foreground arc
      final percentPainter = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      double percentAngle = (percent >= 100)
          ? angleWithRoundStroke
          : percent * angleWithRoundStroke / 100;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        offsetAngle,
        percentAngle,
        false,
        percentPainter,
      );
    }

    // 🔵 거리 (가장 바깥)

    drawArcRing(
      distancePercent,
      AppColors.pink,
      AppColors.pink.withValues(alpha: 0.25),
      isMini ? 1 : 30,
      isMini ? 3 : 20,
    );

    // 🟡 걸음수 (중간)
    drawArcRing(
      stepsPercent,
      AppColors.purple,
      AppColors.purple.withValues(alpha: 0.25),
      isMini ? 6 : 60,
      isMini ? 3 : 20,
    );

    // 🔴 칼로리 (안쪽)
    drawArcRing(
      caloriePercent,
      AppColors.blue,
      AppColors.blue.withValues(alpha: 0.25),
      isMini ? 11 : 90,
      isMini ? 3 : 20,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
