import 'package:flutter/material.dart';

class UserSetting with ChangeNotifier {
  bool _isBluetoothOn = false, _isChargeAlarmOn = false;

  bool get isBluetoothOn => _isBluetoothOn;
  bool get isChargeAlarmOn => _isChargeAlarmOn;

  void setIsBluetoothOn(bool newIsBluetoothOn) {
    _isBluetoothOn = newIsBluetoothOn;
    notifyListeners();
  }

  void setIsChargeAlarmOn(bool newIsChargeAlarmOn) {
    _isChargeAlarmOn = newIsChargeAlarmOn;
    notifyListeners();
  }
}
