import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';

class HealthChartEmpty extends StatelessWidget {
  final String message;

  const HealthChartEmpty({
    super.key,
    this.message = '측정 데이터 없음',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.show_chart_outlined,
            size: 40,
            color: AppColors.lightGray.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: AppColors.lightGray,
              fontSize: 14,
              fontWeight: AppFontWeight.regular,
            ),
          ),
        ],
      ),
    );
  }
}

class HealthChartLoading extends StatelessWidget {
  const HealthChartLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
