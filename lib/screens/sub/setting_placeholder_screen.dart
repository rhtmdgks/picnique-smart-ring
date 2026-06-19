import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';

/// 정책·약관·문의 등 본문이 추후 제공되는 설정 하위 화면.
class SettingPlaceholderScreen extends StatelessWidget {
  const SettingPlaceholderScreen({
    super.key,
    required this.title,
    this.message = '내용을 준비 중입니다.\n추후 업데이트될 예정이에요.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SubAppBar(title: title),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.lightGray,
                fontSize: 15,
                height: 1.6,
                fontWeight: AppFontWeight.regular,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
