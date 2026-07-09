// ignore_for_file: file_names

import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:drift/drift.dart' as drift;
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';

// import 'package:picnique_rosary_healthcare_smartring/core/constants/colors.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:url_launcher/url_launcher.dart'; // pubspec에 추가 필요
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/ring_measurement_policy.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_monitoring_status.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_session_arbiter.dart';

import '../db/app_db.dart';

const MethodChannel _blePlatformChannel = BleCommandQueue.channel;

Future<T?> _bleInvoke<T>(String method, [dynamic arguments]) {
  return BleCommandQueue.invoke<T>(method, arguments);
}

Future<bool> ensureBluetoothOn(
  BuildContext context, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  if (Platform.isIOS) {
    return _ensureBluetoothOnIos(context, timeout: timeout);
  }

  // Android: FlutterBluePlus로 어댑터 상태 확인
  final initial = await FlutterBluePlus.adapterState.first;
  if (initial == BluetoothAdapterState.on) return true;

  try {
    await FlutterBluePlus.turnOn();
  } catch (_) {}
  try {
    await FlutterBluePlus.adapterState
        .firstWhere((s) => s == BluetoothAdapterState.on)
        .timeout(timeout);
    return true;
  } on TimeoutException {
    return false;
  }
}

/// iOS는 스캔/연결에 네이티브 CBCentralManager를 사용한다.
/// FlutterBluePlus.adapterState는 꺼짐으로 오탐하는 경우가 많아 네이티브 상태를 본다.
Future<bool> _ensureBluetoothOnIos(
  BuildContext context, {
  required Duration timeout,
}) async {
  const initWait = Duration(seconds: 3);
  final initDeadline = DateTime.now().add(initWait);

  String? state;
  while (DateTime.now().isBefore(initDeadline)) {
    try {
      state = await _bleInvoke<String>(
        'getBluetoothState',
      );
    } on PlatformException catch (e) {
      debugPrint('[BLE] getBluetoothState error: ${e.code}');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      continue;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      continue;
    }

    if (state == 'on') return true;
    if (state == 'off' ||
        state == 'unauthorized' ||
        state == 'unsupported') {
      break;
    }
    // unknown / resetting → CBCentralManager 초기화 대기
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  if (state == 'on') return true;
  if (!context.mounted) return false;

  final unauthorized = state == 'unauthorized';
  final open =
      await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(
            unauthorized ? '블루투스 권한이 필요합니다' : '블루투스가 꺼져 있습니다',
          ),
          content: Text(
            unauthorized
                ? '설정에서 이 앱의 블루투스 권한을 허용한 뒤 다시 시도해 주세요.'
                : '설정에서 블루투스를 켠 뒤 다시 시도해 주세요.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('취소'),
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('설정 열기'),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ) ??
      false;

  if (!open) return false;

  try {
    await launchUrl(Uri.parse('app-settings:'));
  } catch (_) {}

  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    try {
      state = await _bleInvoke<String>(
        'getBluetoothState',
      );
      if (state == 'on') return true;
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  return false;
}

/// UI 없이 블루투스 사용 가능 여부만 확인한다(자동 재연결 등).
Future<bool> isBluetoothReady({
  Duration timeout = const Duration(seconds: 8),
}) async {
  if (Platform.isIOS) {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final state = await _bleInvoke<String>(
          'getBluetoothState',
        );
        if (state == 'on') return true;
        if (state == 'off' ||
            state == 'unauthorized' ||
            state == 'unsupported') {
          return false;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  try {
    final initial = await FlutterBluePlus.adapterState.first;
    if (initial == BluetoothAdapterState.on) return true;
    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {}
    await FlutterBluePlus.adapterState
        .firstWhere((s) => s == BluetoothAdapterState.on)
        .timeout(timeout);
    return true;
  } on TimeoutException {
    return false;
  } catch (_) {
    return false;
  }
}

/// 연결 직후 자동 모니터링 설정 간격(iOS BLE 안정화).
const Duration _monitoringWriteGap = Duration(milliseconds: 600);

Future<bool> _writeMonitoringWithRetry(
  String method,
  Map<String, dynamic> args, {
  int attempts = 2,
}) async {
  for (var i = 0; i < attempts; i++) {
    if (i > 0) {
      await Future<void>.delayed(_monitoringWriteGap);
    }
    // 수동 측정 중 설정 write 는 링이 거부(HR_WRITE_FAIL 등) —
    // 매 시도마다 수동 세션이 끝날 때까지 기다린다.
    await BleCommandQueue.waitUntilManualIdle();
    try {
      // uiFresh: 수동·자동 측정보다 뒤에 서고(측정 지연 방지),
      // 선점 취소 대상도 아니다. connection 이면 측정 앞에 끼어든다.
      await BleCommandQueue.invoke(method, args, BleOpPriority.uiFresh);
      debugPrint('[MONITOR] $method ok');
      return true;
    } catch (e) {
      debugPrint('[MONITOR] $method attempt ${i + 1}/$attempts failed: $e');
    }
  }
  return false;
}

/// 스케줄 설정 read-back — `{isEnable: bool}` 응답에서 ON 여부 확인.
/// 읽기 실패는 미확인이므로 write 결과를 그대로 신뢰한다(낙관).
Future<bool> _readMonitoringEnabled(String method, bool writeOk) async {
  try {
    final res = await _bleInvoke<dynamic>(method);
    if (res is Map && res['isEnable'] is bool) {
      final enabled = res['isEnable'] as bool;
      debugPrint('[MONITOR] $method → isEnable=$enabled');
      return enabled;
    }
    return writeOk;
  } catch (e) {
    debugPrint('[MONITOR] $method read failed: $e');
    return writeOk;
  }
}

/// 반지 펌웨어 자동 측정(심박·산소·HRV·스트레스)을 켜고 검증한다.
///
/// 펌웨어 스케줄은 **연결 끊김 대비 백업 축적** 담당 — 연결 중 5분 주기
/// 측정은 RingAutoMeasurementService(앱 주도)가 담당한다. 반환한
/// [RingMonitoringStatus] 는 write + read-back 검증 결과로, 깨진
/// 스트림은 오프라인 축적이 안 될 수 있으니 로그로 추적한다.
///
/// QC 링은 **HRV 스케줄 ON → 스트레스 산출** 파이프라인이다.
/// HRV 없이 writePressureSetting만 하면 set/get fail -1 이 자주 난다.
/// picnique_ring 참고: HR → SpO₂ → Pressure → **HRV** 순서.
Future<RingMonitoringStatus> enableRingAutoMonitoring({
  MethodChannel platform = _blePlatformChannel,
}) async {
  await BleCommandQueue.waitUntilManualIdle();
  // 수동 측정·묵주 터치 세션 중엔 설정 쓰기를 미룬다 — 세션과 인터리브되면
  // write fail 이 난다. 세션이 안 끝나면 이번 기회는 건너뛴다(재연결 때 재시도).
  if (!await RingSessionArbiter.instance.waitUntilBackground()) {
    debugPrint('[MONITOR] skipped — ring session busy');
    return RingMonitoringStatus.allBroken;
  }

  const hrInterval = RingMeasurementPolicy.ringAutoHeartIntervalMinutes;

  final hrOk = await _writeMonitoringWithRetry('writeHrSetting', {
    'isEnable': true,
    'interval': hrInterval,
  });
  if (Platform.isIOS) {
    await Future<void>.delayed(_monitoringWriteGap);
  }

  final spo2Ok = await _writeMonitoringWithRetry('writeSpo2Setting', {
    'isEnable': true,
  });
  if (Platform.isIOS) {
    await Future<void>.delayed(_monitoringWriteGap);
  }

  final stressOk = await _writeMonitoringWithRetry('writePressureSetting', {
    'isEnable': true,
  });
  if (Platform.isIOS) {
    await Future<void>.delayed(_monitoringWriteGap);
  }

  final hrvOk = await _writeMonitoringWithRetry('writeHrvSetting', {
    'isEnable': true,
  });

  // write 성공분은 read-back 으로 재검증, 실패분은 그대로 broken.
  final status = RingMonitoringStatus(
    hr: hrOk && await _readMonitoringEnabled('readHrSetting', hrOk),
    spo2: spo2Ok && await _readMonitoringEnabled('readSpo2Setting', spo2Ok),
    stress:
        stressOk && await _readMonitoringEnabled('readPressureSetting', stressOk),
    hrv: hrvOk && await _readMonitoringEnabled('readHrvSetting', hrvOk),
  );
  debugPrint('[MONITOR] schedule status: $status');
  return status;
}

/// 한 번에: 현재 설정 읽어서 print → 전부 ON 시도 → 결과 재확인 print
Future<void> printAndEnableAllSettings(MethodChannel platform) async {
  // 안전 변환 & 프린트 헬퍼
  T as<T>(dynamic v, T def) {
    if (v is T) return v;
    return def;
  }

  Map<String, dynamic>? bp;

  // 1) 현재 상태 읽기
  try {
    await _bleInvoke('readHrSetting');
  } catch (e) {
    debugPrint('[ERR] readHrSetting: $e');
  }
  try {
    await _bleInvoke('readSpo2Setting');
  } catch (e) {
    debugPrint('[ERR] readSpo2Setting: $e');
  }
  try {
    await _bleInvoke('readPressureSetting');
  } catch (e) {
    debugPrint('[ERR] readPressureSetting: $e');
  }
  try {
    await _bleInvoke('readHrvSetting');
  } catch (e) {
    debugPrint('[ERR] readHrvSetting: $e');
  }
  try {
    bp = Map<String, dynamic>.from(
      await _bleInvoke('readBpSetting'),
    );
  } catch (e) {
    debugPrint('[ERR] readBpSetting: $e');
  }

  // 2) 모두 ON 시도
  final hrInterval = RingMeasurementPolicy.ringAutoHeartIntervalMinutes;

  try {
    await _bleInvoke('writeHrSetting', {
      'isEnable': true,
      'interval': hrInterval,
    });
  } catch (e) {
    debugPrint('[ERR] writeHrSetting: $e');
  }

  try {
    await _bleInvoke('writeSpo2Setting', {
      'isEnable': true,
    });
  } catch (e) {
    debugPrint('[ERR] writeSpo2Setting: $e');
  }

  try {
    await _bleInvoke('writePressureSetting', {
      'isEnable': true,
    });
  } catch (e) {
    debugPrint('[ERR] writePressureSetting: $e');
  }

  try {
    await _bleInvoke('writeHrvSetting', {
      'isEnable': true,
    });
  } catch (e) {
    debugPrint('[ERR] writeHrvSetting: $e');
  }

  // BP: 기존 창구/배수 유지, 없으면 기본(09:00~21:00, multiple=60)
  final win = bp?['window'] as Map<dynamic, dynamic>?;
  final startHour = as<int>(win?['startHour'], 9);
  final startMinute = as<int>(win?['startMinute'], 0);
  final endHour = as<int>(win?['endHour'], 21);
  final endMinute = as<int>(win?['endMinute'], 0);
  final multiple = as<int>(bp?['multiple'], 60);

  try {
    await _bleInvoke('writeBpSetting', {
      'isEnable': true,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'multiple': multiple,
    });
  } catch (e) {
    debugPrint('[ERR] writeBpSetting: $e');
  }

  // 3) 결과 재확인 (읽고 print)
  try {
    await _bleInvoke('readHrSetting');
  } catch (_) {}
  try {
    await _bleInvoke('readSpo2Setting');
  } catch (_) {}
  try {
    await _bleInvoke('readPressureSetting');
  } catch (_) {}
  try {
    await _bleInvoke('readHrvSetting');
  } catch (_) {}
  try {
    bp = Map<String, dynamic>.from(
      await _bleInvoke('readBpSetting'),
    );
  } catch (_) {}
}

Future<void> printBattery(MethodChannel platform, Ring ringProvider) async {
  try {
    final battery = await _bleInvoke<dynamic>('getBatteryLevel')
        .timeout(const Duration(seconds: 10));
    if (battery is Map) {
      final level = battery['level'] ?? battery['battery'];
      final charging = battery['charging'] == true;
      if (level is num) {
        ringProvider.setBatteryAndCharging(level.toInt(), charging);
      }
    } else if (battery is int) {
      ringProvider.setBattery(battery);
    }
  } on TimeoutException {
    debugPrint('Battery level request timeout');
  } on PlatformException catch (e) {
    debugPrint('Battery level error: ${e.code} - ${e.message}');
  }
}

Future<void> printSetting(MethodChannel platform) async {
  try {
    final Map<dynamic, dynamic>? rsp = await _bleInvoke(
      "syncTimeAndGetCoreFeatures",
    );

    if (rsp == null) return;
  } on PlatformException catch (e) {
    debugPrint("Setting error: ${e.code} - ${e.message}");
  } catch (e) {
    debugPrint("Setting error: $e");
  }
}

Future<void> printManualHeartRate(
  MethodChannel platform,
  Ring ringProvider,
) async {
  try {
    final Map<dynamic, dynamic>? resp = await _bleInvoke("syncManualHeartRate")
        .timeout(const Duration(seconds: 30)); // 15초 타임아웃

    if (resp == null) return;

    int asInt(dynamic v, {int fallback = 0}) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? "") ?? fallback;
    }

    asInt(resp["hr"], fallback: -1);
    asInt(resp["sbp"], fallback: -1);
    asInt(resp["dbp"], fallback: -1);
    asInt(resp["rri"], fallback: -1);
    asInt(resp["type"], fallback: -1);
    asInt(resp["errCode"], fallback: -1);

    // 필요시 상태 업데이트
    // ringProvider.setHeartRate(hr);
    // ringProvider.setBloodPressure(sbp, dbp);
    // ringProvider.setRri(rri);
  } on TimeoutException {
    debugPrint("HR manual request timeout");
  } on PlatformException catch (e) {
    debugPrint("HR manual error: ${e.code} - ${e.message}");
  } catch (e) {
    debugPrint("HR manual unexpected error: $e");
  }
}

Future<void> printHeartRate(
  MethodChannel platform,
  Ring ringProvider, {
  bool includeZeros = false,
}) async {
  try {
    // nowTime = (UTC초 + 타임존초)
    final int nowUtcSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int tzSec = DateTime.now().timeZoneOffset.inSeconds;
    final int nowTimeLocalSec = nowUtcSec + tzSec;

    final Map<dynamic, dynamic>? resp = await _bleInvoke<Map<dynamic, dynamic>>(
      "syncHeartRate",
      <String, dynamic>{
        "nowTime": nowTimeLocalSec,
      },
    ).timeout(const Duration(seconds: 15));

    if (resp == null) return;

    final int baseUtcSec = (resp["utcTime"] ?? resp["mUtcTime"] ?? 0) as int;
    final List<int> hrArr = ((resp["heartRateArray"] ?? const <int>[]) as List)
        .cast<int>();

    if (baseUtcSec <= 0 || hrArr.isEmpty) return;

    // 필요 시 provider에 반영
    // ringProvider.setHeartRateTimeline(...);
  } on TimeoutException {
    debugPrint("HR auto request timeout");
  } on PlatformException catch (e) {
    debugPrint("HR auto error: ${e.code} - ${e.message}");
  } catch (e) {
    debugPrint("HR auto unexpected error: $e");
  }
}

Future<void> printSleepDetail(
  MethodChannel platform,
  Ring ringProvider,
  int dayOffset,
) async {
  int asInt(dynamic v, {int def = 0}) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? def;
    return def;
  }

  try {
    // Android 측 syncSleepNew(offset, result)와 맞춰 호출
    final rsp = await _bleInvoke<Map<dynamic, dynamic>>(
      "syncSleepNew",
      <String, dynamic>{"offset": dayOffset},
    );

    if (rsp == null) return;

    final st = asInt(rsp['st']); // 시작 epoch-sec (UTC 기준)
    final List<dynamic> rawList = (rsp['list'] as List?) ?? const [];

    // 세그먼트 재구성: st부터 d만큼 누적
    int cursor = st;
    final segments = <Map<String, dynamic>>[];

    for (final e in rawList) {
      final dSec = asInt((e as Map?)?['d']);
      final t = asInt((e)?['t']);
      if (dSec <= 0) continue;

      final start = DateTime.fromMillisecondsSinceEpoch(
        cursor * 1000,
        isUtc: true,
      ).toLocal();
      final end = DateTime.fromMillisecondsSinceEpoch(
        (cursor + dSec) * 1000,
        isUtc: true,
      ).toLocal();

      segments.add({'start': start, 'end': end, 'durSec': dSec, 'type': t});

      cursor += dSec;
    }

    // 원하면 Provider 갱신 (앱 구조에 맞게 구현)
    // ringProvider.setSleepProto(st, et, segments, totals...);
  } on PlatformException catch (e) {
    debugPrint("SleepNew error: ${e.code} - ${e.message}");
  } catch (e) {
    debugPrint("SleepNew unexpected error: $e");
  }
}

Future<void> syncAutoTemperatureAndPrint(
  MethodChannel platform, {
  int days = 2,
}) async {
  try {
    // 네이티브 호출
    final raw = await _bleInvoke<dynamic>(
      'syncAutoTemperature',
      <String, dynamic>{'days': days},
    );

    if (raw == null) return;

    // Map<String, dynamic> 으로 캐스팅
    final map = Map<String, dynamic>.from(raw as Map);

    final tempsRaw = map['temperatures'];
    if (tempsRaw == null) return;

    final List<dynamic> tempListDynamic = tempsRaw as List<dynamic>;
    if (tempListDynamic.isEmpty) return;

    // 성공 시 별도 출력 없음
  } catch (e, s) {
    debugPrint('[Temperature] syncAutoTemperatureAndPrint error: $e\n$s');
  }
}

Future<void> enableRing(MethodChannel platform, Ring ringProvider) async {
  try {
    final Map<dynamic, dynamic>? rsp = await _bleInvoke("readHrSetting")
        .timeout(const Duration(seconds: 15));
    if (rsp == null) return;
    if (rsp["isEnable"] == false) {
      final Map<dynamic, dynamic>? rsp2 = await _bleInvoke<Map<dynamic, dynamic>>(
        "writeHrSettings",
        <String, dynamic>{"isEnabled": true, "interval": 60},
      );
      if (rsp2 == null) return;
    }
  } on TimeoutException {
    debugPrint("Setting timeout");
  } on PlatformException catch (e) {
    debugPrint("Enable error: ${e.code} - ${e.message}");
  } catch (e) {
    debugPrint("Enable unexpected error: $e");
  }
}

/// 입력 세그먼트 형식:
///   - from syncSleepDisplay: [{ "sleepStart": <epochSec>, "sleepEnd": <epochSec>, "type": 1|2|3 }, ...]
///   - 또는 커스텀: [{ "t_start": <minute or second>, "t_end": <minute or second>, "type": 1|2|3 }, ...]
///
/// 반환: 지표/점수/분류가 모두 담긴 Map.
Map<String, dynamic> computeSleepScoreFromList(
  List<dynamic> rawList, {
  bool inputIsSeconds = true, // true: 초(에폭초 등) → 분으로 변환
  bool keysAreEpoch =
      true, // true: sleepStart/sleepEnd 키, false: t_start/t_end 키
}) {
  // --- 0) 유틸 ---
  double clamp(double x, double lo, double hi) =>
      x < lo ? lo : (x > hi ? hi : x);
  double dur(double a, double b) => math.max(0.0, b - a);

  // --- 1) 입력 정렬 + 전처리(분 단위) ---
  // 원본 키 호환: sleepStart/sleepEnd 또는 t_start/t_end
  final segs = rawList.map<Map<String, num>>((e) {
    final startRaw = (keysAreEpoch ? e['sleepStart'] : e['t_start']) ?? 0;
    final endRaw = (keysAreEpoch ? e['sleepEnd'] : e['t_end']) ?? 0;
    final type = (e['type'] ?? 0) as num;
    final startMin =
        (startRaw is num ? startRaw.toDouble() : 0.0) /
        (inputIsSeconds ? 60.0 : 1.0);
    final endMin =
        (endRaw is num ? endRaw.toDouble() : 0.0) /
        (inputIsSeconds ? 60.0 : 1.0);
    return {
      'type': type.toInt(),
      't_start': startMin,
      't_end': math.max(startMin, endMin), // 음수/역전 방지
    };
  }).toList();

  if (segs.isEmpty) {
    return {'status': 'empty', 'message': '세그먼트가 비어 있습니다.'};
  }

  // 시작 시각 오름차순
  segs.sort((a, b) => a['t_start']!.compareTo(b['t_start']!));

  // 연속된 동일 타입 병합(겹침/연속 경계 포함)
  final merged = <Map<String, double>>[];
  for (final s in segs) {
    final t = (s['type'] as int);
    final st = (s['t_start'] as num).toDouble();
    final en = (s['t_end'] as num).toDouble();
    if (merged.isEmpty) {
      merged.add({'type': t.toDouble(), 't_start': st, 't_end': en});
    } else {
      final last = merged.last;
      final lt = last['type']!.toInt();
      final le = last['t_end']!;
      if (t == lt && st <= le) {
        // 같은 타입이며 겹치거나 붙어있으면 병합
        last['t_end'] = math.max(le, en);
      } else {
        merged.add({'type': t.toDouble(), 't_start': st, 't_end': en});
      }
    }
  }

  // --- 2) 핵심 지표 ---
  final firstStart = merged.first['t_start']!;
  final lastEnd = merged.last['t_end']!;
  final tibMin = dur(firstStart, lastEnd);

  // 수면(1,2) 첫 구간
  final idxSleepOnset = merged.indexWhere((m) {
    final t = m['type']!.toInt();
    return t == 1 || t == 2;
  });
  if (idxSleepOnset < 0 || tibMin <= 0) {
    return {
      'status': 'insufficient',
      'message': '수면 구간이 없거나 TIB가 0입니다.',
      'TIB_min': tibMin,
      'segments_merged': merged,
    };
  }

  final tSleepOnset = merged[idxSleepOnset]['t_start']!;
  final tFinalWake = lastEnd;

  // 단계별 합
  double dDeep = 0, dLight = 0, tstMin = 0;
  double wasoMin = 0;
  int nAwake = 0;

  for (int i = 0; i < merged.length; i++) {
    final m = merged[i];
    final t = m['type']!.toInt();
    final st = m['t_start']!;
    final en = m['t_end']!;
    final d = dur(st, en);

    if (t == 1) {
      dDeep += d;
      tstMin += d;
    } else if (t == 2) {
      dLight += d;
      tstMin += d;
    } else if (t == 3) {
      // WASO: [onset, final_wake] 안의 깸 구간
      final interSt = math.max(st, tSleepOnset);
      final interEn = math.min(en, tFinalWake);
      wasoMin += dur(interSt, interEn);
    }

    // 각성 전이 횟수: (1/2) → 3, onset 이후
    if (i > 0) {
      final prev = merged[i - 1];
      final pt = prev['type']!.toInt();
      final currStart = st;
      if ((pt == 1 || pt == 2) &&
          t == 3 &&
          currStart >= tSleepOnset &&
          currStart <= tFinalWake) {
        nAwake += 1;
      }
    }
  }

  final solMin = math.max(0.0, tSleepOnset - firstStart);
  final se = (tibMin > 0) ? (tstMin / tibMin) : 0.0;
  final dr = (tstMin > 0) ? (dDeep / tstMin) : double.nan;
  final arPerH = (tstMin > 0)
      ? (nAwake / (tstMin / 60.0))
      : double.infinity;

  // TST=0이면 점수 계산 중단/결측 처리
  if (tstMin <= 0) {
    return {
      'status': 'insufficient',
      'message': 'TST가 0입니다(수면 구간 미검출).',
      'TIB_min': tibMin,
      'TST_min': tstMin,
      'SE': se,
      'segments_merged': merged,
    };
  }

  // --- 3) 서브스코어 ---
  // (A) 수면시간 점수
  double sDur;
  final tHours = tstMin / 60.0;
  if (tHours <= 4.5 || tHours >= 11.0) {
    sDur = 0;
  } else if (tHours < 6.0) {
    sDur = 50 * (tHours - 4.5) / 1.5;
  } else if (tHours < 7.0) {
    sDur = 50 + 50 * (tHours - 6.0) / 1.0;
  } else if (tHours <= 9.0) {
    sDur = 100;
  } else if (tHours <= 10.0) {
    sDur = 50 + 50 * (10.0 - tHours) / 1.0;
  } else {
    sDur = 50 * (11.0 - tHours) / 1.0;
  }
  sDur = clamp(sDur, 0, 100);

  // (B) 효율 점수
  double sEff = ((se - 0.75) / (0.95 - 0.75)) * 100.0;
  sEff = clamp(sEff, 0, 100);

  // (C) 연속성·각성
  final sWaso = 100.0 * math.exp(-wasoMin / 45.0);
  final sSol = 100.0 * math.exp(-solMin / 20.0);
  final sCont = 0.6 * sWaso + 0.4 * sSol;
  final sAr = 100.0 * math.exp(-arPerH / 1.5);
  final sFrag = 0.5 * sCont + 0.5 * sAr;

  // (D) 깊은수면 비율
  double sDeep;
  if (dr.isNaN) {
    sDeep = 0; // 결측 처리
  } else if (dr <= 0.05 || dr >= 0.40) {
    sDeep = 0;
  } else if (dr < 0.13) {
    sDeep = 100 * (dr - 0.05) / 0.08;
  } else if (dr <= 0.23) {
    sDeep = 100;
  } else {
    sDeep = 100 * (0.40 - dr) / 0.17;
  }
  sDeep = clamp(sDeep, 0, 100);

  // --- 4) 총점 ---
  final sTotal = 0.35 * sDur + 0.25 * sEff + 0.25 * sFrag + 0.15 * sDeep;

  // --- 5) 분류 ---
  final classificationHour = () {
    if (tHours < 6.5) return "수면 부족 상태";
    if (tHours > 9.5) return "수면 과다 상태";
    return "수면 시간 평균";
  }();

  final classificationScore = () {
    if (sTotal >= 80) return "이상적인 수면의 질";
    if (sTotal >= 50) return "평균적인 수면 상태";
    if (sTotal >= 30) return "질이 좋지 않은 수면 상태";
    return "매우 불규칙적인 수면 상태";
  }();

  return {
    'status': 'ok',
    'segments_merged': merged, // 병합 결과(분 단위)
    'first_start_min': firstStart,
    'last_end_min': lastEnd,
    't_sleep_onset_min': tSleepOnset,
    't_final_wake_min': tFinalWake,
    // 핵심 지표
    'TIB_min': tibMin,
    'TST_min': tstMin,
    'SE': se,
    'SOL_min': solMin,
    'WASO_min': wasoMin,
    'D_deep_min': dDeep,
    'D_light_min': dLight,
    'DR': dr,
    'N_awake': nAwake,
    'AR_per_h': arPerH,
    // 서브스코어
    'S_dur': sDur,
    'S_eff': sEff,
    'S_frag': sFrag,
    'S_deep': sDeep,
    // 총점/분류
    'S_total': sTotal,
    'classification_hour': classificationHour,
    'classification_score': classificationScore,
  };
}

/// syncSleepDisplay의 전체 응답(Map rsp)에서 바로 계산하고 싶을 때 사용.
/// rsp['list'](epoch seconds)를 읽어 computeSleepScoreFromList로 위임.
Map<String, dynamic> computeSleepScoreFromRsp(Map rsp) {
  final rawList = (rsp['list'] as List?) ?? const [];
  return computeSleepScoreFromList(
    rawList,
    inputIsSeconds: true, // rsp는 에폭 초이므로 true
    keysAreEpoch: true, // sleepStart/sleepEnd 키 사용
  );
}

Future<Map<String, dynamic>> computeSleepScoreFromDb({
  int dayOffset = 0,
}) async {
  final db = DbManager.I.appDB;
  final t = db.sleepDetails;

  // ✅ "오늘밤 = 어제18~오늘18" 규칙
  (DateTime, DateTime) nightWindowShifted(int offset) {
    final now = DateTime.now(); // 로컬
    final today0 = DateTime(now.year, now.month, now.day);
    final endAnchor = today0.subtract(Duration(days: offset));
    final end = DateTime(
      endAnchor.year,
      endAnchor.month,
      endAnchor.day,
      18,
      0,
      0,
    );
    final start = end.subtract(const Duration(days: 1));
    return (start, end);
  }

  // DB 타입 → 스코어 입력 타입 매핑
  // DB: 2=light, 3=deep, 4=rem, 5=awake
  // Score input: 1=deep, 2=light(REM 포함), 3=awake
  int mapType(int dbType) {
    switch (dbType) {
      case 3:
        return 1; // deep
      case 2:
      case 4:
        return 2; // light + rem
      case 5:
        return 3; // awake
      default:
        return 3;
    }
  }

  final (winS, winE) = nightWindowShifted(dayOffset);

  // 윈도우와 겹치는 구간 조회 (start < winE && end > winS)
  final rows =
      await (db.select(t)
            ..where(
              (r) =>
                  r.end.isBiggerThanValue(winS) &
                  r.start.isSmallerThanValue(winE),
            )
            ..orderBy([
              (r) => drift.OrderingTerm(
                expression: r.start,
                mode: drift.OrderingMode.asc,
              ),
            ]))
          .get();

  if (rows.isEmpty) {
    return {'status': 'empty', 'message': '해당 밤 윈도우에 수면 데이터가 없습니다.'};
  }

  // 윈도우 경계로 클리핑 후, 기존 스코어러 입력 포맷(에폭초)으로 변환
  final rawList = <Map<String, dynamic>>[];
  for (final r in rows) {
    final s = r.start.isBefore(winS) ? winS : r.start;
    final e = r.end.isAfter(winE) ? winE : r.end;
    if (!e.isAfter(s)) continue;
    rawList.add({
      'type': mapType(r.type),
      'sleepStart': s.millisecondsSinceEpoch ~/ 1000, // epoch seconds
      'sleepEnd': e.millisecondsSinceEpoch ~/ 1000,
    });
  }

  if (rawList.isEmpty) {
    return {'status': 'empty', 'message': '윈도우와 겹치는 유효 구간이 없습니다.'};
  }

  // 기존 점수 계산기 재사용
  return computeSleepScoreFromList(
    rawList,
    inputIsSeconds: true,
    keysAreEpoch: true,
  );
}

Future<void> syncRecent3DaysHeartToDb(
  MethodChannel platform, {
  bool includeZeros = false,
}) async {
  return;
}

/// 특정 날짜(로컬 자정 기준)의 5분 간격 심박 배열을 기기에서 가져옵니다.
/// 성공 시 길이<=288의 int 리스트, 실패/없음이면 null.
/// (기기 SDK 특성상 기준 시간을 "그 날 정오"로 넣는 게 안정적인 경우가 많음)
// ignore: unused_element
Future<List<int>?> _fetchHeartArrayForDate(
  MethodChannel platform,
  DateTime dayStartLocal,
) async {
  try {
    final localMidday = DateTime(
      dayStartLocal.year,
      dayStartLocal.month,
      dayStartLocal.day,
      12, // 정오
    );

    // nowTime = (UTC초 + 타임존초)
    final int middayUtcSec = localMidday.millisecondsSinceEpoch ~/ 1000;
    final int nowTimeLocalSec = middayUtcSec;

    final Map<dynamic, dynamic>? resp = await _bleInvoke<Map<dynamic, dynamic>>(
      "syncHeartRate",
      <String, dynamic>{
        "nowTime": nowTimeLocalSec,
      },
    ).timeout(const Duration(seconds: 15));

    if (resp == null) return null;

    final int baseUtcRaw = (resp["utcTime"] ?? resp["mUtcTime"] ?? 0) as int;
    final List<int> hrArr = ((resp["heartRateArray"] ?? const <int>[]) as List)
        .cast<int>();

    if (baseUtcRaw <= 0 || hrArr.isEmpty) return null;
    return hrArr;
  } on TimeoutException {
    debugPrint("[HR_SYNC] timeout for $dayStartLocal");
    return null;
  } on PlatformException catch (_) {
    debugPrint("[HR_SYNC] platform error while syncing HR for $dayStartLocal");
    return null;
  } catch (_) {
    debugPrint("[HR_SYNC] unexpected error while syncing HR for $dayStartLocal");
    return null;
  }
}

Future<void> syncAndSaveSportDetails(
  MethodChannel platform,
  AppDatabase db, {
  required int dayOffset,
}) async {
  // Kotlin: syncSportDetail(dayOffset, result)
  final resp = await _bleInvoke<Map>('syncSportDetail', {
    'dayOffset': dayOffset,
  });

  final List<dynamic> raw = (resp?['details'] as List?) ?? const [];
  final details = raw
      .cast<Map>()
      .map((m) => m.map((k, v) => MapEntry('$k', v)))
      .toList();

  await db.saveSportDetailsFromNative(details.cast<Map<String, dynamic>>());
}

/// 반지에서 오늘 활동 요약을 직접 조회한다. (DB 동기화 없이 즉시 반영용)
Future<Map<String, int>?> fetchTodaySportFromRing(
  MethodChannel platform, {
  void Function(Object error)? onError,
}) async {
  try {
    final res = await _bleInvoke<dynamic>('syncTodaySport');
    if (res is! Map) return null;

    int asInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return {
      'totalSteps': asInt(res['totalSteps']),
      'runningSteps': asInt(res['runningSteps']),
      'calorie': asInt(res['calorie']),
      'walkDistance': asInt(res['walkDistance']),
      'sportDuration': asInt(res['sportDuration']),
    };
  } catch (e) {
    onError?.call(e);
    return null;
  }
}

// 수동 측정 저장은 RingMeasurementService → RingMeasurementStore 단일 경로.
// (과거 persistManualMeasurement 는 화면별 이중 저장을 유발해 제거)

Future<void> syncRecent7DaysStressToDb(
  MethodChannel platform, {
  bool includeZeros = false,
}) async {
  return;
}

Future<void> syncRecent3DaysSportDetailsToDb(
  MethodChannel platform,
) async {
  return;
}

Future<void> syncRecent3DaysOxygenToDb(
  // ← 이름 유지 (요구사항대로 전체 동기화로 동작)
  MethodChannel platform, {
  bool includeZeros = false,
}) async {
  return;
}

Future<void> syncSleepDetailsLast3Days({
  required MethodChannel platform,
}) async {
  return;
}

/// 내부 공용: 주어진 offsets(예: [0,1,2])에 대해 SleepDetails를 갱신
/// 내부 공용: 주어진 offsets(예: [0,1,2])에 대해 SleepDetails를 갱신 + 중간 로그 출력
// ignore: unused_element
Future<void> _upsertSleepDetailsForOffsets({
  required AppDatabase db,
  required MethodChannel platform,
  required List<int> offsets,
}) async {
  int asInt(dynamic v, {int def = 0}) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? def;
    return def;
  }

  DateTime day0(DateTime d) => DateTime(d.year, d.month, d.day);

  final List<SleepDetailsCompanion> inserts = [];
  final Set<DateTime> daysToClear = {};
  final Set<String> seenWindows = {}; // "${st}-${et}"

  for (final offset in offsets) {
    Map<dynamic, dynamic>? rsp;
    try {
      rsp = await _bleInvoke<Map<dynamic, dynamic>>(
        "syncSleepNew",
        <String, dynamic>{"offset": offset},
      );
    } on PlatformException catch (e) {
      debugPrint("[SLEEP_SYNC] platform error(offset=$offset): ${e.code} - ${e.message}");
      continue;
    } catch (e) {
      debugPrint("[SLEEP_SYNC] unexpected invoke error(offset=$offset): $e");
      continue;
    }

    if (rsp == null) continue;

    final st = asInt(rsp['st']); // epoch-sec (UTC)
    final et = asInt(rsp['et']); // epoch-sec (UTC)
    final List<dynamic> rawList = (rsp['list'] as List?) ?? const [];

    if (st <= 0 || et <= 0 || rawList.isEmpty) continue;

    final winKey = "$st-$et";
    if (!seenWindows.add(winKey)) continue;

    int cursor = st;
    for (final e in rawList) {
      final map = e as Map?;
      final dSec = asInt(map?['d']);
      final t = asInt(map?['t']);
      if (dSec <= 0) continue;
      if (!(t == 2 || t == 3 || t == 4 || t == 5)) {
        cursor += dSec;
        continue;
      }

      final segStartUtcMs = cursor * 1000;
      final segEndUtcMs = (cursor + dSec) * 1000;
      cursor += dSec;

      final segStart = DateTime.fromMillisecondsSinceEpoch(
        segStartUtcMs,
        isUtc: true,
      ).toLocal();
      final segEnd = DateTime.fromMillisecondsSinceEpoch(
        segEndUtcMs,
        isUtc: true,
      ).toLocal();
      if (!segEnd.isAfter(segStart)) continue;

      // 자정 경계 분할
      DateTime cur = segStart;
      while (cur.isBefore(segEnd)) {
        final dayKey = day0(cur);
        final nextDay = dayKey.add(const Duration(days: 1));
        final pieceEnd = segEnd.isBefore(nextDay) ? segEnd : nextDay;

        daysToClear.add(dayKey);
        inserts.add(
          SleepDetailsCompanion.insert(
            date: dayKey,
            start: cur,
            end: pieceEnd,
            type: t, // 2=Light, 3=Deep, 4=Rem, 5=Awake
          ),
        );

        cur = pieceEnd;
      }
    }
  }

  await db.transaction(() async {
    for (final day in daysToClear) {
      final dayStart = day0(day);
      final nextDay = dayStart.add(const Duration(days: 1));

      await (db.delete(
        db.sleepDetails,
      )..where((t) => t.date.isBetweenValues(dayStart, nextDay))).go();
    }

    if (inserts.isNotEmpty) {
      try {
        await db
            .batch(
              (b) => b.insertAll(
                db.sleepDetails,
                inserts,
                mode: drift.InsertMode.insertOrIgnore,
              ),
            )
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint("[SLEEP_SYNC] batch insert timeout/fail: $e");
      }
      await db.batch(
        (b) => b.insertAll(
          db.sleepDetails,
          inserts,
          mode: drift.InsertMode.insertOrIgnore,
        ),
      );
    }
  });
}

