// Source: Gadgetbridge YawellRingDeviceSupport onSendConfiguration (AGPL-3.0)
// Verified TX patterns in QRing btsnoop ring_timeline.txt (R08)

import '../codec/packet_codec.dart';
import '../ring_protocol_constants.dart';
import '../transport/ring_command_queue.dart';

class RingSettingStatus {
  const RingSettingStatus({required this.enabled, this.intervalMinutes});

  final bool enabled;
  final int? intervalMinutes;
}

/// Auto-monitoring prefs — all writes go to main 16B channel (handle 0x0010).
class RingSettingsCommand {
  RingSettingsCommand(this._queue);

  final RingCommandQueue _queue;

  Future<RingSettingStatus> writeHrSetting({
    required bool enabled,
    int intervalMinutes = 10,
  }) async {
    final packet = PacketCodec.makePacket(
      RingProtocolConstants.cmdAutoHrPref,
      [
        RingProtocolConstants.prefWrite,
        enabled ? 0x01 : 0x02,
        intervalMinutes.clamp(5, 60),
      ],
    );
    await _queue.writePacket(packet);
    return _readHrSetting();
  }

  Future<RingSettingStatus> readHrSetting() => _readHrSetting();

  Future<RingSettingStatus> _readHrSetting() async {
    final rsp = await _queue.transact(
      RingProtocolConstants.cmdAutoHrPref,
      PacketCodec.makePacket(RingProtocolConstants.cmdAutoHrPref, [
        RingProtocolConstants.prefRead,
      ]),
      timeout: const Duration(seconds: 5),
      predicate: (p) => (p[1] & 0xff) == RingProtocolConstants.prefRead,
    );
    return RingSettingStatus(
      enabled: (rsp[2] & 0xff) == 0x01,
      intervalMinutes: rsp.length > 3 ? rsp[3] & 0xff : null,
    );
  }

  Future<RingSettingStatus> writeSpo2Setting({required bool enabled}) async {
    await _queue.writePacket(
      PacketCodec.makePacket(RingProtocolConstants.cmdAutoSpo2Pref, [
        RingProtocolConstants.prefWrite,
        enabled ? 0x01 : 0x00,
      ]),
    );
    return _readToggle(RingProtocolConstants.cmdAutoSpo2Pref);
  }

  Future<RingSettingStatus> readSpo2Setting() async {
    return _readToggle(RingProtocolConstants.cmdAutoSpo2Pref);
  }

  Future<RingSettingStatus> writeStressSetting({required bool enabled}) async {
    await _queue.writePacket(
      PacketCodec.makePacket(RingProtocolConstants.cmdAutoStressPref, [
        RingProtocolConstants.prefWrite,
        enabled ? 0x01 : 0x00,
      ]),
    );
    return _readToggle(RingProtocolConstants.cmdAutoStressPref);
  }

  Future<RingSettingStatus> readStressSetting() async {
    return _readToggle(RingProtocolConstants.cmdAutoStressPref);
  }

  Future<RingSettingStatus> writeHrvSetting({required bool enabled}) async {
    await _queue.writePacket(
      PacketCodec.makePacket(RingProtocolConstants.cmdAutoHrvPref, [
        RingProtocolConstants.prefWrite,
        enabled ? 0x01 : 0x00,
      ]),
    );
    return _readToggle(RingProtocolConstants.cmdAutoHrvPref);
  }

  Future<RingSettingStatus> readHrvSetting() async {
    return _readToggle(RingProtocolConstants.cmdAutoHrvPref);
  }

  Future<RingSettingStatus> _readToggle(int opcode) async {
    final rsp = await _queue.transact(
      opcode,
      PacketCodec.makePacket(opcode, [RingProtocolConstants.prefRead]),
      timeout: const Duration(seconds: 5),
      predicate: (p) => (p[1] & 0xff) == RingProtocolConstants.prefRead,
    );
    return RingSettingStatus(enabled: (rsp[2] & 0xff) == 0x01);
  }
}
