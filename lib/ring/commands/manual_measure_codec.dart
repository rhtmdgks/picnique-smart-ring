// Source: QRing btsnoop ring_timeline.txt (R08 manual 0x69/0x6a)
// Source: Ring_프로토콜_분석.md §5

import '../ring_protocol_constants.dart';

/// Parses 0x69 stream and 0x6a finalize frames for on-demand measures.
abstract final class ManualMeasureCodec {
  /// Last stable sample from 0x69 push stream (byte[2]≥0x60 → value byte[8]).
  static int? parseStreamSample(List<int> packet, int subtype) {
    if (packet.length < 9) return null;
    if ((packet[0] & 0xff) != RingProtocolConstants.cmdManualHeartRate) {
      return null;
    }
    if ((packet[1] & 0xff) != subtype) return null;

    final flag = packet[2] & 0xff;
    if (packet.length > 8) {
      final direct = packet[8] & 0xff;
      if (_validMetric(subtype, direct)) return direct;
    }
    if (flag >= RingProtocolConstants.manualStreamStableFlag) {
      final v = packet[8] & 0xff;
      if (_validMetric(subtype, v)) return v;
    }

    if (packet.length >= 8) {
      final le = (packet[6] & 0xff) | ((packet[7] & 0xff) << 8);
      if (_validMetric(subtype, le)) return le;
      final b6 = packet[6] & 0xff;
      if (_validMetric(subtype, b6)) return b6;
    }
    return null;
  }

  /// 0x6a finalize response — value in byte[2] when byte[3]==0 (btsnoop 6a015f).
  static ({int value, int errorCode}) parseFinalize(
    List<int> packet,
    int subtype,
  ) {
    if (packet.length < 4) return (value: 0, errorCode: 2);
    if ((packet[0] & 0xff) != RingProtocolConstants.cmdStopRealTime) {
      return (value: 0, errorCode: 2);
    }
    if ((packet[1] & 0xff) != subtype) return (value: 0, errorCode: 2);

    final b2 = packet[2] & 0xff;
    final b3 = packet[3] & 0xff;
    if (b3 == 0 && _validMetric(subtype, b2)) {
      return (value: b2, errorCode: 0);
    }
    if (b2 == 0 && _validMetric(subtype, b3)) {
      return (value: b3, errorCode: 0);
    }
    if (b2 == 0 && b3 == 0) return (value: 0, errorCode: 0);
    return (value: 0, errorCode: b2 != 0 ? b2 : b3);
  }

  static List<int> startPayload(int subtype) {
    if (subtype == RingProtocolConstants.manualSpo2Subtype ||
        subtype == RingProtocolConstants.manualStressSubtype) {
      return [subtype, RingProtocolConstants.manualMeasureDurationSec];
    }
    return [subtype];
  }

  static List<int> finalizePayload(int subtype, {int? lastSample}) {
    switch (subtype) {
      case RingProtocolConstants.manualHrSubtype:
        return [
          subtype,
          lastSample ?? RingProtocolConstants.manualStreamStableFlag,
          0x00,
        ];
      case RingProtocolConstants.manualSpo2Subtype:
        return [subtype, 0x00];
      case RingProtocolConstants.manualStressSubtype:
        return [subtype, 0x30];
      default:
        return [subtype, 0x00];
    }
  }

  static List<int> stopPayload(int subtype) => [subtype, 0x00];

  static bool _validMetric(int subtype, int v) {
    if (v <= 0) return false;
    return switch (subtype) {
      RingProtocolConstants.manualHrSubtype => v >= 30 && v <= 220,
      RingProtocolConstants.manualSpo2Subtype => v >= 70 && v <= 100,
      RingProtocolConstants.manualStressSubtype => v >= 1 && v <= 100,
      _ => v < 250,
    };
  }
}
