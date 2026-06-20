import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/services/battery_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSetting with ChangeNotifier {
  static const _kChargeAlarm = BatteryNotificationService.prefsKeyEnabled;

  bool _isBluetoothOn = false;
  bool _isChargeAlarmOn = false;
  bool _loaded = false;

  bool get isBluetoothOn => _isBluetoothOn;
  bool get isChargeAlarmOn => _isChargeAlarmOn;
  bool get isLoaded => _loaded;

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isChargeAlarmOn = prefs.getBool(_kChargeAlarm) ?? true;
    if (!prefs.containsKey(_kChargeAlarm)) {
      await prefs.setBool(_kChargeAlarm, true);
    }
    _loaded = true;
    notifyListeners();
  }

  void setIsBluetoothOn(bool newIsBluetoothOn) {
    _isBluetoothOn = newIsBluetoothOn;
    notifyListeners();
  }

  Future<bool> setIsChargeAlarmOn(bool enabled) async {
    if (enabled) {
      final granted =
          await BatteryNotificationService.requestNotificationPermission();
      if (!granted) return false;
    }

    _isChargeAlarmOn = enabled;
    await BatteryNotificationService.setEnabled(enabled);
    notifyListeners();
    return true;
  }
}
