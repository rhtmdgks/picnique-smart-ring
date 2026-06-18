import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';

class BatteryStatus extends StatelessWidget {
  const BatteryStatus({
    super.key,
    required this.battery,
  });

  final int battery;

  String get svg {
    if (battery < 20) return 'battery_20';
    if (battery < 40) return 'battery_40';
    if (battery < 60) return 'battery_60';
    if (battery < 80) return 'battery_80';
    return 'battery_100';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(
          'assets/icons/$svg.svg',
        ),
        SizedBox(
          width: 4,
        ),
        SizedBox(
          width: 36,
          child: Text(
            "${battery.toString()}%",
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.lightGray,
              fontSize: 12,
              fontVariations: AppFontVariations.light,
            ),
          ),
        ),
      ],
    );
  }
}
