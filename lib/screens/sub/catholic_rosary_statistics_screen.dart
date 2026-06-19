import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/real_time_card.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/charts/health_chart_card.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';
import 'package:drift/drift.dart' show OrderingMode, OrderingTerm;

double calculateIntervalY(double localMaxY, double localMinY) {
  final double difference = localMaxY - localMinY;

  if (difference < 40) {
    return 5;
  } else if (difference < 80) {
    return 10;
  } else if (difference < 160) {
    return 20;
  } else if (difference < 320) {
    return 40;
  } else if (difference < 1000) {
    return 100;
  } else {
    return 1000;
  }
}

class CatholicRosaryStatisticsScreen extends StatefulWidget {
  const CatholicRosaryStatisticsScreen({super.key});

  @override
  State<CatholicRosaryStatisticsScreen> createState() =>
      _CatholicRosaryStatisticsScreenState();
}

class _CatholicRosaryStatisticsScreenState
    extends State<CatholicRosaryStatisticsScreen> {
  final String unit = "단";
  ToggleRange _selectedRange = ToggleRange.day;
  int? _latestCount;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadLatest();
  }

  Future<void> _loadLatest() async {
    setState(() => _loading = true);
    try {
      final db = DbManager.I.appDB;
      final row =
          await (db.select(db.rosarySessions)
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.startAt,
                    mode: OrderingMode.desc,
                  ),
                ])
                ..limit(1))
              .getSingleOrNull();
      if (!mounted) return;
      setState(() {
        _latestCount = row?.tapCount;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SubAppBar(title: "묵주기도 통계"),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              RealTimeDataCard(
                dataType: DataType.Rosary,
                iconSvgPath: "assets/icons/rosary.svg",
                realTime: _loading ? "loading" : "",
                realTimeData: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _latestCount?.toString() ?? "-",
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
                isButtonExist: false,
              ),
              const SizedBox(height: 16),
              HealthChartCard(
                unit: unit,
                selectedRange: _selectedRange,
                onChanged: (range) => setState(() => _selectedRange = range),
                barType: GraphType.bar,
                intervalYFunc: calculateIntervalY,
                dataType: DataType.Rosary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
