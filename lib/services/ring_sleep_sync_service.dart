import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/ring_measurement_policy.dart';
import 'package:picnique_rosary_healthcare_smartring/db/app_db.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';

/// 이벤트 기반 수면 sync — 주기 폴링 대신 다음 시점에만 pull 한다:
///
/// - 연결 성공 직후 (coordinator `_afterConnectSuccess`)
/// - SleepGate 기상(WAKE) 감지 직후
/// - 아침 첫 foreground 복귀 (마지막 sync 가 오늘 아침 이전일 때)
/// - 수면 탭 진입 ([syncDetailIfIdle])
///
/// 모든 BLE 호출은 backgroundSync 우선순위([BleCommandQueue.invokeAuto]) +
/// 세션 충돌 재시도([BleCommandQueue.runWithSessionRetry])로 실행되어
/// 수동 측정을 방해하지 않는다.
class RingSleepSyncService {
  RingSleepSyncService._();
  static final RingSleepSyncService instance = RingSleepSyncService._();

  bool _syncing = false;
  DateTime? _lastSummaryAt;

  @visibleForTesting
  DateTime? get lastSummaryAt => _lastSummaryAt;

  /// 최근 [days]일 수면 요약을 pull 해 SleepDetails 테이블에 저장한다.
  ///
  /// SDK 제약: `syncSleepNew`(신 프로토콜, REM 포함)는 offset 0~1만
  /// 지원하므로 offset 2 이상은 `syncSleepDisplay`(구 프로토콜)를 쓴다.
  Future<void> syncSummary({int days = 3}) async {
    if (_syncing) {
      debugPrint('[SLEEP_SYNC] skipped — already syncing');
      return;
    }
    _syncing = true;
    try {
      await DbManager.I.open();
      for (var offset = 0; offset < days; offset++) {
        final segments = offset <= 1
            ? await _pullSleepNew(offset)
            : await _pullSleepDisplay(offset);
        if (segments == null || segments.isEmpty) continue;
        await _saveNight(segments);
      }
      _lastSummaryAt = DateTime.now();
    } finally {
      _syncing = false;
    }
  }

  /// 수면 탭 진입용 — 수동 측정 중이 아닐 때만 pull.
  Future<void> syncDetailIfIdle() async {
    if (BleCommandQueue.manualInFlight) {
      debugPrint('[SLEEP_SYNC] detail skipped — manual measurement busy');
      return;
    }
    await syncSummary();
  }

  /// 아침 첫 foreground — 마지막 sync 가 오늘 아침(07:00) 이전이면 실행.
  Future<void> syncSummaryIfMorningStale() async {
    final now = DateTime.now();
    if (now.hour < RingMeasurementPolicy.sleepFallbackEndHour) return;
    final morning = DateTime(
      now.year,
      now.month,
      now.day,
      RingMeasurementPolicy.sleepFallbackEndHour,
    );
    final last = _lastSummaryAt;
    if (last != null && last.isAfter(morning)) return;
    await syncSummary();
  }

  /// 신 프로토콜: `{st, et, list:[{d, t}]}` (t: 2=light, 3=deep, 4=rem, 5=awake).
  Future<List<_SleepSegment>?> _pullSleepNew(int offset) async {
    final Map<dynamic, dynamic>? rsp;
    try {
      rsp = await BleCommandQueue.runWithSessionRetry(
        () => BleCommandQueue.invokeAuto<Map<dynamic, dynamic>>(
          'syncSleepNew',
          {'offset': offset},
        ),
      );
    } catch (e) {
      debugPrint('[SLEEP_SYNC] syncSleepNew($offset) failed: $e');
      return null;
    }
    if (rsp == null) return null;

    final st = _asInt(rsp['st']);
    final rawList = (rsp['list'] as List?) ?? const [];
    if (st <= 0 || rawList.isEmpty) return null;

    var cursor = st;
    final segments = <_SleepSegment>[];
    for (final e in rawList) {
      final map = e as Map?;
      final dSec = _asInt(map?['d']);
      final t = _asInt(map?['t']);
      if (dSec <= 0) continue;
      final segStart = cursor;
      cursor += dSec;
      if (!(t == 2 || t == 3 || t == 4 || t == 5)) continue;
      segments.add(_SleepSegment(
        start: _fromEpochSec(segStart),
        end: _fromEpochSec(segStart + dSec),
        type: t,
      ));
    }
    return segments;
  }

