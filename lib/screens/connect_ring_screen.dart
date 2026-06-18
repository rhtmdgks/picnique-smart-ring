import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:io' show Platform;
import 'package:picnique_rosary_healthcare_smartring/util/BLERealtimeLogger.dart';
import 'package:provider/provider.dart';

import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_background_sync.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/setting/ring_connect_list_card.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/setting/ring_connect_status_card.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';
import '../util/BLEUtil.dart'; // ensureBluetoothOn, printBattery 등

// ─────────────────────────────────────────────────────────────
// (선택) RingConnectListCard 내부에서 아이템 탭 시 호출할 전역 함수
// build 사용법을 바꾸지 않기 위해, 리스트 카드에서 이 함수만 호출하면 됩니다.
// 예: onTap: () => connectRingFromList(context, item['address'])
Future<void> connectRingFromList(BuildContext context, String address) async {
  final state = context
      .findAncestorStateOfType<_ConnectRingSettingScreenState>();
  if (state != null) {
    await state.connectByAddress(address);
  }
}
// ─────────────────────────────────────────────────────────────

class ConnectRingSettingScreen extends StatefulWidget {
  const ConnectRingSettingScreen({super.key});

  @override
  State<ConnectRingSettingScreen> createState() =>
      _ConnectRingSettingScreenState();
}

class _ConnectRingSettingScreenState extends State<ConnectRingSettingScreen> {
  static const MethodChannel _platform = MethodChannel(
    'com.example.picnique_ring/ble',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.example.picnique_ring/ble_events',
  );

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription? _iosScanSub;
  final List<ScanResult> _scanResults = [];
  // UI에 그대로 넘길 리스트(동일한 키 구조 유지: name / address)
  List<Map<String, String>> _connectList = [];

