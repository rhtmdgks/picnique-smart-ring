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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                colorFilter: const ColorFilter.mode(
                  AppColors.lightOrange,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: AppFontWeight.semiBold,
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
                    const double triW = 9;
                    const double triH = 6;

                    final double availableWidth = constraints.maxWidth;
                    final double segmentWidth =
                        ((availableWidth - gap * 4) / 5)
                            .clamp(0, availableWidth)
                            .toDouble();

                    const List<Color> colors = [
                      AppColors.StressBlue,
                      AppColors.StressGreen,
                      AppColors.StressYellow,
                      AppColors.StressOrange,
                      AppColors.StressRed,
                    ];

                    final int stressIndex = isStress;
                    final double triLeft =
                        (2 + (stressIndex - 1) * (segmentWidth + gap))
                            .clamp(0.0, availableWidth - triW);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                    color: colors[(stressIndex - 1).clamp(0, 4)],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: availableWidth,
                          height: barHeight,
                          child: Row(
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

  _DownTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;
    const r = 1.5;

    final path = Path()
      ..moveTo(r, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(
        Offset(w - r * 0.5, r * 0.3),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(w / 2 + r * 0.4, h - r)
      ..arcToPoint(
        Offset(w / 2 - r * 0.4, h - r),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(r * 0.5, r * 0.3)
      ..arcToPoint(
        Offset(r, 0),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DownTrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}
