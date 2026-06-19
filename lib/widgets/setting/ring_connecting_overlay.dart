import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';

/// 스마트링 BLE 연결 중 전체 화면 오버레이 (토스식 카피 + 카드 UI).
class RingConnectingOverlay extends StatefulWidget {
  const RingConnectingOverlay({
    super.key,
    this.deviceName,
  });

  final String? deviceName;

  @override
  State<RingConnectingOverlay> createState() => _RingConnectingOverlayState();
}

class _RingConnectingOverlayState extends State<RingConnectingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.deviceName?.trim();
    final hasName = name != null && name.isNotEmpty && name != '(이름 없음)';

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.lightPurple.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2A1F3D).withValues(alpha: 0.95),
                      const Color(0xFF1A1028).withValues(alpha: 0.98),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purple.withValues(alpha: 0.18),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _pulse,
                          curve: Curves.easeInOut,
                        ),
                      ),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.purple.withValues(alpha: 0.22),
                          border: Border.all(
                            color: AppColors.lightPurple.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/healthcare.svg',
                            width: 36,
                            height: 36,
                            colorFilter: const ColorFilter.mode(
                              AppColors.lightPurple,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '스마트링과 연결하고 있어요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.35,
                        fontWeight: AppFontWeight.semiBold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasName
                          ? '$name\n잠시만 기다려 주세요'
                          : '반지가 가까이 있는지 확인한 뒤\n잠시만 기다려 주세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.lightGray,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: AppFontWeight.regular,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.lightPurple,
                        backgroundColor:
                            AppColors.mutePurple.withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '연결이 끝나면 건강 데이터를\n바로 확인할 수 있어요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.lightGray.withValues(alpha: 0.9),
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: AppFontWeight.regular,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
