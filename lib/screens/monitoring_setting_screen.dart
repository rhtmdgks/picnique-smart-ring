import '../integrations/rwfit/ring_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/monitoring_setting.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/setting/setting_toggle_row.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';
import 'package:provider/provider.dart';

class MonitoringSettingScreen extends StatefulWidget {
  const MonitoringSettingScreen({super.key});

  @override
  State<MonitoringSettingScreen> createState() =>
      _MonitoringSettingScreenState();
}

class _MonitoringSettingScreenState extends State<MonitoringSettingScreen> {
  Map<String, bool> _rwSettings = {};
  bool _rwBusy = false;
  String? _rwError;
  @override
  void initState() {
    super.initState();
    if (RingBackend.isRwfit) _loadRwfit();
  }
  Future<void> _loadRwfit() async {
    setState(() { _rwBusy = true; _rwError = null; });
    try {
      final values = await RingBackend.rwfit!.readMonitoring();
      if (mounted) setState(() => _rwSettings = values);
    } catch (e) { if (mounted) setState(() => _rwError = e.toString()); }
    finally { if (mounted) setState(() => _rwBusy = false); }
  }
  Future<void> _setRwfit(String kind, bool enabled) async {
    setState(() { _rwBusy = true; _rwError = null; });
    try {
      final actual = await RingBackend.rwfit!.setMonitoring(kind, enabled);
      if (mounted) setState(() => _rwSettings[kind] = actual);
    } catch (e) { if (mounted) setState(() => _rwError = e.toString()); }
    finally { if (mounted) setState(() => _rwBusy = false); }
  }
  Widget _rwfitSettings() => Scaffold(
    appBar: AppBar(title: const Text('건강 모니터링 설정')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      if (_rwBusy) const LinearProgressIndicator(),
      if (_rwError != null) Text(_rwError!),
      for (final item in const {'hr': '심박수', 'bo': '혈중산소', 'pressure': '스트레스'}.entries)
        SwitchListTile(title: Text(item.value),
          subtitle: Text(_rwSettings.containsKey(item.key) ? '장치 응답 기준' : '아직 조회하지 못했습니다.'),
          value: _rwSettings[item.key] ?? false,
          onChanged: _rwBusy || !_rwSettings.containsKey(item.key) ? null : (v) => _setRwfit(item.key, v)),
      const ListTile(title: Text('걸음수 · 수면 · 활동'),
        subtitle: Text('제공 SDK의 해당 항목 켜기/끄기 설정 명세가 없어 변경하지 않습니다.')),
      OutlinedButton(onPressed: _rwBusy ? null : _loadRwfit, child: const Text('장치 설정 다시 읽기')),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    if (RingBackend.isRwfit) return _rwfitSettings();
    return Consumer<MonitoringSetting>(
      builder: (context, monitoringSettingProvider, child) {
        final List<Map<String, dynamic>> monitoringSettingRows = [
          {
            "title": "걸음수",
            "iconSvgPath": "assets/icons/step.svg",
            "isToggleOn": monitoringSettingProvider.isStepOn,
            "onTap": () {
              monitoringSettingProvider
                  .setIsStepOn(!monitoringSettingProvider.isStepOn);
            }
          },
          {
            "title": "수면",
            "iconSvgPath": "assets/icons/sleep.svg",
            "isToggleOn": monitoringSettingProvider.isSleepOn,
            "onTap": () {
              monitoringSettingProvider
                  .setIsSleepOn(!monitoringSettingProvider.isSleepOn);
            }
          },
          {
            "title": "심박수",
            "iconSvgPath": "assets/icons/heart.svg",
            "isToggleOn": monitoringSettingProvider.isHeartRateOn,
            "onTap": () {
              monitoringSettingProvider
                  .setIsHeartRateOn(!monitoringSettingProvider.isHeartRateOn);
            }
          },
          {
            "title": "혈중 산소 포화도",
            "iconSvgPath": "assets/icons/oxygen.svg",
            "isToggleOn": monitoringSettingProvider.isBloodOxygenOn,
            "onTap": () {
              monitoringSettingProvider.setIsBloodOxygenOn(
                  !monitoringSettingProvider.isBloodOxygenOn);
            },
          },
          {
            "title": "스트레스",
            "iconSvgPath": "assets/icons/stress.svg",
            "isToggleOn": monitoringSettingProvider.isStressOn,
            "onTap": () {
              monitoringSettingProvider
                  .setIsStressOn(!monitoringSettingProvider.isStressOn);
            },
          },
          {
            "title": "활동",
            "iconSvgPath": "assets/icons/activity.svg",
            "isToggleOn": monitoringSettingProvider.isActivityOn,
            "onTap": () {
              monitoringSettingProvider
                  .setIsActivityOn(!monitoringSettingProvider.isActivityOn);
            },
          }
        ];

        return BackgroundLayout(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: SubAppBar(title: "건강 모니터링 설정"),
            body: Padding(
              padding: EdgeInsetsGeometry.all(12),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var monitoringSettingRow
                        in monitoringSettingRows.asMap().entries)
                      SettingToggleRow(
                          left: SvgPicture.asset(
                            monitoringSettingRow.value["iconSvgPath"]!,
                            colorFilter: ColorFilter.mode(
                                AppColors.lightPurple, BlendMode.srcIn),
                            width: 40,
                            height: 40,
                            fit: BoxFit.scaleDown,
                          ),
                          title: monitoringSettingRow.value["title"]!,
                          isLast: monitoringSettingRow.key ==
                              monitoringSettingRows.length - 1,
                          isToggleOn: monitoringSettingRow.value["isToggleOn"]!,
                          onTap: monitoringSettingRow.value["onTap"]!)
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
