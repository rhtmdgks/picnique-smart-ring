import 'package:flutter/services.dart';

/// 산소포화도(SpO2) 수동 측정 실패 안내 — 토스 톤.
String spo2MeasurementErrorMessage(PlatformException error) {
  final code = error.code.toUpperCase();
  final message = (error.message ?? '').toLowerCase();

  switch (code) {
    case 'SPO2_MANUAL_WEAR':
      return '반지가 손가락에 제대로 닿지 않은 것 같아요.\n'
          '센서가 손바닥 쪽을 향하게 꽉 끼운 뒤 다시 측정해 주세요.';
    case 'SPO2_MANUAL_TIMEOUT':
      return '이번에는 산소포화도 결과를 받지 못했어요.\n'
          '손가락을 움직이지 않고 다시 한 번 측정해 주세요.';
    case 'SPO2_MANUAL_START_FAIL':
      return '반지에 측정 신호를 보내지 못했어요.\n'
          '블루투스 연결을 확인한 뒤 다시 시도해 주세요.';
    case 'SPO2_MANUAL_BUSY':
      return '반지가 다른 측정을 진행 중이에요.\n'
          '잠시 기다렸다가 다시 시도해 주세요.';
    case 'SPO2_MANUAL_SENSOR_ERR':
      return '센서에서 산소포화도 신호를 읽지 못했어요.\n'
          '반지 위치를 조금 조절한 뒤 다시 측정해 주세요.';
    case 'SPO2_MANUAL_NULL':
      return '반지에서 응답이 없어요.\n'
          '연결 상태를 확인한 뒤 다시 측정해 주세요.';
    case 'SPO2_MANUAL_EMPTY':
      return '유효한 산소포화도 값을 받지 못했어요.\n'
          '잠시 후 다시 측정해 주세요.';
    case 'SPO2_MANUAL_RANGE':
      return '측정값이 정상 범위를 벗어났어요.\n'
          '반지를 꽉 낀 채로 다시 측정해 주세요.';
    case 'SPO2_MANUAL_DEVICE_ERR':
      return '반지에서 오류가 발생했어요.\n'
          '(${error.message ?? code})\n'
          '잠시 후 다시 측정해 주세요.';
    case 'SPO2_MANUAL_FAIL':
      if (message.contains('start') || message.contains('command')) {
        return '반지에 측정 신호를 보내지 못했어요.\n'
            '블루투스 연결을 확인한 뒤 다시 시도해 주세요.';
      }
      return '산소포화도 측정을 완료하지 못했어요.\n'
          '잠시 후 다시 시도해 주세요.';
    case 'SESSION_BUSY':
      return '반지가 다른 측정을 진행 중이에요.\n'
          '잠시 기다렸다가 다시 시도해 주세요.';
    case 'MEASURE_INVALID_RESPONSE':
    case 'MEASURE_SESSION_TIMEOUT':
    case 'MEASURE_CHANNEL_TIMEOUT':
      return '측정 응답이 지연됐어요.\n'
          '손가락을 움직이지 않고 다시 측정해 주세요.';
    case 'NOT_CONNECTED':
      return '스마트링이 연결되어 있지 않아요.\n'
          '설정에서 반지 연결을 확인해 주세요.';
    default:
      if (code.contains('NOT_CONNECTED')) {
        return '스마트링이 연결되어 있지 않아요.\n'
            '설정에서 반지 연결을 확인해 주세요.';
      }
      return '산소포화도 측정 중 문제가 발생했어요.\n'
          '잠시 후 다시 시도해 주세요.';
  }
}
