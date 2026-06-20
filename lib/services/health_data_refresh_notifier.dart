import 'package:flutter/foundation.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';

/// 건강 DB에 새 측정값이 들어오면 차트·최신값 UI를 즉시 갱신한다.
class HealthDataRefreshNotifier extends ChangeNotifier {
  int _tick = 0;
  DataType? _lastDataType;

  int get tick => _tick;

  DataType? get lastDataType => _lastDataType;

  bool affects(DataType type) =>
      _lastDataType == null || _lastDataType == type;

  void notifyChanged(DataType type) {
    _tick++;
    _lastDataType = type;
    notifyListeners();
  }

  static DataType? dataTypeForImportRecord(String? type) {
    switch (type) {
      case 'heart':
      case 'heart_sample':
        return DataType.HeartRate;
      case 'spo2':
      case 'spo2_sample':
        return DataType.Oxygen;
      case 'stress':
      case 'stress_sample':
        return DataType.Stress;
      case 'steps':
      case 'sport_slot':
        return DataType.Steps;
      default:
        return null;
    }
  }
}
