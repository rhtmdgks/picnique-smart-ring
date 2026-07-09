// Source: colmi_r06_fbp/lib/main.dart demo flow (BSD-3-Clause)

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/repository/ring_repository.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/transport/ring_permissions.dart';

/// Minimal example: scan → connect → setTime → measure HR once.
///
/// Usage: navigate to [RingDemoScreen] from debug menu or run standalone.
class RingDemoScreen extends StatefulWidget {
  const RingDemoScreen({super.key});

  @override
  State<RingDemoScreen> createState() => _RingDemoScreenState();
}

class _RingDemoScreenState extends State<RingDemoScreen> {
  final _repo = RingRepository.instance;
  final _log = <String>[];
  List<ScanResult> _results = [];
  bool _busy = false;

  Future<void> _scan() async {
    setState(() {
      _busy = true;
      _log.add('Scanning…');
    });
    if (!await RingPermissions.ensureReady()) {
      _log.add('BT permissions/adapter not ready');
      setState(() => _busy = false);
      return;
    }
    await RingRepository.stopScan();
    _results = [];
    final results = await RingRepository.scan();
    final sub = results.listen((r) {
      setState(() {
        _results = r.where(RingRepository.isYawellRingDevice).toList();
      });
    });
    await Future<void>.delayed(const Duration(seconds: 6));
    await sub.cancel();
    await RingRepository.stopScan();
    _log.add('Found ${_results.length} device(s)');
    setState(() => _busy = false);
  }

  Future<void> _connectAndMeasure(ScanResult result) async {
    setState(() {
      _busy = true;
      _log.add('Connecting ${result.device.platformName}…');
    });
    try {
      if (!await _repo.connect(result.device)) {
        _log.add('Connect failed');
        return;
      }
      _log.add('Connected — syncing time…');
      await _repo.setTime.execute();
      _log.add('Measuring HR…');
      final hr = await _repo.realtimeHr.measureOnce();
      if (hr.success) {
        _log.add('HR = ${hr.bpm} bpm');
      } else if (hr.notWorn) {
        _log.add('HR failed — ring not worn');
      } else {
        _log.add('HR failed code=${hr.errorCode}');
      }
    } catch (e) {
      _log.add('Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Colmi Ring Demo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : _scan,
                  child: const Text('Scan'),
                ),
                const SizedBox(width: 8),
                if (_repo.isConnected)
                  Text('Connected: ${_repo.deviceName ?? ""}'),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final r = _results[i];
                return ListTile(
                  title: Text(r.device.platformName),
                  subtitle: Text(r.device.remoteId.str),
                  onTap: _busy ? null : () => _connectAndMeasure(r),
                );
              },
            ),
          ),
          Expanded(
            child: ListView(
              children: _log.map((l) => Text(l)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
