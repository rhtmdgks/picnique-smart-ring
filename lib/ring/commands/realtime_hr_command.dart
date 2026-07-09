// Source: colmi_r06_fbp requestHeartRate + 0x69 parser (BSD-3-Clause)
// Source: Gadgetbridge YawellRingDeviceSupport CMD_MANUAL_HEART_RATE (AGPL-3.0)
// Source: QRing btsnoop — 0x69 stream → 0x6a finalize

import 'dart:async';

import '../codec/packet_codec.dart';
import '../ring_protocol_constants.dart';
import '../transport/ring_command_queue.dart';
import 'manual_measure_codec.dart';

class LiveHrResult {
  const LiveHrResult({required this.bpm, required this.errorCode});
  final int bpm;
  final int errorCode;

  bool get success => errorCode == 0 && bpm > 0;
  bool get notWorn => errorCode == 1;
}

class RealtimeHrCommand {
  RealtimeHrCommand(this._queue);

  final RingCommandQueue _queue;
  int _measureEpoch = 0;
  Future<void>? _exclusiveMeasure;

  void requestCancel() => _measureEpoch++;

  /// Stop all manual-measure subtypes (0x6a) — auto→manual handoff.
  Future<void> teardownAll() async {
    requestCancel();
    for (final subtype in const [
      RingProtocolConstants.manualHrSubtype,
      RingProtocolConstants.manualSpo2Subtype,
      RingProtocolConstants.manualStressSubtype,
    ]) {
      await _stopSubtype(subtype);
    }
    _queue.clearLatestOpcode(RingProtocolConstants.cmdStopRealTime);
  }

  Future<LiveHrResult> measureStressOnce({
    Duration streamWait = const Duration(seconds: 30),
    Duration timeout = const Duration(seconds: 40),
  }) =>
      measureSubtype(
        RingProtocolConstants.manualStressSubtype,
        streamWait: streamWait,
        timeout: timeout,
      );

  /// On-demand HR: 0x69 start → stream poll up to 30s → 0x6a finalize → stop.
  Future<LiveHrResult> measureOnce({
    Duration streamWait = const Duration(seconds: 30),
    Duration timeout = const Duration(seconds: 40),
  }) =>
      measureSubtype(
        RingProtocolConstants.manualHrSubtype,
        streamWait: streamWait,
        timeout: timeout,
      );

  Future<LiveHrResult> measureSubtype(
    int subtype, {
    required Duration streamWait,
    required Duration timeout,
  }) =>
      _runExclusive(() async {
        final epoch = _measureEpoch;
        bool cancelled() => epoch != _measureEpoch;

        _queue.startListening();
        _queue.clearLatestOpcode(RingProtocolConstants.cmdStopRealTime);
        var lastSample = 0;
        StreamSubscription<List<int>>? sub;

        try {
          sub = _queue
              .pushStream(RingProtocolConstants.cmdManualHeartRate)
              .listen((packet) {
            final v = ManualMeasureCodec.parseStreamSample(packet, subtype);
            if (v != null) lastSample = v;
          });

          final start = PacketCodec.makePacket(
            RingProtocolConstants.cmdManualHeartRate,
            ManualMeasureCodec.startPayload(subtype),
          );
          await _queue.writePacket(
            start,
            priority: RingCommandPriority.manual,
            timeout: const Duration(seconds: 5),
          );

          lastSample = await _pollStreamSample(
            streamWait: streamWait,
            cancelled: cancelled,
            readSample: () => lastSample,
          );

          if (cancelled()) {
            return const LiveHrResult(bpm: 0, errorCode: 2);
          }

          final finalize = PacketCodec.makePacket(
            RingProtocolConstants.cmdStopRealTime,
            ManualMeasureCodec.finalizePayload(subtype, lastSample: lastSample),
          );
          final response = await _queue.transact(
            RingProtocolConstants.cmdStopRealTime,
            finalize,
            timeout: timeout,
            priority: RingCommandPriority.manual,
            allowCached: false,
            predicate: (p) => (p[1] & 0xff) == subtype,
          );

          final parsed = ManualMeasureCodec.parseFinalize(response, subtype);
          if (parsed.errorCode != 0) {
            return LiveHrResult(bpm: 0, errorCode: parsed.errorCode);
          }
          if (parsed.value > 0) {
            return LiveHrResult(bpm: parsed.value, errorCode: 0);
          }
          if (lastSample > 0) {
            return LiveHrResult(bpm: lastSample, errorCode: 0);
          }
          return const LiveHrResult(bpm: 0, errorCode: 2);
        } on TimeoutException {
          if (lastSample > 0) {
            return LiveHrResult(bpm: lastSample, errorCode: 0);
          }
          return const LiveHrResult(bpm: 0, errorCode: 2);
        } finally {
          await sub?.cancel();
          if (!cancelled()) {
            await _stopSubtype(subtype);
          }
        }
      });

  Future<void> stop() => _stopSubtype(RingProtocolConstants.manualHrSubtype);

  Future<int> _pollStreamSample({
    required Duration streamWait,
    required bool Function() cancelled,
    required int Function() readSample,
  }) async {
    final deadline = DateTime.now().add(streamWait);
    while (DateTime.now().isBefore(deadline)) {
      if (cancelled()) return readSample();
      final v = readSample();
      if (v > 0) return v;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return readSample();
  }

  Future<T> _runExclusive<T>(Future<T> Function() fn) async {
    while (_exclusiveMeasure != null) {
      await _exclusiveMeasure;
    }
    final gate = Completer<void>();
    _exclusiveMeasure = gate.future;
    try {
      return await fn();
    } finally {
      if (!gate.isCompleted) gate.complete();
      if (identical(_exclusiveMeasure, gate.future)) {
        _exclusiveMeasure = null;
      }
    }
  }

  Future<void> _stopSubtype(int subtype) async {
    final stop = PacketCodec.makePacket(
      RingProtocolConstants.cmdStopRealTime,
      ManualMeasureCodec.stopPayload(subtype),
    );
    try {
      await _queue.writePacket(stop, priority: RingCommandPriority.manual);
    } catch (_) {}
  }

  static LiveHrResult parsePacket(List<int> data) {
    final parsed = ManualMeasureCodec.parseFinalize(
      data,
      data.length > 1 ? data[1] & 0xff : 0,
    );
    return LiveHrResult(bpm: parsed.value, errorCode: parsed.errorCode);
  }

  /// Real-time streaming enable — Gadgetbridge CMD_REALTIME_HEART_RATE 0x1E
  Future<void> setRealtimeStream(bool enable) async {
    final packet = PacketCodec.makePacket(
      RingProtocolConstants.cmdRealtimeHeartRate,
      [enable ? 0x01 : 0x02],
    );
    await _queue.writePacket(packet);
  }
}
