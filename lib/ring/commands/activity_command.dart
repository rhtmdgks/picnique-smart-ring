// Source: colmi_r02_client/colmi_r02_client/steps.py SportDetailParser (MIT)
// Source: colmi_r06_fbp parseNotifStepsCaloriesDistanceData (BSD-3-Clause)

import 'package:flutter/foundation.dart';

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
  ///
  /// Packet stream (colmi_r02_client SportDetailParser):
  /// - first `0xf0` = header (calorie protocol flag) — keep collecting
  /// - first `0xff` = no data — done
  /// - data slots until `packet[5] == packet[6] - 1` (last index)
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
        // Empty history — only terminal empty marker ends early.
        if (nr == 0xff) return true;
        // Header 0xf0 must NOT end collection (was bug: returned true → 0 samples).
        if (nr == 0xf0) return false;
        if (p.length < 7) return false;
        // Last data chunk: index == total-1
        return (p[5] & 0xff) == (p[6] & 0xff) - 1;
      },
    );
    await _queue.writePacket(packet);
    final packets = await packetsFuture;

    return parseHistoryPackets(packets);
  }

  /// Visible for tests — colmi_r02_client SportDetailParser.
  @visibleForTesting
  static List<ActivitySample> parseHistoryPackets(List<List<int>> packets) {
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

      // Ring clock = local wall time (same as sleep / Gadgetbridge).
      details.add(
        ActivitySample(
          timestamp: DateTime(
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

  /// Native `syncSportDetail` shape for DB upsert.
  Future<List<Map<String, dynamic>>> fetchDetailMaps({int daysAgo = 0}) async {
    final samples = await fetchHistory(daysAgo: daysAgo);
    return samples
        .map(
          (s) => <String, dynamic>{
            'year': s.timestamp.year,
            'month': s.timestamp.month,
            'day': s.timestamp.day,
            'timeIndex':
                s.timestamp.hour * 4 + (s.timestamp.minute ~/ 15),
            'calorie': s.calories,
            'walkSteps': s.steps,
            'distance': s.distanceMeters,
            'runSteps': 0,
          },
        )
        .toList();
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
