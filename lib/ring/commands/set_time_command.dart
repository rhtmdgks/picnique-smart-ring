// Source: colmi_r02_client/colmi_r02_client/set_time.py (MIT)
// Source: colmi_r06_fbp Command.setDateTime (BSD-3-Clause)

import '../capability/ring_probe_capabilities.dart';
import '../codec/packet_codec.dart';
import '../ring_protocol_constants.dart';
import '../transport/ring_command_queue.dart';

class SetTimeCommand {
  SetTimeCommand(this._queue);

  final RingCommandQueue _queue;

  /// Sync ring clock + parse 0x01 capability probe (QRing-style).
  Future<RingProbeCapabilities?> execute([DateTime? target]) async {
    final utc = (target ?? DateTime.now()).toUtc();
    assert(utc.year >= 2000);
    final subData = [
      PacketCodec.byteToBcd(utc.year % 2000),
      PacketCodec.byteToBcd(utc.month),
      PacketCodec.byteToBcd(utc.day),
      PacketCodec.byteToBcd(utc.hour),
      PacketCodec.byteToBcd(utc.minute),
      PacketCodec.byteToBcd(utc.second),
      1,
    ];
    final packet = PacketCodec.makePacket(
      RingProtocolConstants.cmdSetDateTime,
      subData,
    );
    try {
      final response = await _queue.transact(
        RingProtocolConstants.cmdSetDateTime,
        packet,
        timeout: const Duration(seconds: 3),
      );
      return RingProbeCapabilities.fromSetTimeResponse(response);
    } catch (_) {
      return null;
    }
  }
}
