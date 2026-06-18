import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/health_care_activity_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/util/date.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/activity/activity_goal_day.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/activity/goal_graph.dart';

class ActivityGoalCard extends StatelessWidget {
  final DateTime date; // 현재 선택일
  final ValueChanged<DateTime> onDateChanged;

  final int stepGoal, calorieGoal;
  final double distanceGoal;

  // 선택일 합계(헤더/그래프용)
  final int steps, calories;
  final double distance;

  // ✅ 전체 일자 합계 Map (key = day0)
  final Map<DateTime, ActivityTotals> allTotals;

  const ActivityGoalCard({
    super.key,
    required this.date,
    required this.onDateChanged,
    required this.stepGoal,
    required this.calorieGoal,
    required this.distanceGoal,
    required this.calories,
    required this.distance,
    required this.steps,
    required this.allTotals, // ✅
  });

  DateTime _day0(DateTime d) => DateTime(d.year, d.month, d.day);
  // 일요일 시작 주간(원 코드 로직 유지)
  DateTime get startOfWeek =>
      _day0(date).subtract(Duration(days: date.weekday % 7));
  List<DateTime> get weekDates => List<DateTime>.generate(
    7,
    (index) => startOfWeek.add(Duration(days: index)),
  );

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<DateTime?> showActivityCalendarSheet({
    required BuildContext context,
    required DateTime initialDate,
    required Map<DateTime, dynamic> allTotals,
    required int calorieGoal,
    required int stepGoal,
    required double distanceGoal,
  }) {
    DateTime day0(DateTime d) => DateTime(d.year, d.month, d.day);

    List<DateTime> buildCalendarDays(DateTime month) {
      final first = DateTime(month.year, month.month, 1);
      final startOffset = first.weekday % 7; // 일요일=0
      final start = first.subtract(Duration(days: startOffset));
      return List.generate(42, (i) => day0(start.add(Duration(days: i))));
    }

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true, // ⚙️ 모달을 더 크게 쓸 수 있게
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: Colors.white24, width: 2), // ⚙️ 테두리 추가
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        DateTime viewMonth = DateTime(initialDate.year, initialDate.month);
        DateTime selected = day0(initialDate);

