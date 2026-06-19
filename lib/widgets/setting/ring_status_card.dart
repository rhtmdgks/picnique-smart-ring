import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/user_setting.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/button.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/setting/barrery_status.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_background_keepalive.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_connection_coordinator.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_live_activity.dart';
import 'package:picnique_rosary_healthcare_smartring/util/BLERealtimeLogger.dart';

class RingStatusCard extends StatelessWidget {
  const RingStatusCard({super.key});

  static const int _maxAddressLength = 16;

  static String _formatAddress(String address) {
    if (address.length <= _maxAddressLength) return address;
    return '${address.substring(0, _maxAddressLength)}...';
  }

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
      await RingConnectionCoordinator.instance.onManualDisconnect();

      if (Platform.isAndroid) {
        await FlutterBluePlus.stopScan();
        final targetAddr =
            ringProvider.address ?? ringProvider.savedAddress;
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
      }

      final ok = await _bleChannel.invokeMethod<bool>('disconnect');
      if (ok != true) {
        debugPrint('Native disconnect returned: $ok');
      }

      try {
        await _fgChannel.invokeMethod('stopService');
      } catch (_) {}
      await RingBackgroundKeepalive.stop();
      try {
        await context.read<RingLiveActivity>().stop();
      } catch (_) {}
      try {
        await BleRealtimeLogger.stop();
      } catch (_) {}

      ringProvider.resetRing();
      await ringProvider.clearPersist();

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('스마트링 연결을 끊었습니다.')));
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
        final isConnected = ringProvider.isConnected &&
            (ringProvider.address?.isNotEmpty ?? false);
        final isReconnecting = ringProvider.isReconnecting &&
            !isConnected &&
            ringProvider.hasSavedDevice;
        final showPaired = isConnected || isReconnecting;

        String title;
        if (isConnected) {
          title = ringProvider.name ?? '연결된 스마트링';
        } else if (isReconnecting) {
          title = '${ringProvider.savedName ?? '스마트링'} (재연결 중…)';
        } else {
          title = '연결된 스마트링 없음';
        }

        final displayAddress = isConnected
            ? (ringProvider.address ?? '')
            : (ringProvider.savedAddress ?? '');

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
                  decoration: showPaired
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
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: showPaired
                                  ? (isReconnecting
                                      ? AppColors.lightGray
                                      : AppColors.lightPurple)
                                  : AppColors.lightGray,
                              fontSize: 14,
                              fontWeight: showPaired
                                  ? AppFontWeight.semiBold
                                  : AppFontWeight.regular,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (showPaired)
                          Button(
                            onTap: () => _disconnect(context, ringProvider),
                            text: '연결 끊기',
                          )
                        else
                          Button(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/connect-ring-setting',
                              );
                            },
                            text: '연결하기',
                          ),
                      ],
                    ),
                  ),
                ),
                showPaired
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatAddress(displayAddress),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.lightGray,
                                  fontSize: 12,
                                  fontWeight: AppFontWeight.light,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isConnected)
                              BatteryStatus(
                                battery: ringProvider.battery ?? 30,
                                isCharging: ringProvider.isCharging,
                              )
                            else if (isReconnecting)
                              Text(
                                '자동 재연결 대기',
                                style: TextStyle(
                                  color: AppColors.lightGray,
                                  fontSize: 12,
                                  fontWeight: AppFontWeight.light,
                                ),
                              ),
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
