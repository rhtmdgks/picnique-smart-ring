import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/setting/setting_row_atomic.dart';

class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.left,
    required this.title,
    required this.isLast,
    required this.onTap,
  });

  final Widget left;
  final String title;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SettingRowAtomic(
        left: left,
        title: title,
        isLast: isLast,
        right: RightIcon(),
      ),
    );
  }
}

class RightIcon extends StatelessWidget {
  const RightIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.chevron_right_rounded, color: AppColors.lightGray);
  }
}
