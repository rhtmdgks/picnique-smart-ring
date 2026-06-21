import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_measurement_service.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_connection_service.dart';
import 'package:picnique_rosary_healthcare_smartring/util/measurement_error_message.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/button.dart';
import 'package:provider/provider.dart';

class RealTimeDataCard extends StatefulWidget {
  final String iconSvgPath, realTime;
  final Widget realTimeData;
  final bool isButtonExist;
  final Widget? bottomWidget;
  final DataType dataType;
  final void Function(Map<dynamic, dynamic> result)? onMeasureSuccess;

  const RealTimeDataCard({
    super.key,
    required this.iconSvgPath,
    required this.realTime,
    required this.realTimeData,
    required this.isButtonExist,
    required this.dataType,
    this.bottomWidget,
    this.onMeasureSuccess,
  });

  @override
  State<RealTimeDataCard> createState() => _RealTimeDataCardState();
}

class _RealTimeDataCardState extends State<RealTimeDataCard> {
  bool _measuring = false;

  static String _notReadyMessage(Ring ring) {
    if (!ring.isConnected) {
      return '스마트링이 연결되어 있지 않아요.\n설정에서 반지 연결을 확인해 주세요.';
    }
    return '반지 연결·준비가 완료된 후 측정해 주세요.\n잠시 후 다시 시도해 주세요.';
  }

  static String _measuringDialogMessage(DataType dataType) {
    switch (dataType) {
      case DataType.Oxygen:
        return '산소포화도 측정 중…\n약 20~40초 걸려요.\n손가락을 움직이지 마세요.';
      case DataType.HeartRate:
        return '심박수 측정 중…\n약 10~30초 걸려요.\n손가락을 움직이지 마세요.';
      case DataType.Stress:
        return Platform.isIOS
            ? '스트레스 측정 중…\n약 20~60초 걸릴 수 있어요.\n반지를 꽉 끼우고 손가락을 움직이지 마세요.'
            : '스트레스 측정 중…\n약 20~40초 걸려요.\n손가락을 움직이지 마세요.';
      default:
        return '측정 중…';
    }
  }

  String _okMessage(DataType dataType, Map<dynamic, dynamic> res) {
    switch (dataType) {
      case DataType.HeartRate:
        final hr = (res['hr'] ?? res['value'] ?? 0).toString();
        final rri = res['rri'];
        return rri != null ? '심박수 $hr bpm (RRI: $rri)' : '심박수 $hr bpm';
      case DataType.Oxygen:
        final spo2 = (res['spo2'] ?? res['value'] ?? 0).toString();
        return '혈중산소 $spo2%';
      case DataType.Stress:
        final pressure = (res['pressure'] ?? res['value'] ?? 0).toString();
        return '스트레스 $pressure';
      default:
        return '측정 완료';
    }
  }

  Future<void> _handleMeasure(BuildContext context) async {
    if (_measuring) return;
    HapticFeedback.lightImpact();

    final ring = context.read<Ring>();
    if (!ring.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_notReadyMessage(ring))),
      );
      return;
    }

    if (!ring.sdkReady) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      final ready = await RingConnectionService.ensureSdkReady(ring);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (!ready) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_notReadyMessage(ring))),
        );
        return;
      }
    }

    setState(() => _measuring = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2038),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _measuringDialogMessage(widget.dataType),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: AppFontWeight.regular,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    void dismissMeasuringDialog() {
      if (!context.mounted) return;
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) {
        nav.pop();
      }
    }

    try {
      final res = await RingMeasurementService.measureManual(widget.dataType);

      if (!context.mounted) return;
      dismissMeasuringDialog();

      widget.onMeasureSuccess?.call(res);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_okMessage(widget.dataType, res))),
      );
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      dismissMeasuringDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            measurementErrorMessage(e, dataType: widget.dataType),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      dismissMeasuringDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '측정 중 문제가 발생했어요.\n잠시 후 다시 시도해 주세요.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _measuring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                widget.iconSvgPath,
                colorFilter: const ColorFilter.mode(
                  AppColors.lightOrange,
                  BlendMode.srcIn,
                ),
                width: 40,
                height: 40,
                fit: BoxFit.scaleDown,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        "실시간 데이터",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: AppFontWeight.semiBold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.realTime,
                        style: const TextStyle(
                          color: AppColors.lightGray,
                          fontSize: 12,
                          fontWeight: AppFontWeight.regular,
                        ),
                      ),
                    ],
                  ),
                  widget.realTimeData,
                ],
              ),
            ],
          ),
          if (widget.isButtonExist)
            Opacity(
              opacity: _measuring ? 0.5 : 1,
              child: Button(
                text: widget.dataType == DataType.Rosary ? "봉헌하기" : "측정하기",
                onTap: _measuring ? () {} : () => _handleMeasure(context),
              ),
            ),
        ],
      ),
    );
  }
}
