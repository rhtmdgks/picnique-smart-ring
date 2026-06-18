import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/setting/ring_connect.dart';

class RingConnectListCard extends StatelessWidget {
  final List<Map<String, String>> connectList;
  final Future<void> Function(String address)? onConnect;

  const RingConnectListCard({
    super.key,
    required this.connectList,
    this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (connectList.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: const Text(
                  "발견된 스마트링이 없습니다.",
                  style: TextStyle(
                    color: AppColors.lightGray,
                    fontSize: 14,
                    fontVariations: AppFontVariations.regular,
                  ),
                ),
              )
            else
              for (var connect in connectList.asMap().entries)
                RingConnect(
                  connect: connect,
                  connectListLength: connectList.length,
                  onConnect: onConnect,
                ),
          ],
        ),
      ),
    );
  }
}
