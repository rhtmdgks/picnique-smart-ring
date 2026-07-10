import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/db/app_db.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/util/BLEUtil.dart';
import 'package:picnique_rosary_healthcare_smartring/util/TrendUtil.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/activity/activity_day_graphs_card.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/activity/activity_goal_card.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/health_message.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_live_activity.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;

class ActivityTotals {
  final int steps; // walk+run
  final int calories; // kcal
  final double distanceKm;
  const ActivityTotals({
    required this.steps,
    required this.calories,
    required this.distanceKm,
  });
}

class HealthCareActivityScreen extends StatefulWidget {
  const HealthCareActivityScreen({super.key});
  @override
  State<HealthCareActivityScreen> createState() =>
      _HealthCareActivityScreenState();
}

class _HealthCareActivityScreenState extends State<HealthCareActivityScreen> {
  // 목표값
  final int stepGoal = 10000;
  final int calorieGoal = 300000;
  final double distanceGoal = 3;

  DateTime _selectedDate = DateTime.now();

  // 선택일 합계
  int? _steps, _calories;
  double? _distanceKm;

  // ✅ 전체 일자별 합계 (key = day0)
  Map<DateTime, ActivityTotals> _totalsByDay = {};

  bool _loading = true;
  final platform = const MethodChannel('com.example.picnique_ring/ble');
  RingLiveActivity? _liveActivity;

  late final Future<String> _healthMessageFuture =
      Future.wait([
        getStepBaselineMessageFromDb(),
        getStepGoalMessageFromDb(),
      ]).then(
        (messages) =>
            "평균 걸음수: ${messages[0] ?? "(충분한 데이터가 모이지 않았습니다.)"}\n목표 대비: ${messages[1] ?? "(충분한 데이터가 모이지 않았습니다.)"}",
      );

  @override
  void initState() {
    super.initState();
    _syncThenLoadAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final live = context.read<RingLiveActivity>();
    if (_liveActivity != live) {
      _liveActivity?.removeListener(_onLiveActivityChanged);
      _liveActivity = live;
      _liveActivity?.addListener(_onLiveActivityChanged);
    }
  }

  @override
  void dispose() {
    _liveActivity?.removeListener(_onLiveActivityChanged);
    super.dispose();
  }

  bool _isSelectedToday() => _day0(_selectedDate) == _day0(DateTime.now());

  void _onLiveActivityChanged() {
    if (!mounted || !_isSelectedToday()) return;
    final ring = context.read<Ring>();
    final live = _liveActivity;
    if (!ring.isConnected || live == null || !live.isTracking) return;

    final today = _day0(DateTime.now());
    final totals = ActivityTotals(
      steps: live.steps,
      calories: live.calories,
      distanceKm: live.distanceMeters / 1000.0,
    );

    setState(() {
      _steps = totals.steps;
      _calories = totals.calories;
      _distanceKm = totals.distanceKm;
      _totalsByDay = {..._totalsByDay, today: totals};
    });
  }

  DateTime _day0(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _syncThenLoadAll() async {
    setState(() => _loading = true);
    try {
      // Pull 0x43 slots into SportDetails (was stub no-op after Dart BLE).
      await syncRecent3DaysSportDetailsToDb(platform);
      if (!mounted) return;
      // Refresh live today totals (initState race: live may bind in didChangeDependencies).
      final live = _liveActivity ?? context.read<RingLiveActivity>();
      await live.refresh();

      await _loadAllTotalsByDay(DbManager.I.heartDB);

      if (!mounted) return;
      _applySelected(_selectedDate);
      _onLiveActivityChanged();
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _steps = 0;
        _calories = 0;
        _distanceKm = 0;
        _totalsByDay = {};
        _loading = false;
      });
    }
  }

  // ✅ 전체 기간(필요 시 start/end로 제한 가능) 일자별 합계 Map 만들기
  Future<void> _loadAllTotalsByDay(
    AppDatabase db, {
    DateTime? start,
    DateTime? end,
  }) async {
    final sel = db.select(db.sportDetails);

    if (start != null && end != null) {
      sel.where((t) => t.date.isBetweenValues(start, end));
    } else if (start != null) {
      sel.where((t) => t.date.isBiggerOrEqual(drift.Variable(start)));
    } else if (end != null) {
      sel.where((t) => t.date.isSmallerThan(drift.Variable(end)));
    }

    sel.orderBy([
      (t) =>
          drift.OrderingTerm(expression: t.date, mode: drift.OrderingMode.asc),
    ]);

    final rows = await sel.get();

    final Map<DateTime, int> stepsPerDay = {};
    final Map<DateTime, int> calPerDay = {};
    final Map<DateTime, int> distMPerDay = {};

    for (final r in rows) {
      final k = _day0(r.date);
      stepsPerDay[k] = (stepsPerDay[k] ?? 0) + (r.walkSteps + r.runSteps);
      calPerDay[k] = (calPerDay[k] ?? 0) + r.calorie;
      distMPerDay[k] = (distMPerDay[k] ?? 0) + r.distance;
    }

    final Map<DateTime, ActivityTotals> map = {};
    for (final k in {
      ...stepsPerDay.keys,
      ...calPerDay.keys,
      ...distMPerDay.keys,
    }) {
      final steps = stepsPerDay[k] ?? 0;
      final cals = calPerDay[k] ?? 0;
      final distKm = (distMPerDay[k] ?? 0) / 1000.0;
      map[k] = ActivityTotals(steps: steps, calories: cals, distanceKm: distKm);
    }

    if (!mounted) return;
    setState(() {
      _totalsByDay = map;
    });
  }

  // ✅ 날짜 변경 시: DB 재조회 없이 Map에서 꺼내 반영
  void _applySelected(DateTime day) {
    final key = _day0(day);
    final t =
        _totalsByDay[key] ??
        const ActivityTotals(steps: 0, calories: 0, distanceKm: 0);
    setState(() {
      _selectedDate = day;
      _steps = t.steps;
      _calories = t.calories;
      _distanceKm = t.distanceKm;
      _loading = false;
    });
  }

  // ✅ GoalCard → 부모 콜백
  void _onDateChanged(DateTime newDate) {
    _applySelected(newDate);
  }

  @override
  Widget build(BuildContext context) {
    final bool notReady =
        _loading || _steps == null || _calories == null || _distanceKm == null;

    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SubAppBar(title: "활동"),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: notReady
              ? const Center(
                  child: SizedBox(
                    height: 48,
                    width: 48,
                    child: CircularProgressIndicator(),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      FutureBuilder<String>(
                        future: _healthMessageFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }
                          if (snapshot.hasError || !snapshot.hasData) {
                            return const Text("Error loading messages");
                          }
                          return HealthMessageCard(message: snapshot.data!);
                        },
                      ),
                      const SizedBox(height: 16),
                      ActivityGoalCard(
                        date: _selectedDate,
                        onDateChanged: _onDateChanged,
                        // ✅ 전체 일자 합계 맵 전달
                        allTotals: _totalsByDay,

                        stepGoal: stepGoal,
                        calorieGoal: calorieGoal,
                        distanceGoal: distanceGoal,

                        // 선택일 합계
                        steps: _steps!,
                        calories: _calories!,
                        distance: _distanceKm!,
                      ),
                      const SizedBox(height: 16),
                      ActivityDayGraphsCard(
                        date: _selectedDate,
                        stepGoal: stepGoal,
                        calorieGoal: calorieGoal,
                        distanceGoal: distanceGoal,
                        steps: _steps!,
                        calories: _calories!,
                        distance: _distanceKm!,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
