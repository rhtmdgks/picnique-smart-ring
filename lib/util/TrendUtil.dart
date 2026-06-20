// ignore_for_file: file_names

import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:drift/drift.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';
import 'package:picnique_rosary_healthcare_smartring/db/app_db.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';

class HeartRateRangeStats {
  const HeartRateRangeStats({
    required this.average,
    required this.minimum,
    required this.maximum,
    required this.hasData,
  });

  final int? average;
  final int? minimum;
  final int? maximum;
  final bool hasData;

  static const empty = HeartRateRangeStats(
    average: null,
    minimum: null,
    maximum: null,
    hasData: false,
  );
}

String heartRatePeriodLabel(ToggleRange range) {
  return switch (range) {
    ToggleRange.day => '오늘',
    ToggleRange.week => '이번 주',
    ToggleRange.month => '이번 달',
    ToggleRange.halfYear => '최근 6개월',
    ToggleRange.year => '최근 1년',
  };
}

Future<HeartRateRangeStats> getHeartRateRangeStatsFromDb(
  ToggleRange range,
) async {
  final db = DbManager.I.appDB;
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  final DateTime start = switch (range) {
    ToggleRange.day => todayStart,
    ToggleRange.week => todayStart.subtract(const Duration(days: 6)),
    ToggleRange.month => todayStart.subtract(const Duration(days: 29)),
    ToggleRange.halfYear => () {
      final curMonth = DateTime(now.year, now.month, 1);
      return DateTime(curMonth.year, curMonth.month - 5, 1);
    }(),
    ToggleRange.year => () {
      final curMonth = DateTime(now.year, now.month, 1);
      return DateTime(curMonth.year, curMonth.month - 11, 1);
    }(),
  };

  final rows =
      await (db.select(db.heartDetails)
            ..where(
              (t) =>
                  t.date.isBetweenValues(start, now) &
                  t.bpm.isBiggerThanValue(0),
            ))
          .get();

  if (rows.isEmpty) return HeartRateRangeStats.empty;

  final bpms = rows.map((r) => r.bpm).toList();
  final sum = bpms.reduce((a, b) => a + b);

  return HeartRateRangeStats(
    average: (sum / bpms.length).round(),
    minimum: bpms.reduce(math.min),
    maximum: bpms.reduce(math.max),
    hasData: true,
  );
}

String buildHeartRateAverageMessage(HeartRateRangeStats stats, ToggleRange range) {
  final period = heartRatePeriodLabel(range);
  final avg = stats.average;
  if (!stats.hasData || avg == null) {
    return '$period 평균 심박 데이터가 아직 없어요.\n조금 더 모이면 알려드릴게요.';
  }
  if (avg < 60) {
    return '$period 평균은 ${avg}bpm이에요.\n평소보다 낮은 편이라 몸이 편안했을 수 있어요.';
  }
  if (avg <= 85) {
    return '$period 평균은 ${avg}bpm이에요.\n무난하게 유지되고 있어요.';
  }
  if (avg <= 100) {
    return '$period 평균은 ${avg}bpm이에요.\n조금 활발한 편이에요. 충분히 쉬어주세요.';
  }
  return '$period 평균은 ${avg}bpm이에요.\n평소보다 높은 편이라 오늘은 천천히 쉬어볼까요?';
}

String buildHeartRateMinimumMessage(HeartRateRangeStats stats, ToggleRange range) {
  final period = heartRatePeriodLabel(range);
  final min = stats.minimum;
  if (!stats.hasData || min == null) {
    return '$period 최저 심박 기록이 아직 없어요.';
  }
  if (min < 55) {
    return '$period 가장 낮았을 때는 ${min}bpm이었어요.\n휴식이 잘 된 순간이에요.';
  }
  return '$period 가장 낮았을 때는 ${min}bpm이었어요.\n몸이 차분해진 구간이 있었어요.';
}

