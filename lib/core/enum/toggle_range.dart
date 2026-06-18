import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';

enum ToggleRange { day, week, month, halfYear, year }

extension ToggleRangeWindow on ToggleRange {
  int get window {
    switch (this) {
      case ToggleRange.day:
        return 24;
      case ToggleRange.week:
        return 7;
      case ToggleRange.month:
        return 31;
      case ToggleRange.halfYear:
        return 6;
      case ToggleRange.year:
        return 12;
    }
  }
}

extension ToggleRangeUnitX on ToggleRange {
  UnitX get unitX {
    switch (this) {
      case ToggleRange.day:
        return UnitX.hour;
      case ToggleRange.week:
        return UnitX.day;
      case ToggleRange.month:
        return UnitX.day;
      case ToggleRange.halfYear:
        return UnitX.month;
      case ToggleRange.year:
        return UnitX.month;
    }
  }
}

extension ToggleRangeIntervalX on ToggleRange {
  int get intervalX {
    switch (this) {
      case ToggleRange.day:
        return 12;
      case ToggleRange.week:
        return 1;
      case ToggleRange.month:
        return 5;
      case ToggleRange.halfYear:
        return 1;
      case ToggleRange.year:
        return 1;
    }
  }
}
