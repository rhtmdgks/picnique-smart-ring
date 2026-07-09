// Source: colmi_r06_fbp requestHeartRate + 0x69 parser (BSD-3-Clause)
// Source: Gadgetbridge YawellRingDeviceSupport CMD_MANUAL_HEART_RATE (AGPL-3.0)
// Source: QRing btsnoop — 0x69 acquire window → 0x6a finalize (metric on 6a only)

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

  static const Duration _defaultTimeout = Duration(seconds: 40);

  void requestCancel() => _measureEpoch++;

  /// Stop all manual-measure subtypes (0x6a) — auto→manual handoff.
  Future<void> teardownAll() async {
    requestCancel();
    for (final subtype in const [
      RingProtocolConstants.manualHrSubtype,
      RingProtocolConstants.manualSpo2Subtype,
      RingProtocolConstants.manualStressMeasureSubtype,
      RingProtocolConstants.manualStressSubtype,
    ]) {
      await _stopSubtype(subtype);
    }
    _queue.clearLatestOpcode(RingProtocolConstants.cmdStopRealTime);
  }

  Future<LiveHrResult> measureStressOnce({
    Duration? streamWait,
    Duration timeout = _defaultTimeout,
  }) {
    final profile = ManualAcquireProfile.forSubtype(
      RingProtocolConstants.manualStressMeasureSubtype,
    );
    return measureSubtype(
      RingProtocolConstants.manualStressMeasureSubtype,
      streamWait: streamWait ?? profile.maxWait,
      minWait: profile.minWait,
      timeout: timeout,
    );
  }

  /// 0x69 start → raw PPG stream window → 0x6a finalize (metric on 6a byte[2] only).
  Future<LiveHrResult> measureOnce({
    Duration? streamWait,
    Duration timeout = _defaultTimeout,
  }) {
    final profile = ManualAcquireProfile.forSubtype(
      RingProtocolConstants.manualHrSubtype,
    );
    return measureSubtype(
      RingProtocolConstants.manualHrSubtype,
      streamWait: streamWait ?? profile.maxWait,
      minWait: profile.minWait,
      timeout: timeout,
    );
  }

  Future<LiveHrResult> measureSubtype(
    int subtype, {
    required Duration streamWait,
    required Duration minWait,
    required Duration timeout,
  }) =>
      _runExclusive(() async {
        final epoch = _measureEpoch;
        bool cancelled() => epoch != _measureEpoch;

        _queue.startListening();
        _queue.clearLatestOpcode(RingProtocolConstants.cmdStopRealTime);
        var streamReady = false;
        StreamSubscription<List<int>>? sub;

        try {
          sub = _queue
              .pushStream(RingProtocolConstants.cmdManualHeartRate)
              .listen((packet) {
            if (ManualMeasureCodec.isStreamReady(packet, subtype)) {
              streamReady = true;
            }
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

          await _pollAcquireWindow(
            minWait: minWait,
            streamWait: streamWait,
            cancelled: cancelled,
            isReady: () => streamReady,
          );

          if (cancelled()) {
            return const LiveHrResult(bpm: 0, errorCode: 2);
          }

          final finalize = PacketCodec.makePacket(
            RingProtocolConstants.cmdStopRealTime,
            ManualMeasureCodec.finalizePayload(subtype),
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
          return const LiveHrResult(bpm: 0, errorCode: 2);
        } on TimeoutException {
          return const LiveHrResult(bpm: 0, errorCode: 2);
        } finally {
          await sub?.cancel();
          if (!cancelled()) {
            await _stopSubtype(subtype);
          }
        }
      });

  Future<void> stop() => _stopSubtype(RingProtocolConstants.manualHrSubtype);

  /// Wait [minWait]..[streamWait]; early exit once stream ready after min.
  Future<void> _pollAcquireWindow({
    required Duration minWait,
    required Duration streamWait,
    required bool Function() cancelled,
    required bool Function() isReady,
  }) async {
    final started = DateTime.now();
    final deadline = started.add(streamWait);
    while (DateTime.now().isBefore(deadline)) {
      if (cancelled()) return;
      final elapsed = DateTime.now().difference(started);
      if (elapsed >= minWait && isReady()) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
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
