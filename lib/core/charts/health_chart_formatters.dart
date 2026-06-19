import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';
import 'package:picnique_rosary_healthcare_smartring/util/graph.dart';

String formatChartTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String formatChartMd(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

String formatChartYm(DateTime d) =>
    "${d.year.toString().substring(2)}.${d.month.toString().padLeft(2, '0')}";

String formatChartYmd(DateTime d) =>
    "${d.year.toString().substring(2)}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}";

String formatTooltipX(
  double xIndex,
  ToggleRange range, {
  DataType dataType = DataType.HeartRate,
  DateTime? dayAnchor,
}) {
  final dt = _dateTimeFromChartX(
    xIndex,
    range,
    dataType: dataType,
    dayAnchor: dayAnchor,
  );
  switch (range) {
    case ToggleRange.day:
      return formatChartTime(dt);
    case ToggleRange.week:
    case ToggleRange.month:
      return formatChartMd(dt);
    case ToggleRange.halfYear:
    case ToggleRange.year:
      return formatChartYm(dt);
  }
}

/// Sparse bottom-axis labels (x = slot/day/month index, not epoch ms).
String formatAxisX(
  double xIndex,
  ToggleRange range, {
  required DataType dataType,
  DateTime? dayAnchor,
}) {
  final dt = _dateTimeFromChartX(
    xIndex,
    range,
    dataType: dataType,
    dayAnchor: dayAnchor,
  );
  switch (range) {
    case ToggleRange.day:
      final h = dt.hour;
      if (h == 0) return '0';
      if (h == 12) return '12';
      if (h == 23) return '23';
      return '$h';
    case ToggleRange.week:
      return formatChartMd(dt);
    case ToggleRange.month:
      return '${dt.day}';
    case ToggleRange.halfYear:
    case ToggleRange.year:
      return '${dt.month}월';
  }
}

DateTime _dateTimeFromChartX(
  double xIndex,
  ToggleRange range, {
  required DataType dataType,
  DateTime? dayAnchor,
}) {
  if (range == ToggleRange.day && dayAnchor != null) {
    final minutes = xIndex.round() * dataType.dayUnitMins;
    return DateTime(
      dayAnchor.year,
      dayAnchor.month,
      dayAnchor.day,
    ).add(Duration(minutes: minutes));
  }
  return getDateTimeFromIndex(xIndex.round(), range, dataType);
}

/// Returns 4–5 tick positions for the x-axis (avoids label overlap).
List<double> computeSparseXTicks({
  required double minX,
  required double maxX,
  required ToggleRange range,
  required DataType dataType,
}) {
  if (maxX <= minX) return [minX];

  switch (range) {
    case ToggleRange.day:
      final slotsPerHour = 60 ~/ dataType.dayUnitMins;
      final step = 6 * slotsPerHour; // every 6 hours
      final ticks = <double>[];
      for (var slot = minX.ceil(); slot <= maxX; slot += step) {
        ticks.add(slot.toDouble());
      }
      if (ticks.isEmpty || ticks.last < maxX - step / 2) {
        ticks.add(maxX);
      }
      return ticks;
    case ToggleRange.week:
      return _evenlySpacedTicks(minX, maxX, 4);
    case ToggleRange.month:
      return _evenlySpacedTicks(minX, maxX, 5);
    case ToggleRange.halfYear:
      return _evenlySpacedTicks(minX, maxX, 4);
    case ToggleRange.year:
      return _evenlySpacedTicks(minX, maxX, 4);
  }
}

List<double> _evenlySpacedTicks(double minX, double maxX, int count) {
  if (count <= 1) return [minX];
  final span = maxX - minX;
  final step = span / (count - 1);
  return List.generate(count, (i) => minX + step * i);
}

bool isNearChartTick(double value, List<double> ticks, {double tolerance = 0.6}) {
  return ticks.any((t) => (value - t).abs() <= tolerance);
}

String formatTooltipXLegacy(double xMs, ToggleRange range) {
  final dt = DateTime.fromMillisecondsSinceEpoch(xMs.toInt(), isUtc: true)
      .toLocal();
  switch (range) {
    case ToggleRange.day:
      return formatChartTime(dt);
    case ToggleRange.week:
    case ToggleRange.month:
      return formatChartMd(dt);
    case ToggleRange.halfYear:
    case ToggleRange.year:
      return formatChartYm(dt);
  }
}

String rangeWindowLabel(ToggleRange range, DateTime selectedDate) {
  final now = DateTime.now();
  DateTime day0(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime endOfDay(DateTime d) => day0(d).add(const Duration(days: 1));

  switch (range) {
    case ToggleRange.day:
      final s = day0(selectedDate);
      return '${formatChartMd(s)} 00:00 ~ 23:59';
    case ToggleRange.week:
      final end = endOfDay(now).subtract(const Duration(seconds: 1));
      final start = day0(now.subtract(const Duration(days: 6)));
      return '${formatChartYmd(start)} ~ ${formatChartYmd(end)}';
    case ToggleRange.month:
      final end = endOfDay(now).subtract(const Duration(seconds: 1));
      final start = day0(now.subtract(const Duration(days: 29)));
      return '${formatChartYmd(start)} ~ ${formatChartYmd(end)}';
    case ToggleRange.halfYear:
      final cur = DateTime(now.year, now.month, 1);
      final start = DateTime(cur.year, cur.month - 5, 1);
      final end = DateTime(cur.year, cur.month + 1, 0);
      return '${formatChartYm(start)} ~ ${formatChartYm(end)}';
    case ToggleRange.year:
      final cur = DateTime(now.year, now.month, 1);
      final start = DateTime(cur.year, cur.month - 11, 1);
      final end = DateTime(cur.year, cur.month + 1, 0);
      return '${formatChartYm(start)} ~ ${formatChartYm(end)}';
  }
}