String buildHeartRateMaximumMessage(HeartRateRangeStats stats, ToggleRange range) {
  final period = heartRatePeriodLabel(range);
  final max = stats.maximum;
  if (!stats.hasData || max == null) {
    return '$period 최고 심박 기록이 아직 없어요.';
  }
  if (max >= 120) {
    return '$period 가장 높았을 때는 ${max}bpm이었어요.\n활동이나 긴장이 있었을 수 있어요.';
  }
  if (max >= 100) {
    return '$period 가장 높았을 때는 ${max}bpm이었어요.\n가벼운 운동이나 스트레스 때 흔히 나오는 수준이에요.';
  }
  return '$period 가장 높았을 때는 ${max}bpm이었어요.\n크게 벗어나지 않은 범위예요.';
}

/// 헬스케어 야간 구간 여부 (수면·HRV 공통 기준).
///
/// 야간 = 전일 18:00 ~ 당일 18:00. 당일 18:00 이전이면 야간 HRV 멘트,
/// 18:00 이후면 주간(일반) HRV 멘트를 표시한다.
bool isNightHrvPeriod([DateTime? now]) {
  final local = now ?? DateTime.now();
  final todayNightEnd = DateTime(local.year, local.month, local.day, 18, 0, 0);
  return local.isBefore(todayNightEnd);
}

/// HRV – 지난 14일 평균 대비 오늘. 경우: <=-10% / -10~+10% / >=+10% / 데이터없음
Future<String?> getHrvTrendMessage() async {
  final db = DbManager.I.appDB;
  final t = db.stressDetails;

  final rows =
      await (db.select(t)
            ..orderBy([
              (r) => drift.OrderingTerm(
                expression: r.date,
                mode: drift.OrderingMode.desc,
              ),
            ])
            ..limit(15))
          .get();

  if (rows.isEmpty) return null;

  final today = rows.first.stress.toDouble();

  final baselineList = rows
      .skip(1)
      .take(14)
      .map((r) => r.stress.toDouble())
      .where((v) => v > 0)
      .toList();

  if (baselineList.isEmpty || today <= 0) return null;

  final baselineAvg =
      baselineList.reduce((a, b) => a + b) / baselineList.length;

  if (baselineAvg <= 0) return null;

  final diffPercent = (today - baselineAvg) / baselineAvg * 100.0;

  if (diffPercent <= -10.0) {
    return '최근 2주 평균보다 회복 여력이 조금 떨어졌어요.\n'
        '잠깐 쉬어가도 괜찮아요.';
  }
  if (diffPercent < 10.0) {
    return '스트레스 반응이 무난하게 조절되고 있어요.\n'
        '지금 리듬 그대로 가도 좋아요.';
  }
  return '휴식이 잘 받아들여지고 있어요.\n'
      '회복력이 올라가는 중이에요.';
}

/// 야간 HRV(24h) – 전일·연속일 비교. 우선순위: 20%↓ → 2~3일 연속↓ → 상승 → 소폭↓ → 유지
Future<String?> getNightHrvMessage() async {
  final db = DbManager.I.appDB;
  final t = db.stressDetails;

  final rows =
      await (db.select(t)
            ..orderBy([
              (r) => drift.OrderingTerm(
                expression: r.date,
                mode: drift.OrderingMode.desc,
              ),
            ])
            ..limit(4))
          .get();

  if (rows.length < 2) return null;

  final today = rows[0].stress.toDouble();
  final yesterday = rows[1].stress.toDouble();

  if (today <= 0 || yesterday <= 0) return null;

  // 1) 전일 대비 20% 이상 감소
  if (today <= yesterday * 0.8) {
    return '어젯밤 회복이 평소보다 낮았어요.\n'
        '오늘은 가볍게 움직이는 게 좋아요.';
  }

  // 2) 2~3일 연속 하락
  if (rows.length >= 3) {
    final twoDaysAgo = rows[2].stress.toDouble();
    if (twoDaysAgo > 0 && today < yesterday && yesterday < twoDaysAgo) {
      return '회복 지표가 며칠째 내려가고 있어요.\n'
          '수면·휴식 패턴을 한번 점검해볼까요?';
    }
  }
  if (rows.length == 2 && today < yesterday) {
    return '어제보다 회복 지표가 조금 낮아졌어요.\n'
        '오늘은 무리하지 않는 게 좋겠어요.';
  }

  // 3) 상승
  if (today > yesterday) {
    return '회복 신호가 좋아 보여요.\n'
        '오늘 컨디션을 기대해도 괜찮아요.';
  }

  // 4) 전일과 비슷 (유지)
  return '어젯밤 회복이 평소랑 비슷해요.\n'
      '지금 생활 패턴을 유지해보세요.';
}

