import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';

class HealthCareCard extends StatelessWidget {
  final String iconSvgPath, title, path;
  final Widget widget;
  final int isStress;

  const HealthCareCard({
    super.key,
    required this.path,
    required this.iconSvgPath,
    required this.title,
    required this.widget,
    required this.isStress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 195,
      width: (MediaQuery.sizeOf(context).width - 40) / 2,
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, path);
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.3),
                AppColors.purple.withValues(alpha: 0.3),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                width: 40,
                height: 40,
                'assets/icons/$iconSvgPath.svg',
                colorFilter: ColorFilter.mode(
                  AppColors.lightOrange,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontVariations: AppFontVariations.medium,
                    ),
                  ),
                  widget,
                ],
              ),
              if (isStress > 0) ...[
                const SizedBox(height: 13),

                LayoutBuilder(
                  builder: (context, constraints) {
                    const double barHeight = 5;
                    const double gap = 4;

                    // 삼각형 스펙
                    const double triW = 9;
                    const double triH = 6;

                    final double availableWidth = constraints.maxWidth;
                    final double segmentWidth = ((availableWidth - gap * 4) / 5)
                        .clamp(0, availableWidth)
                        .toDouble();

                    final List<Color> colors = [
                      AppColors.StressBlue,
                      AppColors.StressGreen,
                      AppColors.StressYellow,
                      AppColors.StressOrange,
                      AppColors.StressRed,
                    ];

                    // ✅ 현재 필드는 bool이므로 극단(1 또는 5)로 매핑
                    final int stressIndex = isStress;

                    // 좌측에서부터의 위치: 2 + (index-1) * (segmentWidth + gap)
                    final double triLeft =
                        (2 + (stressIndex - 1) * (segmentWidth + gap)).clamp(
                          0.0,
                          availableWidth - triW,
                        );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ▼ 삼각형 (막대 위에서 2px 위에 위치시키기 위해 여기 배치)
                        SizedBox(
                          width: availableWidth,
                          height: triH,
                          child: Stack(
                            children: [
                              Positioned(
                                left: triLeft,
                                top: 0,
                                child: CustomPaint(
                                  size: const Size(triW, triH),
                                  painter: _DownTrianglePainter(
                                    color:
                                        colors[(stressIndex - 1).clamp(0, 4)],
                                    radius: 1.0, // "아주살짝 둥근" 정도
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 삼각형과 막대 사이 간격 2
                        const SizedBox(height: 2),

                        // ▼ 기존 5분할 막대
                        SizedBox(
                          width: availableWidth,
                          height: barHeight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              for (int i = 0; i < 5; i++) ...[
                                Container(
                                  width: segmentWidth,
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    color: colors[i],
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                if (i < 4) const SizedBox(width: gap),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DownTrianglePainter extends CustomPainter {
  final Color color;
  final double radius; // 모서리 아주 살짝 라운딩

  _DownTrianglePainter({required this.color, this.radius = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;
    final r = radius.clamp(0.0, 2.0);

    // 아래쪽을 향하는 이등변 삼각형 (윗변 좌우 + 아랫쪽 꼭짓점)
    // 모서리를 '아주살짝' 둥글게 만들기 위해 arc를 조금 섞습니다.
    final path = Path()
      ..moveTo(r, 0) // 좌상단 약간 오른쪽
      ..lineTo(w - r, 0) // 우상단 약간 왼쪽
      ..arcToPoint(
        // 우상단 모서리 라운딩
        Offset(w - r * 0.5, r * 0.3),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(w / 2 + r * 0.4, h - r) // 아래 꼭짓점 근처
      ..arcToPoint(
        // 아래 꼭짓점 라운딩
        Offset(w / 2 - r * 0.4, h - r),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(r * 0.5, r * 0.3) // 좌상단 근처
      ..arcToPoint(
        // 좌상단 모서리 라운딩
        Offset(r, 0),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DownTrianglePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
