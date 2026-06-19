import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/Web_view_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';

class CatholicInfoScreen extends StatelessWidget {
  CatholicInfoScreen({super.key});

  final List<Map<String, String>> catholicInfos = [
    {
      "title": "매일미사",
      "url":
          "https://maria.catholic.or.kr/mobile/missa/missa_view.asp?today=on",
      "icon": "assets/icons/missa.svg",
    },
    {
      "title": "가톨릭 성경",
      "url": "https://bible.cbck.or.kr/Knb",
      "icon": "assets/icons/bible.svg",
    },
    {
      "title": "가톨릭 성가",
      "url":
          "https://maria.catholic.or.kr/mobile/sungga/sungga.asp?flag=0&page=1&scroll_top=0&intLINEPERPAGE=100&topkey=&audioc_nt=204&searchText=&cselJun=",
      "icon": "assets/icons/music.svg",
    },
    {
      "title": "기도문",
      "url":
          "https://maria.catholic.or.kr/mobile/prayer/prayer.asp?pgubun=3&ingId=1",
      "icon": "assets/icons/pray.svg",
    },
    {
      "title": "평화방송(PBC)",
      "url": "https://m.cpbc.co.kr",
      "icon": "assets/icons/rosary.svg",
    },
    {
      "title": "거룩한 독서",
      "url":
          "https://youtube.com/playlist?list=PLnPHr8PgLnuZiVoPq-GGInW6ma_aQLo9K&si=uPMc59lVsrAyiR8f",
      "icon": "assets/icons/rosary.svg",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SubAppBar(title: "가톨릭 정보"),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: ListView.separated(
            // TODO(task): 카드 개수가 홀수일 때 마지막 단일 카드 레이아웃 처리 로직 추가.
            itemCount: catholicInfos.length ~/ 2,
            separatorBuilder: (_, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final left = catholicInfos[index * 2];
              final right = catholicInfos[index * 2 + 1];
              return Row(
                children: [
                  CatholicInfoCard(
                    title: left["title"]!,
                    iconSvgPath: left["icon"]!,
                    url: left["url"]!,
                  ),
                  SizedBox(width: 12),
                  CatholicInfoCard(
                    title: right["title"]!,
                    iconSvgPath: right["icon"]!,
                    url: right["url"]!,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class CatholicInfoCard extends StatelessWidget {
  final String title, iconSvgPath, url;

  const CatholicInfoCard({
    super.key,
    required this.title,
    required this.iconSvgPath,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebViewScreen(url: url, title: title),
            ),
          );
        },
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3E3365), Color(0xFF88447C)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontVariations: AppFontVariations.bold,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ],
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SvgPicture.asset(
                      iconSvgPath,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
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

