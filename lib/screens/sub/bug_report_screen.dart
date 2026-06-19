import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';

class BugReportScreen extends StatelessWidget {
  const BugReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SubAppBar(title: '버그 신고'),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '버그 신고 양식은 준비 중입니다.',
                style: TextStyle(
                  color: AppColors.lightGray,
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: AppFontWeight.regular,
                ),
              ),
              const SizedBox(height: 20),
              _disabledField(label: '제목', hint: '추후 입력 가능'),
              const SizedBox(height: 12),
              Expanded(
                child: _disabledField(
                  label: '상세 내용',
                  hint: '추후 입력 가능',
                  maxLines: 8,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.mutePurple.withValues(alpha: 0.4),
                  disabledBackgroundColor:
                      AppColors.mutePurple.withValues(alpha: 0.4),
                  foregroundColor: Colors.white54,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '제출 (준비 중)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: AppFontWeight.semiBold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _disabledField({
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: AppFontWeight.medium,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          enabled: false,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.lightGray.withValues(alpha: 0.6)),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.darkGray.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
