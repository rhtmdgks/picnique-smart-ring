import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/util/TrendUtil.dart';

class StressHrvMessages extends StatelessWidget {
  const StressHrvMessages({super.key, required this.future});

  final Future<String> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _StressMessageTile(
            label: 'HRV',
            message: '메시지를 불러오고 있어요...',
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const _StressMessageTile(
            label: 'HRV',
            message: '메시지를 불러오지 못했어요.\n잠시 후 다시 확인해 주세요.',
          );
        }

        final lines = snapshot.data!.split('\n\n');
        if (lines.length < 2) {
          return _StressMessageTile(label: 'HRV', message: snapshot.data!);
        }

        return Column(
          children: [
            _StressMessageTile(label: 'HRV', message: lines[0]),
            const SizedBox(height: 8),
            _StressMessageTile(label: '야간 HRV', message: lines[1]),
          ],
        );
      },
    );
  }
}

Future<String> buildStressHrvMessages() {
  return Future.wait([getHrvTrendMessage(), getNightHrvMessage()]).then((
    results,
  ) {
    final parts = <String>[];

    parts.add(
      results[0] ??
          '지난 2주 평균과 비교할 HRV 데이터가 아직 없어요.\n조금 더 모이면 알려드릴게요.',
    );
    parts.add(
      results[1] ??
          '어젯밤 회복 데이터가 아직 없어요.\n수면 후 다시 확인보면 좋아요.',
    );

    return parts.join('\n\n');
  });
}

class _StressMessageTile extends StatelessWidget {
  const _StressMessageTile({required this.label, required this.message});

  final String label;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.lightPurple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.lightPurple,
                fontSize: 12,
                fontWeight: AppFontWeight.semiBold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.lightGray,
                fontSize: 13,
                height: 1.45,
                fontWeight: AppFontWeight.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
