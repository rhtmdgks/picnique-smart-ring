import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';
import 'package:picnique_rosary_healthcare_smartring/services/battery_notification_service.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_auto_measurement_service.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_background_import_scheduler.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_background_keepalive.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_background_sync.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_connection_service.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_live_activity.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_data_refresh_notifier.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_live_metrics.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_health_accumulation.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_pending_import.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_sleep_gate.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_sleep_sync_service.dart';
import 'package:picnique_rosary_healthcare_smartring/util/BLEUtil.dart';

/// BLE 연결 유지·자동 재연결·충전/배터리 이벤트를 중앙에서 처리한다.
class RingConnectionCoordinator with WidgetsBindingObserver {
  RingConnectionCoordinator._();
  static final RingConnectionCoordinator instance =
      RingConnectionCoordinator._();

  static const MethodChannel _fg = MethodChannel(
    'com.example.picnique_ring/foreground_service_channel',
  );
  static const EventChannel _events = EventChannel(
    'com.example.picnique_ring/ble_events',
  );

  static const _backoffMs = <int>[500, 2000, 5000, 15000, 30000];

  Ring? _ring;
  RingLiveActivity? _liveActivity;
  RingSyncController? _sync;
  StreamSubscription<dynamic>? _eventSub;
  Timer? _reconnectTimer;
  bool _started = false;
  bool _isReconnecting = false;
  bool _manualDisconnectRequested = false;
  bool _postConnectInFlight = false;
  int _backoffIndex = 0;
  HealthDataRefreshNotifier? _healthRefresh;

  HealthDataRefreshNotifier? get healthRefresh => _healthRefresh;

