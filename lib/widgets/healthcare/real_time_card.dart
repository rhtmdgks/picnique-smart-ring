import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_touch_mode_service.dart';
import 'package:picnique_rosary_healthcare_smartring/util/measurement_error_message.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/button.dart';
import 'package:provider/provider.dart';

class RealTimeDataCard extends StatelessWidget {
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

  // 공용 BLE 채널 — iOS에서는 BleCommandQueue로 직렬화해야 연결 후처리와 충돌하지 않는다.

  static ManualMeasurementType _manualType(DataType dataType) {
    switch (dataType) {
      case DataType.HeartRate:
        return ManualMeasurementType.heartRate;
      case DataType.Oxygen:
        return ManualMeasurementType.spo2;
      case DataType.Stress:
        return ManualMeasurementType.stress;
      default:
        return ManualMeasurementType.other;
    }
  }

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
        return '스트레스 측정 중…\n약 20~40초 걸려요.\n손가락을 움직이지 마세요.';
      default:
        return '측정 중…';
    }
  }

  Future<void> _handleMeasure(BuildContext context) async {
    HapticFeedback.lightImpact();

    final ring = context.read<Ring>();
    if (!ring.isConnected || !ring.sdkReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_notReadyMessage(ring))),
      );
      return;
    }

    // 어떤 측정을 호출할지 결정
    String method;
    Map<String, Object?> args = const {};
    final manualType = _manualType(dataType);
    switch (dataType) {
      // 프로젝트 enum에 맞춰 조정하세요 ↓↓↓
      case DataType.HeartRate: // 심박
        method = 'syncManualHeartRate';
        break;
      case DataType.Oxygen: // SpO₂
        method = 'syncManualBloodOxygen';
        break;
      case DataType.Stress: // 스트레스(pressure)
        method = 'syncManualPressure';
        break;
      default:
        // 그 외 화면에서 버튼이 보일 일 없다면 기본은 심박
        method = 'syncManualHeartRate';
        break;
    }

    // 진행 다이얼로그 표시
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
                _measuringDialogMessage(dataType),
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

    String okMsg = '측정 완료';
    try {
      await RingTouchModeService.instance.pauseForManualMeasurement(
        type: manualType,
      );
      final res = await BleCommandQueue.invoke<dynamic>(method, args);

      // 다이얼로그 닫기
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (res is Map) {
        // 수신 키들은 브리지가 반환하는 맵에 맞춰 파싱
        switch (method) {
          case 'syncManualHeartRate':
            {
              final hr = (res['hr'] ?? res['value'] ?? 0).toString();
              final rri = res['rri'];
              okMsg = rri != null ? '심박수 $hr bpm (RRI: $rri)' : '심박수 $hr bpm';
              break;
            }
          case 'syncManualBloodOxygen':
            {
              final spo2 = (res['spo2'] ?? res['value'] ?? 0).toString();
              okMsg = '혈중산소 $spo2%';
              break;
            }
          case 'syncManualPressure':
            {
              final pressure = (res['pressure'] ?? res['value'] ?? 0)
                  .toString();
              okMsg = '스트레스 $pressure';
              break;
            }
          case 'syncManualBp':
            {
              final sbp = res['sbp'] ?? 0;
              final dbp = res['dbp'] ?? 0;
              okMsg = '혈압 $sbp/$dbp mmHg';
              break;
            }
        }
        onMeasureSuccess?.call(Map<dynamic, dynamic>.from(res));
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(okMsg)));

      // 여기서 부모에게 새로고침 신호를 주고 싶다면
      // InheritedWidget/EventBus/Provider 등을 통해 리프레시 트리거를 날리세요.
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            measurementErrorMessage(e, dataType: dataType),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '측정 중 문제가 발생했어요.\n잠시 후 다시 시도해 주세요.',
          ),
        ),
      );
    } finally {
      await RingTouchModeService.instance.resumeAfterManualMeasurement(
        type: manualType,
      );
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
                iconSvgPath,
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
                        realTime,
                        style: const TextStyle(
                          color: AppColors.lightGray,
                          fontSize: 12,
                          fontWeight: AppFontWeight.regular,
                        ),
                      ),
                    ],
                  ),
                  realTimeData,
                ],
              ),
            ],
          ),
          if (isButtonExist)
            Button(
              text: dataType == DataType.Rosary ? "봉헌하기" : "측정하기",
              onTap: () => _handleMeasure(context),
            ),
        ],
      ),
    );
  }
}
