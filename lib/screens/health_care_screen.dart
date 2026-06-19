import 'dart:async';
import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/util/BLEUtil.dart';
import 'package:picnique_rosary_healthcare_smartring/util/stress.dart';
import 'package:provider/provider.dart'; // deviceAddress를 Provider에서 가져오는 경우
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/activity/healthcare_activity_card.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/healthcare_card.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_background_sync.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_live_metrics.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_live_activity.dart';

import '../providers/ring.dart';

class HealthCareScreen extends StatefulWidget {
  const HealthCareScreen({super.key});

  @override
  State<HealthCareScreen> createState() => _HealthCareScreenState();
}

class _HealthCareScreenState extends State<HealthCareScreen> {
  int? _stressScore;
  (int? h, int? m)? _sleep;
  int? _heartRate;
  int? _spo2;
  int? _calories;
  int? _walk;
  double? _dist;

  bool _loading = true;
  String? _error;
  bool _isConnected = false;

  Ring? _ring;
  RingSyncController? _sync;
  RingSyncStatus _lastSyncStatus = RingSyncStatus.idle;

  @override
  void initState() {
    super.initState();
    _loadAll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ring = context.read<Ring>()..addListener(_onRingChanged);
      _sync = context.read<RingSyncController>()..addListener(_onSyncChanged);
      _lastSyncStatus = _sync!.status;
    });
  }

  @override
  void dispose() {
    _ring?.removeListener(_onRingChanged);
    _sync?.removeListener(_onSyncChanged);
    super.dispose();
  }

  // 연결 상태가 바뀌면 배너 갱신 + 데이터 재조회
  void _onRingChanged() {
    final connected = _ring?.isConnected ?? false;
    if (connected != _isConnected && mounted) {
      _loadAll();
    }
  }

  // 백그라운드 동기화 완료 시 최신 데이터로 갱신
  void _onSyncChanged() {
    final status = _sync?.status ?? RingSyncStatus.idle;
    if (status != _lastSyncStatus) {
      _lastSyncStatus = status;
      if ((status == RingSyncStatus.done || status == RingSyncStatus.error) &&
          mounted) {
        _loadAll();
      }
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // deviceAddress 확보 (Provider 사용 가정)
      try {
        final ring = context.read<Ring>();
        _isConnected = ring.isConnected;
      } catch (_) {
        // Provider 미존재 시 무시 (수면 데이터는 표시 못할 수 있음)
      }

      final futures = <Future>[];

      final fStress = BleRepository.getLatestStress();
      futures.add(fStress);

      Future<(int?, int?)>? fSleep;
      fSleep = BleRepository.getTodaySleepHM(dayOffset: 0);
      futures.add(fSleep);

      final fHr = BleRepository.getLatestHeartRate();
      futures.add(fHr);

      final fSp = BleRepository.getLatestSpO2();
      futures.add(fSp);

      final fSport = BleRepository.getTodaySportFromDetail();
      futures.add(fSport);

      final results = await Future.wait(futures);

      // 결과 인덱싱
      int idx = 0;
      final stress = results[idx++] as int?;
      (int?, int?)? sleep;
      sleep = results[idx++] as (int?, int?)?;
      final hr = results[idx++] as int?;
      final sp = results[idx++] as int?;

      final calories = results[idx]?['calorie'];
      final walk = results[idx]?['totalSteps'];
      final dist = results[idx]?['walkDistance'];
      double? distKm;
      if (dist != null) {
        distKm = dist / 1000.0;
      } else {
        distKm = null;
      }

      setState(() {
        _stressScore = stress;
        _sleep = sleep;
        _heartRate = hr;
        _spo2 = sp;
        _loading = false;
        _calories = calories;
        _walk = walk;
        _dist = distKm;
      });

      if (mounted) {
        context.read<HealthLiveMetrics>().hydrate(
          heartRate: hr,
          spo2: sp,
          stress: stress,
        );
      }
    } catch (e) {
      setState(() {
        _error = '데이터 조회 중 오류가 발생했습니다: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ring = context.watch<Ring>();
    final live = context.watch<RingLiveActivity>();
    final metrics = context.watch<HealthLiveMetrics>();

    final useLiveSport = ring.isConnected && live.isTracking;
    final displaySteps = useLiveSport ? live.steps : _walk;
    final displayCalories = useLiveSport ? live.calories : _calories;
    final displayDistKm = useLiveSport
        ? live.distanceMeters / 1000.0
        : _dist;

    final heartRate = metrics.heartRate ?? _heartRate;
    final spo2 = metrics.spo2 ?? _spo2;
    final stressScore = metrics.stress ?? _stressScore;

    final stressScoreText = (stressScore != null)
        ? stressScore.toString()
        : '—';
    final stressLabelText = stressScore != null
        ? stressToLabel(stressScore.toDouble())
        : '—';

    final sleepHoursText = (_sleep?.$1 != null) ? _sleep!.$1.toString() : '—';
    final sleepMinutesText = (_sleep?.$2 != null) ? _sleep!.$2.toString() : '—';

    final heartRateText = (heartRate != null) ? heartRate.toString() : '—';
    final spo2Text = (spo2 != null) ? spo2.toString() : '—';

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: _loading
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 200),
                Center(child: CircularProgressIndicator()),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (!_isConnected) _buildNotConnectedBanner(),
                if (_isConnected &&
                    context.watch<RingSyncController>().isSyncing)
                  _buildSyncingBanner(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: AppColors.lightGray,
                        fontSize: 14,
                        fontWeight: AppFontWeight.medium,
                      ),
                    ),
                  ),
                Padding(
                  // ✅ UI 구조/간격은 기존 그대로
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      HealthCareActivityCard(
                        calories: displayCalories,
                        steps: displaySteps,
                        distanceKm: displayDistKm,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          HealthCareCard(
                            path: "/health-care-stress-detail",
                            iconSvgPath: "stress",
                            title: "스트레스",
                            isStress: stressScore != null
                                ? stressLevelIndex(stressScore)
                                : 0,
                            widget: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  stressScoreText,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: AppFontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  stressLabelText,
                                  style: TextStyle(
                                    color: AppColors.lightGray,
                                    fontSize: 16,
                                    fontWeight: AppFontWeight.medium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          HealthCareCard(
                            path: "/health-care-sleep-detail",
                            iconSvgPath: "sleep",
                            title: "수면",
                            isStress: 0,
                            widget: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  sleepHoursText,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: AppFontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  "h",
                                  style: TextStyle(
                                    color: AppColors.lightGray,
                                    fontSize: 16,
                                    fontWeight: AppFontWeight.medium,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  sleepMinutesText,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: AppFontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  "m",
                                  style: TextStyle(
                                    color: AppColors.lightGray,
                                    fontSize: 16,
                                    fontWeight: AppFontWeight.medium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          HealthCareCard(
                            path: "/health-heart-rate-detail",
                            iconSvgPath: "heart",
                            title: "심박수",
                            isStress: 0,
                            widget: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  heartRateText,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: AppFontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "bpm",
                                  style: TextStyle(
                                    color: AppColors.lightGray,
                                    fontSize: 16,
                                    fontWeight: AppFontWeight.medium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          HealthCareCard(
                            path: "/health-oxygen-detail",
                            iconSvgPath: "oxygen",
                            title: "혈중산소포화도",
                            isStress: 0,
                            widget: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  spo2Text,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: AppFontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "%",
                                  style: TextStyle(
                                    color: AppColors.lightGray,
                                    fontSize: 16,
                                    fontWeight: AppFontWeight.medium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSyncingBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.black.withValues(alpha: 0.6),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "최신 데이터를 동기화하고 있습니다…",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: AppFontWeight.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConnectedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.black.withValues(alpha: 0.6),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white, size: 20),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              "기기가 연결되지 않았습니다.\n연결 후 현재 데이터로 갱신됩니다.",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: AppFontWeight.medium,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              await Navigator.of(context).pushNamed('/connect-ring-setting');
              if (!mounted) return;
              await _loadAll();
            },
            child: const Text(
              "연결하기",
              style: TextStyle(
                color: AppColors.lightPurple,
                fontSize: 14,
                fontWeight: AppFontWeight.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