class _DailySpO2Stat {
  final DateTime day;
  final double mean;
  final double std;

  const _DailySpO2Stat(this.day, this.mean, this.std);
}

Future<List<_DailySpO2Stat>> _loadDailySpO2Stats({int maxDays = 30}) async {
  final db = DbManager.I.appDB;
  final t = db.bloodOxygenDetails;

  final now = DateTime.now();
  final from = now.subtract(Duration(days: maxDays));

  // 최근 maxDays 동안의 SpO2 시계열 전부 가져오기 (오래된 것부터)
  final rows =
      await (db.select(t)
            ..where((r) => r.date.isBiggerThanValue(from))
            ..orderBy([
              (r) => drift.OrderingTerm(
                expression: r.date,
                mode: drift.OrderingMode.asc,
              ),
            ]))
          .get();

  if (rows.isEmpty) return const [];

  // 날짜 단위로 그룹핑
  final Map<DateTime, List<int>> byDay = {};
  for (final r in rows) {
    final d = r.date;
    final dayKey = DateTime(d.year, d.month, d.day);
    byDay.putIfAbsent(dayKey, () => <int>[]).add(r.spo2);
  }

  final days = byDay.keys.toList()..sort();

  final List<_DailySpO2Stat> stats = [];
  for (final day in days) {
    final list = byDay[day]!
        .where((v) => v > 0)
        .map((e) => e.toDouble())
        .toList();
    if (list.isEmpty) continue;

    final mean = list.reduce((a, b) => a + b) / list.length;

    if (list.length == 1) {
      stats.add(_DailySpO2Stat(day, mean, 0.0));
      continue;
    }

    final varSum = list
        .map((v) => math.pow(v - mean, 2))
        .reduce((a, b) => a + b)
        .toDouble();
    final variance = varSum / list.length;
    final std = math.sqrt(variance);

    stats.add(_DailySpO2Stat(day, mean, std));
  }

  return stats;
}

/// 평균 SpO₂ – 일일 평균 기준 메시지
///
/// - today = 가장 최근 하루의 평균 SpO₂
/// - baseline = 그 이전 N일 평균
/// - today <= baseline - 2 이면 “경미한 저하” 메시지, 그 외 “정상/안정”
Future<String?> getSpO2AverageMessage() async {
  final stats = await _loadDailySpO2Stats(maxDays: 30);
  if (stats.length < 2) return null;

  final todayStat = stats.last;
  final baselineDays = stats.take(stats.length - 1).toList();

  // 최근 7일(또는 남은 만큼)만 baseline 으로 사용
  const int window = 7;
  final baselineSlice = baselineDays.length > window
      ? baselineDays.sublist(baselineDays.length - window)
      : baselineDays;

  final baselineValues = baselineSlice
      .map((e) => e.mean)
      .where((v) => v > 0)
      .toList();
  if (baselineValues.isEmpty) return null;

  final baselineAvg =
      baselineValues.reduce((a, b) => a + b) / baselineValues.length;

  if (baselineAvg <= 0) return null;

  final today = todayStat.mean;
  final diff = today - baselineAvg;

  // 2%p 이상 낮으면 경미한 저하로 판단
  if (diff <= -2.0) {
    return '산소포화도가 미세하게 떨어진 상태예요.\n'
        '수면 중 상태를 한 번 점검해보는 게 좋겠어요.';
  }

  // 정상 / 안정
  return '호흡과 산소 공급이 건강한 범위예요.\n'
      '지금의 생활 패턴을 잘 유지해보세요.';
}

