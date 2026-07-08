import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_auto_measurement_service.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_sleep_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // 현재 mock 시각 — 각 테스트에서 조정.
  late DateTime now;

  /// probe(syncSleepNew) 응답. null 이면 빈 결과, 'FAIL' 이면 에러.
  dynamic sleepResponse;

  late Ring ring;
  late RingSleepGate gate;

  int epochSec(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  /// [start]~[end] 단일 세그먼트(타입 [type]) 수면 응답 생성.
  Map<String, dynamic> sleepRsp(DateTime start, DateTime end, {int type = 2}) {
    return {
      'st': epochSec(start),
      'et': epochSec(end),
      'list': [
        {'d': end.difference(start).inSeconds, 't': type},
      ],
    };
  }

  setUp(() {
    now = DateTime(2026, 7, 8, 22, 0);
    sleepResponse = null;
    messenger.setMockMethodCallHandler(BleCommandQueue.channel, (call) async {
      if (call.method == 'syncSleepNew') {
        if (sleepResponse == 'FAIL') {
          throw PlatformException(code: 'SLEEP_FAIL');
        }
        return sleepResponse;
      }
      return null;
    });

    ring = Ring();
    // bind 시점엔 미연결 → probe 타이머가 돌지 않아 tick() 을 직접 제어한다.
    gate = RingSleepGate.forTest(now: () => now);
    gate.bind(ring);
    ring.setIsConnected(true);
    ring.setSdkReady(true);
  });

  tearDown(() {
    gate.unbind();
    // 싱글턴 자동 측정 서비스의 sleepHold 잔류 방지.
    RingAutoMeasurementService.instance.resumeAfterWake();
    messenger.setMockMethodCallHandler(BleCommandQueue.channel, null);
  });

  group('후보 시간대 진입', () {
    test('21:00 이후 tick → AWAKE → CANDIDATE', () async {
      expect(gate.state, SleepGateState.awake);
      await gate.tick();
      expect(gate.state, SleepGateState.candidate);
    });

    test('후보 시간대 밖(낮)에는 AWAKE 유지', () async {
      now = DateTime(2026, 7, 8, 14, 0);
      await gate.tick();
      expect(gate.state, SleepGateState.awake);
    });

    test('CANDIDATE 에서 11:00 지나면 AWAKE 복귀', () async {
      await gate.tick(); // 22:00 → CANDIDATE
      expect(gate.state, SleepGateState.candidate);

      now = DateTime(2026, 7, 9, 11, 30);
      await gate.tick();
      expect(gate.state, SleepGateState.awake);
    });

    test('미연결이면 tick 이 상태를 바꾸지 않는다', () async {
      ring.setIsConnected(false);
      await gate.tick();
      expect(gate.state, SleepGateState.awake);
    });
  });

  group('probe → SLEEPING 전이', () {
    test('진행 중 수면 세그먼트(et 30분 이내) → SLEEPING + 자동 측정 pause',
        () async {
      await gate.tick(); // CANDIDATE 진입 (빈 응답 → streak 1)
      expect(gate.state, SleepGateState.candidate);

      now = DateTime(2026, 7, 8, 23, 40);
      sleepResponse = sleepRsp(
        DateTime(2026, 7, 8, 22, 30),
        DateTime(2026, 7, 8, 23, 30), // now 기준 10분 전 종료 — 진행 중으로 판정
      );
      await gate.tick();

      expect(gate.state, SleepGateState.sleeping);
      expect(RingAutoMeasurementService.instance.sleepHold, isTrue);
    });

    test('et 가 30분보다 오래된 stale 데이터는 SLEEPING 으로 안 간다', () async {
      await gate.tick(); // CANDIDATE

      now = DateTime(2026, 7, 8, 23, 40);
      sleepResponse = sleepRsp(
        DateTime(2026, 7, 8, 21, 0),
        DateTime(2026, 7, 8, 22, 30), // 70분 전 종료
      );
      await gate.tick();

      expect(gate.state, SleepGateState.candidate);
    });

    test('폴백: probe 2회 연속 실패 + 23:00~07:00 → SLEEPING', () async {
      now = DateTime(2026, 7, 8, 23, 30);
      sleepResponse = 'FAIL';

      await gate.tick(); // AWAKE → CANDIDATE + 실패 1회
      expect(gate.state, SleepGateState.candidate);

      await gate.tick(); // 실패 2회 → 폴백 SLEEPING
      expect(gate.state, SleepGateState.sleeping);
      expect(RingAutoMeasurementService.instance.sleepHold, isTrue);
    });

    test('폴백 조건이어도 23:00 이전이면 CANDIDATE 유지', () async {
      now = DateTime(2026, 7, 8, 22, 0);
      sleepResponse = null; // 빈 결과

      await gate.tick();
      await gate.tick();
      await gate.tick();

      expect(gate.state, SleepGateState.candidate);
    });
  });

  group('WAKE 전이', () {
    /// 22:30 취침 → SLEEPING 상태로 만드는 공통 셋업.
    Future<void> enterSleep() async {
      await gate.tick(); // CANDIDATE
      now = DateTime(2026, 7, 8, 23, 40);
      sleepResponse = sleepRsp(
        DateTime(2026, 7, 8, 22, 30),
        DateTime(2026, 7, 8, 23, 30),
      );
      await gate.tick();
      expect(gate.state, SleepGateState.sleeping);
    }

    test('마지막 세그먼트 종료 후 30분 경과 → WAKE + onWake 콜백', () async {
      var wakeCount = 0;
      gate.unbind();
      // 미연결 상태에서 bind — probe 타이머 없이 tick() 만 직접 제어.
      ring.setIsConnected(false);
      gate = RingSleepGate.forTest(now: () => now);
      gate.bind(ring, onWake: () => wakeCount++);
      ring.setIsConnected(true);

      await enterSleep();

      // 아침 — et 07:10 그대로, 40분 경과.
      now = DateTime(2026, 7, 9, 7, 50);
      sleepResponse = sleepRsp(
        DateTime(2026, 7, 8, 22, 30),
        DateTime(2026, 7, 9, 7, 10),
      );
      await gate.tick();

      expect(gate.state, SleepGateState.awake);
      expect(RingAutoMeasurementService.instance.sleepHold, isFalse);
      expect(wakeCount, 1);
    });

    test('sober(awake) 꼬리 세그먼트 → 즉시 WAKE', () async {
      await enterSleep();

      now = DateTime(2026, 7, 9, 7, 20);
      sleepResponse = sleepRsp(
        DateTime(2026, 7, 8, 22, 30),
        DateTime(2026, 7, 9, 7, 15),
        type: 5, // sober/awake
      );
      await gate.tick();

      expect(gate.state, SleepGateState.awake);
      expect(RingAutoMeasurementService.instance.sleepHold, isFalse);
    });

    test('수면 진행 중(et 갱신)이면 SLEEPING 유지', () async {
      await enterSleep();

      now = DateTime(2026, 7, 9, 2, 0);
      sleepResponse = sleepRsp(
        DateTime(2026, 7, 8, 22, 30),
        DateTime(2026, 7, 9, 1, 50),
      );
      await gate.tick();

      expect(gate.state, SleepGateState.sleeping);
    });

    test('앱 foreground 복귀 + 07:00 이후 → WAKE', () async {
      await enterSleep();

      now = DateTime(2026, 7, 9, 8, 0);
      gate.onAppResumed();

      expect(gate.state, SleepGateState.awake);
      expect(RingAutoMeasurementService.instance.sleepHold, isFalse);
    });

    test('앱 foreground 복귀라도 새벽(07:00 이전)이면 SLEEPING 유지', () async {
      await enterSleep();

      now = DateTime(2026, 7, 9, 3, 0);
      gate.onAppResumed();

      expect(gate.state, SleepGateState.sleeping);
    });

    test('기상 직후 stale 수면 데이터로 재수면 판정하지 않는다', () async {
      await enterSleep();

      // 07:30 foreground 기상.
      now = DateTime(2026, 7, 9, 7, 30);
      gate.onAppResumed();
      expect(gate.state, SleepGateState.awake);

      // 07:45 probe — 수면 데이터 et 07:25 (20분 전, 기상 시각 이전) → 무시.
      now = DateTime(2026, 7, 9, 7, 45);
      sleepResponse = sleepRsp(
        DateTime(2026, 7, 8, 22, 30),
        DateTime(2026, 7, 9, 7, 25),
      );
      await gate.tick(); // AWAKE → CANDIDATE (아직 11시 전) + probe
      expect(gate.state, SleepGateState.candidate);
      expect(RingAutoMeasurementService.instance.sleepHold, isFalse);
    });
  });
}
