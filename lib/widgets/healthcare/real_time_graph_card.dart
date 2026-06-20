import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/date.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/sleep.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';
import 'package:picnique_rosary_healthcare_smartring/core/models/sleep.dart';
import 'package:picnique_rosary_healthcare_smartring/db/app_db.dart';
import 'package:picnique_rosary_healthcare_smartring/util/BLEUtil.dart';
import 'package:picnique_rosary_healthcare_smartring/util/graph.dart';
import 'package:picnique_rosary_healthcare_smartring/util/sleep.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/charts/health_area_line_chart.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/charts/health_bar_chart.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/charts/health_sleep_timeline_chart.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/charts/health_sleep_stacked_chart.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/range_toggle.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_data_refresh_notifier.dart';
import 'package:provider/provider.dart';
import 'package:picnique_rosary_healthcare_smartring/core/charts/health_chart_theme.dart';
import 'package:drift/drift.dart' hide Column;

// [ ]: 나중에 그래프 별로 분리하기...
// [ ]: 로딩 로직...
// [ ]: 연결 안 됐을 때
class SleepStackBar {
  final DateTime x; // 막대의 기준 시각(일/월/버킷 시작)
  final int deep; // 분
  final int light; // 분
  final int rem; // 분
  final int awake; // 분

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

class _GraphData {
  final List<SleepData> daily; // 일 단위(주/월 그래프 입력)
  final List<SleepMonthData> monthLike; // 일 인덱스 기반(반년/연간 그래프 입력)
  const _GraphData({required this.daily, required this.monthLike});
}

Future<DateTime?> showActivityCalendarSheet({
  required BuildContext context,
  required DateTime initialDate,
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
                                fontWeight: AppFontWeight.semiBold,
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
                                    fontWeight: AppFontWeight.regular,
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
                                    fontWeight: AppFontWeight.regular,
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

                          return InkWell(
                            onTap: () {
                              selected = d;
                              Navigator.of(ctx).pop<DateTime>(d);
                            },
                            child: Opacity(
                              opacity: isInMonth ? 1.0 : 0.35,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    border: selected == d
                                        ? Border.all(color: Colors.white)
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  width: 60,
                                  height: 80,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 4,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d.day.toString(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: AppFontWeight.regular,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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

Future<_GraphData> _loadGraphDataFromDb(
  AppDatabase db,
  ToggleRange r, {
  DateTime? anchorDate,
}) async {
  final sw = Stopwatch()..start();
  void log(String m) => debugPrint('[SleepGraph] $m');

  // 범위별 일 수 결정
  final days = switch (r) {
    ToggleRange.day => 1,
    ToggleRange.week => 7,
    ToggleRange.month => 30,
    ToggleRange.halfYear => 90,
  };
  log('load start | range=$r, days=$days, anchorDate=$anchorDate');

  // anchorDate가 있으면(일 단위에서 날짜 선택) 해당 날짜 기준, 없으면 DB 최신 날짜 기준
  DateTime lastDay0;
  if (anchorDate != null) {
    lastDay0 = _day0(anchorDate);
  } else {
    final latest =
        await (db.select(db.sleepDetails)
              ..orderBy([
                (t) =>
                    OrderingTerm(expression: t.date, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .getSingleOrNull();

    if (latest == null) {
      log('no data in sleepDetails → return empty');
      sw.stop();
      log('done in ${sw.elapsedMilliseconds}ms');
      return const _GraphData(daily: [], monthLike: []);
    }

    lastDay0 = _day0(latest.date); // yyyy-MM-dd 00:00
  }

  final firstDay0 = lastDay0.subtract(Duration(days: days - 1));
  final windowStart = r == ToggleRange.day
      ? firstDay0.subtract(const Duration(days: 1))
      : firstDay0;
  final endExclusive = lastDay0.add(const Duration(days: 1));
  log(
    'window: ${windowStart.toIso8601String()} ~ ${lastDay0.toIso8601String()} (end < ${endExclusive.toIso8601String()})',
  );

  // 날짜 컬럼 기준으로 [firstDay0, lastDay0] 포함 조회
  final rows =
      await (db.select(db.sleepDetails)
            ..where(
              (t) =>
                  t.date.isBiggerOrEqualValue(windowStart) &
                  t.date.isSmallerThanValue(endExclusive),
            )
            ..orderBy([
              (t) => OrderingTerm(expression: t.date, mode: OrderingMode.asc),
              (t) => OrderingTerm(expression: t.start, mode: OrderingMode.asc),
            ]))
          .get();

  log('fetched rows: ${rows.length}');
  // 타입별 건수
  final typeCounts = <int, int>{};
  for (final r in rows) {
    typeCounts.update(r.type, (v) => v + 1, ifAbsent: () => 1);
  }
  log(
    'type counts: ${typeCounts.entries.map((e) => '${e.key}:${e.value}').join(', ')}',
  );

  // 날짜별 그룹핑 및 매핑/스킵 통계
  final byDay = <DateTime, List<SleepStage>>{};
  var accepted = 0, skipped = 0;
  for (final e in rows) {
    final mapped = _mapDbRowToStage(e);
    if (mapped == null) {
      skipped++;
      continue; // awake 등은 스킵
    }
    // 자정 이후까지 걸치는 경우 일자별로 잘라서 저장
    var segStart = mapped.startTime;
    final segEnd = mapped.endTime;
    while (segStart.isBefore(segEnd)) {
      final dayKey = _day0(segStart);
      final dayEnd = dayKey.add(const Duration(days: 1));
      final cutEnd = segEnd.isBefore(dayEnd) ? segEnd : dayEnd;
      final clipped = SleepStage(
        startTime: segStart,
        endTime: cutEnd,
        sleepType: mapped.sleepType,
      );
      (byDay[dayKey] ??= []).add(clipped);
      accepted++;
      segStart = cutEnd;
    }
  }
  log(
    'mapped stages | accepted=$accepted, skipped=$skipped, groupedDays=${byDay.length}',
  );

  // 일 단위 그래프용 리스트(SleepData)
  final daily = byDay.entries.map((kv) {
    // 안전: 섹션 시간 순 정렬 및 잘못된 구간 보정
    final stages = kv.value..sort((a, b) => a.startTime.compareTo(b.startTime));
    final fixed = stages
        .map(
          (s) => s.endTime.isAfter(s.startTime)
              ? s
              : SleepStage(
                  startTime: s.endTime,
                  endTime: s.startTime,
                  sleepType: s.sleepType,
                ),
        )
        .toList();
    return SleepData(date: kv.key, sleep: fixed);
  }).toList()..sort((a, b) => a.date.compareTo(b.date));

  log(
    'daily days=${daily.length}${daily.isNotEmpty ? ', sample=${daily.take(3).map((d) => '${_day0(d.date)}(${d.sleep.length})').join(', ')}' : ''}',
  );

  // 3개월 그래프용: 월 인덱스 기반 SleepMonthData (빈 달도 포함)
  final monthLike = <SleepMonthData>[];
  if (r == ToggleRange.halfYear) {
    const monthsCount = 3;
    final lastMonth = DateTime(lastDay0.year, lastDay0.month, 1);
    final oldestMonthStart = DateTime(
      lastMonth.year,
      lastMonth.month - (monthsCount - 1),
      1,
    );

    final grouped = <String, List<SleepStage>>{};
    for (final d in daily) {
      final mStart = DateTime(d.date.year, d.date.month, 1);
      final key =
          '${mStart.year.toString().padLeft(4, '0')}-${mStart.month.toString().padLeft(2, '0')}';
      grouped
          .putIfAbsent(key, () => <SleepStage>[])
          .addAll(_clipStagesToDay(d.sleep, d.date));
    }

    for (int i = 0; i < monthsCount; i++) {
      final mStart = DateTime(
        oldestMonthStart.year,
        oldestMonthStart.month + i,
      );
      final key =
          '${mStart.year.toString().padLeft(4, '0')}-${mStart.month.toString().padLeft(2, '0')}';
      final stages = grouped[key] ?? const <SleepStage>[];
      monthLike.add(SleepMonthData(date: i, sleep: stages));
    }
    log(
      'monthLike count=${monthLike.length}, base=${oldestMonthStart.toIso8601String()}, lastMonth=${lastMonth.toIso8601String()}',
    );
  }

  sw.stop();
  log('done in ${sw.elapsedMilliseconds}ms');

  return _GraphData(daily: daily, monthLike: monthLike);
}

DateTime _day0(DateTime d) => DateTime(d.year, d.month, d.day);

/// DB row -> 앱의 SleepStage 매핑 (awake/미지원 타입은 null로 스킵)
SleepStage? _mapDbRowToStage(SleepDetail e) {
  final st = e.start;
  final en = e.end;
  final type = switch (e.type) {
    3 => SleepType.deep,
    2 => SleepType.shallow,
    4 => SleepType.rem,
    5 => SleepType.awake,
    _ => null, // 1/5 등은 시각화에서 제외
  };
  if (type == null) return null;
  return SleepStage(startTime: st, endTime: en, sleepType: type);
}

/// 자정~자정(+1d) 범위를 넘어가는 구간을 당일로 클리핑
List<SleepStage> _clipStagesToDay(List<SleepStage> src, DateTime day) {
  final start0 = _day0(day);
  final end0 = start0.add(const Duration(days: 1));

  final out = <SleepStage>[];
  for (final s in src) {
    final st = s.startTime.isBefore(start0) ? start0 : s.startTime;
    final en = s.endTime.isAfter(end0) ? end0 : s.endTime;
    if (en.isAfter(st)) {
      out.add(SleepStage(startTime: st, endTime: en, sleepType: s.sleepType));
    }
  }
  // 시간 순 정렬
  out.sort((a, b) => a.startTime.compareTo(b.startTime));
  return out;
}

double _calculateAverage(Iterable<double> values, {bool excludeZero = true}) {
  final validValues = values
      .where((y) => !y.isNaN && !y.isInfinite && (!excludeZero || y != 0))
      .toList();

  if (validValues.isEmpty) return double.nan;
  return validValues.reduce((a, b) => a + b) / validValues.length;
}

double _averageOfBarGroups(
  List<BarChartGroupData> groups, {
  bool excludeZero = true,
}) {
  if (groups.isEmpty) return double.nan;

  final values = groups.expand((g) => g.barRods.map((rod) => rod.toY));
  return _calculateAverage(values, excludeZero: excludeZero);
}

double _averageOfDotGroups(List<FlSpot> groups, {bool excludeZero = true}) {
  if (groups.isEmpty) return double.nan;

  final values = groups.map((g) => g.y);
  return _calculateAverage(values, excludeZero: excludeZero);
}

List<BarChartGroupData> _buildMonthlySleepAverageBars({
  required List<SleepData> daily,
  required int months,
  required DateTime anchor,
  required double width,
}) {
  DateTime monthStart(DateTime d) => DateTime(d.year, d.month, 1);

  final lastMonthStart = monthStart(anchor);
  final oldestMonthStart = DateTime(
    lastMonthStart.year,
    lastMonthStart.month - (months - 1),
    1,
  );

  int monthDiff(DateTime a, DateTime b) =>
      (a.year - b.year) * 12 + (a.month - b.month);

  final monthlySums = List.generate(
    months,
    (_) => {'shallow': 0, 'rem': 0, 'deep': 0, 'awake': 0, 'days': 0},
  );

  for (final day in daily) {
    final mStart = monthStart(day.date);
    final idx = monthDiff(mStart, oldestMonthStart);
    if (idx < 0 || idx >= months) continue;

    int shallow = 0, rem = 0, deep = 0, awake = 0;
    for (final s in day.sleep) {
      final dur = s.endTime.difference(s.startTime).inMinutes;
      switch (s.sleepType) {
        case SleepType.shallow:
          shallow += dur;
          break;
        case SleepType.rem:
          rem += dur;
          break;
        case SleepType.deep:
          deep += dur;
          break;
        case SleepType.awake:
          awake += dur;
          break;
      }
    }
    final totalDay = shallow + rem + deep + awake;
    if (totalDay > 0) {
      monthlySums[idx]['shallow'] = monthlySums[idx]['shallow']! + shallow;
      monthlySums[idx]['rem'] = monthlySums[idx]['rem']! + rem;
      monthlySums[idx]['deep'] = monthlySums[idx]['deep']! + deep;
      monthlySums[idx]['awake'] = monthlySums[idx]['awake']! + awake;
      monthlySums[idx]['days'] = monthlySums[idx]['days']! + 1;
    }
  }

  final groups = <BarChartGroupData>[];
  for (int i = 0; i < months; i++) {
    final m = monthlySums[i];
    final days = m['days']!;
    if (days == 0) {
      groups.add(BarChartGroupData(x: i, barRods: []));
      continue;
    }

    double toMs(int minutes) => minutes * 60 * 1000.0;
    final avgShallow = toMs((m['shallow']! / days).round());
    final avgRem = toMs((m['rem']! / days).round());
    final avgDeep = toMs((m['deep']! / days).round());
    final avgAwake = toMs((m['awake']! / days).round());

    double cursor = 0;
    final stacks = <BarChartRodStackItem>[
      BarChartRodStackItem(cursor, cursor += avgAwake, AppColors.lightGray),
      BarChartRodStackItem(cursor, cursor += avgShallow, AppColors.lightPurple),
      BarChartRodStackItem(cursor, cursor += avgRem, AppColors.purple),
      BarChartRodStackItem(cursor, cursor += avgDeep, AppColors.darkPurple),
    ];

    groups.add(
      BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            fromY: 0,
            toY: cursor,
            rodStackItems: stacks,
            width: width,
            borderRadius: BorderRadius.circular(4),
            color: Colors.transparent,
          ),
        ],
      ),
    );
  }

  return groups;
}

class RealTimeGraphCard extends StatefulWidget {
  final String unit;
  final ToggleRange selectedRange;
  final void Function(ToggleRange) onChanged;
  final GraphType barType;
  final double Function(double, double) intervalYFunc;
  final DataType dataType;
  final Widget? widget;

  const RealTimeGraphCard({
    super.key,
    required this.unit,
    required this.selectedRange,
    required this.onChanged,
    required this.barType,
    required this.intervalYFunc,
    required this.dataType,
    this.widget,
  });

  @override
  State<RealTimeGraphCard> createState() => _RealTimeGraphCardState();
}

class _RealTimeGraphCardState extends State<RealTimeGraphCard> {
  // DB 기반 시리즈 캐시
  List<FlSpot> _dotGroups = [];

  List<BarChartGroupData> barData = [];

  bool _dbLoading = false;
  int score = 0;

  DateTime selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    0,
    0,
    0,
  );

  _GraphData _stackedData = const _GraphData(daily: [], monthLike: []);
  ToggleRange? _stackedRangeMemo;
  DateTime? _stackedDateMemo; // day 범위일 때 로드한 기준 날짜
  int? _stackedBarScore; // day 범위일 때 선택된 날짜의 수면 점수
  bool _stackedLoaded = false;
  DateTime? _stackedAnchor;

  DateTime? _monthBaseStart;

  String windowXLabel = '';

  HealthDataRefreshNotifier? _healthRefresh;

  @override
  void initState() {
    super.initState();
    _stackedAnchor = selectedDate;
    refreshDB(anchor: selectedDate);
    // [ ]: 하드 코딩 없애기...
    if (widget.dataType == DataType.Sleep || widget.barType == GraphType.dot) {
      if (barData.isNotEmpty) {
        windowXLabel = getWindowXLabel(
          widget.selectedRange == ToggleRange.day
              ? selectedDate
              : getDateTimeFromIndex(
                  barData.first.x.toInt(),
                  widget.selectedRange,
                  widget.dataType,
                ),
          getWindowX(widget.selectedRange, widget.dataType),
          widget.selectedRange,
          widget.dataType,
        );
      } else {
        windowXLabel = _rangeLabel(widget.selectedRange);
      }
    } else {
      windowXLabel = _rangeLabel(widget.selectedRange);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachHealthRefresh());
  }

  void _attachHealthRefresh() {
    if (!mounted) return;
    final next = context.read<HealthDataRefreshNotifier>();
    if (identical(_healthRefresh, next)) return;
    _healthRefresh?.removeListener(_onHealthDataChanged);
    _healthRefresh = next;
    _healthRefresh!.addListener(_onHealthDataChanged);
  }

  void _onHealthDataChanged() {
    if (_healthRefresh?.affects(widget.dataType) ?? false) {
      refreshDB(anchor: selectedDate);
    }
  }

  @override
  void dispose() {
    _healthRefresh?.removeListener(_onHealthDataChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RealTimeGraphCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRange != widget.selectedRange) {
      refreshDB(anchor: selectedDate);
    }
  }

  DateTime _calcMonthBaseStart(DateTime anchor, ToggleRange range) {
    switch (range) {
      case ToggleRange.halfYear:
        {
          final lastMonth = DateTime(anchor.year, anchor.month, 1);
          return DateTime(lastMonth.year, lastMonth.month - 2, 1);
        }
      case ToggleRange.day:
      case ToggleRange.week:
      case ToggleRange.month:
        {
          final day0 = _day0(anchor);
          return DateTime(day0.year, day0.month, 1);
        }
    }
  }

  void refreshDB({DateTime? anchor}) {
    if (anchor != null) {
      _stackedAnchor = anchor;
      _stackedData = const _GraphData(daily: [], monthLike: []);
      _stackedLoaded = false;
      _monthBaseStart = null;
    }
    switch (widget.barType) {
      case GraphType.bar:
      case GraphType.dot:
        _fetchBarDB(widget.selectedRange);
        break;
      case GraphType.stackedBar:
        _refreshDbSeries(widget.selectedRange);
        break;
    }
  }

  // 범위에 맞게 DB 데이터 로드
  Future<void> _refreshDbSeries(ToggleRange range, {DateTime? anchor}) async {
    setState(() => _dbLoading = true);
    try {
      final dayAnchor = anchor ?? selectedDate;
      switch (range) {
        case ToggleRange.day:
          _dotGroups = await _fetchDaySeries(dayAnchor);
          break;
        case ToggleRange.week:
          _dotGroups = await _fetchDailyAggregates(days: 7);
          break;
        case ToggleRange.month:
          _dotGroups = await _fetchDailyAggregates(days: 30);
          break;
        case ToggleRange.halfYear:
          _dotGroups = await _fetchMonthlyAggregates(months: 3);
          break;
      }
    } catch (_) {
      _dotGroups = [];
    } finally {
      if (mounted) setState(() => _dbLoading = false);
    }
    final s = await computeSleepScoreFromDb();
    debugPrint('[SLEEP_SCORE] $s');
    score = (s['S_total'] as num?)?.toInt() ?? 0;
  }

  // 범위에 맞게 DB 데이터 로드
  Future<void> _fetchBarDB(ToggleRange range) async {
    setState(() => _dbLoading = true);
    final endDate = DateTime.now();
    try {
      switch (range) {
        case ToggleRange.day:
          final now = DateTime.now();
          final isToday =
              selectedDate.year == now.year &&
              selectedDate.month == now.month &&
              selectedDate.day == now.day;
          final int baseEndHour;
          final int baseEndMinute;
          if (isToday) {
            baseEndHour = now.hour;
            baseEndMinute = now.minute;
          } else {
            baseEndHour = 24;
            baseEndMinute = 0;
          }
          barData = await fetchDayBarGroups(
            dataType: widget.dataType,
            anchor: selectedDate,
            selectedRange: widget.selectedRange,
            baseStartHour: widget.dataType.startOfDay,
            baseStartMinute: 0,
            baseEndHour: baseEndHour,
            baseEndMinute: baseEndMinute,
          );
          break;
        case ToggleRange.week:
        case ToggleRange.month:
          barData = await fetchDailyBarGroups(
            endDate: endDate,
            dataType: widget.dataType,
            selectedRange: widget.selectedRange,
          );
          break;
        case ToggleRange.halfYear:
          barData = await fetchMonthlyBarGroups(
            endDate: endDate,
            dataType: widget.dataType,
            selectedRange: widget.selectedRange,
          );
          break;
      }
    } catch (_) {
      barData = [];
    } finally {
      if (mounted) setState(() => _dbLoading = false);
    }
  }

  DateTime _startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  DateTime _endOfDay(DateTime dt) =>
      _startOfDay(dt).add(const Duration(days: 1));
  // -------------------------------
  // 공통 헬퍼: (DateTime, int) 쌍을 범위로 가져오기
  // -------------------------------
  Future<List<MapEntry<DateTime, int>>> _fetchRawRange({
    DateTime? start,
    DateTime? end,
  }) async {
    final db = DbManager.I.heartDB;

    // 범위 where 절 공통 적용을 위해 헬퍼
    // Drift의 select(builder) 패턴이 타입마다 달라서 case별로 처리
    switch (widget.dataType) {
      case DataType.HeartRate:
      case DataType.Kcal:
      case DataType.Distance:
      case DataType.Steps:
        {
          final q = db.select(db.heartDetails);
          if (start != null && end != null) {
            q.where((t) => t.date.isBetweenValues(start, end));
          }
          final rows = await q.get();
          return rows.map((r) => MapEntry(r.date, (r.bpm))).toList();
        }
      case DataType.Stress:
        {
          final q = db.select(db.stressDetails);
          if (start != null && end != null) {
            q.where((t) => t.date.isBetweenValues(start, end));
          }
          final rows = await q.get();
          return rows.map((r) => MapEntry(r.date, r.stress)).toList();
        }
      case DataType.Oxygen:
        {
          final q = db.select(db.bloodOxygenDetails);
          if (start != null && end != null) {
            q.where((t) => t.date.isBetweenValues(start, end));
          }
          final rows = await q.get();
          return rows.map((r) => MapEntry(r.date, r.spo2)).toList();
        }
      case DataType.Rosary:
        {
          final appDb = DbManager.I.appDB;
          final q = appDb.select(appDb.rosarySessions);
          if (start != null && end != null) {
            q.where((t) => t.startAt.isBetweenValues(start, end));
          }
          final rows = await q.get();
          return rows.map((r) => MapEntry(r.startAt, r.tapCount)).toList();
        }
      case DataType.Sleep:
        {
          // 주의: sleepDetails가 heartDB에 포함되어 있다고 가정합니다.
          // 만약 별도 DB라면 DbManager.I.sleepDB로 바꿔주세요.
          final q = db.select(db.sleepDetails);
          if (start != null && end != null) {
            q.where((t) => t.date.isBetweenValues(start, end));
          }
          final rows = await q.get();

          // 날짜(로컬 00:00 기준)별 총 수면 분을 누적
          final Map<DateTime, int> totalSleepMinByDay = {};
          for (final r in rows) {
            // r.date: 해당 세그먼트가 속한 '날짜'(로컬 00:00), DB 설계상 이미 start의 로컬 날짜로 저장되어 있다고 가정
            final dayKey = DateTime(r.date.year, r.date.month, r.date.day);

            // 세그먼트 길이(분)
            final segMin = r.end.difference(r.start).inMinutes;
            if (segMin <= 0) continue;

            // 타입: 2=Light, 3=Deep, 4=Rem, 5=Awake
            // 총 수면 시간에는 Awake(5)는 제외합니다.
            final addMin = (r.type == 2 || r.type == 3 || r.type == 4)
                ? segMin
                : 0;

            if (addMin > 0) {
              totalSleepMinByDay.update(
                dayKey,
                (prev) => prev + addMin,
                ifAbsent: () => addMin,
              );
            } else {
              totalSleepMinByDay.putIfAbsent(
                dayKey,
                () => totalSleepMinByDay[dayKey] ?? 0,
              );
            }
          }

          // 그래프 공통 파이프라인(MapEntry<DateTime,int>)에 맞춰 반환
          return totalSleepMinByDay.entries.toList();
        }
    }
  }

  // -------------------------------
  // 하루(오늘 기준 anchor)의 원시 시계열
  // -------------------------------
  Future<List<FlSpot>> _fetchDaySeries(DateTime anchor) async {
    final start = _startOfDay(anchor);
    final end = DateTime.now();

    final pairs = await _fetchRawRange(start: start, end: end);
    pairs.sort((a, b) => a.key.compareTo(b.key));

    final spots = <FlSpot>[];
    for (final e in pairs) {
      final v = e.value;
      if (v <= 0) continue;
      spots.add(FlSpot(e.key.millisecondsSinceEpoch.toDouble(), v.toDouble()));
    }
    if (spots.isNotEmpty) {
      final a = DateTime.fromMillisecondsSinceEpoch(
        spots.first.x.toInt(),
        isUtc: true,
      ).toLocal();
      final b = DateTime.fromMillisecondsSinceEpoch(
        spots.last.x.toInt(),
        isUtc: true,
      ).toLocal();
      debugPrint(
        '[SPOTS] first=${a.toIso8601String()} last=${b.toIso8601String()}',
      );
    }
    return spots;
  }

  // -------------------------------
  // 최근 N일 일평균 (0 제외)
  // -------------------------------
  Future<List<FlSpot>> _fetchDailyAggregates({required int days}) async {
    final todayStart = _startOfDay(DateTime.now());
    final start = todayStart.subtract(Duration(days: days - 1));
    final end = _endOfDay(todayStart);

    final pairs = await _fetchRawRange(start: start, end: end);

    // 날짜별 그룹핑
    final Map<DateTime, List<int>> byDay = {};
    for (final e in pairs) {
      final v = e.value;
      if (v <= 0) continue;
      final k = _startOfDay(e.key);
      byDay.putIfAbsent(k, () => []).add(v);
    }

    final keys = byDay.keys.toList()..sort();
    final spots = <FlSpot>[];
    for (final k in keys) {
      final list = byDay[k]!;
      if (list.isEmpty) continue;
      final avg = list.reduce((a, b) => a + b) / list.length;
      spots.add(FlSpot(k.millisecondsSinceEpoch.toDouble(), avg));
    }
    return spots;
  }

  // -------------------------------
  // 최근 N개월 평균 (0 제외) → x = 0..months-1
  // -------------------------------
  Future<List<FlSpot>> _fetchMonthlyAggregates({required int months}) async {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month);
    final oldestMonthStart = DateTime(
      currentMonthStart.year,
      currentMonthStart.month - (months - 1),
    );
    _monthBaseStart = oldestMonthStart;
    final end = DateTime(currentMonthStart.year, currentMonthStart.month + 1);

    final pairs = await _fetchRawRange(start: oldestMonthStart, end: end);

    String monthKey(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

    // 표시 순서를 고정하기 위해 키 배열 미리 생성
    final orderedMonthKeys = <String>[];
    for (int i = 0; i < months; i++) {
      final mStart = DateTime(
        oldestMonthStart.year,
        oldestMonthStart.month + i,
      );
      orderedMonthKeys.add(monthKey(mStart));
    }

    final Map<String, List<int>> byMonth = {};
    for (final e in pairs) {
      final v = e.value;
      if (v <= 0) continue;
      final mKey = monthKey(DateTime(e.key.year, e.key.month));
      if (!orderedMonthKeys.contains(mKey)) continue;
      byMonth.putIfAbsent(mKey, () => []).add(v);
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < orderedMonthKeys.length; i++) {
      final key = orderedMonthKeys[i];
      final list = byMonth[key] ?? const [];
      if (list.isEmpty) continue;
      final avg = list.reduce((a, b) => a + b) / list.length;
      spots.add(FlSpot(i.toDouble(), avg));
    }
    return spots;
  }

  Widget renderStackedBarGraph() {
    // 선택 범위 또는(일 단위일 때) 선택 날짜가 바뀌면 캐시 무효화
    final dateChanged =
        widget.selectedRange == ToggleRange.day &&
        _stackedDateMemo != selectedDate;
    if (_stackedRangeMemo != widget.selectedRange || dateChanged) {
      _stackedRangeMemo = widget.selectedRange;
      _stackedDateMemo = widget.selectedRange == ToggleRange.day
          ? selectedDate
          : null;
      _stackedBarScore = null;
      _stackedData = const _GraphData(daily: [], monthLike: []);
      _stackedLoaded = false;
    }

    final hasData =
        _stackedData.daily.isNotEmpty || _stackedData.monthLike.isNotEmpty;

    // 데이터가 없으면: 로딩 시작(다음 프레임에 setState) + 스피너 반환
    if (!hasData && !_stackedLoaded) {
      final dateToLoad = widget.selectedRange == ToggleRange.day
          ? selectedDate
          : null;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _dbLoading) return;
        setState(() => _dbLoading = true);
        try {
          final gd = await _loadGraphDataFromDb(
            DbManager.I.heartDB,
            widget.selectedRange,
            anchorDate: dateToLoad,
          );
          int? loadedScore;
          if (widget.selectedRange == ToggleRange.day && dateToLoad != null) {
            final dayOffset = _startOfDay(
              DateTime.now(),
            ).difference(_startOfDay(dateToLoad)).inDays;
            if (dayOffset >= 0) {
              final s = await computeSleepScoreFromDb(dayOffset: dayOffset);
              loadedScore = (s['S_total'] as num?)?.toInt();
            }
          }
          if (!mounted) return;
          setState(() {
            _stackedData = gd;
            _stackedDateMemo = dateToLoad;
            _stackedBarScore = widget.selectedRange == ToggleRange.day
                ? loadedScore
                : null;
            _dbLoading = false;
            _stackedLoaded = true;
            _monthBaseStart ??= _calcMonthBaseStart(
              _stackedAnchor ?? selectedDate,
              widget.selectedRange,
            );
          });
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _dbLoading = false;
            _stackedLoaded = true;
          });
        }
      });

      // 이 프레임에선 간단 스피너 표시 (부모 컨테이너도 _dbLoading으로 스피너를 곧 띄웁니다)
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    // 여기부터는 캐시된 데이터로 즉시 렌더
    final gd = _stackedData;

    switch (widget.selectedRange) {
      case ToggleRange.day:
        // 선택한 날짜(anchor) 기준으로 보여주되, 데이터가 없으면 빈 데이터로 표시
        final anchorDay = _stackedAnchor ?? selectedDate;
        final todayData = gd.daily.firstWhere(
          (d) => _day0(d.date) == _day0(anchorDay),
          orElse: () => SleepData(date: anchorDay, sleep: const []),
        );
        return HealthSleepTimelineChart(data: todayData);
      case ToggleRange.week:
        return HealthSleepStackedChart(
          range: ToggleRange.week,
          unit: widget.unit,
          intervalYFunc: widget.intervalYFunc,
          data: convertToDailyChartData(gd.daily, 16),
        );

      case ToggleRange.month:
        return HealthSleepStackedChart(
          range: ToggleRange.month,
          unit: widget.unit,
          intervalYFunc: widget.intervalYFunc,
          data: convertToDailyChartData(gd.daily, 4),
        );

      case ToggleRange.halfYear:
        {
          final anchor = _stackedAnchor ?? selectedDate;
          final base = _calcMonthBaseStart(anchor, widget.selectedRange);
          _monthBaseStart ??= base;
          final data = _buildMonthlySleepAverageBars(
            daily: gd.daily,
            months: 3,
            anchor: anchor,
            width: 16,
          );
          return HealthSleepStackedChart(
            range: ToggleRange.halfYear,
            unit: widget.unit,
            intervalYFunc: widget.intervalYFunc,
            data: data,
            monthBaseStart: _monthBaseStart!,
          );
        }
    }
  }

  Widget renderDotGraph() {
    final spots = _barDataToDotSpots(barData);
    final useFullDayAxis =
        widget.selectedRange == ToggleRange.day && barData.isNotEmpty;
    final slotCount = barData.length;
    return HealthAreaLineChart(
      spots: spots,
      dataType: widget.dataType,
      range: widget.selectedRange,
      unit: widget.unit,
      minX: useFullDayAxis ? 0 : null,
      maxX: useFullDayAxis ? (slotCount - 1).toDouble() : null,
      dayAnchor: useFullDayAxis ? selectedDate : null,
    );
  }

  Future<void> fetchMoreBarData() async {
    if (widget.selectedRange == ToggleRange.day) return;
    if (barData.isEmpty) return;

    switch (widget.selectedRange) {
      case ToggleRange.week:
      case ToggleRange.month:
        {
          final endX = barData.first.x - 1;
          final endDate = DateTime(
            BASE_DATE.year,
            BASE_DATE.month,
            BASE_DATE.day + endX,
          );

          final older = await fetchDailyBarGroups(
            dataType: widget.dataType,
            selectedRange: widget.selectedRange,
            endDate: endDate,
          );

          setState(() {
            barData = mergeAndSortByX(older, barData);
          });
        }
        return;

      case ToggleRange.halfYear:
        {
          final endMonthX = barData.first.x - 1;
          final endDate = DateTime(
            BASE_DATE.year,
            BASE_DATE.month + endMonthX,
            1,
          );

          final older = await fetchMonthlyBarGroups(
            dataType: widget.dataType,
            selectedRange: widget.selectedRange,
            endDate: endDate,
          );

          setState(() {
            barData = mergeAndSortByX(older, barData);
          });
        }
        return;

      case ToggleRange.day:
        return;
    }
  }

  /// 바 그래프 데이터를 DotGraph용 FlSpot 리스트로 변환 (인덱스 기반)
  List<FlSpot> _barDataToDotSpots(List<BarChartGroupData> data) {
    return data
        .where(
          (g) => g.barRods.isNotEmpty && g.barRods.first.toY > 0,
        )
        .map(
          (g) => FlSpot(g.x.toDouble(), g.barRods.first.toY),
        )
        .toList();
  }

  Widget renderGraph() {
    switch (widget.barType) {
      case GraphType.dot:
        return renderDotGraph();
      case GraphType.bar:
        return HealthBarChart(
          data: barData,
          dataType: widget.dataType,
          range: widget.selectedRange,
          unit: widget.unit,
          showStressZones: widget.dataType == DataType.Stress,
          onRequestMoreLeft: widget.selectedRange == ToggleRange.day
              ? null
              : fetchMoreBarData,
          setWindowXLabel: (label) => setState(() => windowXLabel = label),
          selectedDate: selectedDate,
        );
      case GraphType.stackedBar:
        return renderStackedBarGraph();
    }
  }

  // RealTimeGraphCard 내부에 헬퍼 추가
  String _fmtYMD(DateTime d) =>
      "${d.year.toString().substring(2)}년 ${d.month.toString().padLeft(2, '0')}월 ${d.day.toString().padLeft(2, '0')}일";
  String _fmtMD(DateTime d) =>
      "${d.month.toString().padLeft(2, '0')}월 ${d.day.toString().padLeft(2, '0')}일";
  String _fmtYM(DateTime d) =>
      "${d.year.toString().substring(2)}년 ${d.month.toString().padLeft(2, '0')}월";

  // 선택 범위에 따른 라벨 생성

  String _rangeLabel(ToggleRange r) {
    final now = DateTime.now();
    switch (r) {
      case ToggleRange.day:
        {
          final s = _startOfDay(selectedDate);
          return _fmtMD(s);
        }
      case ToggleRange.week:
        {
          final end = _endOfDay(now).subtract(const Duration(seconds: 1));
          final start = _startOfDay(now.subtract(const Duration(days: 6)));
          return "${_fmtYMD(start)} ~ ${_fmtYMD(end)}";
        }
      case ToggleRange.month:
        {
          final end = _endOfDay(now).subtract(const Duration(seconds: 1));
          final start = _startOfDay(now.subtract(const Duration(days: 29)));
          return "${_fmtYMD(start)} ~ ${_fmtYMD(end)}";
        }
      case ToggleRange.halfYear:
        {
          final curMonth = DateTime(now.year, now.month, 1);
          final start = DateTime(
            curMonth.year,
            curMonth.month - 2,
            1,
          ); // 최근 3개월
          final end = DateTime(curMonth.year, curMonth.month + 1, 0); // 이번달 말일
          return "${_fmtYM(start)} ~ ${_fmtYM(end)}";
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    var avg = double.nan;
    // [ ]: 하드 코딩 나중에 바꾸기
    if (widget.dataType == DataType.Stress || widget.barType == GraphType.dot) {
      final groups = barData;
      avg = _averageOfBarGroups(groups, excludeZero: true);
    } else {
      avg = _averageOfDotGroups(_dotGroups);
      if (widget.dataType == DataType.Sleep && !avg.isNaN) {
        // 수면: stacked bar day 범위면 선택된 날짜 점수(_stackedBarScore), 없으면 전역 score
        avg = (_stackedBarScore ?? score).toDouble();
      }
    }
    final String averageData = avg.isNaN ? "-" : avg.toStringAsFixed(0);

    // 수면 stacked bar: day 범위면 선택된 날짜 기준 라벨, 아니면 범위 라벨
    final effectiveWindowXLabel =
        (widget.dataType == DataType.Sleep &&
            widget.barType == GraphType.stackedBar)
        ? (widget.selectedRange == ToggleRange.day
              ? getWindowXLabel(
                  selectedDate,
                  getWindowX(widget.selectedRange, widget.dataType),
                  widget.selectedRange,
                  widget.dataType,
                )
              : _rangeLabel(widget.selectedRange))
        : windowXLabel;

    return Container(
      padding: EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RangeToggle(
            selectedRange: widget.selectedRange,
            onChanged: widget.onChanged,
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    effectiveWindowXLabel,
                    style: TextStyle(
                      color: AppColors.lightGray,
                      fontSize: 14,
                      fontWeight: AppFontWeight.light,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.dataType != DataType.Sleep ? "평균" : "수면 점수",
                        style: TextStyle(
                          color: AppColors.lightGray,
                          fontSize: 14,
                          fontWeight: AppFontWeight.medium,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        averageData,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: AppFontWeight.semiBold,
                        ),
                      ),
                      SizedBox(width: 4),
                      if (widget.unit.isNotEmpty)
                        Text(
                          widget.unit,
                          style: TextStyle(
                            color: AppColors.lightGray,
                            fontSize: 16,
                            fontWeight: AppFontWeight.regular,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if ((widget.selectedRange == ToggleRange.day) &&
                  (widget.dataType == DataType.Sleep ||
                      widget.dataType == DataType.Stress ||
                      widget.barType == GraphType.dot))
                IconButton(
                  icon: const Icon(
                    Icons.calendar_month,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () async {
                    // 필요한 값들은 현재 화면에서 갖고 있는 걸 넘겨주세요
                    final picked = await showActivityCalendarSheet(
                      context: context,
                      initialDate: selectedDate, // 현재 선택된 날짜
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = picked;
                        windowXLabel = _rangeLabel(widget.selectedRange);
                        _stackedAnchor = picked;
                        _stackedData = const _GraphData(
                          daily: [],
                          monthLike: [],
                        );
                        _stackedLoaded = false;
                      });
                      refreshDB(anchor: picked);
                    }
                  },
                ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: HealthChartTheme.chartHeight,
            color: Colors.transparent,
            child: _dbLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : renderGraph(),
          ),
          widget.widget ?? SizedBox.shrink(),
        ],
      ),
    );
  }
}
