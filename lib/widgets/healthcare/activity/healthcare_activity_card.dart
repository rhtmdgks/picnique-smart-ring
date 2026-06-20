import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';

class HealthCareActivityCard extends StatelessWidget {
  const HealthCareActivityCard({
    super.key,
    required this.calories, // cal
    required this.steps, // 걸음수
    required this.distanceKm, // km
    this.title = "활동",
  });

  final int? calories;
  final int? steps;
  final double? distanceKm;
  final String title;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, "/health-care-activity-detail");
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.3),
              AppColors.purple.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                SvgPicture.asset('assets/icons/activity.svg'),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: AppFontWeight.medium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 칼로리
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "칼로리",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: AppFontWeight.medium,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          calories != null
                              ? (calories! / 1000.0).toStringAsFixed(1)
                              : '—',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: AppFontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "kcal",
                          style: TextStyle(
                            color: AppColors.lightGray,
                            fontSize: 12,
                            fontWeight: AppFontWeight.medium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // 걸음수
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "걸음수",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: AppFontWeight.medium,
                      ),
                    ),
                    Text(
                      steps != null ? _formatInt(steps!) : '—',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: AppFontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // 거리
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "거리",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: AppFontWeight.medium,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          distanceKm != null ? _formatKm(distanceKm!) : '—',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: AppFontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "km",
                          style: TextStyle(
                            color: AppColors.lightGray,
                            fontSize: 12,
                            fontWeight: AppFontWeight.medium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 1,234 형태로 포맷
  static String _formatInt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }

  // 소수점 2자리 고정 (12.34)
  static String _formatKm(double km) {
    return km.toStringAsFixed(2);
  }
}
