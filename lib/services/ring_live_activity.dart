import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/repository/ring_repository.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';

/// Today activity from Colmi 0x73/0x12 push + periodic history poll.
class RingLiveActivity with ChangeNotifier {
  final RingRepository _repo = RingRepository.instance;

  int _steps = 0;
  int _calories = 0;
  int _distanceM = 0;
  bool _tracking = false;

  StreamSubscription<LiveActivitySnapshot>? _liveSub;
  StreamSubscription<void>? _disconnectSub;
  Timer? _pollTimer;

  int get steps => _steps;
  int get calories => _calories;
  int get distanceMeters => _distanceM;
  bool get isTracking => _tracking;

  Future<void> start() async {
    if (_liveSub != null) return;

    _liveSub = _repo.liveActivityUpdates.listen(_applySnapshot);
    _disconnectSub = _repo.disconnectEvents.listen((_) => unawaited(stop()));

    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(refresh()),
    );

    await refresh();
  }

  Future<void> stop() async {
    await _liveSub?.cancel();
    await _disconnectSub?.cancel();
    _liveSub = null;
    _disconnectSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;

    _steps = 0;
    _calories = 0;
    _distanceM = 0;
    _tracking = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    final data = await BleCommandQueue.invoke<Map<dynamic, dynamic>>(
      'syncTodaySport',
    );
    if (data == null) return;
    _apply(
      steps: _asInt(data['totalSteps']),
      calories: _asInt(data['calorie']),
      distanceM: _asInt(data['walkDistance']),
    );
  }

  void _applySnapshot(LiveActivitySnapshot snap) {
    _apply(
      steps: snap.steps,
      calories: snap.calories,
      distanceM: snap.distanceMeters,
    );
  }

  void _apply({
    required int steps,
    required int calories,
    required int distanceM,
  }) {
    _tracking = true;
    if (steps == _steps && calories == _calories && distanceM == _distanceM) {
      return;
    }
    _steps = steps;
    _calories = calories;
    _distanceM = distanceM;
    notifyListeners();
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
