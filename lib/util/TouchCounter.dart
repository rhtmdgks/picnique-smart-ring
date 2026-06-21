// ignore_for_file: file_names

import 'package:flutter/foundation.dart';

/// 묵주 단수 — 화면 탭으로만 증가한다.
class RingTouchController with ChangeNotifier {
  bool _listening = false;

  int tapCount = 0;

  bool get isListening => _listening;

  Future<void> start() async {
    if (_listening) return;
    tapCount = 0;
    _listening = true;
    debugPrint('[ROSARY] manual tap counter started');
    notifyListeners();
  }

  void increment() {
    if (!_listening) return;
    tapCount++;
    debugPrint('[ROSARY] manual tap count=$tapCount');
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_listening) return;
    _listening = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _listening = false;
    super.dispose();
  }
}
