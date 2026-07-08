import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum RingSyncStatus { idle, syncing, done, error }

/// 스마트링 측정 동기화 로직 제거 상태.
class RingSyncController with ChangeNotifier {
  RingSyncStatus _status = RingSyncStatus.idle;
  Object? _error;

  RingSyncStatus get status => _status;
  Object? get error => _error;
  bool get isSyncing => _status == RingSyncStatus.syncing;

  Future<void> run(MethodChannel platform) async {
    _status = RingSyncStatus.done;
    _error = null;
    notifyListeners();
  }

  void reset() {
    _status = RingSyncStatus.idle;
    _error = null;
    notifyListeners();
  }
}
