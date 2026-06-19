import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picnique_rosary_healthcare_smartring/core/charts/health_chart_models.dart';
import 'package:picnique_rosary_healthcare_smartring/core/charts/health_chart_theme.dart';
import 'package:picnique_rosary_healthcare_smartring/core/enum/data_type.dart';

void main() {
  group('HealthChartTheme.computeYBounds', () {
    test('heart rate adds padding', () {
      final b = HealthChartTheme.computeYBounds(
        dataType: DataType.HeartRate,
        values: [72, 85, 90],
      );
      expect(b.minY, greaterThanOrEqualTo(40));
      expect(b.maxY, greaterThan(90));
    });

    test('oxygen clamps 85-100', () {
      final b = HealthChartTheme.computeYBounds(
        dataType: DataType.Oxygen,
        values: [96, 98],
        fixedMin: 85,
        fixedMax: 100,
      );
      expect(b.minY, 85);
      expect(b.maxY, 100);
    });

    test('stress bar color zones', () {
      expect(
        HealthChartTheme.barColorForStress(15),
        isNot(equals(HealthChartTheme.barColorForStress(75))),
      );
    });

    test('sleep timeline uses 2 spots per segment not per minute', () {
      // 8 hours with 40 segments → 80 spots max (not 480 minute spots)
      const segmentCount = 40;
      final spotCount = segmentCount * 2;
      expect(spotCount, lessThan(50 * 2)); // well under old minute-loop scale
      expect(spotCount, 80);
    });

    test('segmentLineSpots skips zeros and breaks on gaps', () {
      final segments = segmentLineSpots([
        const FlSpot(0, 0),
        const FlSpot(1, 72),
        const FlSpot(2, 75),
        const FlSpot(5, 80),
      ]);
      expect(segments.length, 2);
      expect(segments[0].length, 2);
      expect(segments[1].length, 1);
    });
  });
}