/// 네이티브 브릿지 래퍼(이제 DB 래퍼)
class BleRepository {
  // ────────────────────────────────────────────────────────────────────────────
  // 내부 유틸
  static (DateTime start, DateTime end) _sleepWindowForOffset(int dayOffset) {
    // 로컬 기준: 기준일 18:00 ~ 다음날 18:00 (하룻밤 창)
    final now = DateTime.now();
    final baseDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: dayOffset));
    final end = DateTime(baseDay.year, baseDay.month, baseDay.day, 18, 0, 0);
    final start = end.subtract(const Duration(days: 1));
    return (start, end);
  }

  static int _overlapMillis(
    DateTime s1,
    DateTime e1,
    DateTime s2,
    DateTime e2,
  ) {
    final s = s1.isAfter(s2) ? s1 : s2;
    final e = e1.isBefore(e2) ? e1 : e2;
    if (!e.isAfter(s)) return 0;
    return e.difference(s).inMilliseconds;
  }

  // ────────────────────────────────────────────────────────────────────────────
  /// 스트레스(=pressure) 최신 값
  static Future<int?> getLatestStress() async {
    final db = DbManager.I.appDB;
    final t = db.stressDetails;

    // 우선 0보다 큰 최신값, 없으면 가장 최신값
    final nonZero =
        await (db.select(t)
              ..where((r) => r.stress.isBiggerThanValue(0))
              ..orderBy([
                (r) => drift.OrderingTerm(
                  expression: r.date,
                  mode: drift.OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (nonZero != null) return nonZero.stress;

    final latest =
        await (db.select(t)
              ..orderBy([
                (r) => drift.OrderingTerm(
                  expression: r.date,
                  mode: drift.OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    return latest?.stress;
  }

  // ────────────────────────────────────────────────────────────────────────────
  /// 수면 합계(분)를 시:분으로 변환하여 반환
  static Future<(int? hours, int? minutes)> getTodaySleepHM({
    int dayOffset = 0,
  }) async {
    final db = DbManager.I.appDB;
    final t = db.sleepDetails;

    final (winS, winE) = _sleepWindowForOffset(dayOffset);

    // 타입 2(light), 3(deep), 4(rem)만 합산 (5=awake 제외)
    final rows =
        await (db.select(t)..where(
              (r) =>
                  r.type.isIn(const [2, 3, 4]) &
                  // [winS, winE)와 구간이 겹치는 레코드
                  r.end.isBiggerThanValue(winS) &
                  r.start.isSmallerThanValue(winE),
            ))
            .get();

    int totalMs = 0;
    for (final r in rows) {
      totalMs += _overlapMillis(r.start, r.end, winS, winE);
    }
    if (totalMs <= 0) return (0, 0);

    final totalMin = totalMs ~/ 60000;
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    return (h, m);
  }

  // ────────────────────────────────────────────────────────────────────────────
  /// 심박수: 최신 유효값(>0), 없으면 최신값
  static Future<int?> getLatestHeartRate() async {
    final db = DbManager.I.appDB;
    final t = db.heartDetails;

    final nonZero =
        await (db.select(t)
              ..where((r) => r.bpm.isBiggerThanValue(0))
              ..orderBy([
                (r) => drift.OrderingTerm(
                  expression: r.date,
                  mode: drift.OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (nonZero != null) return nonZero.bpm;

    final latest =
        await (db.select(t)
              ..orderBy([
                (r) => drift.OrderingTerm(
                  expression: r.date,
                  mode: drift.OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    return latest?.bpm;
  }

  // ────────────────────────────────────────────────────────────────────────────
  /// 혈중산소: 최신 유효값(>0), 없으면 최신값
  static Future<int?> getLatestSpO2() async {
    final db = DbManager.I.appDB;
    final t = db.bloodOxygenDetails;

    final nonZero =
        await (db.select(t)
              ..where((r) => r.spo2.isBiggerThanValue(0))
              ..orderBy([
                (r) => drift.OrderingTerm(
                  expression: r.date,
                  mode: drift.OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (nonZero != null) return nonZero.spo2;

    final latest =
        await (db.select(t)
              ..orderBy([
                (r) => drift.OrderingTerm(
                  expression: r.date,
                  mode: drift.OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    return latest?.spo2;
  }

  // ────────────────────────────────────────────────────────────────────────────
  /// 오늘 활동 요약(걸음/칼로리 등)
  static Future<Map<String, int>?> getTodaySportFromDetail({
    int dayOffset = 0,
  }) async {
    final db = DbManager.I.appDB;
    final t = db.sportDetails;

    final now = DateTime.now();
    final dayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: dayOffset));
    final dayEnd = dayStart.add(const Duration(days: 1));

    final rows =
        await (db.select(t)..where(
              (r) =>
                  r.date.isBiggerOrEqualValue(dayStart) &
                  r.date.isSmallerThanValue(dayEnd),
            ))
            .get();

    if (rows.isEmpty) {
      return {
        'totalSteps': 0,
        'runningSteps': 0,
        'calorie': 0,
        'walkDistance': 0,
        'sportDuration': 0,
      };
    }

    int totalSteps = 0;
    int runningSteps = 0;
    int calorie = 0;
    int walkDistance = 0;

    final activeIndexes = <int>{};
    for (final r in rows) {
      final step = (r.walkSteps + r.runSteps);
      totalSteps += step;
      runningSteps += r.runSteps;
      calorie += r.calorie;
      walkDistance += r.distance;
      if (step > 0) activeIndexes.add(r.timeIndex);
    }

    // 슬롯 96(15분 단위) 가정. DB가 드문드문일 수 있으므로 전체 슬롯 수는 고정 가정이 안전.
    const slotCount = 96;
    const windowSeconds = 86400 ~/ slotCount; // 900초
    final sportDuration = activeIndexes.length * windowSeconds;

    return {
      'totalSteps': totalSteps,
      'runningSteps': runningSteps,
      'calorie': calorie,
      'walkDistance': walkDistance,
      'sportDuration': sportDuration,
    };
  }
}

// 로그인 관련 로직 임시 비활성화
// Future<Map<String, dynamic>?> login(String userId, String password) async {
//   var baseUrl = "https://www.taeanaihealth.or.kr";
//   final url = Uri.parse("$baseUrl/users/login");
//
//   final response = await http.post(
//     url,
//     headers: {"Content-Type": "application/json"},
//     body: jsonEncode({"user_id": userId, "password": password}),
//   );
//
//   if (response.statusCode == 200 || response.statusCode == 201) {
//     return jsonDecode(response.body);
//   } else {
//     debugPrint("login failed: status ${response.statusCode}");
//     return null;
//   }
// }

Future<void> syncAllRecentData(MethodChannel platform) async {
  return;
}
