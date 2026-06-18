import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/util/date.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/activity/goal_graph.dart';

class ActivityGoalDay extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final VoidCallback onTap;

  final int calories, steps, calorieGoal, stepGoal;
  final double distance, distanceGoal;

  final bool showDay;

  const ActivityGoalDay({
    super.key,
    required this.date,
    required this.isSelected,
    required this.onTap,
    required this.calories,
    required this.steps,
    required this.distance,
    required this.calorieGoal,
    required this.stepGoal,
    required this.distanceGoal,
    required this.showDay,
  });
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double _safePct(num v, num goal) {
    if (goal <= 0) return 0;
    final pct = (v / goal) * 100.0;
    if (pct.isNaN || pct.isInfinite) return 0;
    return pct.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);
    final d0 = DateTime(date.year, date.month, date.day);

    // 상태 플래그
    final bool isToday = _isSameDay(d0, today0);
    final bool isFuture = d0.isAfter(today0);

    // 스타일 (선택 > 오늘 > 기본)
    final Color bgColor = isSelected
        ? Colors.white.withValues(alpha: 0.15)
        : (isToday
              ? AppColors.lightPurple.withValues(alpha: 0.2)
              : Colors.transparent);

    final Color borderColor = isSelected ? Colors.white : Colors.transparent;

    final Color textColorTop = isSelected
        ? Colors.white
        : (isToday ? Colors.white : AppColors.lightGray);

    final textVarTop = isSelected
        ? AppFontVariations.semiBold
        : (isToday ? AppFontVariations.medium : AppFontVariations.regular);

    final double caloriePct = _safePct(calories, calorieGoal);
    final double stepsPct = _safePct(steps, stepGoal);
    final double distancePct = _safePct(distance, distanceGoal);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: bgColor,
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          children: [
            SizedBox(
              // width: 24,
              height: 24,
              child: Text(
                "${date.day}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColorTop,
                  fontSize: 14,
                  fontVariations: textVarTop,
                ),
              ),
            ),
            SizedBox(
              // width: 32,
              child: isFuture
                  ? const SizedBox(height: 16)
                  : GoalGraph(
                      caloriePercent: caloriePct,
                      stepsPercent: stepsPct,
                      distancePercent: distancePct,
                      isMini: true,
                    ),
            ),
            if (showDay)
              SizedBox(
                width: 24,
                height: 24,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    getWeekday(date),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColorTop,
                      fontSize: 14,
                      fontVariations: textVarTop,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
