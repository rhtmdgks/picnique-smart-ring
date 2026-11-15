import 'rwfit_session.dart';

/// Selected once at application bootstrap, never switched during a connection.
class RingBackend {
  static RwfitSession? rwfit;
  static bool get isRwfit => rwfit != null;
  static Future<void> refresh(Future<void> Function() legacy) async {
    final session = rwfit;
    if (session == null) { await legacy(); return; }
    if (session.ready) await session.refreshHistory();
    // Offline chart reads use already persisted local data.
  }
}
