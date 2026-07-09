// Source: colmi_r06_fbp raw sensor parsers (BSD-3-Clause)
// Source: colmi_r06_fbp Command enableAllRawData/getAllRawData (BSD-3-Clause)

import 'dart:async';

import '../codec/packet_codec.dart';
import '../ring_protocol_constants.dart';
import '../transport/ring_command_queue.dart';

class AccelerometerSample {
  const AccelerometerSample({
    required this.rawX,
    required this.rawY,
    required this.rawZ,
  });

  final int rawX;
  final int rawY;
  final int rawZ;
}

class RawSensorCommand {
  RawSensorCommand(this._queue);

  final RingCommandQueue _queue;

  Future<void> enableStream(bool on) async {
    final hex = on ? 'a104' : 'a102';
    final packet = PacketCodec.hexStringToCmdBytes(hex);
    await _queue.writePacket(packet);
  }

  Future<void> pollSnapshot() async {
    final packet = PacketCodec.hexStringToCmdBytes('a103');
    await _queue.writePacket(packet);
  }

  Stream<AccelerometerSample> accelerometerStream() {
    return _queue
        .pushStream(RingProtocolConstants.cmdRawSensor)
        .where((p) => p[1] == RingProtocolConstants.rawAccelerometer)
        .map(parseAccelerometer);
  }

  /// colmi_r06_fbp parseRawAccelerometerSensorData
  static AccelerometerSample parseAccelerometer(List<int> data) {
    int toSigned12(int high, int lowNibble) {
      final raw = ((high << 4) | (lowNibble & 0xf));
      if (raw >= 2048) return raw - 4096;
      return raw;
    }

    final rawY = toSigned12(data[2], data[3]);
    final rawZ = toSigned12(data[4], data[5]);
    final rawX = toSigned12(data[6], data[7]);
    return AccelerometerSample(rawX: rawX, rawY: rawY, rawZ: rawZ);
  }
}
