import 'package:flutter/material.dart';

class UserSetting with ChangeNotifier {
  bool _isBluetoothOn = false, _isChargeAlarmOn = false;

  bool get isBluetoothOn => _isBluetoothOn;
  bool get isChargeAlarmOn => _isChargeAlarmOn;

  void setIsBluetoothOn(newIsBluetoothOn) {
    _isBluetoothOn = newIsBluetoothOn;
    notifyListeners();
  }

  void setIsChargeAlarmOn(newIsChargeAlarmOn) {
    _isChargeAlarmOn = newIsChargeAlarmOn;
    notifyListeners();
  }
}
