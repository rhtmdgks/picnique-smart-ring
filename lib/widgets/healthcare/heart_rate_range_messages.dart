import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';
import 'package:picnique_rosary_healthcare_smartring/util/TrendUtil.dart';

class HeartRateRangeMessages extends StatefulWidget {
  const HeartRateRangeMessages({super.key, required this.range});

  final ToggleRange range;

  @override
  State<HeartRateRangeMessages> createState() => _HeartRateRangeMessagesState();
}

class _HeartRateRangeMessagesState extends State<HeartRateRangeMessages> {
  late Future<HeartRateRangeStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = getHeartRateRangeStatsFromDb(widget.range);
  }

  @override
  void didUpdateWidget(covariant HeartRateRangeMessages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range != widget.range) {
      _statsFuture = getHeartRateRangeStatsFromDb(widget.range);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HeartRateRangeStats>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final stats = snapshot.data ?? HeartRateRangeStats.empty;
        final range = widget.range;

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              _RangeMessageTile(
                label: '평균',
                message: buildHeartRateAverageMessage(stats, range),
              ),
              const SizedBox(height: 8),
              _RangeMessageTile(
                label: '최소',
                message: buildHeartRateMinimumMessage(stats, range),
              ),
              const SizedBox(height: 8),
              _RangeMessageTile(
                label: '최대',
                message: buildHeartRateMaximumMessage(stats, range),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RangeMessageTile extends StatelessWidget {
  const _RangeMessageTile({required this.label, required this.message});

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
                fontVariations: AppFontVariations.semiBold,
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
                fontVariations: AppFontVariations.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
