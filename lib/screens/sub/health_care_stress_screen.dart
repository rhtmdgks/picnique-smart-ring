import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/util/BLEUtil.dart';
import 'package:picnique_rosary_healthcare_smartring/util/stress.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/real_time_card.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/charts/health_chart_card.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/stress_hrv_messages.dart';
import 'package:provider/provider.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_data_refresh_notifier.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_live_metrics.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';

// y축 간격은 간단 고정
double calculateIntervalY(double localMaxY, double localMinY) => 20;

class HealthCareStressScreen extends StatefulWidget {
  const HealthCareStressScreen({super.key});

  @override
  State<HealthCareStressScreen> createState() => _HealthCareStressScreenState();
}

class _HealthCareStressScreenState extends State<HealthCareStressScreen> {
  ToggleRange _selectedRange = ToggleRange.day;

  // 최신 데이터 표시용
  String _latestLabel = "-"; // "5분 전" 등
  String _latestValueText = "-"; // "30" 등
  bool _latestLoading = false;
  int? _latestStress; // 숫자값 보관(라벨 계산용)

  // stress 라벨(unit) 동적 계산
  String get unit => stressToLabel((_latestStress ?? 0).toDouble());

  final platform = BleCommandQueue.channel;
  HealthDataRefreshNotifier? _healthRefresh;
  Ring? _ring;
  bool _stressSyncStarted = false;

  late final Future<StressHrvMessageResult> _healthMessageFuture =
      buildStressHrvMessages();

  @override
  void initState() {
    super.initState();
    _loadLatestStress(skipSync: true);
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

  void _onRingStateChanged() {
    if (_ring?.sdkReady == true && !_stressSyncStarted) {
      _stressSyncStarted = true;
      unawaited(_loadLatestStress());
    }
  }

  void _onHealthDataRefresh() {
    if (_healthRefresh?.affects(DataType.Stress) ?? false) {
      unawaited(_loadLatestStress(skipSync: true));
    }
  }

  // "방금 전 / N분 전 / N시간 M분 전 / N일 전"
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

  Future<void> _loadLatestStress({bool skipSync = false}) async {
    setState(() => _latestLoading = true);
    try {
      // iOS: bulk stress sync는 pending import·수동 측정과 BLE 충돌
      if (!skipSync && !Platform.isIOS) {
        await syncRecent7DaysStressToDb(platform);
      }

      final db = DbManager.I.heartDB;

      // 2) stress > 0 최신 1건
      final q = db.select(db.stressDetails)
        ..where((t) => t.stress.isBiggerThanValue(0))
        ..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        ])
        ..limit(1);

      final rows = await q.get();
      if (rows.isEmpty) {
        _latestLabel = "데이터 없음";
        _latestValueText = "-";
        _latestStress = null;
      } else {
        final r = rows.first;
        _latestStress = r.stress;
        _latestValueText = r.stress.toString();

        final diff = DateTime.now().difference(r.date);
        _latestLabel = _formatAgo(diff);
      }
    } catch (e) {
      _latestLabel = "불러오기 오류";
      _latestValueText = "-";
      _latestStress = null;
    } finally {
      if (mounted) setState(() => _latestLoading = false);
    }
  }

  Future<void> _onManualMeasureSuccess(Map<dynamic, dynamic> result) async {
    await persistManualMeasurement(
      dataType: DataType.Stress,
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
        appBar: const SubAppBar(title: "스트레스"),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                RealTimeDataCard(
                  dataType: DataType.Stress,
                  iconSvgPath: "assets/icons/stress.svg",
                  realTime: _latestLoading ? "대기 중" : _latestLabel,
                  realTimeData: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _latestValueText,
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
                StressHrvMessages(future: _healthMessageFuture),
                const SizedBox(height: 16),
                HealthChartCard(
                  unit: unit,
                  selectedRange: _selectedRange,
                  onChanged: (range) => setState(() => _selectedRange = range),
                  barType: GraphType.bar,
                  intervalYFunc: calculateIntervalY,
                  dataType: DataType.Stress,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
