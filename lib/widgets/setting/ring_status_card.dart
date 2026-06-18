import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/user_setting.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/button.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/setting/barrery_status.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:picnique_rosary_healthcare_smartring/util/BLERealtimeLogger.dart';

class RingStatusCard extends StatelessWidget {
  const RingStatusCard({super.key});

  // ⚠️ 프로젝트에서 사용 중인 채널 이름으로 교체하세요.
  static const MethodChannel _bleChannel = MethodChannel(
    'com.example.picnique_ring/ble',
  );
  static const MethodChannel _fgChannel = MethodChannel(
    'com.example.picnique_ring/foreground_service_channel',
  );

  Future<void> _disconnect(BuildContext context, Ring ringProvider) async {
    String? deviceAddress(BluetoothDevice d) {
      try {
        // ignore: deprecated_member_use
        return d.remoteId.str;
      } catch (_) {
        try {
          // ignore: deprecated_member_use
          return d.id.toString();
        } catch (_) {
          return null;
        }
      }
    }

    try {
      // 1) FlutterBluePlus 레벨 연결 해제
      await FlutterBluePlus.stopScan();
      final targetAddr = ringProvider.address;
      if (targetAddr != null && targetAddr.isNotEmpty) {
        final connected = FlutterBluePlus.connectedDevices;
        for (final d in connected) {
          final id = deviceAddress(d);
          if (id == targetAddr) {
            try {
              await d.disconnect();
            } catch (_) {}
            break;
          }
        }
      }

      // 2) 네이티브 SDK 연결 해제
      final ok = await _bleChannel.invokeMethod<bool>('disconnect');
      if (ok != true) {
        debugPrint('Native disconnect returned: $ok');
      }

      // 3) 포그라운드 서비스/실시간 로거 중단
      try {
        await _fgChannel.invokeMethod('stopService');
      } catch (_) {}
      try {
        await BleRealtimeLogger.stop();
      } catch (_) {}

      // ✅ Provider 상태 갱신 (프로바이더 메서드명은 프로젝트에 맞게 조정하세요)
      ringProvider.resetRing();

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('스마트링 연결을 해제했습니다.')));
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('연결 해제 실패: ${e.code} ${e.message ?? ''}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('연결 해제 중 오류가 발생했습니다: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<Ring, UserSetting>(
      builder: (context, ringProvider, userSettingProvider, child) {
        final isConnected = ringProvider.isConnected;

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
                Container(
                  decoration: isConnected
                      ? BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                        )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ringProvider.name ?? "연결된 스마트링 없음",
                          style: TextStyle(
                            color: isConnected
                                ? AppColors.lightPurple
                                : AppColors.lightGray,
                            fontSize: 14,
                            fontVariations: isConnected
                                ? AppFontVariations.semiBold
                                : AppFontVariations.regular,
                          ),
                        ),
                        Button(
                          onTap: isConnected
                              ? () =>
                                    _disconnect(context, ringProvider) // ⬅️ 연결
                              : () {
                                  Navigator.pushNamed(
                                    context,
                                    "/connect-ring-setting",
                                  );
                                },
                          text: isConnected ? "연결해제" : "연결하기",
                        ),
                      ],
                    ),
                  ),
                ),
                isConnected
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ringProvider.address ?? "",
                              style: TextStyle(
                                color: AppColors.lightGray,
                                fontSize: 12,
                                fontVariations: AppFontVariations.light,
                              ),
                            ),
                            BatteryStatus(battery: ringProvider.battery ?? 30),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        );
      },
    );
  }
}
