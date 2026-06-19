import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';

class SettingRowAtomic extends StatelessWidget {
  const SettingRowAtomic({
    super.key,
    required this.title,
    required this.isLast,
    required this.left,
    required this.right,
  });

  final String title;
  final bool isLast;
  final Widget left, right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isLast
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                left,
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFontWeight.semiBold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            right,
          ],
        ),
      ),
    );
  }
}