/// SpO₂ 변동성(표준편차) 기준 메시지
///
/// - todayStd vs baselineStd 비교
/// - todayStd >= baselineStd * 1.15 → 변동성 증가(불안정)
/// - todayStd <= baselineStd * 0.85 → 변동성 감소(안정적 패턴)
Future<String?> getSpO2VariabilityMessage() async {
  final stats = await _loadDailySpO2Stats(maxDays: 30);
  if (stats.length < 2) return null;

  final todayStat = stats.last;
  final baselineDays = stats.take(stats.length - 1).toList();

  const int window = 7;
  final baselineSlice = baselineDays.length > window
      ? baselineDays.sublist(baselineDays.length - window)
      : baselineDays;

  final baselineStdValues = baselineSlice
      .map((e) => e.std)
      .where((v) => v > 0)
      .toList();
  if (baselineStdValues.isEmpty) return null;

  final baselineStd =
      baselineStdValues.reduce((a, b) => a + b) / baselineStdValues.length;
  if (baselineStd <= 0) return null;

  final todayStd = todayStat.std;
  final ratio = todayStd / baselineStd * 100.0;

  if (ratio >= 115.0) {
    // ±15% 이상 증가 → 변동성 증가
    return '산소포화도 변동폭이 큰 편입니다.\n'
        '안정이 필요할 수 있어요.\n';
  }

  if (ratio <= 85.0) {
    // 변동성 감소(안정적 패턴)
    return '호흡 리듬이 안정적으로 유지되고 있습니다.';
  }

  // 애매한 구간은 메시지 없이 넘어가고 싶으면 null
  return '호흡 리듬이 대체로 안정적입니다.';
}

Future<String?> getAverageHrMessageFromDb() async {
  final db = DbManager.I.appDB;
  final t = db.heartDetails;

  final now = DateTime.now();
  final from = now.subtract(Duration(days: 8)); // 최근 8일

  // 최근 8일치 모두 가져오기
  final rows =
      await (db.select(t)
            ..where((r) => r.date.isBiggerThanValue(from))
            ..orderBy([
              (r) => OrderingTerm(expression: r.date, mode: OrderingMode.asc),
            ]))
          .get();

  if (rows.isEmpty) return null;

  // 날짜별 그룹화
  final Map<DateTime, List<int>> byDay = {};
  for (final r in rows) {
    final d = r.date;
    final dayKey = DateTime(d.year, d.month, d.day);
    byDay.putIfAbsent(dayKey, () => []).add(r.bpm);
  }

  // 최소 2일 이상 있어야 today + baseline 비교 가능
  if (byDay.keys.length < 2) return null;

  final days = byDay.keys.toList()..sort();

  final todayKey = days.last;
  final todayList = byDay[todayKey]!;
  final todayAvg = todayList.reduce((a, b) => a + b) / todayList.length;

  // baseline(이전 7일)
  final baselineDays = days.take(days.length - 1).toList();
  final usableBaseline = baselineDays.length > 7
      ? baselineDays.sublist(baselineDays.length - 7)
      : baselineDays;

  final baselineValues = usableBaseline
      .map((day) => byDay[day]!)
      .expand((list) => list)
      .toList();

  if (baselineValues.isEmpty) return null;

  final baselineAvg =
      baselineValues.reduce((a, b) => a + b) / baselineValues.length;

  final ratio = todayAvg / baselineAvg * 100.0;

  if (ratio >= 115.0) {
    return '요즘 심박수가 평소보다 살짝 높게 나왔어요.\n'
        '몸이 조금 피곤한 건 아닌지, 오늘은 천천히 쉬어볼까요?';
  }

  return '평균 심박수가 무난하게 유지되고 있어요.\n'
      '지금 페이스 그대로 가도 좋아요.';
}

Future<String?> getRestingHrMessageFromDb() async {
  final db = DbManager.I.appDB;
  final t = db.heartDetails;

  final now = DateTime.now();
  final from = now.subtract(Duration(days: 15));

  final rows =
      await (db.select(t)
            ..where((r) => r.date.isBiggerThanValue(from))
            ..orderBy([
              (r) => OrderingTerm(expression: r.date, mode: OrderingMode.asc),
            ]))
          .get();

  if (rows.isEmpty) return null;

  // 날짜별 최소 HR 저장
  Map<DateTime, int> minByDay = {};

  for (final r in rows) {
    final d = r.date;
    final key = DateTime(d.year, d.month, d.day);

    if (!minByDay.containsKey(key) || r.bpm < minByDay[key]!) {
      minByDay[key] = r.bpm;
    }
  }

  if (minByDay.keys.length < 2) return null;

  final days = minByDay.keys.toList()..sort();

  final todayKey = days.last;
  final todayMin = minByDay[todayKey]!;

  // baseline 이전 14일
  final baselineDays = days.take(days.length - 1).toList();
  final usableBaseline = baselineDays.length > 14
      ? baselineDays.sublist(baselineDays.length - 14)
      : baselineDays;

  final baselineValues = usableBaseline.map((d) => minByDay[d]!).toList();

  final baselineAvg =
      baselineValues.reduce((a, b) => a + b) / baselineValues.length;

  final ratio = todayMin / baselineAvg * 100;

  if (ratio >= 110.0) {
    return '쉬고 있을 때 심박수가 평소보다 조금 높아요.\n'
        '잠깐 숨 고르고 쉬는 시간을 가져보면 좋겠어요.';
  }

  return '안정 시 심박수가 평소처럼 잘 유지되고 있어요.\n'
      '몸이 차분한 상태예요.';
}

