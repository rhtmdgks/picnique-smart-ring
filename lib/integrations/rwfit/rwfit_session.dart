import '../../services/ring_session_arbiter.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'rwfit_history_store.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:rwfit_ble/rwfit_ble.dart';

/// RWFit-only session. Never shares a BLE connection with the legacy QRing bridge.
/// Contract pinned to the SDK snapshot in Picnique Inc. (be17a8f306e19aa3de2e306c044d94e5d76c691f).
class RwfitSession extends ChangeNotifier {
  RwfitSession({required this.store});
  final RwfitHistoryStore store;
  BleDevice? savedDevice;
  Future<void> _writes = Future.value();
  Object? _writeError;
  Future<void>? _refreshing;
  DateTime? _lastRefresh;
  final RwfitBle _sdk = RwfitBle.instance;
  final Map<String, BleDevice> _devices = {};
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void>? _initializing;
  FunctionMenu? capabilities;
  BleDevice? device;
  ConnectState state = ConnectState.disconnected;
  int? battery;
  String? error;
  bool scanning = false;
  bool busy = false;
  bool _disposed = false;
  bool _connecting = false;
  bool _requiresReconnect = false;
  Completer<void>? _readyWaiter;
  Completer<void>? _operation;
  RealtimeMetric? _measurement;
  final List<SyncResult> history = [];
  RealtimeData? latestMeasurement;
  TouchEvent? lastTouch;
  int singleTaps = 0;

  List<BleDevice> get devices => _devices.values.toList()
    ..sort((a, b) => b.rssi.compareTo(a.rssi));
  bool get ready => capabilities != null && !_requiresReconnect;
  String identity(BleDevice d) => (d.uuid?.isNotEmpty ?? false) ? d.uuid! : d.mac;
  void _changed() { if (!_disposed) notifyListeners(); }

  Future<void> initialize() => _initializing ??= _initialize().catchError((Object e) async {
    for (final subscription in _subscriptions) { await subscription.cancel(); }
    _subscriptions.clear();
    _initializing = null;
    _recordError(e);
    throw e;
  });
  Future<void> _initialize() async {
    if (Platform.isAndroid) {
      final permissions = await [Permission.bluetoothScan, Permission.bluetoothConnect,
        Permission.locationWhenInUse].request();
      if (permissions.values.any((status) => status.isPermanentlyDenied)) {
        throw StateError('블루투스 권한을 앱 설정에서 허용해 주세요.');
      }
    }
    _subscriptions.add(_sdk.onScanResult.listen((d) {
      if (identity(d).isNotEmpty) _devices[identity(d)] = d;
      _changed();
    }, onError: _recordError));
    _subscriptions.add(_sdk.onScanFinish.listen((_) { scanning = false; _changed(); }, onError: _recordError));
    _subscriptions.add(_sdk.onConnectState.listen((event) {
      state = event.state;
      if (state == ConnectState.failed || state == ConnectState.disconnected) {
        capabilities = null;
        battery = null;
        final failure = StateError(event.reason ?? 'Device disconnected');
        if (_readyWaiter?.isCompleted == false) _readyWaiter!.completeError(failure);
        if (_operation?.isCompleted == false) _operation!.completeError(failure);
      }
      _changed();
    }, onError: _recordError));
    _subscriptions.add(_sdk.onFunctionMenu.listen((menu) {
      final current = device;
      if (current == null) return;
      final same = (current.uuid?.isNotEmpty ?? false)
          ? menu.uuid == current.uuid : menu.mac.toLowerCase() == current.mac.toLowerCase();
      if (!same) return;
      capabilities = menu;
      if (_readyWaiter?.isCompleted == false) _readyWaiter!.complete();
      _changed();
    }, onError: _recordError));
    _subscriptions.add(_sdk.onBatteryChanged.listen((b) { battery = b.power; _changed(); }, onError: _recordError));
    _subscriptions.add(_sdk.onTouchEvent.listen((event) {
      lastTouch = event;
      if (event.action == TouchAction.singleTap) singleTaps++;
      _changed();
    }, onError: _recordError));
    _subscriptions.add(_sdk.onRealtimeData.listen((data) {
      if (_measurement == null) return;
      final expected = {
        RealtimeMetric.hr: HealthType.hr, RealtimeMetric.bloodOxy: HealthType.bloodOxy,
        RealtimeMetric.hrv: HealthType.hrv, RealtimeMetric.pressure: HealthType.pressure,
        RealtimeMetric.bloodSugar: HealthType.bloodSugar,
        RealtimeMetric.bloodPressure: HealthType.bloodBp,
        RealtimeMetric.temperature: HealthType.temperature,
      }[_measurement];
      if (data.type != expected) return;
      latestMeasurement = data;
      _changed();
    }, onError: _recordError));
    _subscriptions.add(_sdk.onRealtimeMeasureComplete.listen((result) {
      if (_measurement == null || _operation?.isCompleted != false) return;
      if (result.isSuccess && latestMeasurement != null) {
        _operation!.complete();
      } else {
        _operation!.completeError(StateError('Measurement failed or returned no data (${result.errorCode})'));
      }
    }, onError: _recordError));
    _subscriptions.add(_sdk.onSyncResult.listen((result) {
      if (_measurement != null || !busy || _operation == null) return;
      final id = device == null ? '' : identity(device!);
      if (id.isEmpty) { _recordError(StateError('Missing device identity')); return; }
      _writes = _writes.then((_) => store.save(id, result)).catchError((Object e) {
        _writeError = e;
        _recordError(e);
      });
      history.add(result);
      _changed();
    }, onError: _recordError));
    _subscriptions.add(_sdk.onSyncFinish.listen((_) {
      if (_measurement == null && _operation?.isCompleted == false) _operation!.complete();
    }, onError: _recordError));
    _subscriptions.add(_sdk.onSyncError.listen((failure) {
      if (_measurement == null && _operation?.isCompleted == false) {
        _operation!.completeError(StateError('History synchronization failed: $failure'));
      }
    }, onError: _recordError));
    try { await _sdk.init(); } catch (e) { _recordError(e); rethrow; }
  }
  void _recordError(Object e) { error = e.toString(); _changed(); }

