import 'package:flutter/material.dart';

class MonitoringSetting with ChangeNotifier {
  bool _isStepOn = true,
      _isSleepOn = true,
      _isHeartRateOn = true,
      _isBloodOxygenOn = true,
      _isStressOn = true,
      _isActivityOn = true;

  bool get isStepOn => _isStepOn;
  bool get isSleepOn => _isSleepOn;
  bool get isHeartRateOn => _isHeartRateOn;
  bool get isBloodOxygenOn => _isBloodOxygenOn;
  bool get isStressOn => _isStressOn;
  bool get isActivityOn => _isActivityOn;

  void setIsStepOn(bool newIsStepOn) {
    _isStepOn = newIsStepOn;
    notifyListeners();
  }

  void setIsSleepOn(bool newIsSleepOn) {
    _isSleepOn = newIsSleepOn;
    notifyListeners();
  }

  void setIsHeartRateOn(bool newIsHeartRateOn) {
    _isHeartRateOn = newIsHeartRateOn;
    notifyListeners();
  }

  void setIsBloodOxygenOn(bool newIsBloodOxygenOn) {
    _isBloodOxygenOn = newIsBloodOxygenOn;
    notifyListeners();
  }

  void setIsStressOn(bool newIsStressOn) {
    _isStressOn = newIsStressOn;
    notifyListeners();
  }

  void setIsActivityOn(bool newIsActivityOn) {
    _isActivityOn = newIsActivityOn;
    notifyListeners();
  }
}
