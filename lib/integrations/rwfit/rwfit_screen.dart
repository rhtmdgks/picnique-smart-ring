import 'package:flutter/material.dart';
import 'package:rwfit_ble/rwfit_ble.dart';
import 'rwfit_session.dart';

/// Isolated RWFit UI; do not mount beside the legacy QRing transport.
class RwfitScreen extends StatefulWidget {
  const RwfitScreen({super.key, required this.session});
  final RwfitSession session;
  @override
  State<RwfitScreen> createState() => _RwfitScreenState();
}
class _RwfitScreenState extends State<RwfitScreen> {
  bool _acting = false;
  String? _error;
  Future<void> _perform(Future<void> Function() action) async {
    if (_acting) return;
    setState(() { _acting = true; _error = null; });
    try { await action(); } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _acting = false); }
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.session,
    builder: (context, _) {
      final s = widget.session;
      final disabled = _acting || s.busy;
      return Scaffold(
        appBar: AppBar(title: const Text('Picnique · RWFit 스마트링')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(s.ready ? '연결 준비 완료' : '장치 상태: ${s.state.name}'),
          if (s.device != null) Text(s.device!.name),
          if (s.battery != null) Text('배터리 ${s.battery}%'),
          if (_error != null || s.error != null)
            SelectableText(_error ?? s.error!, style: const TextStyle(color: Colors.red)),
          if (s.savedDevice != null && !s.ready) OutlinedButton(
            onPressed: disabled ? null : () => _perform(s.reconnectSaved),
            child: Text('최근 기기 재연결: ${s.savedDevice!.name}')),
          if (s.savedDevice != null) TextButton(
            onPressed: disabled ? null : () => _perform(s.forgetBinding),
            child: const Text('저장된 기기 연결 해제 및 삭제')),
          const SizedBox(height: 16),
          FilledButton(onPressed: disabled ? null : () => _perform(s.scan),
            child: Text(s.scanning ? '다시 검색' : '스마트링 검색')),
          for (final d in s.devices) ListTile(
            title: Text(d.name.isEmpty ? '이름 없는 기기' : d.name),
            subtitle: Text('${s.identity(d)} · ${d.rssi} dBm'),
            onTap: disabled ? null : () => _perform(() => s.connect(d)),
          ),
          if (s.ready) ...[
            const Divider(),
            const Text('건강 측정은 한 항목씩 실행합니다. 지원하지 않는 기능은 장치에서 오류가 반환될 수 있습니다.'),
            Wrap(spacing: 8, children: [
              for (final item in const {
                RealtimeMetric.hr: '심박수', RealtimeMetric.bloodOxy: '혈중산소',
                RealtimeMetric.hrv: 'HRV', RealtimeMetric.pressure: '스트레스',
              }.entries) OutlinedButton(
                onPressed: disabled ? null : () => _perform(() => s.measure(item.key)),
                child: Text(item.value),
              ),
            ]),
            if (s.latestMeasurement != null)
              Text('최근 수신값: ${s.latestMeasurement!.value} (${s.latestMeasurement!.type?.name ?? "알 수 없는 형식"})'),
            Text('단일 터치 수: ${s.singleTaps}'),
            FilledButton(onPressed: disabled ? null : () => _perform(s.syncHistory),
              child: const Text('장치 이력 가져오기')),
            const Text('SDK 원본은 로컬 DB에 보관합니다. 확인된 심박·산소·스트레스·수면·15분 활동 데이터만 차트에 반영합니다.'),
            for (final result in s.history) Text('${result.type}: ${result.data.length}개 레코드'),
          ],
          OutlinedButton(onPressed: disabled ? null : () => _perform(s.disconnect),
            child: const Text('연결 해제')),
          if (disabled) const LinearProgressIndicator(),
        ]),
      );
    },
  );
}
