import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:io' show Platform;
import 'package:picnique_rosary_healthcare_smartring/services/ble_command_queue.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_connection_service.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_live_activity.dart';
import 'package:picnique_rosary_healthcare_smartring/util/BLERealtimeLogger.dart';
import 'package:provider/provider.dart';

import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_background_sync.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/setting/ring_connecting_overlay.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/setting/ring_connect_list_card.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/setting/ring_connect_status_card.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/sub_app_bar.dart';
import '../util/BLEUtil.dart'; // ensureBluetoothOn, printBattery 등
import '../util/ring_scan_message.dart';

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
  int _discoveredDuringScan = 0;
  String? _connectingDeviceName;

  @override
  void initState() {
    super.initState();
    _boot(); // 진입 즉시 블루투스 확인 + 스캔 시작
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _iosScanSub?.cancel();
    if (Platform.isAndroid) {
      FlutterBluePlus.stopScan();
    }
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
      _discoveredDuringScan = 0;
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
          _discoveredDuringScan++;
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
      const scanTimeout = Duration(seconds: 10);
      try {
        await BleCommandQueue.invoke('startScan', <String, dynamic>{
          'namePrefix': null, // uuidString 기준으로 사용
          'timeoutMs': scanTimeout.inMilliseconds,
        });
        // iOS 네이티브 startScan은 스캔 시작 직후 즉시 true를 반환한다.
        // UI가 조기 종료되지 않도록 전체 탐색 시간만큼 대기한다.
        await Future<void>.delayed(scanTimeout);
      } catch (e) {
        debugPrint('iOS startScan error: $e');
      } finally {
        await _stopScanOnly();
        _finishScan();
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
          _discoveredDuringScan = results.length;
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
      ).whenComplete(_finishScan);
    }
  }

  void _finishScan() {
    if (!mounted) return;
    setState(() => _isScanning = false);
    if (_discoveredDuringScan == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ringScanNotFoundMessage),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
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
        await BleCommandQueue.invoke('stopScan');
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
    final liveActivity = context.read<RingLiveActivity>();
    await _stopScanOnly();
    try {
      await BleCommandQueue.invoke('disconnect');
    } catch (_) {}
    try {
      const fgChannel = MethodChannel(
        'com.example.picnique_ring/foreground_service_channel',
      );
      await fgChannel.invokeMethod('stopService');
    } catch (_) {}
    try {
      await liveActivity.stop();
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
    final liveActivity = context.read<RingLiveActivity>();
    try {
      debugPrint('[CONNECT] start for $address');
      await _stopScanOnly();

      final found = _connectList.firstWhere(
        (e) => e['address'] == address,
        orElse: () => const <String, String>{},
      );
      final deviceName = (found['name']?.isNotEmpty ?? false)
          ? found['name']!
          : (ring.name?.trim().isNotEmpty ?? false)
              ? ring.name!
              : '(이름 없음)';

      if (mounted) {
        setState(() => _connectingDeviceName = deviceName);
      }

      final ok = await RingConnectionService.connect(
        address: address,
        deviceName: deviceName,
        ring: ring,
        liveActivity: liveActivity,
        sync: sync,
      );

      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연결되었습니다: ${ring.name ?? "(알 수 없음)"}')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('연결에 실패했습니다. 다시 시도해 주세요.')),
        );
      }
    } finally {
      _setConnecting(false);
    }
  }

  void _setConnecting(bool value, {String? deviceName}) {
    if (!mounted) return;
    setState(() {
      _connecting = value;
      if (value) {
        _connectingDeviceName = deviceName;
      } else {
        _connectingDeviceName = null;
      }
    });
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
                      discoveredCount: _discoveredDuringScan,
                      startScan: _startScan,
                    ),
                    const SizedBox(height: 16),
                    RingConnectListCard(
                      connectList: _connectList,
                      isScanning: _isScanning,
                      onConnect: connectByAddress,
                    ),
                  ],
                ),
              ),
            ),
            if (_connecting)
              RingConnectingOverlay(deviceName: _connectingDeviceName),
          ],
        ),
      ),
    );
  }
}
