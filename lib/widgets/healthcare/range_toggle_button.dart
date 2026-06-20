import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';

class RangeToggleButton extends StatelessWidget {
  final ToggleRange range;
  final bool isSelected;
  final VoidCallback onTap;

  const RangeToggleButton({
    super.key,
    required this.range,
    required this.isSelected,
    required this.onTap,
  });

  String get rangeString => switch (range) {
    ToggleRange.day => "1일",
    ToggleRange.week => "1주",
    ToggleRange.month => "1개월",
    ToggleRange.halfYear => "3개월",
  };

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.lightGray : AppColors.gray,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            rangeString,
            style: TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: isSelected ? AppFontWeight.semiBold : AppFontWeight.medium,
            ),
          ),
        ),
      ),
    );
  }
}