        return FractionallySizedBox(
          // ⚙️ 모달 높이 제한 (필요시 0.8~0.95로 조절)
          heightFactor: 0.7,
          child: SafeArea(
            top: false,
            child: StatefulBuilder(
              builder: (ctx, setState) {
                final days = buildCalendarDays(viewMonth);
                String monthTitle =
                    "${viewMonth.year}.${viewMonth.month.toString().padLeft(2, '0')}";
                const dow = ["일", "월", "화", "수", "목", "금", "토"];

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    24,
                    16,
                    16 + MediaQuery.of(ctx).padding.bottom, // ⚙️ 바텀 세이프패딩
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max, // ⚙️ 가용 높이 꽉 채우기
                    children: [
                      // 헤더
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              final m = DateTime(
                                viewMonth.year,
                                viewMonth.month - 1,
                              );
                              setState(
                                () => viewMonth = DateTime(m.year, m.month),
                              );
                            },
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                monthTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontVariations: AppFontVariations.semiBold,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              final m = DateTime(
                                viewMonth.year,
                                viewMonth.month + 1,
                              );
                              setState(
                                () => viewMonth = DateTime(m.year, m.month),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 요일 라벨
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children:
                            List.generate(7, (i) {
                              return Expanded(
                                child: Center(
                                  child: Text(
                                    // dow[i]
                                    dow[i],
                                    // 위 Center의 child를 Text(dow[i], ...)로 바꿔주세요.
                                    // (코드 블록 축약을 위해 빈 문자열 넣었습니다.)
                                    style: TextStyle(
                                      color: AppColors.lightGray,
                                      fontSize: 12,
                                      fontVariations: AppFontVariations.regular,
                                    ),
                                  ),
                                ),
                              );
                            }).asMap().entries.map((e) {
                              return Expanded(
                                child: Center(
                                  child: Text(
                                    dow[e.key],
                                    style: const TextStyle(
                                      color: AppColors.lightGray,
                                      fontSize: 12,
                                      fontVariations: AppFontVariations.regular,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 8),

                      // ⚙️ Grid는 Expanded로 감싸 스크롤 가능하게
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: days.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 0.85,
                              ),
                          itemBuilder: (_, idx) {
                            final d = days[idx];
                            final isInMonth = d.month == viewMonth.month;
                            final totals = allTotals[day0(d)];
                            final calories = (totals?.calories ?? 0) as int;
                            final steps = (totals?.steps ?? 0) as int;
                            final distanceKm =
                                (totals?.distanceKm ?? 0.0) as double;

                            return Opacity(
                              opacity: isInMonth ? 1.0 : 0.35,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: 60,
                                  child: ActivityGoalDay(
                                    date: d,
                                    isSelected:
                                        d.year == selected.year &&
                                        d.month == selected.month &&
                                        d.day == selected.day,
                                    onTap: () {
                                      selected = d;
                                      Navigator.of(ctx).pop<DateTime>(d);
                                    },
                                    calories: calories,
                                    steps: steps,
                                    distance: distanceKm,
                                    calorieGoal: calorieGoal,
                                    stepGoal: stepGoal,
                                    distanceGoal: distanceGoal,
                                    showDay: false,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더: 선택된 날짜
          Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: Text(
                  "${date.month}월 ${date.day}일 (${getWeekday(date)})",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontVariations: AppFontVariations.semiBold,
                  ),
                ),
              ),
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                child: IconButton(
                  icon: const Icon(
                    Icons.calendar_month,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () async {
                    // 필요한 값들은 현재 화면에서 갖고 있는 걸 넘겨주세요
                    final picked = await showActivityCalendarSheet(
                      context: context,
                      initialDate: date, // 현재 선택된 날짜
                      allTotals:
                          allTotals, // Map<DateTime, Totals> (아래 helper가 day0 키로 접근)
                      calorieGoal: calorieGoal,
                      stepGoal: stepGoal,
                      distanceGoal: distanceGoal,
                    );
                    if (picked != null) {
                      onDateChanged(picked); // 모달에서 고른 날짜로 변경
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 주간 칩(각 날짜 값은 allTotals에서 직접 꺼냄)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in weekDates)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                      ), // 칩 사이 간격
                      child: ActivityGoalDay(
                        date: d,
                        isSelected: _isSameDay(d, date),
                        onTap: () => onDateChanged(d),
                        calories: (allTotals[_day0(d)]?.calories ?? 0),
                        steps: (allTotals[_day0(d)]?.steps ?? 0),
                        distance: (allTotals[_day0(d)]?.distanceKm ?? 0),
                        calorieGoal: calorieGoal,
                        stepGoal: stepGoal,
                        distanceGoal: distanceGoal,
                        showDay: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 선택일 누적 % 그래프
          GoalGraph(
            caloriePercent:
                (calories / (calorieGoal == 0 ? 1 : calorieGoal)) * 100,
            stepsPercent: (steps / (stepGoal == 0 ? 1 : stepGoal)) * 100,
            distancePercent:
                (distance / (distanceGoal == 0 ? 1 : distanceGoal)) * 100,
            isMini: false,
          ),
          const SizedBox(height: 24),

          // 선택일 수치
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Metric(
                label: "칼로리",
                value: (calories / 1000.0).toString(),
                goal: "/ ${(calorieGoal / 1000).toInt()} kcal",
                color: AppColors.pink,
              ),
              _Metric(
                label: "걸음수",
                value: steps.toString(),
                goal: "/ $stepGoal",
                color: AppColors.purple,
              ),
              _Metric(
                label: "거리",
                value: distance.toString(),
                goal: "/ $distanceGoal km",
                color: AppColors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label, value, goal;
  final Color color;
  const _Metric({
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontVariations: AppFontVariations.semiBold,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontVariations: AppFontVariations.bold,
          ),
        ),
        Text(
          goal,
          style: TextStyle(
            color: AppColors.lightGray,
            fontSize: 12,
            fontVariations: AppFontVariations.medium,
          ),
        ),
      ],
    );
  }
}
