// Source: colmi_r02_client/colmi_r02_client/set_time.py parse_set_time_packet (MIT)
// Source: Gadgetbridge YawellRingDeviceSupport setTime response (AGPL-3.0)

/// Device-reported capabilities from 0x01 setTime response.
class RingProbeCapabilities {
  const RingProbeCapabilities({
    this.supportsTemperature = false,
    this.supportsSpo2 = true,
    this.supportsBloodPressure = false,
    this.supportsStress = true,
    this.supportsHrv = false,
    this.newSleepProtocol = false,
    this.supportsManualHeart = true,
  });

  final bool supportsTemperature;
  final bool supportsSpo2;
  final bool supportsBloodPressure;
  final bool supportsStress;
  final bool supportsHrv;
  final bool newSleepProtocol;
  final bool supportsManualHeart;

  /// colmi_r02_client set_time.parse_set_time_packet
  factory RingProbeCapabilities.fromSetTimeResponse(List<int> packet) {
    if (packet.isEmpty || packet[0] != 0x01 || packet.length < 15) {
      return const RingProbeCapabilities();
    }
    final b = packet.sublist(1, 15);
    final flags3 = b[3] & 0xff;
    final flags11 = b[11] & 0xff;
    final flags13 = b[13] & 0xff;
    return RingProbeCapabilities(
      supportsTemperature: b[0] == 1,
      supportsSpo2: (flags3 & 2) != 0,
      supportsBloodPressure: (flags3 & 4) != 0,
      supportsStress: (flags13 & 16) != 0,
      supportsHrv: (flags13 & 32) != 0,
      newSleepProtocol: b[8] == 1,
      supportsManualHeart: (flags11 & 1) != 0,
    );
  }
}
