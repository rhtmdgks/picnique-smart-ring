// Source: QRing btsnoop — TX `04 02 0a 53 4d-2d…` after setTime (handle 0x0010)

import '../codec/packet_codec.dart';
import '../ring_protocol_constants.dart';
import '../transport/ring_command_queue.dart';

class PhoneNameCommand {
  PhoneNameCommand(this._queue);

  final RingCommandQueue _queue;

  /// Send phone model name so ring accepts companion binding (R08+).
  Future<void> send(String phoneName) async {
    final name = phoneName.trim();
    if (name.isEmpty) return;
    final ascii = name.codeUnits.take(12).toList();
    final packet = PacketCodec.makePacket(
      RingProtocolConstants.cmdPhoneName,
      [0x02, ascii.length, ...ascii],
    );
    try {
      await _queue.transact(
        RingProtocolConstants.cmdPhoneName,
        packet,
        timeout: const Duration(seconds: 3),
      );
    } catch (_) {}
  }
}
