import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/core/errors/hr_measurement_error_code.dart';

/// 수동 심박 측정 실패 시 토스(Toss) 톤의 사용자 안내 문구.
String hrMeasurementErrorMessage(PlatformException error) {
  final kind = parseHrMeasurementErrorCode(error);
  final deviceErr = parseHrDeviceErrCode(error);

  return switch (kind) {
    HrMeasurementErrorCode.notWorn => _notWorn,
    HrMeasurementErrorCode.timeout => _timeout,
    HrMeasurementErrorCode.startCommandFailed => _startCommandFailed,
    HrMeasurementErrorCode.endCommandFailed => _endCommandFailed,
    HrMeasurementErrorCode.measuringInterrupted => _measuringInterrupted,
    HrMeasurementErrorCode.nullResponse => _nullResponse,
    HrMeasurementErrorCode.emptyResult => _emptyResult,
    HrMeasurementErrorCode.deviceBusy => _deviceBusy,
    HrMeasurementErrorCode.sensorError => _sensorError,
    HrMeasurementErrorCode.deviceTimeout => _deviceTimeout,
    HrMeasurementErrorCode.deviceError => _deviceError(deviceErr),
    HrMeasurementErrorCode.notConnected => _notConnected,
    HrMeasurementErrorCode.touchModeFailed => _touchModeFailed,
    HrMeasurementErrorCode.genericFailure => _genericFailure,
    HrMeasurementErrorCode.unknown => _unknown(error),
  };
}

const _notWorn =
    '반지가 손가락에 제대로 닿지 않은 것 같아요.\n'
    '센서가 손바닥 쪽을 향하게 꽉 끼운 뒤 다시 측정해 주세요.';

const _timeout =
    '이번에는 심박수 결과를 받지 못했어요.\n'
    '손가락을 움직이지 않고 다시 한 번 측정해 주세요.';

const _startCommandFailed =
    '반지에 측정 신호를 보내지 못했어요.\n'
    '블루투스 연결을 확인한 뒤 다시 시도해 주세요.';

const _endCommandFailed =
    '측정을 마무리하지 못했어요.\n'
    '잠시 후 다시 측정해 주세요.';

const _measuringInterrupted =
    '측정이 중간에 끊겼어요.\n'
    '반지를 꽉 낀 채로 다시 한 번 눌러 주세요.';

const _nullResponse =
    '반지에서 응답이 없어요.\n'
    '연결 상태를 확인한 뒤 다시 측정해 주세요.';

const _emptyResult =
    '유효한 심박수 값을 받지 못했어요.\n'
    '잠시 후 다시 측정해 주세요.';

const _deviceBusy =
    '반지가 다른 측정을 진행 중이에요.\n'
    '잠시 기다렸다가 다시 시도해 주세요.';

const _sensorError =
    '센서에서 심박 신호를 읽지 못했어요.\n'
    '반지 위치를 조금 조절한 뒤 다시 측정해 주세요.';

const _deviceTimeout =
    '반지에서 측정이 제시간에 끝나지 않았어요.\n'
    '손가락을 고정한 채 다시 시도해 주세요.';

String _deviceError(int? deviceErr) {
  if (deviceErr != null) {
    return '반지에서 오류가 발생했어요. (코드 $deviceErr)\n'
        '잠시 후 다시 측정해 주세요.';
  }
  return '반지에서 오류가 발생했어요.\n'
      '잠시 후 다시 측정해 주세요.';
}

const _notConnected =
    '스마트링이 연결되어 있지 않아요.\n'
    '설정에서 반지 연결을 확인해 주세요.';

const _touchModeFailed =
    '반지 모드 전환에 실패했어요.\n'
    '연결 상태를 확인한 뒤 다시 측정해 주세요.';

const _genericFailure =
    '심박수 측정을 완료하지 못했어요.\n'
    '잠시 후 다시 시도해 주세요.';

String _unknown(PlatformException error) {
  final code = error.code;
  if (code.isEmpty) {
    return '측정 중 알 수 없는 문제가 발생했어요.\n'
        '잠시 후 다시 시도해 주세요.';
  }
  return '측정 중 문제가 발생했어요. ($code)\n'
      '잠시 후 다시 시도해 주세요.';
}