  bool _isScanning = false;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _boot(); // 진입 즉시 블루투스 확인 + 스캔 시작
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _iosScanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  // 1) 진입 시 블루투스 켜기 → 스캔
  Future<void> _boot() async {
    final ok = await ensureBluetoothOn(context);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('블루투스를 켠 후 다시 시도해 주세요.')));
      return;
    }
    if (!mounted) return;
    final ring = context.read<Ring>();
    final hasLiveConnection =
        ring.isConnected && (ring.address?.isNotEmpty ?? false);
    // 이미 연결된 상태로 화면에 들어오면 기존 연결을 끊지 않는다.
    if (!hasLiveConnection) {
      await _fullDisconnect();
    } else {
      await _stopScanOnly();
    }
    await _startScan();
  }

  // 2) 스캔 시작: 결과를 _connectList에 반영
  Future<void> _startScan() async {
    await _stopScanOnly();
    setState(() {
      _isScanning = true;
      _scanResults.clear();
      _connectList = [];
    });

    if (Platform.isIOS) {
      _injectCachedDevice();
      await _iosScanSub?.cancel();
      _iosScanSub = _eventChannel.receiveBroadcastStream().listen((event) {
        if (!mounted) return;
        if (event is Map && event['type'] == 'scanResult') {
          final addr = (event['address'] ?? '') as String;
          final name = (event['name'] ?? '') as String;
          if (addr.isEmpty) return;
          final map = {
            'name': name.isNotEmpty ? name : '(이름 없음)',
            'address': addr,
          };
          final dedup = {for (final e in _connectList) e['address']: e};
          dedup[addr] = map;
          setState(() {
            _connectList = dedup.values.toList();
          });
        }
      });
      try {
        await _platform.invokeMethod('startScan', <String, dynamic>{
          'namePrefix': null, // uuidString 기준으로 사용
          'timeoutMs': 10000,
        });
      } catch (e) {
        debugPrint('iOS startScan error: $e');
      } finally {
        if (mounted) setState(() => _isScanning = false);
      }
    } else {
      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((list) {
        if (!mounted) return;
        // 중복 제거(주소 기준) 및 최신 결과로 갱신
        final Map<String, ScanResult> dedup = {};
        for (final r in list) {
          debugPrint(
            '[SCAN][Android] name=${_deviceName(r)} addr=${_deviceAddress(r.device)} rssi=${r.rssi}',
          );
          final id = _deviceAddress(r.device);
          if (id != null) dedup[id] = r;
        }
        final results = dedup.values.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));

        setState(() {
          _scanResults
            ..clear()
            ..addAll(results);
          final scanned = _scanResults.map((r) {
            final name = _deviceName(r);
            final addr = _deviceAddress(r.device) ?? '(unknown)';
            return {'name': name, 'address': addr};
          }).toList();
          _connectList = _withCachedDevicePinned(scanned);
        });
      });

      // 정확한 이름 일치 대신 전체 스캔을 노출해 링을 놓치지 않는다(이름 편차 대응).
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      ).whenComplete(() {
        if (mounted) setState(() => _isScanning = false);
      });
    }
  }

  /// 최근 연결된(캐시) 기기를 목록 맨 앞에 고정한다. iOS/Android 공통.
  List<Map<String, String>> _withCachedDevicePinned(
    List<Map<String, String>> list,
  ) {
    final ring = context.read<Ring>();
    final addr = ring.address;
    if (addr == null || addr.isEmpty) return list;
    final ringName = ring.name;
    final name = (ringName != null && ringName.isNotEmpty)
        ? ringName
        : '최근 연결된 기기';
    final rest = list.where((e) => e['address'] != addr).toList();
    return [
      {'name': name, 'address': addr},
      ...rest,
    ];
  }

  void _injectCachedDevice() {
    setState(() {
      _connectList = _withCachedDevicePinned(_connectList);
    });
  }

  // 스캔만 중단(연결은 유지). 화면 진입/재탐색에서 사용.
  Future<void> _stopScanOnly() async {
    if (Platform.isIOS) {
      try {
        await _platform.invokeMethod('stopScan');
      } catch (_) {}
      await _iosScanSub?.cancel();
      _iosScanSub = null;
    } else {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      await _scanSub?.cancel();
      _scanSub = null;
    }
    if (mounted) setState(() => _isScanning = false);
  }

  // 스캔 중단 + 실제 연결 해제(네이티브/포그라운드/실시간). 명시적 해제에서만 사용.
  Future<void> _fullDisconnect() async {
    await _stopScanOnly();
    try {
      await _platform.invokeMethod('disconnect');
    } catch (_) {}
    try {
      const fgChannel = MethodChannel(
        'com.example.picnique_ring/foreground_service_channel',
      );
      await fgChannel.invokeMethod('stopService');
    } catch (_) {}
    try {
      await BleRealtimeLogger.stop();
    } catch (_) {}
  }

  // 3) 주소로 연결: 리스트 카드에서 address만 넘겨 호출
  Future<void> connectByAddress(String address) async {
    if (_connecting) return;
    _setConnecting(true);

    final ring = context.read<Ring>();
    final sync = context.read<RingSyncController>();
    try {
      debugPrint('[CONNECT] start for $address');
      await _stopScanOnly();

      // 표시용 이름: 스캔/캐시 목록에서 조회
      final found = _connectList.firstWhere(
        (e) => e['address'] == address,
        orElse: () => const <String, String>{},
      );
      final deviceName = (found['name']?.isNotEmpty ?? false)
          ? found['name']!
          : '(이름 없음)';

      // 단일 BLE 스택만 사용: 네이티브 SDK 직접 연결 (FBP device.connect 제거)
      debugPrint('[CONNECT] connectDirectly begin');
      await _platform
          .invokeMethod("connectDirectly", <String, dynamic>{
            "deviceAddress": address,
          })
          .timeout(const Duration(seconds: 60));
      debugPrint('[CONNECT] connectDirectly done');

      // 연결 완료 대기: 디바이스가 명령에 응답할 때까지 확인(고정 지연 대체)
      final ready = await _waitDeviceReady();
      if (!ready) {
        throw TimeoutException('device not ready after connect');
      }

      ring.setIsConnected(true);
      ring.setName(deviceName);
      ring.setAddress(address);
      await ring.persist();

      // Phase A(경량): 배터리만 즉시 조회
      if (!mounted) return;
      await printBattery(_platform, ring);

      // 실시간 알림 + 포그라운드 서비스 시작. 끊김 이벤트는 여기서 감지.
      debugPrint('[CONNECT] realtime start');
      await BleRealtimeLogger.start(
        onDisconnected: () {
          ring.setIsConnected(false);
        },
      );
      try {
        const fgChannel = MethodChannel(
          'com.example.picnique_ring/foreground_service_channel',
        );
        await fgChannel.invokeMethod('startService');
      } catch (_) {}
      debugPrint('[CONNECT] done');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('연결되었습니다: ${ring.name ?? "(알 수 없음)"}')),
      );

      // Phase B(백그라운드): 최근 데이터 동기화는 UI를 막지 않고 진행.
      unawaited(sync.run(_platform));
    } on TimeoutException {
      debugPrint('[CONNECT] timeout at outer block');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('연결이 시간 초과되었습니다. 다시 시도해 주세요.')),
        );
      }
      try {
        await _platform.invokeMethod('disconnect');
      } catch (_) {}
      ring.resetRing();
      await ring.clearPersist();
    } catch (e) {
      debugPrint('[CONNECT] error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('연결 실패: $e')));
      }
      try {
        await _platform.invokeMethod('disconnect');
      } catch (_) {}
      ring.resetRing();
      await ring.clearPersist();
    } finally {
      _setConnecting(false);
    }
  }

  /// 연결 직후 디바이스가 실제로 명령에 응답하는지 확인한다.
  /// Android는 connectDirectly가 즉시 반환하므로(준비 전), 배터리 조회로 준비 완료를 판단.
  /// iOS는 didConnect 이후 반환되므로 대부분 첫 시도에 성공한다.
  Future<bool> _waitDeviceReady() async {
    const attempts = 12;
    for (var i = 0; i < attempts; i++) {
      try {
        final battery = await _platform
            .invokeMethod('getBatteryLevel')
            .timeout(const Duration(seconds: 3));
        if (battery != null) return true;
      } catch (_) {
        // 아직 준비 안 됨 → 재시도
      }
      await Future.delayed(const Duration(milliseconds: 700));
    }
    return false;
  }

  void _setConnecting(bool value) {
    if (!mounted) return;
    setState(() => _connecting = value);
  }

  // 안전한 이름/주소 추출
  String _deviceName(ScanResult r) {
    final adv = r.device.advName;
    final plat = r.device.platformName;
    if (adv.isNotEmpty) return adv;
    if (plat.isNotEmpty) return plat;
    return '(이름 없음)';
    // 필요시 r.advertisementData.advName 등 추가
  }

  String? _deviceAddress(BluetoothDevice d) {
    try {
      // FlutterBluePlus v1
      // ignore: deprecated_member_use
      return d.remoteId.str;
    } catch (_) {
      try {
        // 구버전
        // ignore: deprecated_member_use
        return d.id.toString();
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const SubAppBar(title: "스마트링 연결"),
        body: Stack(
          children: [
            AbsorbPointer(
              absorbing: _connecting,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    RingConnectStatusCard(
                      isConnecting: _connecting,
                      isScanning: _isScanning,
                      startScan: _startScan,
                    ),
                    const SizedBox(height: 16),
                    RingConnectListCard(
                      connectList: _connectList,
                      onConnect: connectByAddress,
                    ),
                  ],
                ),
              ),
            ),
            if (_connecting)
              Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
