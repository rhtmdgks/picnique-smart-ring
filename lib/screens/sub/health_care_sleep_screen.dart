import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/util/BLEUtil.dart';
import 'package:picnique_rosary_healthcare_smartring/util/TrendUtil.dart';
import 'package:picnique_rosary_healthcare_smartring/util/stress.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/health_message.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/real_time_card.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/charts/health_chart_card.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';

// y축 간격은 간단 고정
double calculateIntervalY(double localMaxY, double localMinY) {
  final diff =
      (localMaxY - localMinY) / Duration.millisecondsPerHour.toDouble();
  final hour = Duration.millisecondsPerHour.toDouble();
  if (diff.abs() <= 4) {
    return hour;
  } else if (diff.abs() <= 8) {
    return hour * 2;
  } else if (diff.abs() <= 16) {
    return hour * 4;
  }
  {
    return hour * 6;
  }
}

class HealthCareSleepScreen extends StatefulWidget {
  const HealthCareSleepScreen({super.key});

  @override
  State<HealthCareSleepScreen> createState() => _HealthCareSleepScreenState();
}

class _HealthCareSleepScreenState extends State<HealthCareSleepScreen> {
  ToggleRange _selectedRange = ToggleRange.day;

  // 최신 데이터 표시용
  String _latestLabel = "-"; // "5분 전" 등
  bool _latestLoading = false;
  int? _latestStress; // 숫자값 보관(라벨 계산용)

  (int? h, int? m)? _sleep;
  late final Future<String> _sleepMessageFuture;

  // stress 라벨(unit) 동적 계산
  String get unit => stressToLabel((_latestStress ?? 0).toDouble());

  final platform = const MethodChannel('com.example.picnique_ring/ble');

  @override
  void initState() {
    super.initState();
    _sleepMessageFuture = _loadSleepMessages();
    _fetchLatest();
  }

  Future<void> _fetchLatest() async {
    setState(() => _latestLoading = true);
    try {
      final s = await BleRepository.getTodaySleepHM().timeout(
        const Duration(seconds: 6),
      ); // (int?, int?)? 반환 가정
      if (!mounted) return;
      setState(() {
        _sleep = s;
        _latestLoading = false;
        _latestLabel = ""; // 필요 시 최신 동기화 시간으로 갱신
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _latestLoading = false;
        _latestLabel = "오류";
        _sleep = null; // 안전하게 초기화
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수면 데이터를 불러오지 못했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  Future<String> _safeMessage(Future<String?> future, String label) async {
    try {
      final result = await future.timeout(const Duration(seconds: 5));
      return result ?? '-';
    } catch (_) {
      return '-';
    }
  }

  Future<String> _loadSleepMessages() async {
    final results = await Future.wait<String>([
      _safeMessage(getTotalSleepMessageFromDb(), "total"),
      _safeMessage(getAwakeCountMessageFromDb(), "awake"),
      _safeMessage(getBedtimeRegularityMessageFromDb(), "regularity"),
    ]);

    return "총 수면 시간: ${results[0]}\n깸 횟수: ${results[1]}\n취침 규칙성: ${results[2]}";
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SubAppBar(title: "수면"),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                RealTimeDataCard(
                  dataType: DataType.Sleep,
                  iconSvgPath: "assets/icons/sleep.svg",
                  realTime: _latestLoading ? "대기 중" : _latestLabel,
                  realTimeData: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        (_sleep?.$1)?.toString() ?? "-",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontVariations: AppFontVariations.regular,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        "h",
                        style: TextStyle(
                          color: AppColors.lightGray,
                          fontSize: 16,
                          fontVariations: AppFontVariations.regular,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        (_sleep?.$2)?.toString() ?? "-",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontVariations: AppFontVariations.regular,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        "m",
                        style: TextStyle(
                          color: AppColors.lightGray,
                          fontSize: 16,
                          fontVariations: AppFontVariations.regular,
                        ),
                      ),
                    ],
                  ),
                  isButtonExist: false,
                ),
                const SizedBox(height: 16),
                FutureBuilder<String>(
                  future: _sleepMessageFuture,
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
                  unit: "",
                  selectedRange: _selectedRange,
                  onChanged: (range) => setState(() => _selectedRange = range),
                  barType: GraphType.stackedBar,
                  intervalYFunc: calculateIntervalY,
                  dataType: DataType.Sleep,
                  widget: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        SizedBox(width: 12),
                        Row(
                          children: [
                            Container(
                              color: const Color(0xFFBB8EFA),
                              width: 16,
                              height: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "얕은 수면",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 12),
                        Row(
                          children: [
                            Container(
                              color: AppColors.purple,
                              width: 16,
                              height: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "렘 수면",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 12),
                        Row(
                          children: [
                            Container(
                              color: const Color(0xFF500EAD),
                              width: 16,
                              height: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "깊은 수면",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
