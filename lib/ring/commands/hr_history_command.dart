// Source: colmi_r02_client/colmi_r02_client/hr.py HeartRateLogParser (MIT)
// Source: Gadgetbridge YawellRingDeviceSupport HR sync (AGPL-3.0)

import '../codec/packet_codec.dart';
import '../ring_protocol_constants.dart';
import '../transport/ring_command_queue.dart';

class HeartRateSample {
  const HeartRateSample({required this.bpm, required this.timestamp});
  final int bpm;
  final DateTime timestamp;
}

class HeartRateLog {
  HeartRateLog({
    required this.samples,
    required this.dayStart,
    required this.intervalMinutes,
  });

  final List<HeartRateSample> samples;
  final DateTime dayStart;
  final int intervalMinutes;
}

class NoHeartRateData {
  const NoHeartRateData();
}

sealed class HeartRateLogResult {}

class HeartRateLogData extends HeartRateLogResult {
  HeartRateLogData(this.log);
  final HeartRateLog log;
}

class HeartRateNoData extends HeartRateLogResult {
  HeartRateNoData();
}

class HrHistoryCommand {
  HrHistoryCommand(this._queue);

  final RingCommandQueue _queue;

  /// Fetch HR log for [day] (midnight UTC).
  Future<HeartRateLogResult> fetchDay(DateTime day) async {
    final midnight = DateTime.utc(day.year, day.month, day.day);
    final epochSec = midnight.millisecondsSinceEpoch ~/ 1000;
    final subData = PacketCodec.packUint32Le(epochSec);
    final packet = PacketCodec.makePacket(
      RingProtocolConstants.cmdSyncHeartRate,
      subData,
    );
    final packetsFuture = _queue.collectPackets(
      RingProtocolConstants.cmdSyncHeartRate,
      timeout: const Duration(seconds: 15),
      done: (p, all) => _isHrComplete(p, all),
    );
    await _queue.writePacket(packet, timeout: const Duration(seconds: 5));
    final packets = await packetsFuture;

    return _parse(packets, midnight);
  }

  Future<HeartRateLog?> fetchDayLog(DateTime day) async {
    final result = await fetchDay(day);
    return switch (result) {
      HeartRateLogData(:final log) => log,
      HeartRateNoData() => null,
    };
  }

  bool _isHrComplete(List<int> packet, List<List<int>> all) {
    final sub = packet[1] & 0xff;
    if (sub == 0xff) return true;
    if (sub == 0) return false;
    if (all.isEmpty) return false;
    final header = all.firstWhere((p) => (p[1] & 0xff) == 0, orElse: () => []);
    if (header.isEmpty) return false;
    final size = header[2] & 0xff;
    return sub == size - 1;
  }

  HeartRateLogResult _parse(
    List<List<int>> packets,
    DateTime dayStart,
  ) {
    if (packets.isEmpty) return HeartRateNoData();
    if (packets.any((p) => (p[1] & 0xff) == 0xff)) {
      return HeartRateNoData();
    }

    final header = packets.firstWhere(
      (p) => (p[1] & 0xff) == 0,
      orElse: () => [],
    );
    if (header.isEmpty) return HeartRateNoData();

    final size = header[2] & 0xff;
    final range = header[3] & 0xff;
    final interval = range > 0 ? range : 5;

    final raw = List<int>.filled(size * 13, -1);
    var index = 0;

    for (final packet in packets) {
      final sub = packet[1] & 0xff;
      if (sub == 0) continue;
      if (sub == 1) {
        for (var i = 6; i < 15; i++) {
          if (index < raw.length) raw[index++] = packet[i] & 0xff;
        }
      } else {
        for (var i = 2; i < 15; i++) {
          if (index < raw.length) raw[index++] = packet[i] & 0xff;
        }
      }
    }

    var hr = raw.length > 288 ? raw.sublist(0, 288) : List<int>.from(raw);
    while (hr.length < 288) {
      hr.add(0);
    }

    final now = DateTime.now().toUtc();
    if (_isSameDay(dayStart, now)) {
      final slots = (now.hour * 60 + now.minute) ~/ interval;
      for (var i = slots; i < hr.length; i++) {
        hr[i] = 0;
      }
    }

    final samples = <HeartRateSample>[];
    for (var i = 0; i < hr.length; i++) {
      final bpm = hr[i];
      if (bpm > 0) {
        samples.add(
          HeartRateSample(
            bpm: bpm,
            timestamp: dayStart.add(Duration(minutes: i * interval)),
          ),
        );
      }
    }

    return HeartRateLogData(
      HeartRateLog(
        samples: samples,
        dayStart: dayStart,
        intervalMinutes: interval,
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
