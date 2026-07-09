// Source: colmi_r06_fbp parseBatteryData (BSD-3-Clause)
// Source: colmi_r02_client/colmi_r02_client/battery.py (MIT)

import '../codec/packet_codec.dart';
import '../ring_protocol_constants.dart';
import '../transport/ring_command_queue.dart';

class BatteryStatus {
  const BatteryStatus({required this.level, required this.charging});
  final int level;
  final bool charging;
}

class BatteryCommand {
  BatteryCommand(this._queue);

  final RingCommandQueue _queue;

  Future<BatteryStatus> query() async {
    final packet = PacketCodec.makePacket(RingProtocolConstants.cmdBattery);
    final response = await _queue.transact(
      RingProtocolConstants.cmdBattery,
      packet,
      timeout: const Duration(seconds: 3),
    );
    return parseDirect(response);
  }

  /// colmi_r06_fbp parseBatteryData
  static BatteryStatus parseDirect(List<int> data) {
    assert(data[0] == RingProtocolConstants.cmdBattery);
    return BatteryStatus(
      level: data[1] & 0xff,
      charging: data[2] == 1,
    );
  }

  /// colmi_r06_fbp parseNotifBatteryData — 0x73/0x0c push notification
  static BatteryStatus? parseNotification(List<int> data) {
    if (data.length < 4) return null;
    if (data[0] != RingProtocolConstants.cmdNotification) return null;
    if (data[1] != RingProtocolConstants.notifBatteryLevel) return null;
    return BatteryStatus(
      level: data[2] & 0xff,
      charging: data[3] == 1,
    );
  }
}
