import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/util/BLEUtil.dart';
import 'package:picnique_rosary_healthcare_smartring/util/TrendUtil.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/health_message.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/heart_rate_range_messages.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/real_time_card.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/charts/health_chart_card.dart';
import 'package:provider/provider.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_data_refresh_notifier.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_live_metrics.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';

// 추가: DB와 정렬용 drift

double calculateIntervalY(double localMaxY, double localMinY) {
  final double difference = localMaxY - localMinY;

  if (difference < 40) {
    return 5;
  } else if (difference < 80) {
    return 10;
  } else {
    return 20;
  }
}

class HealthCareHeartScreen extends StatefulWidget {
  const HealthCareHeartScreen({super.key});

  @override
  State<HealthCareHeartScreen> createState() => _HealthCareHeartScreenState();
}

class _HealthCareHeartScreenState extends State<HealthCareHeartScreen> {
  final String unit = "bpm";
  ToggleRange _selectedRange = ToggleRange.day;

  // 최신 데이터 표시용 상태
  String _latestLabel = "-"; // "5분 전" 등
  String _latestBpmText = "-"; // "84" 등
  bool _latestLoading = false;
  bool _hrSyncStarted = false;
  Ring? _ring;
  HealthDataRefreshNotifier? _healthRefresh;

  /// 날짜/범위와 무관하게 한 번만 로드해 유지
  late final Future<String> _healthMessageFuture = Future.wait([
    getAverageHrMessageFromDb(),
    getSleepHrMessageFromDb(),
    getRestingHrMessageFromDb(),
  ]).then(_formatHeartMessages);

  String _formatHeartMessages(List<String?> messages) {
    const labels = ['평균 심박수', '수면 중 심박수', '안정 시 심박수'];
    final parts = <String>[];

    for (var i = 0; i < labels.length; i++) {
      final msg = messages[i];
      if (msg != null && msg.isNotEmpty) {
        parts.add('${labels[i]}\n$msg');
      }
    }

    if (parts.isEmpty) {
      return '아직 데이터가 조금 더 모여야\n심박 메시지를 드릴 수 있어요.';
    }

    return parts.join('\n\n');
  }

  @override
  void initState() {
    super.initState();
    _loadLatestHeart(syncFromRing: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRing = context.read<Ring>();
    if (!identical(_ring, nextRing)) {
      _ring?.removeListener(_onRingStateChanged);
      _ring = nextRing;
      _ring!.addListener(_onRingStateChanged);
      _onRingStateChanged();
    }
    final nextRefresh = context.read<HealthDataRefreshNotifier>();
    if (!identical(_healthRefresh, nextRefresh)) {
      _healthRefresh?.removeListener(_onHealthDataRefresh);
      _healthRefresh = nextRefresh;
      _healthRefresh!.addListener(_onHealthDataRefresh);
    }
  }

  @override
  void dispose() {
    _ring?.removeListener(_onRingStateChanged);
    _healthRefresh?.removeListener(_onHealthDataRefresh);
    super.dispose();
  }

  void _onHealthDataRefresh() {
    if (_healthRefresh?.affects(DataType.HeartRate) ?? false) {
      unawaited(_loadLatestHeart(syncFromRing: false));
    }
  }

  void _onRingStateChanged() {
    if (_ring?.sdkReady == true && !_hrSyncStarted) {
      _hrSyncStarted = true;
      unawaited(_loadLatestHeart(syncFromRing: true));
    }
  }

  // "방금 전 / N분 전 / N시간 M분 전 / N일 전" 포맷
  String _formatAgo(Duration d) {
    if (d.inSeconds < 60) return "방금 전";
    final m = d.inMinutes;
    if (d.inHours * 60 + m < 200) return "${d.inHours * 60 + m}분 전";
    final h = d.inHours;
    if (h < 24) {
      final mm = m % 60;
      return mm == 0 ? "$h시간 전" : "$h시간 $mm분 전";
    }
    final days = d.inDays;
    return "$days일 전";
  }

  Future<void> _loadLatestHeart({required bool syncFromRing}) async {
    if (syncFromRing && _ring?.sdkReady != true) return;

    setState(() => _latestLoading = true);
    try {
      // iOS: bulk HR sync는 pending import·수동 측정과 BLE 충돌 → DB만 갱신
      if (syncFromRing && !Platform.isIOS) {
        await syncRecent3DaysHeartToDb(BleCommandQueue.channel);
      }
      final db = DbManager.I.heartDB;

      // bpm > 0 인 최신 1건
      final q = db.select(db.heartDetails)
        ..where((t) => t.bpm.isBiggerThanValue(0))
        ..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        ])
        ..limit(1);

      final rows = await q.get();

      if (rows.isEmpty) {
        _latestLabel = "데이터 없음";
        _latestBpmText = "-";
      } else {
        final r = rows.first;
        final dt = r.date; // DateTime
        final bpm = r.bpm; // int
        final diff = DateTime.now().difference(dt);

        _latestLabel = _formatAgo(diff);
        _latestBpmText = bpm > 0 ? bpm.toString() : "-";
      }
    } catch (_) {
      _latestLabel = "불러오기 오류";
      _latestBpmText = "-";
    } finally {
      if (mounted) setState(() => _latestLoading = false);
    }
  }

  Future<void> _onManualMeasureSuccess(Map<dynamic, dynamic> result) async {
    await persistManualMeasurement(
      dataType: DataType.HeartRate,
      result: result,
      metrics: context.read<HealthLiveMetrics>(),
      refreshNotifier: context.read<HealthDataRefreshNotifier>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SubAppBar(
          title: "심박수",
          // (선택) 즉석 새로고침 버튼이 필요하면 주석 해제
          // actions: [
          //   IconButton(
          //     icon: const Icon(Icons.refresh),
          //     onPressed: _loadLatestHeart,
          //     tooltip: '최신 심박 재조회',
          //   ),
          // ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                RealTimeDataCard(
                  dataType: DataType.HeartRate,
                  iconSvgPath: "assets/icons/heart.svg",
                  realTime: _latestLoading ? "대기 중" : _latestLabel,
                  realTimeData: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _latestBpmText,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: AppFontWeight.semiBold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        unit,
                        style: TextStyle(
                          color: AppColors.lightGray,
                          fontSize: 16,
                          fontWeight: AppFontWeight.regular,
                        ),
                      ),
                    ],
                  ),
                  isButtonExist: true,
                  onMeasureSuccess: _onManualMeasureSuccess,
                ),
                const SizedBox(height: 16),
                FutureBuilder<String>(
                  future: _healthMessageFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const HealthMessageCard(
                        title: '오늘의 심박 메시지',
                        message: '메시지를 불러오고 있어요...',
                      );
                    } else if (snapshot.hasError) {
                      return const HealthMessageCard(
                        title: '오늘의 심박 메시지',
                        message:
                            '메시지를 불러오지 못했어요.\n잠시 후 다시 확인해 주세요.',
                      );
                    } else {
                      return HealthMessageCard(
                        title: '오늘의 심박 메시지',
                        message: snapshot.data ?? '',
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                HealthChartCard(
                  unit: unit,
                  selectedRange: _selectedRange,
                  onChanged: (range) {
                    setState(() {
                      _selectedRange = range;
                    });
                  },
                  barType: GraphType.dot,
                  intervalYFunc: calculateIntervalY,
                  dataType: DataType.HeartRate,
                  widget: HeartRateRangeMessages(range: _selectedRange),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
