import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  static const _appName = 'Picnique Smart Ring';
  static const _version = '1.0.0';
  static const _buildNumber = '1';

  @override
  Widget build(BuildContext context) {
    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SubAppBar(title: '앱 정보'),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _appName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: AppFontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '버전 $_version ($_buildNumber)',
                  style: TextStyle(
                    color: AppColors.lightGray,
                    fontSize: 14,
                    fontWeight: AppFontWeight.regular,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '앱에 대한 상세 정보는 준비 중입니다.',
                  style: TextStyle(
                    color: AppColors.lightGray,
                    fontSize: 15,
                    height: 1.6,
                    fontWeight: AppFontWeight.regular,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