/// SleepDetails + HeartDetails 를 이용해
/// "수면 중 HR" 메시지를 계산해서 반환.
///
/// 로직:
/// 1) 최근 15일 SleepDetails 불러와서 날짜별(일자)로 묶음
/// 2) 각 날짜별 수면 구간(start~end) 동안의 HeartDetails.bpm 평균 계산
/// 3) 가장 최근 날짜 = todayAvg
/// 4) 그 이전 최대 14일 평균 = baselineAvg
/// 5) diff% = (todayAvg - baselineAvg) / baselineAvg * 100
///    - |diff%| >= 15 → 패턴 변화
///    - 그 미만        → 회복 좋음
Future<String?> getSleepHrMessageFromDb() async {
  final db = DbManager.I.appDB;
  final s = db.sleepDetails;
  final h = db.heartDetails;

  final now = DateTime.now();
  final from = now.subtract(const Duration(days: 15));

  // 1) 최근 15일 SleepDetails 전부 가져오기 (날짜 오름차순)
  final sleepRows =
      await (db.select(s)
            ..where((r) => r.date.isBiggerThanValue(from))
            ..orderBy([
              (r) => drift.OrderingTerm(
                expression: r.date,
                mode: drift.OrderingMode.asc,
              ),
            ]))
          .get();

  if (sleepRows.isEmpty) return null;

  // 2) 날짜별로 수면 구간 묶기
  final Map<DateTime, List<dynamic>> sleepsByDay = {};

  for (final row in sleepRows) {
    final d = row.date;
    final dayKey = DateTime(d.year, d.month, d.day);
    sleepsByDay.putIfAbsent(dayKey, () => <dynamic>[]).add(row);
  }

  if (sleepsByDay.keys.length < 2) {
    // 오늘 + baseline 최소 하루 이상 필요
    return null;
  }

  // 날짜 정렬
  final dayKeys = sleepsByDay.keys.toList()..sort();

  // 3) 각 날짜별 "수면 중 HR 평균" 계산
  final Map<DateTime, double> sleepHrAvgByDay = {};

  for (final day in dayKeys) {
    final segments = sleepsByDay[day]!;
    // 해당 날짜의 전체 수면 구간에서 HR 평균 계산
    // 3-1) 먼저 이 날짜의 수면 전체 시간 범위 (minStart ~ maxEnd)
    DateTime? minStart;
    DateTime? maxEnd;

    for (final seg in segments) {
      final DateTime st = seg.start;
      final DateTime et = seg.end;
      if (minStart == null || st.isBefore(minStart)) {
        minStart = st;
      }
      if (maxEnd == null || et.isAfter(maxEnd)) {
        maxEnd = et;
      }
    }

    if (minStart == null || maxEnd == null) continue;

    // 3-2) 해당 범위의 HR 모두 가져오기
    final hrRows =
        await (db.select(h)
              ..where((r) => r.date.isBiggerOrEqualValue(minStart!))
              ..where((r) => r.date.isSmallerOrEqualValue(maxEnd!))
              ..orderBy([
                (r) => drift.OrderingTerm(
                  expression: r.date,
                  mode: drift.OrderingMode.asc,
                ),
              ]))
            .get();

    if (hrRows.isEmpty) continue;

    // 3-3) HR 중 실제로 수면 segment 안에 들어가는 것만 사용
    int sum = 0;
    int count = 0;

    for (final hr in hrRows) {
      final t = hr.date;

      bool inAnySegment = false;
      for (final seg in segments) {
        final DateTime st = seg.start;
        final DateTime et = seg.end;
        if (!t.isBefore(st) && !t.isAfter(et)) {
          inAnySegment = true;
          break;
        }
      }

      if (inAnySegment) {
        sum += hr.bpm;
        count++;
      }
    }

    if (count == 0) continue;

    sleepHrAvgByDay[day] = sum / count;
  }

  if (sleepHrAvgByDay.length < 2) {
    // 수면 HR 평균이 계산된 날짜가 최소 2개 이상이어야 함
    return null;
  }

  // 4) today + baseline 계산
  final sortedDays = sleepHrAvgByDay.keys.toList()..sort();
  final todayDay = sortedDays.last;
  final todayAvg = sleepHrAvgByDay[todayDay]!;

  final baselineDays = sortedDays.take(sortedDays.length - 1).toList();
  // 최근 14일까지만 baseline 으로 사용
  const int baselineWindow = 14;
  final usableBaselineDays = baselineDays.length > baselineWindow
      ? baselineDays.sublist(baselineDays.length - baselineWindow)
      : baselineDays;

  final baselineValues = usableBaselineDays
      .map((d) => sleepHrAvgByDay[d]!)
      .toList();
  if (baselineValues.isEmpty) return null;

  final baselineAvg =
      baselineValues.reduce((a, b) => a + b) / baselineValues.length;

  if (baselineAvg <= 0) return null;

  final diffPercent = (todayAvg - baselineAvg) / baselineAvg * 100.0;

  // 5) 메시지 선택
  if (diffPercent.abs() >= 15.0) {
    return '어젯밤 수면 중 심박 패턴이 평소랑 조금 달랐어요.\n'
        '오늘은 무리하지 말고, 몸 신호를 잘 들어봐 주세요.';
  } else {
    return '자는 동안 심박수가 잘 내려갔어요.\n'
        '몸이 충분히 쉬었다는 신호예요.';
  }
}

