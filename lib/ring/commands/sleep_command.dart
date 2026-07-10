// Source: ring-health-tracker ColmiProtocol.parseSleepPacket (Gadgetbridge-derived, AGPL-3.0)
// Source: Gadgetbridge YawellRingPacketHandler sleep (AGPL-3.0)

import '../codec/big_data_codec.dart';
import '../codec/packet_codec.dart';
import '../ring_protocol_constants.dart';
import '../transport/ring_command_queue.dart';

class SleepStageRaw {
  const SleepStageRaw({
    required this.start,
    required this.durationMinutes,
    required this.stageByte,
  });

  final DateTime start;
  final int durationMinutes;
  final int stageByte;
}

class SleepSessionRaw {
  const SleepSessionRaw({
    required this.start,
    required this.end,
    required this.stages,
  });

  final DateTime start;
  final DateTime end;
  final List<SleepStageRaw> stages;
}

/// Interface for derived sleep metrics — not implemented (per plan).
abstract class SleepDerivedMetrics {
  Future<Map<String, dynamic>> computeScore(SleepSessionRaw session);
}

class SleepCommand {
  SleepCommand(this._queue);

  final RingCommandQueue _queue;

  Future<List<SleepSessionRaw>> fetchHistory() async {
    final cmd = BigDataCodec.makeRequest(RingProtocolConstants.bigDataTypeSleep);
    final packet = await _queue.transactBigData(
      cmd,
      RingProtocolConstants.bigDataTypeSleep,
      timeout: const Duration(seconds: 30),
    );
    return parseSleepPacket(packet);
  }

  /// ring-health-tracker parseSleepPacket
  static List<SleepSessionRaw> parseSleepPacket(List<int> value) {
    if (value.length < 7) return [];
    if (value[0] != RingProtocolConstants.cmdBigDataV2) return [];
    if (value[1] != RingProtocolConstants.bigDataTypeSleep) return [];

    final length = PacketCodec.unpackUint16Le(value, 2);
    if (length < 2) return [];

    final daysInPacket = value[6] & 0xff;
    final sessions = <SleepSessionRaw>[];
    var idx = 7;

    for (var d = 0; d < daysInPacket; d++) {
      if (idx + 5 >= value.length) break;
      final daysAgo = value[idx] & 0xff;
      idx++;
      final dayBytes = value[idx] & 0xff;
      idx++;
      final sleepStart = PacketCodec.unpackUint16Le(value, idx);
      idx += 2;
      final sleepEnd = PacketCodec.unpackUint16Le(value, idx);
      idx += 2;

      // ring-health-tracker / Gadgetbridge: local midnight (ring clock = local).
      // UTC midnight shifts KST sleep by -9h → wrong day window / empty UI.
      final nowLocal = DateTime.now();
      final dayMidnight = DateTime(
        nowLocal.year,
        nowLocal.month,
        nowLocal.day,
      ).subtract(Duration(days: daysAgo));

      final DateTime startCal;
      if (sleepStart > sleepEnd) {
        startCal = dayMidnight.subtract(
          Duration(minutes: 1440 - sleepStart),
        );
      } else {
        startCal = dayMidnight.add(Duration(minutes: sleepStart));
      }

      final endCal = dayMidnight.add(Duration(minutes: sleepEnd));

      final stages = <SleepStageRaw>[];
      var stageTime = startCal;
      var j = 4;
      while (j < dayBytes && idx + 1 < value.length) {
        final stage = value[idx] & 0xff;
        idx++;
        final duration = value[idx] & 0xff;
        idx++;
        if (duration > 0) {
          stages.add(
            SleepStageRaw(
              start: stageTime,
              durationMinutes: duration,
              stageByte: stage,
            ),
          );
          stageTime = stageTime.add(Duration(minutes: duration));
        }
        j += 2;
      }

      sessions.add(
        SleepSessionRaw(
          start: startCal,
          end: endCal,
          stages: stages,
        ),
      );
    }
    return sessions;
  }
}