  Future<void> scan() async {
    await initialize();
    if (busy || _connecting) throw StateError('Operation already in progress');
    await _sdk.stopScan();
    _devices.clear();
    error = null;
    scanning = true;
    _changed();
    try { await _sdk.startScan(); } catch (e) { scanning = false; _recordError(e); rethrow; }
  }

  Future<void> connect(BleDevice target) async {
    await initialize();
    if (busy || _connecting) throw StateError('Operation already in progress');
    _connecting = true;
    _lastRefresh = null;
    error = null;
    capabilities = null;
    _requiresReconnect = false;
    try {
      await _sdk.stopScan();
      scanning = false;
      await _sdk.disconnect();
      device = target;
      final waiter = Completer<void>();
      _readyWaiter = waiter;
      // Attach the failure handler before native callbacks can fire.
      final readyFuture = waiter.future.timeout(const Duration(seconds: 45));
      await Future.wait<void>([_sdk.connect(target), readyFuture], eagerError: true);
      battery = await _sdk.getPower();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rwfit.binding.v1', jsonEncode(target.toMap()));
      savedDevice = target;
    } catch (e) {
      capabilities = null;
      _requiresReconnect = true;
      _recordError(e);
      try { await _sdk.disconnect(); } catch (_) {}
      rethrow;
    } finally { _readyWaiter = null; _connecting = false; _changed(); }
  }