/// Baseline 기반 상대 비교 (지난 14일 평균 걸음수 vs 오늘)
///
/// SportDetails:
///   - date: 해당 15분 슬롯 시작 시각
///   - walkSteps, runSteps: 15분 동안 걸음 수
///
/// 로직:
///  - 최근 15일 데이터를 읽어서 날짜별 총 걸음 수 집계
///  - 가장 최근 날짜 = todaySteps
///  - 나머지 최대 14일 = baseline 평균
///  - diff% = (today - baseline) / baseline * 100
///    * diff <= -30   → "평소보다 활동량이 크게 적은 날이에요. (-30%)"
///    * -30 < diff < -10 → "오늘 활동량이 평소보다 줄었어요. (-10% ~ -30%)"
///    * -10 <= diff <= 10 → "평소와 비슷한 활동량이에요. (±10% 이내)"
///    * diff > 10     → "평소보다 많이 움직였어요! 활동량이 증가했습니다.(+10% 이상)"
Future<String?> getStepBaselineMessageFromDb() async {
  final db = DbManager.I.appDB;
  final t = db.sportDetails;

  final now = DateTime.now();
  final from = now.subtract(const Duration(days: 15));

  // 최근 15일 동안의 모든 슬롯 데이터
  final rows =
      await (db.select(t)
            ..where((r) => r.date.isBiggerThanValue(from))
            ..orderBy([
              (r) => drift.OrderingTerm(
                expression: r.date,
                mode: drift.OrderingMode.asc,
              ),
            ]))
          .get();

  if (rows.isEmpty) return null;

  // 날짜별 총 걸음수 합산 (walk + run)
  final Map<DateTime, int> stepsByDay = {};

  for (final r in rows) {
    final d = r.date;
    final key = DateTime(d.year, d.month, d.day);
    final steps = r.walkSteps + r.runSteps;
    stepsByDay.update(key, (old) => old + steps, ifAbsent: () => steps);
  }

  if (stepsByDay.keys.length < 2) {
    // 오늘 + baseline 최소 하루 이상 필요
    return null;
  }

  final days = stepsByDay.keys.toList()..sort();

  final todayKey = days.last;
  final todaySteps = stepsByDay[todayKey] ?? 0;

  // baseline: 이전 최대 14일
  final baselineDays = days.take(days.length - 1).toList();
  const int window = 14;
  final usableBaselineDays = baselineDays.length > window
      ? baselineDays.sublist(baselineDays.length - window)
      : baselineDays;

  final baselineValues = usableBaselineDays
      .map((d) => stepsByDay[d] ?? 0)
      .where((v) => v > 0)
      .toList();

  if (baselineValues.isEmpty) return null;

  final baselineAvg =
      baselineValues.reduce((a, b) => a + b) / baselineValues.length;

  if (baselineAvg <= 0) return null;

  final diffPercent = (todaySteps - baselineAvg) / baselineAvg * 100.0;

  if (diffPercent <= -30.0) {
    return '평소보다 활동량이 크게 적은 날이에요. (-30% 이하)';
  } else if (diffPercent < -10.0) {
    return '오늘 활동량이 평소보다 줄었어요. (-10% ~ -30%)';
  } else if (diffPercent <= 10.0) {
    return '평소와 비슷한 활동량이에요. (±10% 이내)';
  } else {
    return '평소보다 많이 움직였어요!\n활동량이 증가했습니다. (+10% 이상)';
  }
}

