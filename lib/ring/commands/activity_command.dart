// Source: colmi_r02_client/colmi_r02_client/steps.py SportDetailParser (MIT)
// Source: colmi_r06_fbp parseNotifStepsCaloriesDistanceData (BSD-3-Clause)

import '../codec/packet_codec.dart';
import '../ring_protocol_constants.dart';
import '../transport/ring_command_queue.dart';

class ActivitySample {
  const ActivitySample({
    required this.timestamp,
    required this.steps,
    required this.calories,
    required this.distanceMeters,
  });

  final DateTime timestamp;
  final int steps;
  final int calories;
  final int distanceMeters;
}

class LiveActivitySnapshot {
  const LiveActivitySnapshot({
    required this.steps,
    required this.calories,
    required this.distanceMeters,
  });

  final int steps;
  final int calories;
  final int distanceMeters;
}

class ActivityCommand {
  ActivityCommand(this._queue);

  final RingCommandQueue _queue;

  /// Historical activity for [daysAgo] from ring clock (0=today).
  Future<List<ActivitySample>> fetchHistory({int daysAgo = 0}) async {
    final packet = PacketCodec.makePacket(
      RingProtocolConstants.cmdSyncActivity,
      [daysAgo, 0x0f, 0x00, 0x5f, 0x01],
    );
    final packetsFuture = _queue.collectPackets(
      RingProtocolConstants.cmdSyncActivity,
      timeout: const Duration(seconds: 15),
      done: (p, all) {
        final nr = p[1] & 0xff;
        if (nr == 0xff || nr == 0xf0) return true;
        if (p.length < 7) return false;
        return (p[5] & 0xff) == (p[6] & 0xff) - 1;
      },
    );
    await _queue.writePacket(packet);
    final packets = await packetsFuture;

    return _parseHistory(packets);
  }

  List<ActivitySample> _parseHistory(List<List<int>> packets) {
    if (packets.isEmpty) return [];
    if (packets.first[1] == 0xff) return [];

    var newCalorieProtocol = false;
    final details = <ActivitySample>[];

    for (final packet in packets) {
      final nr = packet[1] & 0xff;
      if (nr == 0xf0) {
        if (packet.length > 3 && packet[3] == 1) newCalorieProtocol = true;
        continue;
      }
      if (nr == 0xff) continue;

      final year = 2000 + PacketCodec.bcdToDecimal(packet[1]);
      final month = PacketCodec.bcdToDecimal(packet[2]);
      final day = PacketCodec.bcdToDecimal(packet[3]);
      final timeIndex = packet[4] & 0xff;
      var calories = PacketCodec.unpackUint16Le(packet, 7);
      if (newCalorieProtocol) calories *= 10;
      final steps = PacketCodec.unpackUint16Le(packet, 9);
      final distance = PacketCodec.unpackUint16Le(packet, 11);

      details.add(
        ActivitySample(
          timestamp: DateTime.utc(
            year,
            month,
            day,
            timeIndex ~/ 4,
            (timeIndex % 4) * 15,
          ),
          steps: steps,
          calories: calories,
          distanceMeters: distance,
        ),
      );
    }
    return details;
  }

  /// colmi_r06_fbp parseNotifStepsCaloriesDistanceData — 0x73/0x12 push
  static LiveActivitySnapshot? parseLiveNotification(List<int> data) {
    if (data.length < 11) return null;
    if (data[0] != RingProtocolConstants.cmdNotification) return null;
    if (data[1] != RingProtocolConstants.notifLiveActivity) return null;

    final steps =
        ((data[2] & 0xff) << 16) | ((data[3] & 0xff) << 8) | (data[4] & 0xff);
    final rawCal =
        ((data[5] & 0xff) << 16) | ((data[6] & 0xff) << 8) | (data[7] & 0xff);
    final calories = rawCal ~/ 1000;
    final distance =
        ((data[8] & 0xff) << 16) | ((data[9] & 0xff) << 8) | (data[10] & 0xff);

    return LiveActivitySnapshot(
      steps: steps,
      calories: calories,
      distanceMeters: distance,
    );
  }
}
