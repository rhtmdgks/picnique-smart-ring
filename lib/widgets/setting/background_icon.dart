
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';

class BackgroundIcon extends StatelessWidget {
  const BackgroundIcon({
    super.key,
    required this.svg,
  });

  final String svg;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: 32,
      decoration: BoxDecoration(
        color: AppColors.lightPurple,
        borderRadius: BorderRadius.circular(50),
      ),
      child: SvgPicture.asset(
        'assets/icons/$svg.svg',
        colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
        width: 24,
        height: 24,
        fit: BoxFit.scaleDown,
      ),
    );
  }
}
