// Source: QRing btsnoop ring_timeline.txt (R08 manual 0x69/0x6a)
// Source: Ring_프로토콜_분석.md §5

import '../ring_protocol_constants.dart';

class ManualAcquireProfile {
  const ManualAcquireProfile({
    required this.minWait,
    required this.maxWait,
  });

  final Duration minWait;
  final Duration maxWait;

  static ManualAcquireProfile forSubtype(int subtype) => switch (subtype) {
        RingProtocolConstants.manualHrSubtype => const ManualAcquireProfile(
            minWait: Duration(seconds: 15),
            maxWait: Duration(seconds: 30),
          ),
        RingProtocolConstants.manualSpo2Subtype => const ManualAcquireProfile(
            minWait: Duration(seconds: 15),
            maxWait: Duration(seconds: 30),
          ),
        RingProtocolConstants.manualStressMeasureSubtype =>
          const ManualAcquireProfile(
            minWait: Duration(seconds: 28),
            maxWait: Duration(seconds: 45),
          ),
        _ => const ManualAcquireProfile(
            minWait: Duration(seconds: 15),
            maxWait: Duration(seconds: 30),
          ),
      };
}

/// Parses 0x69 stream and 0x6a finalize frames for on-demand measures.
abstract final class ManualMeasureCodec {
  /// 0x69 stream is raw PPG — **not** HR/SpO2/stress. Only readiness via byte[2].
  static bool isStreamReady(List<int> packet, int subtype) {
    if (packet.length < 3) return false;
    if ((packet[0] & 0xff) != RingProtocolConstants.cmdManualHeartRate) {
      return false;
    }
    if ((packet[1] & 0xff) != subtype) return false;
    final flag = packet[2] & 0xff;
    return switch (subtype) {
      RingProtocolConstants.manualStressMeasureSubtype =>
        flag == 0xa1 || flag >= RingProtocolConstants.manualStreamStableFlag,
      RingProtocolConstants.manualStressSubtype => flag >= 0x30,
      _ => flag >= RingProtocolConstants.manualStreamStableFlag,
    };
  }

  /// Final metric on 0x6a only (HR 6a015f→95, SpO2 6a0360→96, stress 6a0ba1→25).
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

    if (subtype == RingProtocolConstants.manualStressMeasureSubtype &&
        b3 == 0 &&
        b2 >= 0x89) {
      final score = b2 - 0x88;
      if (score >= 1 && score <= 100) {
        return (value: score, errorCode: 0);
      }
    }

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
        subtype == RingProtocolConstants.manualStressMeasureSubtype ||
        subtype == RingProtocolConstants.manualStressSubtype) {
      return [subtype, RingProtocolConstants.manualMeasureDurationSec];
    }
    return [subtype];
  }

  static List<int> finalizePayload(int subtype) {
    switch (subtype) {
      case RingProtocolConstants.manualHrSubtype:
        return [
          subtype,
          RingProtocolConstants.manualStreamStableFlag,
          0x00,
        ];
      case RingProtocolConstants.manualSpo2Subtype:
        return [subtype, 0x00];
      case RingProtocolConstants.manualStressMeasureSubtype:
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
      RingProtocolConstants.manualStressSubtype ||
      RingProtocolConstants.manualStressMeasureSubtype =>
        v >= 1 && v <= 100,
      _ => v < 250,
    };
  }
}
