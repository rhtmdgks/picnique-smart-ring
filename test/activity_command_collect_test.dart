import 'package:flutter_test/flutter_test.dart';
import 'package:picnique_rosary_healthcare_smartring/ring/commands/activity_command.dart';

/// Mirrors ActivityCommand.fetchHistory `done` predicate — regression for 0xf0.
bool activityCollectDone(List<int> p, List<List<int>> all) {
  final nr = p[1] & 0xff;
  if (nr == 0xff) return true;
  if (nr == 0xf0) return false;
  if (p.length < 7) return false;
  return (p[5] & 0xff) == (p[6] & 0xff) - 1;
}

void main() {
  test('0xf0 header does not end collection', () {
    final header = List<int>.filled(16, 0);
    header[0] = 0x43;
    header[1] = 0xf0;
    header[3] = 0x01;
    expect(activityCollectDone(header, [header]), isFalse);
  });

  test('0xff empty ends collection', () {
    final empty = List<int>.filled(16, 0);
    empty[0] = 0x43;
    empty[1] = 0xff;
    expect(activityCollectDone(empty, [empty]), isTrue);
  });

  test('last data chunk ends when index == total-1', () {
    final chunk = List<int>.filled(16, 0);
    chunk[0] = 0x43;
    chunk[1] = 0x26;
    chunk[5] = 4;
    chunk[6] = 5;
    expect(activityCollectDone(chunk, [chunk]), isTrue);
  });

  test('parseHistoryPackets local DateTime + new calorie protocol', () {
    final header = List<int>.filled(16, 0);
    header[0] = 0x43;
    header[1] = 0xf0;
    header[3] = 0x01;

    final data = List<int>.filled(16, 0);
    data[0] = 0x43;
    data[1] = 0x26; // BCD 26 → 2026
    data[2] = 0x07;
    data[3] = 0x10;
    data[4] = 8; // 02:00
    data[5] = 0;
    data[6] = 1;
    data[7] = 10; // calories raw 10 → *10 = 100
    data[8] = 0;
    data[9] = 500 & 0xff;
    data[10] = (500 >> 8) & 0xff;
    data[11] = 300 & 0xff;
    data[12] = (300 >> 8) & 0xff;

    final samples = ActivityCommand.parseHistoryPackets([header, data]);
    expect(samples.length, 1);
    expect(samples.first.steps, 500);
    expect(samples.first.calories, 100);
    expect(samples.first.distanceMeters, 300);
    expect(samples.first.timestamp.isUtc, isFalse);
    expect(samples.first.timestamp.year, 2026);
    expect(samples.first.timestamp.month, 7);
    expect(samples.first.timestamp.day, 10);
    expect(samples.first.timestamp.hour, 2);
  });
}
