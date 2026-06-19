import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_charging_live_activity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 스마트링 배터리·충전 로컬 알림 (Android / iOS).
class BatteryNotificationService {
  BatteryNotificationService._();

  static const prefsKeyEnabled = 'battery_low_alert_enabled';
  static const lowThreshold = 20;
  static const resetThreshold = 25;
  static const fullChargeThreshold = 95;

  static const _lowNotificationId = 1001;
  static const _chargingNotificationId = 1002;
  static const _fullChargeNotificationId = 1003;

  static const _lowChannelId = 'battery_low_alert';
  static const _lowChannelName = '배터리 부족 알림';
  static const _chargingChannelId = 'ring_charging_alert';
  static const _chargingChannelName = '충전 알림';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static int? _lastNotifiedLevel;
  static bool? _lastChargingState;
  static int? _lastChargingProgressLevel;
  static DateTime? _lastChargingProgressAt;
  static bool _fullChargeNotified = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _lowChannelId,
        _lowChannelName,
        description: '스마트링 배터리가 부족할 때 알려줍니다.',
        importance: Importance.high,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _chargingChannelId,
        _chargingChannelName,
        description: '스마트링 충전 상태를 알려줍니다.',
        importance: Importance.defaultImportance,
      ),
    );

    _initialized = true;
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKeyEnabled) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKeyEnabled, enabled);
    if (!enabled) {
      _lastNotifiedLevel = null;
      _lastChargingState = null;
      _lastChargingProgressLevel = null;
      _lastChargingProgressAt = null;
      _fullChargeNotified = false;
      await _plugin.cancel(_lowNotificationId);
      await _plugin.cancel(_chargingNotificationId);
      await _plugin.cancel(_fullChargeNotificationId);
    }
  }

  static Future<bool> requestNotificationPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final result = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return result ?? false;
    }

    return true;
  }

  static Future<bool> hasNotificationPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final enabled = await android.areNotificationsEnabled();
      return enabled ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final settings = await ios.checkPermissions();
      return settings?.isEnabled ?? false;
    }

    return true;
  }

  static Future<void> onBatteryLevel(int? battery) async {
    if (battery == null) return;
    if (!await isEnabled()) return;
    if (battery > lowThreshold) {
      if (battery >= resetThreshold) {
        _lastNotifiedLevel = null;
      }
      return;
    }

    if (_lastNotifiedLevel != null && battery >= _lastNotifiedLevel!) {
      return;
    }

    if (!await hasNotificationPermission()) return;

    await _showLowBatteryAlert(battery);
    _lastNotifiedLevel = battery;
  }

  static Future<void> onChargingState({
    required bool isCharging,
    int? battery,
  }) async {
    if (!await isEnabled()) return;
    if (!await hasNotificationPermission()) return;

    final wasCharging = _lastChargingState ?? false;
    _lastChargingState = isCharging;

    if (isCharging) {
      _fullChargeNotified = false;
      if (!wasCharging) {
        await _showChargingStarted(battery);
        _lastChargingProgressLevel = battery;
        _lastChargingProgressAt = DateTime.now();
      }
      if (Platform.isIOS) {
        await RingChargingLiveActivity.sync(
          isCharging: true,
          battery: battery,
        );
      }
      return;
    }

    if (wasCharging) {
      if (Platform.isIOS) {
        await RingChargingLiveActivity.sync(isCharging: false, battery: battery);
      }
      final level = battery ?? _lastChargingProgressLevel ?? 0;
      if (level >= fullChargeThreshold && !_fullChargeNotified) {
        await _showFullChargeAlert(level);
        _fullChargeNotified = true;
      }
      await _plugin.cancel(_chargingNotificationId);
      _lastChargingProgressLevel = null;
      _lastChargingProgressAt = null;
    }
  }

  static Future<void> onChargingProgress(int? battery) async {
    if (battery == null) return;
    if (!await isEnabled()) return;
    if (_lastChargingState != true) return;
    if (!await hasNotificationPermission()) return;

    final lastLevel = _lastChargingProgressLevel;
    final lastAt = _lastChargingProgressAt;
    final now = DateTime.now();
    final levelDelta = lastLevel == null ? 999 : (battery - lastLevel).abs();
    final timeElapsed = lastAt == null
        ? const Duration(hours: 1)
        : now.difference(lastAt);

    if (levelDelta < 5 && timeElapsed.inMinutes < 10) return;

    await _showChargingProgress(battery);
    _lastChargingProgressLevel = battery;
    _lastChargingProgressAt = now;

    if (Platform.isIOS) {
      await RingChargingLiveActivity.sync(isCharging: true, battery: battery);
    }

    if (battery >= fullChargeThreshold && !_fullChargeNotified) {
      await _showFullChargeAlert(battery);
      _fullChargeNotified = true;
    }
  }

  static Future<void> _showLowBatteryAlert(int battery) async {
    try {
      await _plugin.show(
        _lowNotificationId,
        '스마트링 배터리 부족',
        '배터리가 $battery%입니다. 충전해 주세요.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _lowChannelId,
            _lowChannelName,
            channelDescription: '스마트링 배터리가 부족할 때 알려줍니다.',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[BATTERY_ALERT] show failed: $e');
    }
  }

  static Future<void> _showChargingStarted(int? battery) async {
    final body = battery != null && battery > 0
        ? '스마트링 충전을 시작했습니다. ($battery%)'
        : '스마트링 충전을 시작했습니다.';
    await _showChargingNotification(
      title: '스마트링 충전 중',
      body: body,
    );
  }

  static Future<void> _showChargingProgress(int battery) async {
    await _showChargingNotification(
      title: '스마트링 충전 중',
      body: '충전 중 · $battery%',
    );
  }

  static Future<void> _showFullChargeAlert(int battery) async {
    try {
      await _plugin.show(
        _fullChargeNotificationId,
        '충전 완료',
        '스마트링 배터리가 $battery%입니다. 충전이 완료되었습니다.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _chargingChannelId,
            _chargingChannelName,
            channelDescription: '스마트링 충전 상태를 알려줍니다.',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      await _plugin.cancel(_chargingNotificationId);
    } catch (e) {
      debugPrint('[CHARGING_ALERT] full charge show failed: $e');
    }
  }

  static Future<void> _showChargingNotification({
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.show(
        _chargingNotificationId,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _chargingChannelId,
            _chargingChannelName,
            channelDescription: '스마트링 충전 상태를 알려줍니다.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
            ongoing: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: false,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[CHARGING_ALERT] show failed: $e');
    }
  }
}
