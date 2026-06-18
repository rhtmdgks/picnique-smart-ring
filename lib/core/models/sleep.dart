
import 'package:picnique_rosary_healthcare_smartring/core/enum/sleep.dart';

class SleepStage {
  final DateTime startTime;
  final DateTime endTime;
  final SleepType sleepType;

  SleepStage({
    required this.startTime,
    required this.endTime,
    required this.sleepType,
  });
}

class SleepData {
  final DateTime date;
  final List<SleepStage> sleep;

  SleepData({
    required this.date,
    required this.sleep,
  });
}

class SleepMonthData {
  final int date;
  final List<SleepStage> sleep;

  SleepMonthData({
    required this.date,
    required this.sleep,
  });
}
