import '../integrations/rwfit/ring_backend.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum RingSyncStatus { idle, syncing, done, error }

/// 스마트링 측정 동기화 로직 제거 상태.
class RingSyncController with ChangeNotifier {
  RingSyncController() { RingBackend.rwfit?.addListener(_onRwfit); }
  void _onRwfit() {
    final s = RingBackend.rwfit;
    if (s == null) return;
    final next = s.busy ? RingSyncStatus.syncing :
      s.error != null ? RingSyncStatus.error : RingSyncStatus.done;
    if (_status != next) { _status = next; _error = s.error; notifyListeners(); }
  }
  @override
  void dispose() { RingBackend.rwfit?.removeListener(_onRwfit); super.dispose(); }
  RingSyncStatus _status = RingSyncStatus.idle;
  Object? _error;

  RingSyncStatus get status => _status;
  Object? get error => _error;
  bool get isSyncing => _status == RingSyncStatus.syncing;

  Future<void> run(MethodChannel platform) async {
    if (RingBackend.isRwfit) {
      await RingBackend.rwfit!.refreshHistory();
      return;
    }
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
