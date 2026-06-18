import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/util/BLEUtil.dart';

enum RingSyncStatus { idle, syncing, done, error }

/// 연결 직후 무거운 데이터 동기화를 UI와 분리해 백그라운드로 수행한다.
///
/// 단일 BLE 링크를 공유하므로 명령은 직렬로 실행한다(동시 실행 시 SDK 응답이
/// 엉킬 수 있음). 각 작업은 1회 재시도하며, 일부 실패해도 연결 상태는 유지한다.
class RingSyncController with ChangeNotifier {
  RingSyncStatus _status = RingSyncStatus.idle;
  Object? _error;

  RingSyncStatus get status => _status;
  Object? get error => _error;
  bool get isSyncing => _status == RingSyncStatus.syncing;

  Future<void> run(MethodChannel platform) async {
    if (_status == RingSyncStatus.syncing) return;
    _status = RingSyncStatus.syncing;
    _error = null;
    notifyListeners();

    var anyFailed = false;

    Future<void> job(String label, Future<void> Function() task) async {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          await task();
          return;
        } catch (e) {
          debugPrint('[SYNC] $label attempt ${attempt + 1} error: $e');
          if (attempt == 1) {
            anyFailed = true;
            _error = e;
          }
        }
      }
    }

    await job('heart', () => syncRecent3DaysHeartToDb(platform));
    await job('oxygen', () => syncRecent3DaysOxygenToDb(platform));
    await job('sport', () => syncRecent3DaysSportDetailsToDb(platform));
    await job('stress', () => syncRecent7DaysStressToDb(platform));
    await job('sleep', () => syncSleepDetailsLast3Days(platform: platform));

    _status = anyFailed ? RingSyncStatus.error : RingSyncStatus.done;
    notifyListeners();
  }

  void reset() {
    _status = RingSyncStatus.idle;
    _error = null;
    notifyListeners();
  }
}