/// 목표 기반 달성률 (걸음수) – 목표 10,000걸음 기준
///
/// - 오늘 날짜 기준 총 걸음 수(todaySteps) 계산
/// - ratio = todaySteps / 10,000 * 100
///
/// 조건:
///   ratio < 60    → "달성률이 낮습니다. 컨디션이 좋지 않았을 수 있어요.(60% 미만)"
///   60 <= ratio < 100 → 중간 안내 메시지
///   100 <= ratio < 130 → "오늘 활동 목표를 달성했어요.(100% 이상)"
///   ratio >= 130  → "오늘은 목표 대비 xxx% 달성했어요.(130% 이상)"
Future<String?> getStepGoalMessageFromDb({int dailyGoal = 10000}) async {
  final db = DbManager.I.appDB;
  final t = db.sportDetails;

  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  // 오늘 하루 데이터만
  final rows =
      await (db.select(t)
            ..where((r) => r.date.isBiggerOrEqualValue(startOfDay))
            ..where((r) => r.date.isSmallerThanValue(endOfDay)))
          .get();

  if (rows.isEmpty) return null;

  int todaySteps = 0;
  for (final r in rows) {
    todaySteps += r.walkSteps + r.runSteps;
  }

  if (dailyGoal <= 0) return null;

  final ratio = todaySteps / dailyGoal * 100.0;
  final ratioRounded = ratio.round();

  if (ratio < 60.0) {
    return '달성률이 낮습니다.\n컨디션이 좋지 않았을 수 있어요. (60% 미만)';
  } else if (ratio < 100.0) {
    return '오늘은 목표의 약 $ratioRounded%를 달성했어요.\n조금만 더 움직여볼까요?';
  } else if (ratio < 130.0) {
    return '오늘 활동 목표를 달성했어요! (100% 이상)\n수고 많았어요.';
  } else {
    return '오늘은 목표 대비 약 $ratioRounded% 달성했어요! (130% 이상)\n아주 활발하게 움직인 하루였어요.';
  }
}

Future<Map<DateTime, List<SleepDetail>>> _loadSleepByDay({
  int days = 14,
}) async {
  final db = DbManager.I.appDB;
  final t = db.sleepDetails;

  final now = DateTime.now();
  final from = now.subtract(Duration(days: days + 1));

  final rows =
      await (db.select(t)
            ..where((r) => r.date.isBiggerThanValue(from))
            ..orderBy([
              (r) => drift.OrderingTerm(
                expression: r.start,
                mode: drift.OrderingMode.asc,
              ),
            ]))
          .get();

  final Map<DateTime, List<SleepDetail>> byDay = {};

  for (final r in rows) {
    final d = r.date;
    final key = DateTime(d.year, d.month, d.day);
    byDay.putIfAbsent(key, () => []).add(r);
  }

  return byDay;
}

