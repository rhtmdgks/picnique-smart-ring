import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/rosary_mysteries.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';

class CatholicRosaryMysteryScreen extends StatelessWidget {
  const CatholicRosaryMysteryScreen({super.key});

  Color _accentFor(String theme) => switch (theme) {
    'joyful' => AppColors.lightOrange,
    'sorrowful' => const Color(0xFF8BA4D9),
    'glorious' => AppColors.lightPurple,
    'luminous' => const Color(0xFFFFD89B),
    _ => AppColors.lightPurple,
  };

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final set = mysterySetForWeekday(now.weekday);
    final focusIndex = todayMysteryIndex(now);
    final focus = set.mysteries[focusIndex];
    final accent = _accentFor(set.themeColor);
    final dateLabel =
        '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SubAppBar(title: '오늘의 신비'),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroCard(
                setName: set.name,
                subtitle: set.subtitle,
                weekday: weekdayLabelKo(now.weekday),
                dateLabel: dateLabel,
                accent: accent,
              ),
              const SizedBox(height: 16),
              _FocusMysteryCard(
                index: focusIndex + 1,
                mystery: focus,
                accent: accent,
              ),
              const SizedBox(height: 24),
              Text(
                '${set.name} 다섯 묵상',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: AppFontWeight.semiBold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '오늘은 ${focusIndex + 1}번째 묵상에 집중해 보세요.',
                style: TextStyle(
                  color: AppColors.lightGray,
                  fontSize: 13,
                  fontWeight: AppFontWeight.regular,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(set.mysteries.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MysteryListTile(
                    index: i + 1,
                    mystery: set.mysteries[i],
                    isToday: i == focusIndex,
                    accent: accent,
                  ),
                );
              }),
              const SizedBox(height: 8),
              _TipCard(accent: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.setName,
    required this.subtitle,
    required this.weekday,
    required this.dateLabel,
    required this.accent,
  });

  final String setName;
  final String subtitle;
  final String weekday;
  final String dateLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 168,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.35),
            AppColors.darkPurple.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -24,
              child: Opacity(
                opacity: 0.18,
                child: Image.asset(
                  'assets/images/rosary.png',
                  width: 160,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '$weekday · $dateLabel',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: AppFontWeight.medium,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    setName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: AppFontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 14,
                      fontWeight: AppFontWeight.regular,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusMysteryCard extends StatelessWidget {
  const _FocusMysteryCard({
    required this.index,
    required this.mystery,
    required this.accent,
  });

  final int index;
  final RosaryMystery mystery;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: accent,
                    fontSize: 16,
                    fontWeight: AppFontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘의 묵상',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: AppFontWeight.semiBold,
                      ),
                    ),
                    Text(
                      mystery.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: AppFontWeight.semiBold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, color: accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  mystery.scripture,
                  style: TextStyle(
                    color: AppColors.lightGray,
                    fontSize: 13,
                    fontWeight: AppFontWeight.medium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            mystery.meditation,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 15,
              height: 1.65,
              fontWeight: AppFontWeight.regular,
            ),
          ),
        ],
      ),
    );
  }
}

class _MysteryListTile extends StatelessWidget {
  const _MysteryListTile({
    required this.index,
    required this.mystery,
    required this.isToday,
    required this.accent,
  });

  final int index;
  final RosaryMystery mystery;
  final bool isToday;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isToday
            ? accent.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday
              ? accent.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Text(
            '$index',
            style: TextStyle(
              color: isToday ? accent : AppColors.gray,
              fontSize: 14,
              fontWeight: AppFontWeight.semiBold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mystery.title,
                  style: TextStyle(
                    color: isToday ? Colors.white : AppColors.lightGray,
                    fontSize: 14,
                    fontWeight: isToday
                        ? AppFontWeight.semiBold
                        : AppFontWeight.medium,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  mystery.scripture,
                  style: TextStyle(
                    color: AppColors.gray,
                    fontSize: 12,
                    fontWeight: AppFontWeight.regular,
                  ),
                ),
              ],
            ),
          ),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '오늘',
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: AppFontWeight.semiBold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '묵주기도 화면에서 손가락을 두드리며 기도하시면, '
              '오늘의 묵상을 마음에 새기는 시간이 됩니다.',
              style: TextStyle(
                color: AppColors.lightGray,
                fontSize: 13,
                height: 1.5,
                fontWeight: AppFontWeight.regular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