  /// 구 프로토콜: `{list:[{sleepStart, sleepEnd, type}]}`
  /// (type: 1=deep, 2=light/rem, 3=awake) → DB 타입(3/2/5)으로 변환.
  Future<List<_SleepSegment>?> _pullSleepDisplay(int offset) async {
    final Map<dynamic, dynamic>? rsp;
    try {
      rsp = await BleCommandQueue.runWithSessionRetry(
        () => BleCommandQueue.invokeAuto<Map<dynamic, dynamic>>(
          'syncSleepDisplay',
          {'dayOffset': offset},
        ),
      );
    } catch (e) {
      debugPrint('[SLEEP_SYNC] syncSleepDisplay($offset) failed: $e');
      return null;
    }
    if (rsp == null) return null;

    final rawList = (rsp['list'] as List?) ?? const [];
    final segments = <_SleepSegment>[];
    for (final e in rawList) {
      final map = e as Map?;
      final startSec = _asInt(map?['sleepStart']);
      final endSec = _asInt(map?['sleepEnd']);
      final displayType = _asInt(map?['type']);
      if (startSec <= 0 || endSec <= startSec) continue;
      final dbType = switch (displayType) {
        1 => 3, // deep
        2 => 2, // light (REM 포함)
        3 => 5, // awake
        _ => 0,
      };
      if (dbType == 0) continue;
      segments.add(_SleepSegment(
        start: _fromEpochSec(startSec),
        end: _fromEpochSec(endSec),
        type: dbType,
      ));
    }
    return segments;
  }

  /// 한 밤 윈도우 저장 — 기존 행과 dedupe:
  /// 같은 윈도우와 겹치는 기존 행을 지우고 새 세그먼트로 교체한다
  /// (probe 로 저장된 부분 데이터를 최신 전체 데이터가 대체).
  Future<void> _saveNight(List<_SleepSegment> segments) async {
    final db = DbManager.I.appDB;

    var windowStart = segments.first.start;
    var windowEnd = segments.first.end;
    for (final s in segments) {
      if (s.start.isBefore(windowStart)) windowStart = s.start;
      if (s.end.isAfter(windowEnd)) windowEnd = s.end;
    }

    DateTime day0(DateTime d) => DateTime(d.year, d.month, d.day);

    // 자정 경계 분할 — 기존 SleepDetails 스키마(date=일자, start/end/type) 유지.
    final inserts = <SleepDetailsCompanion>[];
    for (final seg in segments) {
      var cur = seg.start;
      while (cur.isBefore(seg.end)) {
        final dayKey = day0(cur);
        final nextDay = dayKey.add(const Duration(days: 1));
        final pieceEnd = seg.end.isBefore(nextDay) ? seg.end : nextDay;
        inserts.add(SleepDetailsCompanion.insert(
          date: dayKey,
          start: cur,
          end: pieceEnd,
          type: seg.type,
        ));
        cur = pieceEnd;
      }
    }
    if (inserts.isEmpty) return;

    await db.transaction(() async {
      // 밤 윈도우와 겹치는 기존 행 제거 (start < windowEnd AND end > windowStart)
      await (db.delete(db.sleepDetails)
            ..where(
              (t) =>
                  t.start.isSmallerThanValue(windowEnd) &
                  t.end.isBiggerThanValue(windowStart),
            ))
          .go();
      await db.batch(
        (b) => b.insertAll(
          db.sleepDetails,
          inserts,
          mode: InsertMode.insertOrIgnore,
        ),
      );
    });
    debugPrint(
      '[SLEEP_SYNC] night $windowStart~$windowEnd saved '
      '(${inserts.length} rows)',
    );
  }

  static DateTime _fromEpochSec(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true).toLocal();

  static int _asInt(dynamic v, {int def = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? def;
  }
}

class _SleepSegment {
  _SleepSegment({required this.start, required this.end, required this.type});

  final DateTime start;
  final DateTime end;

  /// DB 타입: 2=light, 3=deep, 4=rem, 5=awake.
  final int type;
}
