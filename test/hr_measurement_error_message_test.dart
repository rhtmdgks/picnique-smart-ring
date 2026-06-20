import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picnique_rosary_healthcare_smartring/core/errors/hr_measurement_error_code.dart';
import 'package:picnique_rosary_healthcare_smartring/util/hr_measurement_error_message.dart';

PlatformException _ex(
  String code, {
  String? message,
  Object? details,
}) =>
    PlatformException(code: code, message: message, details: details);

void main() {
  group('parseHrMeasurementErrorCode', () {
    test('HR_MANUAL_WEAR → notWorn', () {
      expect(
        parseHrMeasurementErrorCode(_ex('HR_MANUAL_WEAR')),
        HrMeasurementErrorCode.notWorn,
      );
    });

    test('HR_MANUAL_TIMEOUT → timeout', () {
      expect(
        parseHrMeasurementErrorCode(_ex('HR_MANUAL_TIMEOUT')),
        HrMeasurementErrorCode.timeout,
      );
    });

    test('HR_MANUAL_START_FAIL → startCommandFailed', () {
      expect(
        parseHrMeasurementErrorCode(_ex('HR_MANUAL_START_FAIL')),
        HrMeasurementErrorCode.startCommandFailed,
      );
    });

    test('HR_MANUAL_MEASURING_FAIL → measuringInterrupted', () {
      expect(
        parseHrMeasurementErrorCode(_ex('HR_MANUAL_MEASURING_FAIL')),
        HrMeasurementErrorCode.measuringInterrupted,
      );
    });

    test('HR_MANUAL_NULL → nullResponse', () {
      expect(
        parseHrMeasurementErrorCode(_ex('HR_MANUAL_NULL')),
        HrMeasurementErrorCode.nullResponse,
      );
    });

    test('HR_MANUAL_EMPTY → emptyResult', () {
      expect(
        parseHrMeasurementErrorCode(_ex('HR_MANUAL_EMPTY')),
        HrMeasurementErrorCode.emptyResult,
      );
    });

    test('HR_MANUAL_BUSY → deviceBusy', () {
      expect(
        parseHrMeasurementErrorCode(_ex('HR_MANUAL_BUSY')),
        HrMeasurementErrorCode.deviceBusy,
      );
    });

    test('HR_MANUAL_SENSOR_ERR → sensorError', () {
      expect(
        parseHrMeasurementErrorCode(_ex('HR_MANUAL_SENSOR_ERR')),
        HrMeasurementErrorCode.sensorError,
      );
    });

    test('HR_MANUAL_DEVICE_TIMEOUT → deviceTimeout', () {
      expect(
        parseHrMeasurementErrorCode(_ex('HR_MANUAL_DEVICE_TIMEOUT')),
        HrMeasurementErrorCode.deviceTimeout,
      );
    });

    test('HR_MANUAL_DEVICE_ERR errCode=3 → notWorn', () {
      expect(
        parseHrMeasurementErrorCode(
          _ex('HR_MANUAL_DEVICE_ERR', message: 'Device errCode=3'),
        ),
        HrMeasurementErrorCode.notWorn,
      );
    });

    test('HR_MANUAL_DEVICE_ERR errCode=1 → deviceBusy', () {
      expect(
        parseHrMeasurementErrorCode(
          _ex(
            'HR_MANUAL_DEVICE_ERR',
            details: {'deviceErrCode': 1},
          ),
        ),
        HrMeasurementErrorCode.deviceBusy,
      );
    });

    test('HR_MANUAL_FAIL start message → startCommandFailed', () {
      expect(
        parseHrMeasurementErrorCode(
          _ex(
            'HR_MANUAL_FAIL',
            message: 'startHeartRateMeasuring command rejected',
          ),
        ),
        HrMeasurementErrorCode.startCommandFailed,
      );
    });

    test('HR_MANUAL_FAIL measuringFail → measuringInterrupted', () {
      expect(
        parseHrMeasurementErrorCode(
          _ex('HR_MANUAL_FAIL', message: 'measuringFail callback'),
        ),
        HrMeasurementErrorCode.measuringInterrupted,
      );
    });

    test('NOT_CONNECTED → notConnected', () {
      expect(
        parseHrMeasurementErrorCode(_ex('NOT_CONNECTED')),
        HrMeasurementErrorCode.notConnected,
      );
    });
  });

  group('hrMeasurementErrorMessage', () {
    test('notWorn message contains 꽉 끼운', () {
      final msg = hrMeasurementErrorMessage(_ex('HR_MANUAL_WEAR'));
      expect(msg, contains('꽉 끼운'));
      expect(msg, isNot(contains('HR_MANUAL')));
    });

    test('timeout message distinct from notWorn', () {
      final msg = hrMeasurementErrorMessage(_ex('HR_MANUAL_TIMEOUT'));
      expect(msg, contains('결과를 받지 못했'));
      expect(msg, isNot(contains('꽉 끼운')));
    });

    test('start fail mentions 블루투스', () {
      final msg = hrMeasurementErrorMessage(_ex('HR_MANUAL_START_FAIL'));
      expect(msg, contains('블루투스'));
    });

    test('device error includes code when available', () {
      final msg = hrMeasurementErrorMessage(
        _ex('HR_MANUAL_DEVICE_ERR', details: {'deviceErrCode': 9}),
      );
      expect(msg, contains('코드 9'));
    });

    test('each known code returns non-empty message', () {
      final codes = [
        'HR_MANUAL_WEAR',
        'HR_MANUAL_TIMEOUT',
        'HR_MANUAL_START_FAIL',
        'HR_MANUAL_MEASURING_FAIL',
        'HR_MANUAL_NULL',
        'HR_MANUAL_EMPTY',
        'HR_MANUAL_BUSY',
        'HR_MANUAL_SENSOR_ERR',
        'HR_MANUAL_DEVICE_TIMEOUT',
        'NOT_CONNECTED',
      ];
      final messages =
          codes.map((c) => hrMeasurementErrorMessage(_ex(c))).toList();
      expect(messages.every((m) => m.trim().isNotEmpty), isTrue);
      expect(messages.toSet().length, greaterThan(5));
    });
  });
}
