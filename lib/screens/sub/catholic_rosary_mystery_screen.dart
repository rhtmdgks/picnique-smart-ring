import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';

class CatholicRosaryMysteryScreen extends StatelessWidget {
  const CatholicRosaryMysteryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SubAppBar(title: "오늘의 신비"),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              '오늘의 신비: 환희의 신비\n\n“내 영혼이 주님을 찬송하며”\n\n묵상 문구와 성경 구절을 표시하는 영역입니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }
}
