import 'package:flutter/services.dart';

/// 수동 심박(HR) 측정 실패 유형.
///
/// 네이티브 `PlatformException.code` 및 [details]의 `deviceErrCode`로부터 파싱한다.
enum HrMeasurementErrorCode {
  notWorn,
  timeout,
  startCommandFailed,
  endCommandFailed,
  measuringInterrupted,
  nullResponse,
  emptyResult,
  deviceBusy,
  sensorError,
  deviceTimeout,
  deviceError,
  notConnected,
  touchModeFailed,
  genericFailure,
  unknown,
}

HrMeasurementErrorCode parseHrMeasurementErrorCode(PlatformException error) {
  final code = error.code.toUpperCase();
  final message = (error.message ?? '').toLowerCase();
  final deviceErr = parseHrDeviceErrCode(error);

  switch (code) {
    case 'HR_MANUAL_WEAR':
      return HrMeasurementErrorCode.notWorn;
    case 'HR_MANUAL_TIMEOUT':
      return HrMeasurementErrorCode.timeout;
    case 'HR_MANUAL_START_FAIL':
      return HrMeasurementErrorCode.startCommandFailed;
    case 'HR_MANUAL_END_FAIL':
      return HrMeasurementErrorCode.endCommandFailed;
    case 'HR_MANUAL_MEASURING_FAIL':
      return HrMeasurementErrorCode.measuringInterrupted;
    case 'HR_MANUAL_NULL':
      return HrMeasurementErrorCode.nullResponse;
    case 'HR_MANUAL_EMPTY':
      return HrMeasurementErrorCode.emptyResult;
    case 'HR_MANUAL_BUSY':
      return HrMeasurementErrorCode.deviceBusy;
    case 'HR_MANUAL_SENSOR_ERR':
      return HrMeasurementErrorCode.sensorError;
    case 'HR_MANUAL_DEVICE_TIMEOUT':
      return HrMeasurementErrorCode.deviceTimeout;
    case 'HR_MANUAL_DEVICE_ERR':
      return _fromDeviceErrCode(deviceErr);
    case 'HR_MANUAL_FAIL':
      if (message.contains('start') ||
          message.contains('command rejected') ||
          message.contains('startheart')) {
        return HrMeasurementErrorCode.startCommandFailed;
      }
      if (message.contains('measuringfail') ||
          message.contains('callback') ||
          message.contains('interrupted')) {
        return HrMeasurementErrorCode.measuringInterrupted;
      }
      return HrMeasurementErrorCode.genericFailure;
    case 'NOT_CONNECTED':
      return HrMeasurementErrorCode.notConnected;
    case 'TOUCH_MODE_FAIL':
    case 'TOUCH_LOG_FAIL':
      return HrMeasurementErrorCode.touchModeFailed;
    default:
      if (code.contains('NOT_CONNECTED')) {
        return HrMeasurementErrorCode.notConnected;
      }
      if (code.startsWith('HR_MANUAL')) {
        return HrMeasurementErrorCode.unknown;
      }
      return HrMeasurementErrorCode.unknown;
  }
}

HrMeasurementErrorCode _fromDeviceErrCode(int? deviceErr) {
  switch (deviceErr) {
    case 1:
      return HrMeasurementErrorCode.deviceBusy;
    case 2:
      return HrMeasurementErrorCode.sensorError;
    case 3:
    case 5:
      return HrMeasurementErrorCode.notWorn;
    case 4:
      return HrMeasurementErrorCode.deviceTimeout;
    case null:
      return HrMeasurementErrorCode.deviceError;
    default:
      return HrMeasurementErrorCode.deviceError;
  }
}

int? parseHrDeviceErrCode(PlatformException error) {
  final details = error.details;
  if (details is Map) {
    final raw = details['deviceErrCode'];
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
  }

  final message = error.message ?? '';
  final match = RegExp(
    r'(?:device\s*)?err(?:or)?code\s*[=:]\s*(\d+)',
    caseSensitive: false,
  ).firstMatch(message);
  if (match != null) {
    return int.tryParse(match.group(1)!);
  }
  return null;
}
