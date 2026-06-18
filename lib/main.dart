import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/db/app_db.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/monitoring_setting.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/user_setting.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/connect_ring_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/main_screen_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/monitoring_setting_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/catholic_info_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/catholic_rosary_mystery_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/catholic_rosary_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/catholic_rosary_statistics_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/health_care_activity_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/health_care_heart_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/health_care_oxygen_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/health_care_sleep_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/health_care_stress_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_background_sync.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DbManager.I.open();
  await _ensureBatteryOptExclusion();
  runApp(
    MultiProvider(
      providers: [
        Provider<DbManager>(
          create: (_) => DbManager.I,
          dispose: (_, m) => m.close(),
        ),
        ProxyProvider<DbManager, AppDatabase>(update: (_, m, __) => m.appDB),
        ChangeNotifierProvider(create: (_) => Ring()..loadFromPrefs()),
        ChangeNotifierProvider(create: (_) => UserSetting()),
        ChangeNotifierProvider(create: (_) => MonitoringSetting()),
        ChangeNotifierProvider(create: (_) => RingSyncController()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MainScreenLayout(),
      routes: {
        '/connect-ring-setting': (context) => ConnectRingSettingScreen(),
        '/search-ring-setting': (context) => MonitoringSettingScreen(),
        '/monitoring-setting': (context) => MonitoringSettingScreen(),
        '/updrade-setting': (context) => MonitoringSettingScreen(),
        '/system-setting': (context) => MonitoringSettingScreen(),
        '/health-heart-rate-detail': (context) => HealthCareHeartScreen(),
        '/health-oxygen-detail': (context) => HealthCareOxygenScreen(),
        '/health-care-stress-detail': (context) => HealthCareStressScreen(),
        '/health-care-activity-detail': (context) => HealthCareActivityScreen(),
        '/health-care-sleep-detail': (context) => HealthCareSleepScreen(),
        '/catholic-rosary-screen': (context) => CatholicRosaryScreen(),
        '/catholic-rosary-statistics-screen': (context) =>
            CatholicRosaryStatisticsScreen(),
        '/catholic-info-screen': (context) => CatholicInfoScreen(),
        '/catholic-rosary-mystery-screen': (context) =>
            const CatholicRosaryMysteryScreen(),
      },
      theme: ThemeData(
        fontFamily: 'Paperlogy',
        scaffoldBackgroundColor: const Color(0xFF1D1B29),
      ),
    );
  }
}

Future<void> _ensureBatteryOptExclusion() async {
  if (!Platform.isAndroid) return;
  const channel = MethodChannel('com.example.picnique_ring/ble');
  try {
    await channel.invokeMethod<bool>('ensureIgnoreBatteryOptimizations');
  } catch (e) {
    debugPrint('battery opt check failed: $e');
  }
}
