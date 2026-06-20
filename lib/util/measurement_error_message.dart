import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/util/hr_measurement_error_message.dart';
import 'package:picnique_rosary_healthcare_smartring/util/spo2_measurement_error_message.dart';

/// 수동 측정 실패 시 사용자에게 보여줄 안내 문구.
String measurementErrorMessage(
  PlatformException error, {
  DataType? dataType,
}) {
  final code = error.code.toUpperCase();

  if (dataType == DataType.HeartRate || code.startsWith('HR_')) {
    return hrMeasurementErrorMessage(error);
  }

  if (dataType == DataType.Oxygen || code.startsWith('SPO2_')) {
    return spo2MeasurementErrorMessage(error);
  }

  if (code.contains('MANUAL_TIMEOUT')) {
    return '측정 시간이 초과됐어요.\n'
        '손가락을 움직이지 않은 상태로 다시 측정해 주세요.';
  }

  if (code.contains('MANUAL_EMPTY')) {
    return '측정값을 가져오지 못했어요.\n'
        '잠시 후 다시 측정해 주세요.';
  }

  if (code.contains('NOT_CONNECTED')) {
    return '스마트링이 연결되어 있지 않아요.\n'
        '설정에서 반지 연결을 확인해 주세요.';
  }

  if (code.endsWith('_MANUAL_WEAR')) {
    return _ringNotWornMessage(dataType);
  }

  if (code.contains('MANUAL_FAIL')) {
    return '측정을 완료하지 못했어요.\n'
        '잠시 후 다시 시도해 주세요.';
  }

  return '측정 중 문제가 발생했어요.\n'
      '잠시 후 다시 시도해 주세요.';
}

String _ringNotWornMessage(DataType? dataType) {
  final metric = switch (dataType) {
    DataType.HeartRate => '심박수',
    DataType.Oxygen => '산소포화도',
    DataType.Stress => '스트레스',
    _ => null,
  };

  if (metric != null) {
    return '반지가 손가락에 제대로 닿지 않은 것 같아요.\n'
        '반지를 꽉 끼운 뒤 $metric 측정을 다시 해 주세요.';
  }

  return '반지가 손가락에 제대로 닿지 않은 것 같아요.\n'
      '반지를 꽉 끼운 뒤 다시 측정해 주세요.';
}
