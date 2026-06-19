import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';

class RingConnect extends StatelessWidget {
  const RingConnect({
    super.key,
    required this.connect,
    required this.connectListLength,
    this.onConnect,
  });

  final MapEntry<int, Map<String, String>> connect;
  final int connectListLength;
  final Future<void> Function(String address)? onConnect;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final address = connect.value['address']?.trim();
        if (address == null || address.isEmpty || address == '-') {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('유효한 기기 주소가 없습니다.')));
          return;
        }
        if (onConnect != null) {
          await onConnect!(address);
        }
      },
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: connect.key == connectListLength - 1
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connect.value['name']!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: AppFontWeight.semiBold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    connect.value['address']!,
                    style: TextStyle(
                      color: AppColors.lightGray,
                      fontSize: 12,
                      fontWeight: AppFontWeight.light,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
