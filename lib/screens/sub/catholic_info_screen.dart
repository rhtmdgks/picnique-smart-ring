import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/Web_view_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';

class CatholicInfoScreen extends StatelessWidget {
  const CatholicInfoScreen({super.key});

  static const List<_CatholicInfoSection> _sections = [
    _CatholicInfoSection(
      title: '예배 · 말씀',
      items: [
        _CatholicInfoItem(
          title: '매일미사',
          subtitle: '오늘의 전례와 복음',
          icon: 'assets/icons/missa.svg',
          accent: Color(0xFFE8AFA0),
          route: _CatholicInfoRoute.webView,
          target:
              'https://maria.catholic.or.kr/mobile/missa/missa_view.asp?today=on',
        ),
        _CatholicInfoItem(
          title: '가톨릭 성경',
          subtitle: '한국천주교회 공식 성경',
          icon: 'assets/icons/bible.svg',
          accent: Color(0xFF8BA4D9),
          route: _CatholicInfoRoute.webView,
          target: 'https://bible.cbck.or.kr/Knb',
        ),
        _CatholicInfoItem(
          title: '가톨릭 성가',
          subtitle: '전례 성가 모음',
          icon: 'assets/icons/music.svg',
          accent: Color(0xFFBEA9FF),
          route: _CatholicInfoRoute.webView,
          target:
              'https://maria.catholic.or.kr/mobile/sungga/sungga.asp?flag=0&page=1',
        ),
      ],
    ),
    _CatholicInfoSection(
      title: '기도 · 묵상',
      items: [
        _CatholicInfoItem(
          title: '기도문',
          subtitle: '교회 기도문 모음',
          icon: 'assets/icons/pray.svg',
          accent: Color(0xFFFFD89B),
          route: _CatholicInfoRoute.webView,
          target:
              'https://maria.catholic.or.kr/mobile/prayer/prayer.asp?pgubun=3&ingId=1',
        ),
        _CatholicInfoItem(
          title: '거룩한 독서',
          subtitle: '영성 독서 플레이리스트',
          icon: 'assets/icons/cross.svg',
          accent: Color(0xFF68A84A),
          route: _CatholicInfoRoute.webView,
          target:
              'https://youtube.com/playlist?list=PLnPHr8PgLnuZiVoPq-GGInW6ma_aQLo9K',
        ),
      ],
    ),
    _CatholicInfoSection(
      title: '미디어 · 커뮤니티',
      items: [
        _CatholicInfoItem(
          title: '평화방송(PBC)',
          subtitle: '가톨릭 공영방송',
          icon: 'assets/icons/catholic.svg',
          accent: Color(0xFF408CFF),
          route: _CatholicInfoRoute.webView,
          target: 'https://m.cpbc.co.kr',
        ),
        _CatholicInfoItem(
          title: 'WYD Community',
          subtitle: '세계 청년의 날 커뮤니티',
          icon: 'assets/icons/rosary.svg',
          accent: AppColors.lightPurple,
          route: _CatholicInfoRoute.named,
          target: '/wyd-community',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SubAppBar(title: '가톨릭 정보'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const _HeroBanner(),
            const SizedBox(height: 20),
            for (var i = 0; i < _sections.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _SectionBlock(section: _sections[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 148,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/catholic_info.png',
            fit: BoxFit.cover,
            opacity: const AlwaysStoppedAnimation(0.35),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.darkPurple.withValues(alpha: 0.75),
                  const Color(0xFF3E3365).withValues(alpha: 0.9),
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: SvgPicture.asset(
                        'assets/icons/catholic.svg',
                        colorFilter: const ColorFilter.mode(
                          AppColors.lightPurple,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '가톨릭 정보',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: AppFontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '매일미사·성경·성가·기도문을 한곳에서',
                  style: TextStyle(
                    color: AppColors.lightGray,
                    fontSize: 13,
                    fontWeight: AppFontWeight.regular,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.section});

  final _CatholicInfoSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            section.title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              fontWeight: AppFontWeight.semiBold,
            ),
          ),
        ),
        ...List.generate(section.items.length, (i) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: i < section.items.length - 1 ? 10 : 0,
            ),
            child: _CatholicInfoTile(item: section.items[i]),
          );
        }),
      ],
    );
  }
}

class _CatholicInfoTile extends StatelessWidget {
  const _CatholicInfoTile({required this.item});

  final _CatholicInfoItem item;

  void _open(BuildContext context) {
    if (item.route == _CatholicInfoRoute.named) {
      Navigator.pushNamed(context, item.target);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            WebViewScreen(url: item.target, title: item.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.accent.withValues(alpha: 0.25),
            ),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                item.accent.withValues(alpha: 0.14),
                Colors.black.withValues(alpha: 0.45),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: item.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: item.accent.withValues(alpha: 0.35),
                    ),
                  ),
                  padding: const EdgeInsets.all(11),
                  child: SvgPicture.asset(
                    item.icon,
                    colorFilter: ColorFilter.mode(
                      item.accent,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: AppFontWeight.semiBold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          color: AppColors.lightGray,
                          fontSize: 12,
                          fontWeight: AppFontWeight.regular,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: item.accent.withValues(alpha: 0.85),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _CatholicInfoRoute { webView, named }

class _CatholicInfoSection {
  const _CatholicInfoSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_CatholicInfoItem> items;
}

class _CatholicInfoItem {
  const _CatholicInfoItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.route,
    required this.target,
  });

  final String title;
  final String subtitle;
  final String icon;
  final Color accent;
  final _CatholicInfoRoute route;
  final String target;
}
