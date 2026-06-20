import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/button.dart';

String getRingStatusText({
  required bool isScanning,
  required bool isConnecting,
  required int discoveredCount,
}) {
  if (isScanning) {
    return '스마트링 검색 중';
  }
  if (isConnecting) {
    return '스마트링 연결 중';
  }
  if (discoveredCount > 0) {
    return '스마트링을 찾았어요';
  }
  return '탐색을 마쳤어요';
}

class RingConnectStatusCard extends StatefulWidget {
  final bool isScanning;
  final bool isConnecting;
  final int discoveredCount;
  final Future<void> Function() startScan;

  const RingConnectStatusCard({
    super.key,
    required this.isScanning,
    required this.isConnecting,
    required this.discoveredCount,
    required this.startScan,
  });

  @override
  State<RingConnectStatusCard> createState() => _RingConnectStatusCardState();
}

class _RingConnectStatusCardState extends State<RingConnectStatusCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isScanning || widget.isConnecting) {
      _dotController.repeat();
    }
  }

  @override
  void didUpdateWidget(RingConnectStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final animating = widget.isScanning || widget.isConnecting;
    if (animating && !_dotController.isAnimating) {
      _dotController.repeat();
    } else if (!animating) {
      _dotController
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  String _animatedDots() {
    final phase = (_dotController.value * 3).floor() % 3;
    return '.' * (phase + 1);
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = widget.isScanning || widget.isConnecting;
    final statusText = getRingStatusText(
      isScanning: widget.isScanning,
      isConnecting: widget.isConnecting,
      discoveredCount: widget.discoveredCount,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.isScanning)
                        Text(
                          '주변 기기 탐색',
                          style: TextStyle(
                            color: AppColors.lightGray.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: AppFontWeight.regular,
                          ),
                        ),
                      if (widget.isScanning) const SizedBox(height: 4),
                      isBusy
                          ? AnimatedBuilder(
                              animation: _dotController,
                              builder: (context, child) {
                                return Text(
                                  '$statusText${_animatedDots()}',
                                  style: TextStyle(
                                    color: AppColors.lightGray,
                                    fontSize: widget.isScanning ? 13 : 14,
                                    fontWeight: AppFontWeight.regular,
                                  ),
                                );
                              },
                            )
                          : Text(
                              statusText,
                              style: TextStyle(
                                color: AppColors.lightGray,
                                fontSize: 14,
                                fontWeight: AppFontWeight.regular,
                              ),
                            ),
                    ],
                  ),
                  isBusy
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: AppColors.mutePurple,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Button(
                          onTap: () {
                            widget.startScan();
                          },
                          text: '다시 탐색',
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