  Future<void> start({
    required Ring ring,
    RingLiveActivity? liveActivity,
    RingSyncController? sync,
    HealthDataRefreshNotifier? healthRefresh,
    HealthLiveMetrics? liveMetrics,
  }) async {
    _ring = ring;
    _liveActivity = liveActivity;
    _sync = sync;
    _healthRefresh = healthRefresh;
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    await ring.loadFromPrefs();
    RingBackgroundImportScheduler.instance.bind(
      ring,
      refreshNotifier: healthRefresh,
    );
    RingAutoMeasurementService.instance.bind(
      ring,
      refreshNotifier: healthRefresh,
      liveMetrics: liveMetrics,
    );
    // 야간 수면 감지 — 기상 시 수면 sync + 야간 축적 생체 데이터 병합.
    RingSleepGate.instance.bind(ring, onWake: _onSleepGateWake);
    if (ring.hasSavedDevice) {
      await BatteryNotificationService.ensureReadyForBackgroundAlerts();
    }
    ring.addListener(_onRingProviderChanged);
    _eventSub = _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object err) =>
          debugPrint('[BLE][coordinator] event error: $err'),
    );
    await RingPendingImport.importAll(
      ring: _ring,
      refreshNotifier: _healthRefresh,
    );
    unawaited(_tryReconnect(trigger: 'startup'));
  }

  Future<void> stop() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _ring?.removeListener(_onRingProviderChanged);
    RingBackgroundImportScheduler.instance.unbind();
    RingAutoMeasurementService.instance.unbind();
    RingSleepGate.instance.unbind();
    WidgetsBinding.instance.removeObserver(this);
    await _eventSub?.cancel();
    _eventSub = null;
    _started = false;
  }

  Future<void> onManualDisconnect() async {
    _manualDisconnectRequested = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _ring?.markDisconnected(forgetSaved: true);
  }

  Future<bool> ensureConnected() async {
    final ring = _ring;
    if (ring == null) return false;
    if (ring.isConnected) return true;
    await _tryReconnect(trigger: 'ensure');
    return ring.isConnected;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 아침 foreground 복귀 — 수면 중이었다면 기상 처리(내부에서 시간대 판정).
      RingSleepGate.instance.onAppResumed();
      // 마지막 수면 sync 가 오늘 아침 이전이면 요약 sync.
      unawaited(RingSleepSyncService.instance.syncSummaryIfMorningStale());
      unawaited(_flushHealthIfConnected());
      unawaited(_tryReconnect(trigger: 'resume'));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(RingPendingImport.importAll(
        ring: _ring,
        refreshNotifier: _healthRefresh,
      ));
    }
  }

  Future<void> _flushHealthIfConnected() async {
    final ring = _ring;
    if (ring == null || !ring.isConnected || !ring.sdkReady) return;
    await RingHealthAccumulation.flushConnectedToApp(
      ring: ring,
      refreshNotifier: _healthRefresh,
    );
  }

  void _onRingProviderChanged() {
    RingBackgroundImportScheduler.instance.onRingStateChanged();
    RingAutoMeasurementService.instance.onRingStateChanged();
    RingSleepGate.instance.onRingStateChanged();
  }

  /// SleepGate 기상 감지 — 수면 sync + 야간 축적 생체 데이터 병합.
  void _onSleepGateWake() {
    unawaited(RingSleepSyncService.instance.syncSummary());
    unawaited(RingHealthAccumulation.flushConnectedToApp(
      ring: _ring,
      refreshNotifier: _healthRefresh,
      force: true,
    ));
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type']?.toString();

    switch (type) {
      case 'connected':
        _handleConnected(event);
      case 'disconnected':
        _handleDisconnected();
      case 'rtCharging':
        _handleBatteryEvent(event, charging: true);
      case 'rtBattery':
        _handleBatteryEvent(
          event,
          charging: event['isCharging'] == true,
        );
    }
  }

  void _handleConnected(Map<dynamic, dynamic> event) {
    final ring = _ring;
    if (ring == null) return;
    final address = (event['address']?.toString() ?? '').trim();
    final name = (event['name']?.toString() ?? '').trim();
    final safeAddress =
        address.isNotEmpty ? address : (ring.savedAddress ?? '');
    if (safeAddress.isEmpty) return;
    final safeName = name.isNotEmpty ? name : (ring.savedName ?? '스마트링');
    _backoffIndex = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    unawaited(ring.markConnected(name: safeName, address: safeAddress));
    if (_isReconnecting || RingConnectionService.isConnecting) return;
    unawaited(_runAfterConnectSuccess(safeAddress, safeName));
  }

  void _handleDisconnected() {
    final ring = _ring;
    if (ring == null) return;
    unawaited(_liveActivity?.stop());
    unawaited(ring.markDisconnected(forgetSaved: false));
    if (_manualDisconnectRequested) {
      _manualDisconnectRequested = false;
      return;
    }
    _scheduleReconnect(trigger: 'disconnected');
  }

  void _handleBatteryEvent(Map<dynamic, dynamic> event, {required bool charging}) {
    final ring = _ring;
    if (ring == null) return;
    final percent = _asInt(event['percent']);
    if (percent > 0) {
      ring.setBatteryAndCharging(percent, charging);
    } else {
      ring.setCharging(charging);
    }
  }

  void _scheduleReconnect({required String trigger}) {
    if (_manualDisconnectRequested) return;
    final ring = _ring;
    if (ring == null || ring.isConnected) return;
    if (ring.savedAddress == null || ring.savedAddress!.isEmpty) return;

    _reconnectTimer?.cancel();
    final delayMs = _backoffMs[_backoffIndex.clamp(0, _backoffMs.length - 1)];
    _backoffIndex = (_backoffIndex + 1).clamp(0, _backoffMs.length - 1);

    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      unawaited(_tryReconnect(trigger: trigger));
    });
  }

  Future<void> _tryReconnect({required String trigger}) async {
    final ring = _ring;
    if (ring == null || _isReconnecting || _manualDisconnectRequested) return;
    final address = ring.savedAddress;
    if (address == null || address.isEmpty) return;
    if (ring.isConnected) return;

    if (!Platform.isIOS) {
      final adapterState = await _waitForBluetoothAdapterReady(trigger: trigger);
      if (adapterState != BluetoothAdapterState.on) {
        debugPrint(
          '[BLE][coordinator] skip reconnect($trigger): adapter=$adapterState',
        );
        _scheduleReconnect(trigger: trigger);
        return;
      }
    } else {
      if (!await isBluetoothReady()) {
        _scheduleReconnect(trigger: trigger);
        return;
      }
    }

    ring.setIsReconnecting(true);
    _isReconnecting = true;
    try {
      final ok = await _connectAndVerify(address);
      if (!ok) {
        debugPrint('[BLE][coordinator] reconnect failed trigger=$trigger');
        _scheduleReconnect(trigger: trigger);
        return;
      }

      final name = ring.savedName ?? '스마트링';
      await ring.markConnected(name: name, address: address);
      _backoffIndex = 0;

      await _readBattery(ring);
      await _runAfterConnectSuccess(address, name);
      debugPrint('[BLE][coordinator] reconnect success trigger=$trigger');
    } catch (e) {
      debugPrint('[BLE][coordinator] reconnect error trigger=$trigger err=$e');
      _scheduleReconnect(trigger: trigger);
    } finally {
      _isReconnecting = false;
      if (!ring.isConnected) {
        ring.setIsReconnecting(true);
      }
    }
  }

  Future<void> _runAfterConnectSuccess(String address, String name) async {
    if (_postConnectInFlight) return;
    _postConnectInFlight = true;
    try {
      await _afterConnectSuccess(address, name);
    } finally {
      _postConnectInFlight = false;
    }
  }

  Future<void> _afterConnectSuccess(String address, String name) async {
    final ring = _ring;
    if (ring == null) return;

    if (Platform.isIOS) {
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    var sdkReady = await RingConnectionService.syncTimeAfterConnect();
    if (!sdkReady && Platform.isIOS) {
      await Future<void>.delayed(const Duration(seconds: 2));
      sdkReady = await RingConnectionService.syncTimeAfterConnect();
    }
    // 이미 ready 였다면 유지 — syncTime 은 큐 대기 포함 15초 타임아웃이라
    // 자동 측정이 큐를 점유 중이면 거짓 실패한다. 여기서 강등하면
    // 자동 측정·SleepGate 가 연쇄로 죽는다(도돌이표 원인).
    if (!sdkReady && ring.sdkReady) {
      debugPrint('[CONNECT] syncTime timed out but SDK already ready — keep');
      sdkReady = true;
    }
    ring.setSdkReady(sdkReady);
    RingBackgroundImportScheduler.instance.onRingStateChanged();
    RingAutoMeasurementService.instance.onRingStateChanged();

    if (!sdkReady) {
      debugPrint('[CONNECT] SDK not ready — skip post-connect setup');
      return;
    }

    final live = _liveActivity;
    if (live != null) {
      await live.start();
    }

    try {
      await BleCommandQueue.invoke('enableRealtimeNotifications');
    } catch (_) {}

    // 반지 펌웨어 자동 측정 — iOS는 연결 직후 BLE가 바쁠 때 수동 측정과 충돌하므로 잠시 뒤에 켠다.
    if (Platform.isIOS) {
      unawaited(
        Future<void>.delayed(const Duration(seconds: 15), () async {
          try {
            await BleCommandQueue.waitUntilManualIdle();
            await enableRingAutoMonitoring();
          } catch (e) {
            debugPrint('[CONNECT] delayed auto monitoring failed: $e');
          }
        }),
      );
    } else {
      await enableRingAutoMonitoring();
    }

    try {
      await _fg.invokeMethod('startService');
    } catch (_) {}

    await RingBackgroundKeepalive.start(address: address, name: name);
    await BatteryNotificationService.ensureReadyForBackgroundAlerts();

    if (Platform.isIOS) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    // 재연결·연결 직후: 반지 내부 저장분 → 앱 DB (오프라인 축적분 강제 pull)
    await RingHealthAccumulation.flushConnectedToApp(
      ring: ring,
      refreshNotifier: _healthRefresh,
      force: true,
    );

    final sync = _sync;
    if (sync != null && !Platform.isIOS) {
      unawaited(sync.run(BleCommandQueue.channel));
    }

    // 연결 직후 수면 요약 sync (이벤트 기반 — backgroundSync 우선순위).
    unawaited(RingSleepSyncService.instance.syncSummary());
  }

  Future<void> _readBattery(Ring ring) async {
    try {
      final result = await BleCommandQueue.invoke<dynamic>('getBatteryLevel');
      if (result is Map) {
        final level = _asInt(result['level'] ?? result['battery']);
        final charging = result['charging'] == true;
        if (level > 0) {
          ring.setBatteryAndCharging(level, charging);
        }
      } else if (result is int) {
        ring.setBattery(result);
      }
    } catch (_) {}
  }

  Future<BluetoothAdapterState> _waitForBluetoothAdapterReady({
    required String trigger,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    BluetoothAdapterState current = await FlutterBluePlus.adapterState.first;
    if (current == BluetoothAdapterState.on) return current;

    final transient = <BluetoothAdapterState>{
      BluetoothAdapterState.unknown,
      BluetoothAdapterState.turningOn,
    };
    if (!transient.contains(current)) return current;

    try {
      current = await FlutterBluePlus.adapterState
          .where((s) => !transient.contains(s))
          .first
          .timeout(timeout);
      debugPrint(
        '[BLE][coordinator] adapter settled ($trigger): was transient → $current',
      );
      return current;
    } on TimeoutException {
      return await FlutterBluePlus.adapterState.first;
    }
  }

  Future<bool> _connectAndVerify(String address) async {
    try {
      final ok = await BleCommandQueue
          .invoke<bool>('reconnectKnownDevice', <String, dynamic>{
            'deviceAddress': address,
          })
          .timeout(const Duration(seconds: 20));
      if (ok == true) return true;
    } catch (_) {}

    try {
      final ok = await BleCommandQueue
          .invoke<bool>('connectDirectly', <String, dynamic>{
            'deviceAddress': address,
          })
          .timeout(const Duration(seconds: 30));
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
