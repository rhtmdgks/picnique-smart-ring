import 'package:flutter_test/flutter_test.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/commands/sleep_command.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/ring_protocol_constants.dart';

void main() {
  test('parseSleepPacket uses local midnight (not UTC)', () {
    // Frame: BC 27 lenLE … days=1, daysAgo=0, dayBytes=8,
    // sleepStart=1380 (23:00), sleepEnd=420 (07:00),
    // one light stage 60min + one deep 60min.
    final sleepStart = 1380;
    final sleepEnd = 420;
    final payload = <int>[
      RingProtocolConstants.cmdBigDataV2,
      RingProtocolConstants.bigDataTypeSleep,
      0x0c, 0x00, // length = 12 (placeholder; parser uses daysInPacket)
      0x00, 0x00, // unused in our parser path before idx 6
      0x01, // daysInPacket
      0x00, // daysAgo
      0x08, // dayBytes (header 4 + 2 stages * 2)
      sleepStart & 0xff, (sleepStart >> 8) & 0xff,
      sleepEnd & 0xff, (sleepEnd >> 8) & 0xff,
      0x02, 60, // light 60m
      0x03, 60, // deep 60m
      0x00, 0x00, // crc placeholder
    ];
    // Fix length field to match payload after header (bytes from idx 4).
    final length = payload.length - 6;
    payload[2] = length & 0xff;
    payload[3] = (length >> 8) & 0xff;

    final sessions = SleepCommand.parseSleepPacket(payload);
    expect(sessions, isNotEmpty);
    final s = sessions.first;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Started yesterday 23:00 local (sleepStart > sleepEnd).
    final expectedStart = today.subtract(const Duration(minutes: 1440 - 1380));
    final expectedEnd = today.add(const Duration(minutes: 420));

    expect(s.start.year, expectedStart.year);
    expect(s.start.month, expectedStart.month);
    expect(s.start.day, expectedStart.day);
    expect(s.start.hour, 23);
    expect(s.end.hour, 7);
    expect(s.end.day, expectedEnd.day);
    expect(s.stages.length, 2);
    expect(s.stages[0].stageByte, 2);
    expect(s.stages[1].stageByte, 3);
  });
}
