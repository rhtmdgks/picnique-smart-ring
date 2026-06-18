import 'package:flutter/material.dart';

class CatholicScreen extends StatelessWidget {
  const CatholicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsGeometry.all(12),
      child: SingleChildScrollView(
        child: Column(
          children: [
          CatholicCard(
            onTap: () {
              Navigator.pushNamed(context, "/catholic-rosary-screen");
            },
            title: '묵주기도',
            subtitle: '묵주기도 단수기도',
            imgPath: "assets/images/rosary.png",
          ),
          SizedBox(height: 16),
          CatholicCard(
            onTap: () {
              Navigator.pushNamed(context, "/catholic-info-screen");
            },
            title: '가톨릭정보',
            subtitle: '매일미사·성경·성가 등 모아보기',
            imgPath: "assets/images/catholic_info.png",
          ),
          SizedBox(height: 16),
          CatholicCard(
            onTap: () {
              Navigator.pushNamed(context, "/catholic-rosary-mystery-screen");
            },
            title: '오늘의 신비',
            subtitle: '오늘의 묵상과 성경 구절',
            imgPath: "assets/images/rosary.png",
          ),
          SizedBox(height: 16),
          CatholicCard(
            onTap: () {
              Navigator.pushNamed(context, "/catholic-rosary-statistics-screen");
            },
            title: '기도 기록',
            subtitle: '묵주기도 통계와 기록',
            imgPath: "assets/images/rosary.png",
          ),
        ],
        ),
      ),
    );
  }
}

class CatholicCard extends StatelessWidget {
  final void Function() onTap;
  final String title, subtitle, imgPath;

  const CatholicCard({
    super.key,
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.imgPath,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.3,
                  child: Image.asset(imgPath, fit: BoxFit.cover),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black, Colors.transparent],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
