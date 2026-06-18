import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ★ 추가
import 'package:flutter_svg/svg.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/button.dart';

class RealTimeDataCard extends StatelessWidget {
  final String iconSvgPath, realTime;
  final Widget realTimeData;
  final bool isButtonExist;
  final Widget? bottomWidget;
  final DataType dataType;

  const RealTimeDataCard({
    super.key,
    required this.iconSvgPath,
    required this.realTime,
    required this.realTimeData,
    required this.isButtonExist,
    required this.dataType,
    this.bottomWidget,
  });

  // 공용 BLE 채널
  static const MethodChannel _ble = MethodChannel(
    'com.example.picnique_ring/ble',
  );

  Future<void> _handleMeasure(BuildContext context) async {
    HapticFeedback.lightImpact();

    // 어떤 측정을 호출할지 결정
    String method;
    Map<String, Object?> args = const {};
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
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String okMsg = '측정 완료';
    try {
      final res = await _ble.invokeMethod<dynamic>(method, args);

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
        SnackBar(content: Text('에러: ${e.code} - ${e.message ?? ''}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('에러: $e')));
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
                          fontVariations: AppFontVariations.semiBold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        realTime,
                        style: const TextStyle(
                          color: AppColors.lightGray,
                          fontSize: 12,
                          fontVariations: AppFontVariations.regular,
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
