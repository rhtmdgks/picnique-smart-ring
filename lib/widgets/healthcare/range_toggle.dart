import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/healthcare/range_toggle_button.dart';

class RangeToggle extends StatefulWidget {
  final ToggleRange selectedRange;
  final ValueChanged<ToggleRange> onChanged;

  const RangeToggle({
    super.key,
    required this.selectedRange,
    required this.onChanged,
  });

  @override
  State<RangeToggle> createState() => _RangeToggleState();
}

class _RangeToggleState extends State<RangeToggle> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.gray,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          RangeToggleButton(
            range: ToggleRange.day,
            isSelected: widget.selectedRange == ToggleRange.day,
            onTap: () => widget.onChanged(ToggleRange.day),
          ),
          SizedBox(width: 8),
          RangeToggleButton(
            range: ToggleRange.week,
            isSelected: widget.selectedRange == ToggleRange.week,

            onTap: () => widget.onChanged(ToggleRange.week),
          ),
          SizedBox(width: 8),
          RangeToggleButton(
            range: ToggleRange.month,
            isSelected: widget.selectedRange == ToggleRange.month,
            onTap: () => widget.onChanged(ToggleRange.month),
          ),
          SizedBox(width: 8),
          RangeToggleButton(
            range: ToggleRange.halfYear,
            isSelected: widget.selectedRange == ToggleRange.halfYear,
            onTap: () => widget.onChanged(ToggleRange.halfYear),
          ),
          SizedBox(width: 8),
          RangeToggleButton(
            range: ToggleRange.year,
            isSelected: widget.selectedRange == ToggleRange.year,
            onTap: () => widget.onChanged(ToggleRange.year),
          ),
        ],
      ),
    );
  }
}
