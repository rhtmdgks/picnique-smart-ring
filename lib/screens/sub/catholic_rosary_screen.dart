import 'dart:math';

import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/util/TouchCounter.dart';
import 'package:picnique_rosary_healthcare_smartring/db/app_db.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';
import 'dart:ui';

class CatholicRosaryScreen extends StatefulWidget {
  const CatholicRosaryScreen({super.key});

  @override
  State<CatholicRosaryScreen> createState() => _CatholicRosaryScreenState();
}

class _CatholicRosaryScreenState extends State<CatholicRosaryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final int _numberOfDots = 18;
  late int _specialDotIndex;
  int _completedAnimations = 0;
  bool _isRecording = false;
  int count = 0;
  RingTouchController touchCounter = RingTouchController();
  late final VoidCallback _onCounterUpdated;
  DateTime? _sessionStart;
  DateTime today = DateTime.now();
  String get todayStr =>
      "${today.year % 100}.${today.month.toString().padLeft(2, '0')}.${today.day.toString().padLeft(2, '0')}";

  @override
  void initState() {
    super.initState();
    _specialDotIndex = (_numberOfDots / 2).floor();

    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 400),
        )..addListener(() {
          setState(() {});
        });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _completedAnimations++;
          _specialDotIndex = (_specialDotIndex + 1) % _numberOfDots;
          _controller.reset();
        });
      }
    });

    _onCounterUpdated = () {
      if (!_isRecording) return;
      if (!_controller.isAnimating) {
        _controller.forward();
      }
      // count 텍스트는 touchCounter.count를 읽으므로 setState만 해주면 됨
      setState(() {});
    };
    touchCounter.addListener(_onCounterUpdated);
  }

  Future<void> _startRecording() async {
    _sessionStart = DateTime.now();
    touchCounter.tapCount = 0;
    await touchCounter.start();
    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _stopRecording() async {
    final start = _sessionStart;
    final end = DateTime.now();
    final taps = touchCounter.tapCount;
    await touchCounter.stop();
    if (mounted) {
      setState(() {
        _isRecording = false;
      });
    }
    _sessionStart = null;

    if (start != null) {
      try {
        await DbManager.I.appDB.insertRosarySession(
          RosarySessionsCompanion.insert(
            startAt: start,
            endAt: end,
            tapCount: taps,
          ),
        );
      } catch (e) {
        debugPrint('Failed to save rosary session: $e');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    touchCounter.removeListener(_onCounterUpdated);
    // 녹화 중이면 종료 + 저장
    if (_isRecording) {
      _stopRecording();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final appBar = const SubAppBar(title: "묵주기도");
    final appBarHeight = appBar.preferredSize.height;

    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                right: -size.width * 3 / 4,
                top: size.height / 2 - (size.width * 3 / 4) - appBarHeight,
                child: CustomPaint(
                  size: Size(size.width * (3 / 2), size.width * (3 / 2)),
                  painter: OrbitAndDotsPainter(
                    numberOfDots: _numberOfDots,
                    specialDotIndex: _specialDotIndex,
                    animationValue: _controller.value,
                    completedAnimations: _completedAnimations,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: size.height / 2 - appBarHeight,
                child: FractionalTranslation(
                  translation: const Offset(0.0, -0.5),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: BoxBorder.fromLTRB(
                            bottom: BorderSide(color: Colors.white, width: 1.0),
                          ),
                        ),
                        child: Text(
                          "${touchCounter.tapCount} 단",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontVariations: AppFontVariations.semiBold,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      GestureDetector(
                        onTap: () async {
                          if (_isRecording) {
                            await _stopRecording();
                          } else {
                            await _startRecording();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _isRecording
                                ? "기록을 중단하시려면 클릭하세요."
                                : "기록을 시작하시려면 클릭하세요.",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          if (!_isRecording) {
                            // TODO(task): 비기록 상태 탭 시 봉헌 플로우(확인 다이얼로그/저장/완료 피드백) 연결.
                          }
                        },
                        child: Opacity(
                          opacity: _isRecording ? 0.2 : 1.0,
                          child: Row(
                            children: [
                              Image.asset(
                                "assets/images/WYD_logo.jpg",
                                width: 40, // 너비
                                height: 40, // 높이
                                fit: BoxFit.cover, // 이미지가 잘리더라도 영역을 꽉 채움
                              ),
                              SizedBox(width: 16),
                              // TODO(task): 기획 문구 확정 후 i18n 키 기반 텍스트로 교체.
                              Text(
                                "WYD 봉헌하기",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontVariations: AppFontVariations.regular,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      "/catholic-rosary-statistics-screen",
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.only(left: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          todayStr,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontVariations: AppFontVariations.medium,
                          ),
                        ),
                        SizedBox(width: 4),
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          // TODO(task): FAB 제거 후 링 터치 이벤트를 동일 동작(_controller.forward + count 증가)에 매핑.
          onPressed: () {
            if (_isRecording) {
              _controller.forward();
              setState(() {
                count++;
              });
            }
          },
          backgroundColor: Colors.white,
          child: const Icon(Icons.play_arrow, color: Colors.black),
        ),
      ),
    );
  }
}

class OrbitAndDotsPainter extends CustomPainter {
  final int numberOfDots;
  final double dotRadius;
  final int specialDotIndex;
  final double animationValue;
  final int completedAnimations;

  OrbitAndDotsPainter({
    required this.numberOfDots,
    required this.specialDotIndex,
    required this.animationValue,
    required this.completedAnimations,
    this.dotRadius = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final orbitPaint = Paint()
      ..color = AppColors.darkGray
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, orbitPaint);

    final dotPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final filledDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final double angleStep = 2 * pi / numberOfDots;
    final double rotation =
        (completedAnimations * angleStep) + (animationValue * angleStep);

    final int becomingNormalIndex = specialDotIndex;
    final int becomingSpecialIndex = (specialDotIndex + 1) % numberOfDots;

    for (int i = 0; i < numberOfDots; i++) {
      final double angle = i * angleStep - rotation;

      final double x = center.dx + radius * cos(angle);
      final double y = center.dy + radius * sin(angle);
      final Offset dotPosition = Offset(x, y);

      if (i == becomingNormalIndex) {
        final double outerR = lerpDouble(40, dotRadius, animationValue)!;
        final double innerR = lerpDouble(dotRadius, 0, animationValue)!;

        canvas.drawCircle(dotPosition, outerR, dotPaint);
        if (innerR > 0.1) {
          canvas.drawCircle(
            dotPosition,
            innerR,
            filledDotPaint
              ..color = Colors.white.withValues(alpha: (1.0 - animationValue)),
          );
        }
      } else if (i == becomingSpecialIndex) {
        // 보통 점에서 -> 특별한 점으로 모습이 변합니다.
        final double outerR = lerpDouble(dotRadius, 40, animationValue)!;
        final double innerR = lerpDouble(0, dotRadius, animationValue)!;

        canvas.drawCircle(dotPosition, outerR, dotPaint);
        if (innerR > 0.1) {
          // 안쪽 원은 나타나는 효과를 줍니다.
          canvas.drawCircle(
            dotPosition,
            innerR,
            filledDotPaint
              ..color = Colors.white.withValues(alpha: animationValue),
          );
        }
      } else {
        canvas.drawCircle(dotPosition, dotRadius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant OrbitAndDotsPainter oldDelegate) {
    return true;
  }
}
