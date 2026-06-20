import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/user_setting.dart';
import 'package:picnique_rosary_healthcare_smartring/services/battery_notification_service.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/setting/background_icon.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/setting/setting_chevron_row.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/setting/setting_toggle_row.dart';
import 'package:provider/provider.dart';

class SettingCard extends StatelessWidget {
  const SettingCard({super.key});

  Future<void> _toggleChargeAlarm(BuildContext context) async {
    final userSetting = context.read<UserSetting>();
    final next = !userSetting.isChargeAlarmOn;
    final ok = await userSetting.setIsChargeAlarmOn(next);
    if (!context.mounted) return;
    if (ok && next) {
      final battery = context.read<Ring>().battery;
      if (battery != null) {
        await BatteryNotificationService.onBatteryLevel(battery);
      }
    }
    if (!context.mounted) return;
    if (!ok && next) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('알림 권한이 필요합니다. 설정에서 알림을 허용해 주세요.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserSetting>(
      builder: (context, userSettingProvider, child) {
        final List<Map<String, dynamic>> settingRowData = [
          const {
            "svg": "heart_plus",
            "title": "건강 모니터링 설정",
            "type": "chevron",
            "router": "/monitoring-setting",
          },
          {
            "svg": "charge",
            "title": "배터리·충전 알림",
            "type": "toggle",
            "isToggleOn": userSettingProvider.isChargeAlarmOn,
            "onTap": () => _toggleChargeAlarm(context),
          },
          const {
            "svg": "download",
            "title": "펌웨어 업그레이드",
            "type": "chevron",
            "router": "/updrade-setting",
          },
          const {
            "svg": "setting",
            "title": "시스템 설정",
            "type": "chevron",
            "router": "/system-setting",
          },
        ];
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                for (var settingRowDatum in settingRowData.asMap().entries)
                  settingRowDatum.value["type"]! == "chevron"
                      ? SettingRow(
                          title: settingRowDatum.value["title"]!,
                          left: BackgroundIcon(
                            svg: settingRowDatum.value["svg"]!,
                          ),
                          isLast:
                              settingRowDatum.key == settingRowData.length - 1,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              settingRowDatum.value["router"]!,
                            );
                          },
                        )
                      : SettingToggleRow(
                          title: settingRowDatum.value["title"]!,
                          left: BackgroundIcon(
                            svg: settingRowDatum.value["svg"]!,
                          ),
                          isLast:
                              settingRowDatum.key == settingRowData.length - 1,
                          isToggleOn: settingRowDatum.value["isToggleOn"],
                          onTap: settingRowDatum.value["onTap"],
                        ),
              ],
            ),
          ),
        );
      },
    );
  }
}
