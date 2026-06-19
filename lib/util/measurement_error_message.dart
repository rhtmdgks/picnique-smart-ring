import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';

/// 수동 측정 실패 시 사용자에게 보여줄 토스식 안내 문구.
String measurementErrorMessage(
  PlatformException error, {
  DataType? dataType,
}) {
  final code = error.code.toUpperCase();
  final message = (error.message ?? '').toLowerCase();

  if (_isRingWearOrContactError(code, message)) {
    return _ringNotWornMessage(dataType);
  }

  if (code.contains('MANUAL_TIMEOUT')) {
    return '측정 시간이 초과됐어요.\n'
        '반지를 손가락에 맞게 착용한 뒤 다시 측정해 주세요.';
  }

  if (code.contains('MANUAL_EMPTY')) {
    return '측정값을 가져오지 못했어요.\n'
        '잠시 후 다시 측정해 주세요.';
  }

  if (code.contains('MANUAL_FAIL')) {
    return _ringNotWornMessage(dataType);
  }

  return '측정 중 문제가 발생했어요.\n'
      '잠시 후 다시 시도해 주세요.';
}

bool _isRingWearOrContactError(String code, String message) {
  if (code.endsWith('_MANUAL_FAIL')) return true;
  if (message.contains('manual') && message.contains('fail')) return true;
  if (message.contains('measuring failed')) return true;
  if (message.contains('measurement failed')) return true;
  return false;
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
