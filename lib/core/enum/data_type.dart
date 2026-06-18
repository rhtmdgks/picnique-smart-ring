// ignore_for_file: constant_identifier_names

import 'package:picnique_rosary_healthcare_smartring/core/enum/bar.dart';

enum DataType {
  HeartRate,
  Stress,
  Oxygen,
  Sleep,
  Rosary,
  Kcal,
  Distance,
  Steps,
}

extension DataTypeCalcMaxY on DataType {
  num Function(num maxY) get calcMaxY {
    switch (this) {
      case DataType.HeartRate:
        return (maxY) {
          final rounded = (maxY / 10).ceil() * 10;
          return rounded < 20 ? 20 : rounded;
        };
      case DataType.Oxygen:
      case DataType.Sleep:
      case DataType.Rosary:
      case DataType.Stress:
        return (maxY) {
          return 100;
        };
      case DataType.Kcal:
        return (maxY) {
          return (maxY / calcIntervalY(maxY)).ceil() * calcIntervalY(maxY);
        };
      // m로...
      case DataType.Distance:
        return (maxY) {
          return (maxY / calcIntervalY(maxY)).ceil() * calcIntervalY(maxY);
        };
      case DataType.Steps:
        return (maxY) {
          return (maxY / calcIntervalY(maxY)).ceil() * calcIntervalY(maxY);
        };
    }
  }
}

extension DataTypeCalcMinY on DataType {
  num Function(num minY) get calcMinY {
    switch (this) {
      case DataType.HeartRate:
      case DataType.Oxygen:
        return (minY) {
          final floored = (minY / 10).floor() * 10;
          return floored < 0 ? 0 : floored.toDouble();
        };
      case DataType.Sleep:
      case DataType.Rosary:
      case DataType.Stress:
        return (minY) {
          final floored = minY.floor().toDouble();
          return floored < 0 ? 0 : floored;
        };
      case DataType.Kcal:
      case DataType.Distance:
      case DataType.Steps:
        return (_) => 0;
    }
  }
}

extension DataTypeCalcIntervalY on DataType {
  num Function(num) get calcIntervalY {
    switch (this) {
      case DataType.HeartRate:
      case DataType.Oxygen:
        return (maxY) {
          return 10;
        };
      case DataType.Sleep:
      case DataType.Rosary:
      case DataType.Stress:
        return (maxY) {
          return 20;
        };
      // 최대 2000정도로 생각
      case DataType.Kcal:
        return (maxY) {
          if (maxY < 100) {
            return 10;
          } else if (maxY < 200) {
            return 20;
          } else if (maxY < 500) {
            return 50;
          } else if (maxY < 1000) {
            return 100;
          } else {
            return 200;
          }
        };
      // 최대 5000정도로 생각
      case DataType.Distance:
        return (maxY) {
          if (maxY < 500) {
            return 100;
          } else if (maxY < 1000) {
            return 200;
          } else if (maxY < 2000) {
            return 400;
          } else {
            return 500;
          }
        };
      // 최대 만보 정도
      case DataType.Steps:
        return (maxY) {
          if (maxY < 200) {
            return 20;
          } else if (maxY < 500) {
            return 100;
          } else if (maxY < 1000) {
            return 200;
          } else if (maxY < 2000) {
            return 400;
          } else if (maxY < 5000) {
            return 1000;
          } else {
            return 2000;
          }
        };
    }
  }
}

extension DataTypeDataUnitFunc on DataType {
  String Function(num) get dataUnitFunc {
    switch (this) {
      case DataType.HeartRate:
        return (_) {
          return "bpm";
        };
      case DataType.Oxygen:
        return (_) {
          return "%";
        };
      case DataType.Sleep:
        return (_) {
          return "점수";
        };
      case DataType.Rosary:
        return (_) {
          return "단";
        };
      case DataType.Stress:
        return (stress) {
          if (stress < 20) {
            return "안정";
          } else if (stress < 40) {
            return "주의";
          } else if (stress < 60) {
            return "경고";
          } else if (stress < 80) {
            return "위험";
          } else {
            return "심각";
          }
        };
      case DataType.Kcal:
        return (_) {
          return "kcal";
        };
      case DataType.Distance:
        return (_) {
          return "m";
        };
      case DataType.Steps:
        return (_) {
          return "걸음";
        };
    }
  }
}

extension DataTypeDayUnitX on DataType {
  UnitX get dayUnitX {
    switch (this) {
      case DataType.HeartRate:
        return UnitX.fiveMin;
      case DataType.Stress:
        return UnitX.halfHour;
      case DataType.Oxygen:
      case DataType.Sleep:
      case DataType.Rosary:
      case DataType.Kcal:
      case DataType.Distance:
      case DataType.Steps:
        return UnitX.hour;
    }
  }
}

extension DataTypeDayUnitMins on DataType {
  int get dayUnitMins {
    switch (this) {
      case DataType.HeartRate:
        return 5;
      case DataType.Stress:
        return 30;
      case DataType.Oxygen:
      case DataType.Sleep:
      case DataType.Rosary:
      case DataType.Kcal:
      case DataType.Distance:
      case DataType.Steps:
        return 60;
    }
  }
}

extension DataTypeStartOfDay on DataType {
  int get startOfDay {
    switch (this) {
      case DataType.HeartRate:
      case DataType.Oxygen:
      case DataType.Sleep:
      case DataType.Rosary:
      case DataType.Stress:
      case DataType.Kcal:
      case DataType.Distance:
      case DataType.Steps:
        return 0;
    }
  }
}

extension DataTypeGraphType on DataType {
  GraphType get graphType {
    switch (this) {
      case DataType.Rosary:
      case DataType.Kcal:
      case DataType.Distance:
      case DataType.Steps:
      case DataType.Stress:
        return GraphType.bar;
      case DataType.HeartRate:
      case DataType.Oxygen:
        return GraphType.dot;
      case DataType.Sleep:
        return GraphType.stackedBar;
    }
  }
}
