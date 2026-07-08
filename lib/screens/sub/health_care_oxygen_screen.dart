import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:picnique_rosary_healthcare_smartring/core/charts/health_chart_theme.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/util/BLEUtil.dart';
import 'package:picnique_rosary_healthcare_smartring/util/TrendUtil.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/health_message.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/real_time_card.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/charts/health_chart_card.dart';
import 'package:provider/provider.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_data_refresh_notifier.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';

double calculateIntervalY(double localMaxY, double localMinY) {
  final double diff = localMaxY - localMinY;
  if (diff < 4) return 1;
  if (diff < 8) return 2;
  return 5;
}

class HealthCareOxygenScreen extends StatefulWidget {
  const HealthCareOxygenScreen({super.key});

  @override
  State<HealthCareOxygenScreen> createState() => _HealthCareOxygenScreenState();
}

class _HealthCareOxygenScreenState extends State<HealthCareOxygenScreen> {
  final String unit = "%";
  ToggleRange _selectedRange = ToggleRange.day;

  String _latestLabel = "-";
  String _latestValueText = "-";
  bool _latestLoading = false;

  final platform = const MethodChannel('com.example.picnique_ring/ble');
  HealthDataRefreshNotifier? _healthRefresh;

  /// 날짜/범위와 무관하게 한 번만 로드해 유지
  late final Future<String> _healthMessageFuture =
      Future.wait([getSpO2AverageMessage(), getSpO2VariabilityMessage()]).then(
        (results) =>
            "하루 간: ${results[0] ?? "(충분한 데이터가 모이지 않았습니다.)"}\n변동폭: ${results[1] ?? "(충분한 데이터가 모이지 않았습니다.)"}",
      );

  @override
  void initState() {
    super.initState();
    _loadLatestOxygen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRefresh = context.read<HealthDataRefreshNotifier>();
    if (!identical(_healthRefresh, nextRefresh)) {
      _healthRefresh?.removeListener(_onHealthDataRefresh);
      _healthRefresh = nextRefresh;
      _healthRefresh!.addListener(_onHealthDataRefresh);
    }
  }

  @override
  void dispose() {
    _healthRefresh?.removeListener(_onHealthDataRefresh);
    super.dispose();
  }

  void _onHealthDataRefresh() {
    if (_healthRefresh?.affects(DataType.Oxygen) ?? false) {
      unawaited(_reloadLatestFromDb());
    }
  }

  Future<void> _reloadLatestFromDb() async {
    try {
      final db = DbManager.I.heartDB;
      final q = db.select(db.bloodOxygenDetails)
        ..where((t) => t.spo2.isBiggerThanValue(0))
        ..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        ])
        ..limit(1);

      final rows = await q.get();
      if (!mounted) return;
      if (rows.isEmpty) {
        setState(() {
          _latestLabel = '데이터 없음';
          _latestValueText = '-';
        });
        return;
      }
      final r = rows.first;
      setState(() {
        _latestValueText = r.spo2.toString();
        _latestLabel = _formatAgo(DateTime.now().difference(r.date));
      });
    } catch (_) {}
  }

  String _formatAgo(Duration d) {
    if (d.inSeconds < 60) return "방금 전";
    final m = d.inMinutes;
    if (d.inHours * 60 + m < 200) return "${d.inHours * 60 + m}분 전";
    final h = d.inHours;
    if (h < 24) {
      return "$h시간 전";
    }
    final days = d.inDays;
    return "$days일 전";
  }

  Future<void> _loadLatestOxygen() async {
    setState(() => _latestLoading = true);
    try {
      // 1) 최근 3일 산소 데이터 동기화
      // 프로젝트에 없다면 주석 처리
      await syncRecent3DaysOxygenToDb(platform);

      final db = DbManager.I.heartDB;

      // 2) spo2 > 0 최신 1건
      final q = db.select(db.bloodOxygenDetails)
        ..where((t) => t.spo2.isBiggerThanValue(0))
        ..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        ])
        ..limit(1);

      final rows = await q.get();
      if (rows.isEmpty) {
        _latestLabel = "데이터 없음";
        _latestValueText = "-";
      } else {
        final r = rows.first;
        _latestValueText = r.spo2.toString();
        final diff = DateTime.now().difference(r.date);
        _latestLabel = _formatAgo(diff);
      }
    } catch (e) {
      _latestLabel = "불러오기 오류";
      _latestValueText = "-";
    } finally {
      if (mounted) setState(() => _latestLoading = false);
    }
  }

  Color _latestValueColor() {
    final v = int.tryParse(_latestValueText);
    if (v == null) return Colors.white;
    if (v < HealthChartTheme.oxygenDangerThreshold) return AppColors.StressRed;
    if (v < 90) return AppColors.StressOrange;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SubAppBar(title: "혈중산소포화도"),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                RealTimeDataCard(
                  dataType: DataType.Oxygen,
                  iconSvgPath: "assets/icons/oxygen.svg",
                  realTime: _latestLoading ? "대기 중" : _latestLabel,
                  realTimeData: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _latestValueText,
                        style: TextStyle(
                          color: _latestValueColor(),
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
                ),
                const SizedBox(height: 16),
                FutureBuilder<String>(
                  future: _healthMessageFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return HealthMessageCard(message: "Loading...");
                    } else if (snapshot.hasError) {
                      return HealthMessageCard(
                        message: "Error loading message",
                      );
                    } else {
                      return HealthMessageCard(message: snapshot.data ?? "");
                    }
                  },
                ),
                const SizedBox(height: 16),
                HealthChartCard(
                  unit: unit,
                  selectedRange: _selectedRange,
                  onChanged: (range) => setState(() => _selectedRange = range),
                  barType: GraphType.dot,
                  intervalYFunc: calculateIntervalY,
                  dataType: DataType.Oxygen,
                ),
                const SizedBox(height: 8),
                _OxygenChartLegend(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OxygenChartLegend extends StatelessWidget {
  const _OxygenChartLegend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: AppColors.lightGray,
              fontSize: 12,
              fontWeight: AppFontWeight.regular,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          item(AppColors.StressRed, '80% 미만 · 주의'),
          item(AppColors.StressOrange, '80–89%'),
          item(const Color(0xFF5AC8FA), '90% 이상'),
        ],
      ),
    );
  }
}
