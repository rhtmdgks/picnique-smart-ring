import 'package:flutter/foundation.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';

/// 수동 측정 직후 앱 전역(헬스케어 홈·요약)에 최신 생체 신호를 공유한다.
class HealthLiveMetrics with ChangeNotifier {
  int? _heartRate;
  int? _spo2;
  int? _stress;

  int? get heartRate => _heartRate;
  int? get spo2 => _spo2;
  int? get stress => _stress;

  void record(DataType type, int value) {
    if (value <= 0) return;
    switch (type) {
      case DataType.HeartRate:
        _heartRate = value;
      case DataType.Oxygen:
        _spo2 = value;
      case DataType.Stress:
        _stress = value;
      default:
        return;
    }
    notifyListeners();
  }

  void hydrate({
    int? heartRate,
    int? spo2,
    int? stress,
  }) {
    var changed = false;
    if (_heartRate == null && heartRate != null && heartRate > 0) {
      _heartRate = heartRate;
      changed = true;
    }
    if (_spo2 == null && spo2 != null && spo2 > 0) {
      _spo2 = spo2;
      changed = true;
    }
    if (_stress == null && stress != null && stress > 0) {
      _stress = stress;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void clear() {
    _heartRate = null;
    _spo2 = null;
    _stress = null;
    notifyListeners();
  }
}
