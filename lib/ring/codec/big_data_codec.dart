// Source: Gadgetbridge YawellRingDeviceSupport big-data notify (AGPL-3.0)
// Verified against QRing btsnoop: BC|tag|lenLE|payload|crc16 → total = len + 6

import '../ring_protocol_constants.dart';

/// 0xBC big-data channel frame (notify V2 / handle 0x0018).
///
/// Layout (btsnoop R08, 33-byte example `bc271b00…`):
/// ```
/// [0]     0xBC
/// [1]     tag (0x27 sleep, 0x2a spo2, …)
/// [2..3]  payload length uint16 LE
/// [4..]   payload (length bytes)
/// [end]   CRC16 (2 bytes) — included in `length + 6` total frame size
/// ```
abstract final class BigDataCodec {
  static const int headerSize = 4;
  static const int trailerSize = 2;

  static int payloadLength(List<int> frame) {
    if (frame.length < headerSize) return 0;
    return frame[2] | ((frame[3] & 0xff) << 8);
  }

  static int expectedFrameLength(int payloadLen) =>
      payloadLen + headerSize + trailerSize;

  static bool isComplete(List<int> buffer) {
    if (buffer.isEmpty || (buffer[0] & 0xff) != RingProtocolConstants.cmdBigDataV2) {
      return false;
    }
    if (buffer.length < headerSize) return false;
    return buffer.length >= expectedFrameLength(payloadLength(buffer));
  }

  /// Build raw bytes for V2 command characteristic (sleep/spo2 request).
  static List<int> makeRequest(int tag) => [
        RingProtocolConstants.cmdBigDataV2,
        tag,
        0x01,
        0x00,
        0xff,
        0x00,
        0xff,
      ];
}

/// Reassembles fragmented 0xBC notify chunks (Gadgetbridge pattern).
class BigDataAssembler {
  List<int>? _buffer;

  /// Returns zero or more complete frames from [chunk].
  List<List<int>> feed(List<int> chunk) {
    var data = chunk;
    if (_buffer != null) {
      data = [..._buffer!, ...data];
      _buffer = null;
    }

    final frames = <List<int>>[];
    var offset = 0;

    while (offset < data.length) {
      if ((data[offset] & 0xff) != RingProtocolConstants.cmdBigDataV2) {
        offset++;
        continue;
      }

      final remaining = data.sublist(offset);
      if (!BigDataCodec.isComplete(remaining)) {
        _buffer = remaining;
        break;
      }

      final len = BigDataCodec.expectedFrameLength(
        BigDataCodec.payloadLength(remaining),
      );
      frames.add(List<int>.from(remaining.sublist(0, len)));
      offset += len;
    }

    return frames;
  }

  void reset() => _buffer = null;
}
