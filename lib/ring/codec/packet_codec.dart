// Source: colmi_r02_client/colmi_r02_client/packet.py (MIT, Wesley Ellis)
// Source: colmi_r06_fbp/lib/colmi_ring.dart hexStringToCmdBytes (BSD-3-Clause)

import '../ring_protocol_constants.dart';

/// 16-byte Colmi packet encoder/decoder with checksum = sum(bytes) & 0xff.
abstract final class PacketCodec {
  /// Build a 16-byte packet from [command] and optional [subData] (max 14 bytes).
  static List<int> makePacket(int command, [List<int>? subData]) {
    assert(command >= 0 && command <= 255);
    final packet = List<int>.filled(RingProtocolConstants.packetLength, 0);
    packet[0] = command;
    if (subData != null) {
      assert(subData.length <= 14);
      for (var i = 0; i < subData.length; i++) {
        packet[i + 1] = subData[i] & 0xff;
      }
    }
    packet[15] = checksum(packet);
    return packet;
  }

  /// colmi_r06_fbp hexStringToCmdBytes — packs hex string into 16-byte command.
  static List<int> hexStringToCmdBytes(String hexString) {
    if (hexString.length > 30 || hexString.length.isOdd) {
      throw ArgumentError('hex string must be even length <= 30');
    }
    final bytes = List<int>.filled(RingProtocolConstants.packetLength, 0);
    for (var i = 0; i < hexString.length ~/ 2; i++) {
      bytes[i] = int.parse(hexString.substring(2 * i, 2 * i + 2), radix: 16);
    }
    bytes[15] = checksum(bytes);
    return bytes;
  }

  static int checksum(List<int> packet) {
    var sum = 0;
    for (final b in packet) {
      sum = (sum + (b & 0xff)) & 0xff;
    }
    return sum;
  }

  /// Validate packet length and checksum. Returns false on mismatch.
  static bool validate(List<int> packet) {
    if (packet.length != RingProtocolConstants.packetLength) return false;
    return checksum(List<int>.from(packet)..[15] = 0) == (packet[15] & 0xff);
  }

  /// BCD helpers — colmi_r02_client/set_time.py
  static int byteToBcd(int value) {
    assert(value >= 0 && value < 100);
    return ((value ~/ 10) << 4) | (value % 10);
  }

  static int bcdToDecimal(int b) {
    return (((b >> 4) & 15) * 10) + (b & 15);
  }

  /// Little-endian uint32 pack/unpack.
  static List<int> packUint32Le(int value) {
    return [
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ];
  }

  static int unpackUint32Le(List<int> data, int offset) {
    return (data[offset] & 0xff) |
        ((data[offset + 1] & 0xff) << 8) |
        ((data[offset + 2] & 0xff) << 16) |
        ((data[offset + 3] & 0xff) << 24);
  }

  static int unpackUint16Le(List<int> data, int offset) {
    return (data[offset] & 0xff) | ((data[offset + 1] & 0xff) << 8);
  }
}