/// 총 수면시간 메시지
///
/// 수면 타입 = 2(light), 3(deep), 4(rem)
Future<String?> getTotalSleepMessageFromDb() async {
  final byDay = await _loadSleepByDay(days: 14);
  if (byDay.keys.length < 2) return null;

  final days = byDay.keys.toList()..sort();

  // 날짜별 총 수면시간(분)
  final Map<DateTime, int> sleepMinutesByDay = {};

  for (final day in days) {
    final segs = byDay[day]!;
    int total = 0;

    for (final s in segs) {
      if (s.type == 2 || s.type == 3 || s.type == 4) {
        total += s.end.difference(s.start).inMinutes;
      }
    }
    sleepMinutesByDay[day] = total;
  }

  final today = days.last;
  final todayMin = sleepMinutesByDay[today] ?? 0;

  // baseline = 이전 14일
  final baselineDays = days.take(days.length - 1).toList();
  final baselineValues = baselineDays
      .map((d) => sleepMinutesByDay[d]!)
      .toList();

  final baselineAvg =
      baselineValues.reduce((a, b) => a + b) / baselineValues.length;

  final diff = todayMin - baselineAvg;

  if (diff <= -45) {
    return '평소보다 수면시간이 줄었어요.\n컨디션에 영향을 줄 수 있습니다.';
  } else if (diff >= 45) {
    return '총수면시간이 충분해요.\n오늘 컨디션이 좋을 가능성이 높아요.';
  } else {
    return '총수면시간이 평소와 비슷해요.';
  }
}

/// 각성 횟수 메시지
///
/// awake(type=5) 구간의 "연속 구간 묶음 개수" = 각성 횟수
Future<String?> getAwakeCountMessageFromDb() async {
  final byDay = await _loadSleepByDay(days: 14);
  if (byDay.keys.isEmpty) return null;

  final days = byDay.keys.toList()..sort();

  // 날짜별 각성 횟수
  final Map<DateTime, int> awakeCountByDay = {};

  for (final day in days) {
    final segs = byDay[day]!..sort((a, b) => a.start.compareTo(b.start));

    int awakenings = 0;
    bool inAwake = false;

    for (final s in segs) {
      if (s.type == 5) {
        if (!inAwake) {
          awakenings++;
          inAwake = true;
        }
      } else {
        inAwake = false;
      }
    }

    awakeCountByDay[day] = awakenings;
  }

  final today = days.last;
  final todayCount = awakeCountByDay[today] ?? 0;

  // 메시지 규칙
  if (todayCount >= 10) {
    return '밤에 깨는 횟수가 늘었어요.\n수면 안정성이 떨어진 신호입니다.';
  } else if (todayCount >= 7) {
    return '평소보다 뒤척임이 조금 많았어요.';
  } else {
    return '밤 동안 거의 깨지 않으셨어요.\n깊고 안정적인 수면이었어요.';
  }
}

/// 취침시간 규칙성 메시지
///
/// 취침시간 = 하루의 첫 sleep segment.start
Future<String?> getBedtimeRegularityMessageFromDb() async {
  final byDay = await _loadSleepByDay(days: 7);
  if (byDay.keys.length < 2) return null;

  final days = byDay.keys.toList()..sort();

  // 날짜별 취침시간 → 분단위 (0~1440)
  final Map<DateTime, int> bedtimeMinutes = {};

  for (final day in days) {
    final segs = byDay[day]!..sort((a, b) => a.start.compareTo(b.start));

    if (segs.isEmpty) continue;

    final first = segs.first.start;
    final mins = first.hour * 60 + first.minute;
    bedtimeMinutes[day] = mins;
  }

  final today = days.last;

  if (!bedtimeMinutes.containsKey(today)) return null;

  final todayMin = bedtimeMinutes[today]!;

  // baseline = 이전 최대 7일
  final baselineDays = days.take(days.length - 1).toList();

  final baselineValues = baselineDays.map((d) => bedtimeMinutes[d]!).toList();

  final baselineAvg =
      baselineValues.reduce((a, b) => a + b) / baselineValues.length;

  final diff = todayMin - baselineAvg;

  if (diff.abs() >= 45) {
    return '취침 시간이 불규칙해지고 있어요.';
  } else {
    return '취침 패턴이 잘 유지되고 있어요.';
  }
}
