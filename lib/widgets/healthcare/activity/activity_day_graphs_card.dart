import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';
import 'package:picnique_rosary_healthcare_smartring/db/app_db.dart';
import 'package:picnique_rosary_healthcare_smartring/util/graph.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';
import 'package:drift/drift.dart' as drift;
import 'package:picnique_rosary_healthcare_smartring/core/charts/health_chart_theme.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/charts/health_bar_chart.dart';

class ActivityDayGraphsCard extends StatefulWidget {
  final DateTime date;
  final int stepGoal, calorieGoal, steps, calories;
  final double distanceGoal;
  final double distance;

  // 임시로 하고, 나중에 데이터 넘길 때 정수/실수 선택하는 게 맞는 듯

  const ActivityDayGraphsCard({
    super.key,
    required this.date,
    required this.stepGoal,
    required this.calorieGoal,
    required this.distanceGoal,
    required this.calories,
    required this.distance,
    required this.steps,
  });

  @override
  State<ActivityDayGraphsCard> createState() => _ActivityDayGraphsCardState();
}

class _ActivityDayGraphsCardState extends State<ActivityDayGraphsCard> {
  // 시간대별 데이터(0~23시)
  List<BarChartGroupData> hourCalories = [];
  List<BarChartGroupData> hourSteps = [];
  List<BarChartGroupData> hourDistanceKm = [];
  bool _loading = true;
  final now = DateTime.now();

  // ── (A) 공용 유틸: 자정/시간 바닥 ───────────────────────────────────────────
  DateTime _day0(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _hour0(DateTime d) => DateTime(d.year, d.month, d.day, d.hour);
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _loadFor(widget.date);
  }

  @override
  void didUpdateWidget(covariant ActivityDayGraphsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ 날짜가 바뀌면 재조회
    if (!_isSameDay(oldWidget.date, widget.date)) {
      _loadFor(widget.date);
    }
  }

  Future<void> _loadFor(DateTime day) async {
    setState(() => _loading = true);
    await loadHourlySeriesAll(db: DbManager.I.heartDB, day: day);
  }

  // ── (B) 오늘(now) 제거 → day 파라미터로 조회 ───────────────────────────
  Future<void> loadHourlySeriesAll({
    required AppDatabase db,
    required DateTime day,
  }) async {
    final base = _day0(day);
    final next = base.add(const Duration(days: 1));

    final sel = db.select(db.sportDetails)
      ..where((t) => t.date.isBetweenValues(base, next))
      ..orderBy([
        (t) => drift.OrderingTerm(
          expression: t.date,
          mode: drift.OrderingMode.asc,
        ),
      ]);

    final rows = await sel.get();

    // 시간(h) 단위 누적 버킷
    final Map<DateTime, int> stepsAcc = {};
    final Map<DateTime, double> calAcc = {};
    final Map<DateTime, double> distAcc = {};

    for (final r in rows) {
      final k = _hour0(r.date); // 로컬 시각 기준 시간 바닥
      stepsAcc[k] = (stepsAcc[k] ?? 0) + (r.walkSteps + r.runSteps);
      calAcc[k] = ((calAcc[k] ?? 0) + r.calorie) / 1000.0;
      distAcc[k] = (distAcc[k] ?? 0) + (r.distance / 1000.0);
    }

    // ✅ 이 날의 0~23시 키 생성 (day 기준)
    final keys = List<DateTime>.generate(
      24,
      (i) => base.add(Duration(hours: i)),
    );

    // 키 순서대로 FlSpot 시리즈 생성 (없으면 0)
    final stepsSeries = <FlSpot>[];
    final calSeries = <FlSpot>[];
    final distSeries = <FlSpot>[];

    for (final k in keys) {
      // 👉 ActivityBarGraph가 X축을 epoch(ms)로 파싱한다면 아래 줄 유지
      final x = k.millisecondsSinceEpoch.toDouble();

      // 👉 만약 ActivityBarGraph가 0~23 정수 hour를 기대한다면
      // final x = k.hour.toDouble();

      stepsSeries.add(FlSpot(x, (stepsAcc[k] ?? 0).toDouble()));
      calSeries.add(FlSpot(x, (calAcc[k] ?? 0).toDouble()));
      distSeries.add(FlSpot(x, (distAcc[k] ?? 0.0)));
    }
    final fetchedHourCalories = await fetchDayBarGroups(
      dataType: DataType.Kcal,
      anchor: day,
      selectedRange: ToggleRange.day,
      baseStartHour: 0,
      baseStartMinute: 0,
      color: AppColors.pink,
    );
    final fetchedHourSteps = await fetchDayBarGroups(
      dataType: DataType.Steps,
      anchor: day,
      selectedRange: ToggleRange.day,
      baseStartHour: 0,
      baseStartMinute: 0,
      color: AppColors.purple,
    );
    final fetchedHourDistanceKm = await fetchDayBarGroups(
      dataType: DataType.Distance,
      anchor: day,
      selectedRange: ToggleRange.day,
      baseStartHour: 0,
      baseStartMinute: 0,
      color: AppColors.blue,
    );

    if (!mounted) return;
    setState(() {
      hourSteps = fetchedHourSteps;
      hourCalories = fetchedHourCalories;
      hourDistanceKm = fetchedHourDistanceKm;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Column(
      children: [
        ActivityGraphCard(
          hourCalories: hourCalories,
          selectedDate: widget.date,
          dataType: DataType.Kcal,
          title: '칼로리',
          value: (widget.calories / 1000.0),
          goal: (widget.calorieGoal / 1000),
          tooltipColor: AppColors.pink,
          isDataDouble: false,
          unit: 'kcal',
        ),
        const SizedBox(height: 16),
        ActivityGraphCard(
          hourCalories: hourSteps,
          selectedDate: widget.date,
          dataType: DataType.Steps,
          title: '걸음수',
          value: widget.steps,
          goal: widget.stepGoal,
          tooltipColor: AppColors.purple,
          isDataDouble: false,
          unit: '걸음',
        ),
        const SizedBox(height: 16),
        ActivityGraphCard(
          hourCalories: hourDistanceKm,
          selectedDate: widget.date,
          dataType: DataType.Distance,
          title: '거리',
          value: widget.distance,
          goal: widget.distanceGoal,
          tooltipColor: AppColors.blue,
          isDataDouble: true,
          unit: 'km',
        ),
      ],
    );
  }
}

class ActivityGraphCard extends StatelessWidget {
  const ActivityGraphCard({
    super.key,
    required this.hourCalories,
    required this.selectedDate,
    required this.dataType,
    required this.title,
    required this.value,
    required this.goal,
    required this.tooltipColor,
    required this.isDataDouble,
    required this.unit,
  });

  final List<BarChartGroupData> hourCalories;
  final DateTime selectedDate;
  final DataType dataType;
  final String title;
  final num value, goal;
  final Color tooltipColor;
  final bool isDataDouble;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: tooltipColor,
              fontSize: 16,
              fontWeight: AppFontWeight.medium,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: AppFontWeight.bold,
                ),
              ),
              Text(
                " / $goal $unit",
                style: TextStyle(
                  color: AppColors.lightGray,
                  fontSize: 14,
                  fontWeight: AppFontWeight.regular,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: HealthChartTheme.chartHeight * 0.72,
            child: HealthBarChart(
              data: hourCalories,
              dataType: dataType,
              range: ToggleRange.day,
              unit: unit,
              goalLineY: goal.toDouble(),
              selectedDate: selectedDate,
            ),
          ),
        ],
      ),
    );
  }
}
