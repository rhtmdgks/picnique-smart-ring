import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(BleCommandQueue.channel, null);
  });

  group('우선순위 정렬', () {
    test('connection > manual > uiFresh > backgroundSync 순서', () async {
      final executed = <String>[];
      final gate = Completer<void>();
      messenger.setMockMethodCallHandler(BleCommandQueue.channel, (call) async {
        if (call.method == 'block') {
          await gate.future;
          return null;
        }
        executed.add(call.method);
        return null;
      });

      // 첫 호출로 큐를 점유 — 이후 호출들은 _pending 에 쌓인다.
      final blockFuture = BleCommandQueue.invoke<void>('block');

      final futures = <Future<dynamic>>[
        BleCommandQueue.invokeAuto<dynamic>('bg1'),
        BleCommandQueue.invoke<dynamic>('ui1', null, BleOpPriority.uiFresh),
        // _manualMethods 포함 → 자동으로 manual 우선순위.
        BleCommandQueue.invoke<dynamic>('syncManualHeartRate'),
        BleCommandQueue.invoke<dynamic>('conn1'),
        BleCommandQueue.invoke<dynamic>('conn2'),
      ];

      gate.complete();
      await blockFuture;
      await Future.wait(futures);

      // 낮은 enum index = 높은 우선순위: connection(0) > manual(1) >
      // uiFresh(2) > backgroundSync(3).
      expect(executed, [
        'conn1',
        'conn2',
        'syncManualHeartRate',
        'ui1',
        'bg1',
      ]);
    });

    test('같은 우선순위끼리는 FIFO 유지', () async {
      final executed = <String>[];
      final gate = Completer<void>();
      messenger.setMockMethodCallHandler(BleCommandQueue.channel, (call) async {
        if (call.method == 'block') {
          await gate.future;
          return null;
        }
        executed.add(call.method);
        return null;
      });

      final blockFuture = BleCommandQueue.invoke<void>('block');
      final futures = <Future<dynamic>>[
        BleCommandQueue.invokeAuto<dynamic>('bg1'),
        BleCommandQueue.invokeAuto<dynamic>('bg2'),
        BleCommandQueue.invokeAuto<dynamic>('bg3'),
      ];

      gate.complete();
      await blockFuture;
      await Future.wait(futures);

      expect(executed, ['bg1', 'bg2', 'bg3']);
    });

    test('invokeAuto 는 backgroundSync — preemptAutoForManual 로 취소된다',
        () async {
      final gate = Completer<void>();
      messenger.setMockMethodCallHandler(BleCommandQueue.channel, (call) async {
        if (call.method == 'block') {
          await gate.future;
        }
        return null;
      });

      final blockFuture = BleCommandQueue.invoke<void>('block');
      final autoFuture = BleCommandQueue.invokeAuto<dynamic>('bgQueued');

      // completeError 전에 에러 리스너를 먼저 붙인다 (unhandled error 방지).
      final expectation = expectLater(
        autoFuture,
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            BleCommandQueue.autoCancelledCode,
          ),
        ),
      );

      await BleCommandQueue.preemptAutoForManual();
      gate.complete();
      await blockFuture;
      await expectation;
    });
  });

  group('runWithSessionRetry', () {
    test('SESSION_BUSY — 5초 → 10초 backoff 후 성공', () {
      fakeAsync((async) {
        var attempts = 0;
        String? result;
        BleCommandQueue.runWithSessionRetry<String>(() async {
          attempts++;
          if (attempts < 3) {
            throw PlatformException(code: 'SESSION_BUSY');
          }
          return 'ok';
        }).then((v) => result = v);

        async.flushMicrotasks();
        expect(attempts, 1);

        // 1차 backoff 5초 — 4초 시점엔 아직 재시도 전.
        async.elapse(const Duration(seconds: 4));
        expect(attempts, 1);
        async.elapse(const Duration(seconds: 1));
        expect(attempts, 2);

        // 2차 backoff 10초.
        async.elapse(const Duration(seconds: 9));
        expect(attempts, 2);
        async.elapse(const Duration(seconds: 1));
        expect(attempts, 3);
        expect(result, 'ok');
      });
    });

    test('TIMEOUT 코드 포함도 재시도 대상', () {
      fakeAsync((async) {
        var attempts = 0;
        BleCommandQueue.runWithSessionRetry<void>(() async {
          attempts++;
          if (attempts < 2) {
            throw PlatformException(code: 'MEASURE_CHANNEL_TIMEOUT');
          }
        });

        async.flushMicrotasks();
        expect(attempts, 1);
        async.elapse(const Duration(seconds: 5));
        expect(attempts, 2);
      });
    });

    test('maxAttempts 소진 시 마지막 에러 rethrow', () {
      fakeAsync((async) {
        var attempts = 0;
        Object? error;
        BleCommandQueue.runWithSessionRetry<void>(
          () async {
            attempts++;
            throw PlatformException(code: 'MEASURE_IN_PROGRESS');
          },
          maxAttempts: 3,
        ).catchError((Object e) {
          error = e;
        });

        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5)); // 1 → 2
        async.elapse(const Duration(seconds: 10)); // 2 → 3
        async.flushMicrotasks();

        expect(attempts, 3);
        expect(
          error,
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'MEASURE_IN_PROGRESS'),
        );
      });
    });

    test('재시도 대상이 아닌 코드는 즉시 rethrow', () {
      fakeAsync((async) {
        var attempts = 0;
        Object? error;
        BleCommandQueue.runWithSessionRetry<void>(() async {
          attempts++;
          throw PlatformException(code: 'SLEEP_FAIL');
        }).catchError((Object e) {
          error = e;
        });

        async.flushMicrotasks();
        expect(attempts, 1);
        expect(
          error,
          isA<PlatformException>().having((e) => e.code, 'code', 'SLEEP_FAIL'),
        );
      });
    });
  });
}
