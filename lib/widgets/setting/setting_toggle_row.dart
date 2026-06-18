import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/user_setting.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/setting/setting_row_atomic.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/toggle.dart';
import 'package:provider/provider.dart';

class SettingToggleRow extends StatelessWidget {
  const SettingToggleRow({
    super.key,
    required this.left,
    required this.title,
    required this.isLast,
    required this.isToggleOn,
    required this.onTap,
  });

  final Widget left;
  final String title;
  final bool isLast, isToggleOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Consumer<UserSetting>(
      builder: (context, userSettingProvider, child) {
        return SettingRowAtomic(
          left: left,
          title: title,
          isLast: isLast,
          right: RightIcon(
            isToggleOn: isToggleOn,
            onTap: onTap,
          ),
        );
      },
    );
  }
}

class RightIcon extends StatelessWidget {
  const RightIcon({
    super.key,
    required this.isToggleOn,
    required this.onTap,
  });

  final bool isToggleOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Toggle(
      isToggleOn: isToggleOn,
      onTap: onTap,
    );
  }
}