// Source: colmi_r02_client/colmi_r02_client/reboot.py (MIT)
// Source: Gadgetbridge CMD_FACTORY_RESET / CMD_POWER_OFF (AGPL-3.0)

import '../codec/packet_codec.dart';
import '../ring_protocol_constants.dart';
import '../transport/ring_command_queue.dart';

class RebootCommand {
  RebootCommand(this._queue);

  final RingCommandQueue _queue;

  Future<void> reboot() async {
    final packet = PacketCodec.makePacket(
      RingProtocolConstants.cmdPowerOff,
      [0x01],
    );
    await _queue.writePacket(packet);
  }

  Future<void> factoryReset() async {
    final packet = PacketCodec.makePacket(
      RingProtocolConstants.cmdFactoryReset,
      [0x66, 0x66],
    );
    await _queue.writePacket(packet);
  }
}
