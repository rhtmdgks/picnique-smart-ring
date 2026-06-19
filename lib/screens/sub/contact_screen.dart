import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static const supportEmail = 'ceo@picnique.kr';

  Future<void> _openEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: const {'subject': 'Picnique Smart Ring 문의'},
    );
    if (!await launchUrl(uri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이메일 앱을 열 수 없습니다. $supportEmail 로 직접 보내 주세요.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SubAppBar(title: '문의하기'),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '서비스 이용·기기 연결·개인정보 등 문의 사항이 있으시면 아래 이메일로 연락해 주세요.',
                  style: TextStyle(
                    color: AppColors.lightGray,
                    fontSize: 15,
                    height: 1.6,
                    fontWeight: AppFontWeight.regular,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '문의 이메일',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: AppFontWeight.medium,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  supportEmail,
                  style: TextStyle(
                    color: AppColors.lightPurple,
                    fontSize: 17,
                    fontWeight: AppFontWeight.semiBold,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => _openEmail(context),
                  icon: const Icon(Icons.mail_outline_rounded, size: 20),
                  label: Text(
                    '이메일 보내기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: AppFontWeight.semiBold,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lightPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
