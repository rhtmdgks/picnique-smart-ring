import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';

class BatteryStatus extends StatelessWidget {
  const BatteryStatus({
    super.key,
    required this.battery,
    this.isCharging = false,
  });

  final int battery;
  final bool isCharging;

  String get _iconName {
    if (isCharging) return 'charge';
    if (battery < 20) return 'battery_20';
    if (battery < 40) return 'battery_40';
    if (battery < 60) return 'battery_60';
    if (battery < 80) return 'battery_80';
    return 'battery_100';
  }

  @override
  Widget build(BuildContext context) {
    final label = isCharging ? '충전 중 $battery%' : '$battery%';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/icons/$_iconName.svg',
          width: 16,
          height: 16,
          colorFilter: ColorFilter.mode(
            isCharging ? AppColors.lightPurple : AppColors.lightGray,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: isCharging ? AppColors.lightPurple : AppColors.lightGray,
            fontSize: 12,
            fontWeight: AppFontWeight.medium,
          ),
        ),
      ],
    );
  }
}
