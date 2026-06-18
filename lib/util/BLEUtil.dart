// ignore_for_file: file_names

import 'dart:async';
import 'dart:math' as math;
import 'dart:math' show min;

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

import '../db/app_db.dart';

Future<bool> ensureBluetoothOn(
  BuildContext context, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  // 1) 현재 상태
  final initial = await FlutterBluePlus.adapterState.first;
  if (initial == BluetoothAdapterState.on) return true;

  if (Platform.isAndroid) {
    // 2-A) Android: 켜기 요청 + 대기
    try {
      await FlutterBluePlus.turnOn(); // 시스템 다이얼로그 (권한/기기 따라 예외 가능)
    } catch (_) {}
    try {
      await FlutterBluePlus.adapterState
          .firstWhere((s) => s == BluetoothAdapterState.on)
          .timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    }
  } else if (Platform.isIOS) {
    if (!context.mounted) return false;
    // 2-B) iOS: 사용자가 직접 켜야 함 (프로그래매틱 토글 불가)
    final open =
        await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('블루투스가 꺼져 있습니다'),
            content: const Text('설정에서 블루투스를 켠 뒤 다시 시도해 주세요.'),
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

    if (open) {
      // 앱 설정 화면 열기 (Bluetooth 화면으로 직접 이동은 불가/비권장)
      try {
        await launchUrl(Uri.parse('app-settings:'));
      } catch (_) {}

      // 사용자가 설정에서 블루투스를 켜고 돌아올 때까지 대기
      try {
        await FlutterBluePlus.adapterState
            .firstWhere((s) => s == BluetoothAdapterState.on)
            .timeout(timeout);
        return true;
      } on TimeoutException {
        return false;
      }
    }
    return false;
  } else {
    // 그 외 플랫폼은 일단 통과
    return true;
  }
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
    await platform.invokeMethod('readHrSetting');
  } catch (e) {
    debugPrint('[ERR] readHrSetting: $e');
  }
  try {
    await platform.invokeMethod('readSpo2Setting');
  } catch (e) {
    debugPrint('[ERR] readSpo2Setting: $e');
  }
  try {
    await platform.invokeMethod('readPressureSetting');
  } catch (e) {
    debugPrint('[ERR] readPressureSetting: $e');
  }
  try {
    await platform.invokeMethod('readHrvSetting');
  } catch (e) {
    debugPrint('[ERR] readHrvSetting: $e');
  }
  try {
    bp = Map<String, dynamic>.from(
      await platform.invokeMethod('readBpSetting'),
    );
  } catch (e) {
    debugPrint('[ERR] readBpSetting: $e');
  }

  // 2) 모두 ON 시도
  final hrInterval = 5;

  try {
    await platform.invokeMethod('writeHrSetting', {
      'isEnable': true,
      'interval': hrInterval,
    });
  } catch (e) {
    debugPrint('[ERR] writeHrSetting: $e');
  }

  try {
    await platform.invokeMethod('writeSpo2Setting', {
      'isEnable': true,
    });
  } catch (e) {
    debugPrint('[ERR] writeSpo2Setting: $e');
  }

  try {
    await platform.invokeMethod('writePressureSetting', {
      'isEnable': true,
    });
  } catch (e) {
    debugPrint('[ERR] writePressureSetting: $e');
  }

  try {
    await platform.invokeMethod('writeHrvSetting', {
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
    await platform.invokeMethod('writeBpSetting', {
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
    await platform.invokeMethod('readHrSetting');
  } catch (_) {}
  try {
    await platform.invokeMethod('readSpo2Setting');
  } catch (_) {}
  try {
    await platform.invokeMethod('readPressureSetting');
  } catch (_) {}
  try {
    await platform.invokeMethod('readHrvSetting');
  } catch (_) {}
  try {
    bp = Map<String, dynamic>.from(
      await platform.invokeMethod('readBpSetting'),
    );
  } catch (_) {}
}

Future<void> printBattery(MethodChannel platform, Ring ringProvider) async {
  try {
    var battery = await platform
        .invokeMethod("getBatteryLevel")
        .timeout(Duration(seconds: 10)); // 10초 타임아웃
    ringProvider.setBattery(battery);
  } on TimeoutException {
    debugPrint("Battery level request timeout");
  } on PlatformException catch (e) {
    debugPrint("Battery level error: ${e.code} - ${e.message}");
  }
}

Future<void> printSetting(MethodChannel platform) async {
  try {
    final Map<dynamic, dynamic>? rsp = await platform.invokeMethod(
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
    final Map<dynamic, dynamic>? resp = await platform
        .invokeMethod("syncManualHeartRate")
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

    final Map<dynamic, dynamic>? resp = await platform
        .invokeMethod<Map<dynamic, dynamic>>("syncHeartRate", <String, dynamic>{
          "nowTime": nowTimeLocalSec,
        })
        .timeout(const Duration(seconds: 15));

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
    final rsp = await platform.invokeMethod<Map<dynamic, dynamic>>(
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
    final raw = await platform.invokeMethod<dynamic>(
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
    final Map<dynamic, dynamic>? rsp = await platform
        .invokeMethod("readHrSetting")
        .timeout(const Duration(seconds: 15));
    if (rsp == null) return;
    if (rsp["isEnable"] == false) {
      final Map<dynamic, dynamic>? rsp2 = await platform
          .invokeMethod<Map<dynamic, dynamic>>(
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
  final heartDb = DbManager.I.heartDB;

  for (int offset = 0; offset < 3; offset++) {
    final now = DateTime.now();
    final dayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: offset)); // 로컬 자정
    final dayEnd = dayStart.add(const Duration(days: 1));
    final mustRefresh = (offset >= 0); // 오늘은 무조건 갱신

    // 존재 여부 확인(어제/그저께만). 효율 위해 limit(1).
    if (!mustRefresh) {
      final exists =
          await (heartDb.select(heartDb.heartDetails)
                ..where((t) => t.date.isBetweenValues(dayStart, dayEnd))
                ..limit(1))
              .get();
      if (exists.isNotEmpty) {
        // 이미 있으면 스킵
        continue;
      }
    }

    // 기기에서 대상 날짜의 5분 간격 HR 배열(최대 288개) 요청
    final hrArr = await _fetchHeartArrayForDate(platform, dayStart);
    if (hrArr == null || hrArr.isEmpty) continue;

    final rows = <Insertable<HeartDetail>>[];
    final count = hrArr.length < 288 ? hrArr.length : 288;
    for (int i = 0; i < count; i++) {
      final bpm = hrArr[i];
      if (!includeZeros && bpm == 0) continue;

      final sampleTime = dayStart.add(Duration(minutes: 5 * i)); // 로컬시각

      rows.add(HeartDetailsCompanion.insert(date: sampleTime, bpm: bpm));
    }

    // 2) 삭제 + 삽입을 하나의 batch로 묶어서 같은 트랜잭션 안에 실행
    // (2) 트랜잭션: 삭제 먼저(배치 아님)
    await heartDb.transaction(() async {
      await (heartDb.delete(
        heartDb.heartDetails,
      )..where((t) => t.date.isBetweenValues(dayStart, dayEnd))).go();

      // (3) 삽입: 배치 대신 작은 덩어리로 나눠 순차 삽입
      const chunk = 64;
      final total = rows.length;

      for (var i = 0; i < total; i += chunk) {
        final slice = rows.sublist(i, min(i + chunk, total));
        // 배치 대신 개별 insert (드리프트가 내부에서 단건 INSERT 쿼리를 직렬로 수행)
        for (final r in slice) {
          await heartDb.into(heartDb.heartDetails).insert(r);
        }
      }
    });
  }
}

/// 특정 날짜(로컬 자정 기준)의 5분 간격 심박 배열을 기기에서 가져옵니다.
/// 성공 시 길이<=288의 int 리스트, 실패/없음이면 null.
/// (기기 SDK 특성상 기준 시간을 "그 날 정오"로 넣는 게 안정적인 경우가 많음)
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

    final Map<dynamic, dynamic>? resp = await platform
        .invokeMethod<Map<dynamic, dynamic>>("syncHeartRate", <String, dynamic>{
          "nowTime": nowTimeLocalSec,
        })
        .timeout(const Duration(seconds: 15));

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
  final resp = await platform.invokeMethod<Map>('syncSportDetail', {
    'dayOffset': dayOffset,
  });

  final List<dynamic> raw = (resp?['details'] as List?) ?? const [];
  final details = raw
      .cast<Map>()
      .map((m) => m.map((k, v) => MapEntry('$k', v)))
      .toList();

  await db.saveSportDetailsFromNative(details.cast<Map<String, dynamic>>());
}

Future<void> syncRecent7DaysStressToDb(
  MethodChannel platform, {
  bool includeZeros = false,
}) async {
  final db = DbManager.I.heartDB;

  DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  int asInt(dynamic v, {int def = 0}) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? def;
    return def;
  }

  for (int offset = 0; offset <= 6; offset++) {
    // 1) 네이티브 호출
    Map<dynamic, dynamic>? resp;
    try {
      resp = await platform.invokeMethod<Map<dynamic, dynamic>>(
        'syncPressure',
        {'offset': offset},
      );
    } catch (e) {
      debugPrint("[STRESS_SYNC] invoke error(offset=$offset): $e");
      continue;
    }
    if (resp == null) continue;

    // 2) 기준 날짜 계산 (today가 있으면 그 날짜 기준에서 offset만큼 전날로)
    final todayMap = resp['today'] as Map<dynamic, dynamic>?;
    DateTime baseToday = startOfDay(DateTime.now());
    if (todayMap != null) {
      final y = asInt(todayMap['year']);
      final m = asInt(todayMap['month']);
      final d = asInt(todayMap['day']);
      if (y > 0 && m > 0 && d > 0) baseToday = DateTime(y, m, d);
    }
    final dayStart = baseToday.subtract(Duration(days: offset));
    final dayEnd = dayStart.add(const Duration(days: 1));

    // 오늘만 무조건 갱신, 나머지는 있으면 스킵
    final mustRefresh = (offset >= 0);
    if (!mustRefresh) {
      final exists =
          await (db.select(db.stressDetails)
                ..where((t) => t.date.isBetweenValues(dayStart, dayEnd))
                ..limit(1))
              .get();
      if (exists.isNotEmpty) continue;
    }

    // 3) range(분) 간격으로 array 시퀀스 해석
    final rangeMinRaw = asInt(resp['range'], def: 30);
    final rangeMin = (rangeMinRaw <= 0 || rangeMinRaw > 1440)
        ? 30
        : rangeMinRaw;

    final List<dynamic> arrDyn = (resp['array'] as List<dynamic>?) ?? const [];
    if (arrDyn.isEmpty) continue;

    final rows = <Insertable<StressDetail>>[];
    for (int i = 0; i < arrDyn.length; i++) {
      final val = asInt(arrDyn[i]);
      if (!includeZeros && val <= 0) continue;

      final t = dayStart.add(Duration(minutes: i * rangeMin));
      if (!t.isBefore(dayEnd)) break; // 일자 경계 넘으면 중단

      rows.add(StressDetailsCompanion.insert(date: t, stress: val));
    }
    if (rows.isEmpty) continue;

    // 4) 트랜잭션: 해당 일자 삭제 후 삽입
    await db.transaction(() async {
      await (db.delete(
        db.stressDetails,
      )..where((t) => t.date.isBetweenValues(dayStart, dayEnd))).go();

      // 건수 많지 않으므로 단건 삽입으로도 충분
      for (final r in rows) {
        await db.into(db.stressDetails).insert(r);
      }
    });
  }
}

Future<void> syncRecent3DaysSportDetailsToDb(
  MethodChannel platform,
) async {
  final db = DbManager.I.heartDB;

  DateTime day0(DateTime d) => DateTime(d.year, d.month, d.day);

  for (int offset = 0; offset < 3; offset++) {
    final now = DateTime.now();
    final dayStart = day0(now).subtract(Duration(days: offset));
    final dayEnd = dayStart.add(const Duration(days: 1));

    // 오늘만 항상 갱신, 나머지는 있으면 스킵
    final mustRefresh = offset == 0;

    // before: 현재 DB 상태 요약
    final beforeRows =
        await (db.select(db.sportDetails)..where(
              (t) =>
                  t.date.isBiggerOrEqual(drift.Variable(dayStart)) &
                  t.date.isSmallerThan(drift.Variable(dayEnd)),
            ))
            .get();

    if (!mustRefresh && beforeRows.isNotEmpty) {
      continue;
    }

    // 네이티브 호출
    Map<dynamic, dynamic>? resp;
    try {
      resp = await platform.invokeMethod<Map<dynamic, dynamic>>(
        'syncSportDetail',
        {'dayOffset': offset},
      );
    } catch (e) {
      debugPrint("[SPORT_SYNC] invoke error(offset=$offset): $e");
      continue;
    }

    final raw = (resp?['details'] as List<dynamic>?) ?? const [];
    if (raw.isEmpty) continue;

    // 하루치 전체 삭제 후 삽입 (프로젝트의 saveSportDetailsFromNative 규약)
    final details = raw
        .cast<Map>()
        .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
    await db.saveSportDetailsFromNative(details.cast<Map<String, dynamic>>());
  }
}

Future<void> syncRecent3DaysOxygenToDb(
  // ← 이름 유지 (요구사항대로 전체 동기화로 동작)
  MethodChannel platform, {
  bool includeZeros = false,
}) async {
  final db = DbManager.I.heartDB;
  final startedAt = DateTime.now();
  debugPrint("[OXY_SYNC] start includeZeros=$includeZeros");

  // ---- helpers ----
  DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime? dayStartFromDateStr(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final norm = s.contains(' ') && !s.contains('T')
          ? s.replaceFirst(' ', 'T')
          : s;
      final dt = DateTime.parse(norm);
      return startOfDay(dt);
    } catch (_) {
      return null;
    }
  }

  DateTime? dayStartFromUnix(dynamic v) {
    if (v is! num) return null;
    final n = v.toInt();
    final ms = n > 1000000000000 ? n : n * 1000; // sec or ms 추정
    final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return startOfDay(dt);
  }

  int asInt(dynamic v, {int def = 0}) {
    if (v == null) return def;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? def;
    return def;
  }

  List<int> asIntList(dynamic any) {
    if (any is List) return any.map((e) => asInt(e, def: 0)).toList();
    return const <int>[];
  }

  // ---- 1) 네이티브에서 전체 SpO2 리스트 수신 ----
  final List<dynamic> raw;
  try {
    // Kotlin: once.success(out)  // out: List<Map<String, Any?>>
    final t0 = DateTime.now();
    final resp = await platform
        .invokeMethod<List<dynamic>>('syncBloodOxygen')
        .timeout(const Duration(seconds: 20));
    debugPrint(
      "[OXY_SYNC] native returned count=${resp?.length ?? 0} in ${DateTime.now().difference(t0).inMilliseconds}ms",
    );
    raw = resp ?? const [];
  } on TimeoutException {
    debugPrint("[OXY_SYNC] native call timeout");
    return;
  } catch (e) {
    debugPrint("[OXY_SYNC] invoke error: $e");
    return; // 네이티브 미구현/에러 시 종료
  }
  if (raw.isEmpty) return;

  // ---- 2) 파싱 → 일자별(hourly) 레코드 축적 ----
  // dayStart(자정) -> 그 날짜에 삽입할 Companion 리스트
  final Map<DateTime, List<BloodOxygenDetailsCompanion>> rowsByDay = {};

  for (final item in raw) {
    if (item is! Map) continue;

    final dateStr = item['dateStr'] as String?;
    final unix = item['unix_time'];
    final dayStart = dayStartFromDateStr(dateStr) ?? dayStartFromUnix(unix);
    if (dayStart == null) continue;

    final minArray = asIntList(item['minArray']);
    final maxArray = asIntList(item['maxArray']);

    // “정시 1시간 간격”으로 해석 → 인덱스 i = 시(hour)
    // 일반적으로 24개일 것이므로 0..23까지만 쓴다.
    final len = math.min(math.max(minArray.length, maxArray.length), 24);
    if (len == 0) continue;

    final dayRows = rowsByDay.putIfAbsent(
      dayStart,
      () => <BloodOxygenDetailsCompanion>[],
    );

    for (int i = 0; i < len; i++) {
      final minV = i < minArray.length ? minArray[i] : 0;
      final maxV = i < maxArray.length ? maxArray[i] : 0;

      int v;
      if (minV > 0 && maxV > 0) {
        v = ((minV + maxV) / 2).round();
      } else {
        v = maxV > 0 ? maxV : minV;
      }
      if (!includeZeros && v <= 0) continue;

      final t = dayStart.add(Duration(hours: i)); // 정시(시간) 타임스탬프
      dayRows.add(BloodOxygenDetailsCompanion.insert(date: t, spo2: v));
    }
  }

  debugPrint(
    "[OXY_SYNC] parsed days=${rowsByDay.length} totalRows=${rowsByDay.values.fold<int>(0, (acc, e) => acc + e.length)}",
  );

  if (rowsByDay.isEmpty) return;

  // ---- 3) 트랜잭션: 날짜별로 삭제 후 삽입(덮어쓰기) ----
  final t1 = DateTime.now();
  await db.transaction(() async {
    for (final entry in rowsByDay.entries) {
      final dayStart = entry.key;
      final dayEnd = dayStart.add(const Duration(days: 1));
      final rows = entry.value;

      // 해당 일자 범위 기존 값 삭제
      await (db.delete(
        db.bloodOxygenDetails,
      )..where((t) => t.date.isBetweenValues(dayStart, dayEnd))).go();

      // 삽입 (chunk)
      const chunk = 128;
      for (int i = 0; i < rows.length; i += chunk) {
        final slice = rows.sublist(i, math.min(i + chunk, rows.length));
        for (final r in slice) {
          await db.into(db.bloodOxygenDetails).insert(r);
        }
      }
    }
  });
  debugPrint(
    "[OXY_SYNC] db write done in ${DateTime.now().difference(t1).inMilliseconds}ms (total ${DateTime.now().difference(startedAt).inMilliseconds}ms)",
  );
}

Future<void> syncSleepDetailsLast3Days({
  required MethodChannel platform,
}) async {
  await _upsertSleepDetailsForOffsets(
    db: DbManager.I.sleepDB,
    platform: platform,
    offsets: const [0, 1, 2],
  );
}

/// 내부 공용: 주어진 offsets(예: [0,1,2])에 대해 SleepDetails를 갱신
/// 내부 공용: 주어진 offsets(예: [0,1,2])에 대해 SleepDetails를 갱신 + 중간 로그 출력
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
      rsp = await platform.invokeMethod<Map<dynamic, dynamic>>(
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
  try {
    await syncRecent3DaysHeartToDb(platform);
    await syncRecent3DaysOxygenToDb(platform);
    await syncRecent3DaysSportDetailsToDb(platform);
    await syncRecent7DaysStressToDb(platform);
    await syncSleepDetailsLast3Days(platform: platform);
  } catch (e, s) {
    debugPrint('syncAllRecentData error: $e\n$s');
  }
}
