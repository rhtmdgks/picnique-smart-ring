// Source: colmi_r06_fbp requestSpO2 (BSD-3-Clause)
// Source: ring-health-tracker ColmiProtocol.parseSpo2Packet (Gadgetbridge-derived, AGPL-3.0)

import '../codec/big_data_codec.dart';
import '../codec/packet_codec.dart';
import '../ring_protocol_constants.dart';
import '../transport/ring_command_queue.dart';
import 'realtime_hr_command.dart';

class Spo2Sample {
  const Spo2Sample({required this.timestamp, required this.percent});
  final DateTime timestamp;
  final int percent;
}

class Spo2Command {
  Spo2Command(this._queue);

  final RingCommandQueue _queue;

  /// On-demand SpO2 via 0x69/0x03 → stream → 0x6a finalize (btsnoop R08).
  Future<LiveHrResult> measureOnce({
    Duration streamWait = const Duration(seconds: 30),
    Duration timeout = const Duration(seconds: 40),
  }) async {
    final hr = RealtimeHrCommand(_queue);
    return hr.measureSubtype(
      RingProtocolConstants.manualSpo2Subtype,
      streamWait: streamWait,
      timeout: timeout,
    );
  }

  /// Historical SpO2 via V2 big data 0xBC/0x2A.
  Future<List<Spo2Sample>> fetchHistory() async {
    final cmd = BigDataCodec.makeRequest(RingProtocolConstants.bigDataTypeSpo2);
    final packet = await _queue.transactBigData(
      cmd,
      RingProtocolConstants.bigDataTypeSpo2,
      timeout: const Duration(seconds: 30),
    );
    return parseHistoryPacket(packet);
  }

  /// ring-health-tracker parseSpo2Packet
  static List<Spo2Sample> parseHistoryPacket(List<int> value) {
    if (value.length < 6) return [];
    if (value[0] != RingProtocolConstants.cmdBigDataV2) return [];
    if (value[1] != RingProtocolConstants.bigDataTypeSpo2) return [];

    final length = PacketCodec.unpackUint16Le(value, 2);
    final samples = <Spo2Sample>[];
    var idx = 6;
    var lastDaysAgo = -1;

    while (lastDaysAgo != 0 && idx - 6 < length && idx < value.length) {
      final daysAgo = value[idx] & 0xff;
      lastDaysAgo = daysAgo;
      idx++;
      final day = DateTime.now().toUtc().subtract(Duration(days: daysAgo));
      final dayStart = DateTime.utc(day.year, day.month, day.day);

      for (var hour = 0; hour < 24; hour++) {
        if (idx + 1 >= value.length || idx - 6 >= length) break;
        final min = value[idx] & 0xff;
        idx++;
        final max = value[idx] & 0xff;
        idx++;
        if (min > 0 && max > 0) {
          samples.add(
            Spo2Sample(
              timestamp: dayStart.add(Duration(hours: hour)),
              percent: (min + max) ~/ 2,
            ),
          );
        }
      }
    }
    return samples;
  }
}
