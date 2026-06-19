import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';

class HealthMessageCard extends StatelessWidget {
  final String message;
  final String title;

  const HealthMessageCard({
    super.key,
    required this.message,
    this.title = '오늘의 건강 메세지',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sticky_note_2_outlined, color: Colors.white, size: 20),
              SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: AppFontWeight.semiBold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: AppColors.lightGray,
              fontSize: 14,
              fontWeight: AppFontWeight.medium,
            ),
          ),
        ],
      ),
    );
  }
}
