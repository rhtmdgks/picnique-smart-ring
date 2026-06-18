import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/button.dart';

String getRingStatusText({
  required bool isScanning,
  required bool isConnecting,
}) {
  if (isScanning) {
    return "스마트링 찾는 중 ...";
  } else if (isConnecting) {
    return "스마트링 연결 중 ...";
  } else {
    return "스마트링 탐색 완료";
  }
}

class RingConnectStatusCard extends StatelessWidget {
  final bool isScanning;
  final bool isConnecting;
  final Function startScan;

  const RingConnectStatusCard({
    super.key,
    required this.isScanning,
    required this.isConnecting,
    required this.startScan,
  });

  @override
  Widget build(BuildContext context) {
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
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      getRingStatusText(
                        isScanning: isScanning,
                        isConnecting: isConnecting,
                      ),
                      style: TextStyle(
                        color: AppColors.lightGray,
                        fontSize: 14,
                        fontVariations: AppFontVariations.regular,
                      ),
                    ),
                    isScanning || isConnecting
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: AppColors.mutePurple,
                            ),
                          )
                        : Button(
                            onTap: () {
                              startScan();
                            },
                            text: "다시 탐색",
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
