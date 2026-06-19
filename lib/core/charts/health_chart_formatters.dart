import 'package:picnique_rosary_healthcare_smartring/core/enum/toggle_range.dart';

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

String formatTooltipX(double xMs, ToggleRange range) {
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