  Future<void> restoreBinding() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('rwfit.binding.v1');
    if (encoded != null) {
      try { savedDevice = BleDevice.fromMap(jsonDecode(encoded) as Map); }
      catch (_) { savedDevice = null; }
    }
    _changed();
  }
  Future<void> reconnectSaved() async {
    final saved = savedDevice;
    if (saved == null) throw StateError('저장된 기기가 없습니다.');
    // Complete saved scan object preserves iOS UUID, not just Android MAC.
    await connect(saved);
  }
  Future<void> forgetBinding() async {
    await disconnect();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('rwfit.binding.v1');
    savedDevice = null;
    _changed();
  }
  Future<void> refreshHistory() {
    if (_refreshing != null) return _refreshing!;
    if (_lastRefresh != null && DateTime.now().difference(_lastRefresh!).inSeconds < 30) return Future.value();
    return _refreshing = syncHistory().then((_) { _lastRefresh = DateTime.now(); })
      .whenComplete(() { _refreshing = null; });
  }
  Future<bool> setMonitoring(String kind, bool enabled) async {
    if (!ready || busy) throw StateError('기기가 준비되지 않았거나 작업 중입니다.');
    busy = true;
    _changed();
    try {
      switch (kind) {
        case 'hr':
          final c = await _sdk.getTimedHeartRate();
          await _sdk.setTimedHeartRate(c.copyWith(isOpen: enabled));
          return (await _sdk.getTimedHeartRate()).isOpen;
        case 'bo':
          final c = await _sdk.getTimedBloodOxygen();
          await _sdk.setTimedBloodOxygen(c.copyWith(isOpen: enabled));
          return (await _sdk.getTimedBloodOxygen()).isOpen;
        case 'pressure':
          final c = await _sdk.getTimedStress();
          await _sdk.setTimedStress(c.copyWith(isOpen: enabled));
          return (await _sdk.getTimedStress()).isOpen;
        default: throw UnsupportedError('이 항목의 장치 설정 명세가 없습니다.');
      }
    } finally { busy = false; _changed(); }
  }
  Future<Map<String, bool>> readMonitoring() async {
    if (!ready || busy) throw StateError('기기가 준비되지 않았거나 작업 중입니다.');
    busy = true;
    _changed();
    try {
      return {
        'hr': (await _sdk.getTimedHeartRate()).isOpen,
        'bo': (await _sdk.getTimedBloodOxygen()).isOpen,
        'pressure': (await _sdk.getTimedStress()).isOpen,
      };
    } finally { busy = false; _changed(); }
  }

  void _begin() {
    if (!ready) throw StateError('Wait for the device capability table or reconnect');
    if (busy || _connecting) throw StateError('Only one device operation may run at a time');
    busy = true;
    error = null;
    _operation = Completer<void>();
    _changed();
  }
  Future<void> measure(RealtimeMetric metric) async {
    if (RingSessionArbiter.instance.mode == RingSessionMode.rosaryTouch) {
      throw StateError('묵주 기록을 종료한 뒤 측정해 주세요.');
    }
    _begin();
    _measurement = metric;
    latestMeasurement = null;
    final terminal = _operation!.future.timeout(const Duration(seconds: 80));
    try {
      await Future.wait<void>([_sdk.startRealtimeMeasure(metric), terminal], eagerError: true);
      final measured = latestMeasurement!;
      final shape = switch (measured.type) {
        HealthType.hr => ('hr', 'hr'),
        HealthType.bloodOxy => ('bo', 'bloodOxy'),
        HealthType.pressure => ('pressure', 'pressure'),
        _ => (measured.type?.name ?? 'unknown', 'value'),
      };
      await store.save(identity(device!), SyncResult(type: shape.$1, data: [
        {'items': [{'time': measured.timestampSec, shape.$2: measured.value}], 'source': 'realtime'}
      ]));
    } catch (e) {
      _requiresReconnect = true;
      _recordError(e);
      rethrow;
    } finally {
      try { await _sdk.stopRealtimeMeasure(metric); } catch (e) { _requiresReconnect = true; _recordError(e); }
      _measurement = null;
      _operation = null;
      busy = false;
      _changed();
    }
  }
  Future<void> syncHistory() async {
    // Confirm storage can be opened before requesting a potentially destructive
    // device-side sync. SDK deletion/ACK itself is not controlled by this app.
    await store.prepare();
    _begin();
    history.clear();
    _writeError = null;
    final terminal = _operation!.future.timeout(const Duration(minutes: 3));
    try {
      await Future.wait<void>([_sdk.syncAllHealthData(), terminal], eagerError: true);
      await _writes;
      if (_writeError != null) throw StateError('Local history save failed: $_writeError');
    } catch (e) {
      _requiresReconnect = true;
      _recordError(e);
      rethrow;
    } finally {
      await _writes; // retain partial batches even when sync fails
      _operation = null;
      busy = false;
      _changed();
    }
  }
  Future<void> disconnect() async {
    await _sdk.stopScan();
    await _sdk.disconnect();
    capabilities = null;
    device = null;
    battery = null;
    scanning = false;
    state = ConnectState.disconnected;
    _changed();
  }
  Future<void> close() async {
    try { await disconnect(); } finally {
      for (final subscription in _subscriptions) { await subscription.cancel(); }
      _subscriptions.clear();
    }
  }
  @override
  void dispose() {
    _disposed = true;
    unawaited(close().catchError((Object _) {}));
    super.dispose();
  }
}
