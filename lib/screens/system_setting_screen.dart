import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/app_info_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/bug_report_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/contact_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/legal_document_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/setting/setting_chevron_row.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';

class SystemSettingScreen extends StatelessWidget {
  const SystemSettingScreen({super.key});

  static const _items = <_SystemSettingItem>[
    _SystemSettingItem(
      title: '개인정보 처리방침',
      icon: Icons.privacy_tip_outlined,
    ),
    _SystemSettingItem(
      title: '서비스 이용약관',
      icon: Icons.description_outlined,
    ),
    _SystemSettingItem(
      title: '문의하기',
      icon: Icons.mail_outline_rounded,
    ),
    _SystemSettingItem(
      title: '앱 정보',
      icon: Icons.info_outline_rounded,
    ),
    _SystemSettingItem(
      title: '버그 신고',
      icon: Icons.bug_report_outlined,
    ),
  ];

  void _open(BuildContext context, _SystemSettingItem item) {
    final Widget screen;
    switch (item.title) {
      case '개인정보 처리방침':
        screen = const LegalDocumentScreen(
          title: '개인정보 처리방침',
          assetPath: 'assets/legal/privacy_policy.md',
        );
        break;
      case '서비스 이용약관':
        screen = const LegalDocumentScreen(
          title: '서비스 이용약관',
          assetPath: 'assets/legal/terms_of_service.md',
        );
        break;
      case '문의하기':
        screen = const ContactScreen();
        break;
      case '앱 정보':
        screen = const AppInfoScreen();
        break;
      case '버그 신고':
        screen = const BugReportScreen();
        break;
      default:
        return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SubAppBar(title: '시스템 설정'),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in _items.asMap().entries)
                  SettingRow(
                    title: entry.value.title,
                    left: _MenuIcon(icon: entry.value.icon),
                    isLast: entry.key == _items.length - 1,
                    onTap: () => _open(context, entry.value),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemSettingItem {
  const _SystemSettingItem({required this.title, required this.icon});

  final String title;
  final IconData icon;
}

class _MenuIcon extends StatelessWidget {
  const _MenuIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: 32,
      decoration: BoxDecoration(
        color: AppColors.lightPurple,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}
