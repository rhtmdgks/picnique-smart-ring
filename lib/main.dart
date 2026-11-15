import 'integrations/rwfit/ring_backend.dart';
import 'integrations/rwfit/rwfit_session.dart';
import 'integrations/rwfit/rwfit_history_store.dart';
import 'integrations/rwfit/rwfit_screen.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:picnique_rosary_healthcare_smartring/db/app_db.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/db/db_manager.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/monitoring_setting.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/user_setting.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/community/wyd_community_placeholder_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/connect_ring_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/main_screen_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/monitoring_setting_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/system_setting_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/catholic_info_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/catholic_rosary_mystery_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/catholic_rosary_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/catholic_rosary_statistics_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/health_care_activity_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/health_care_heart_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/health_care_oxygen_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/health_care_sleep_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/health_care_stress_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/services/battery_notification_service.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_data_refresh_notifier.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_background_sync.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_live_activity.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_live_metrics.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/fonts.dart';
import 'package:provider/provider.dart';

void main() => runPicnique();

Future<void> runPicnique({bool useRwfit = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  if (useRwfit && !Platform.isAndroid && !Platform.isIOS) {
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('RWFit은 Android/iOS 전용입니다.')))));
    return;
  }
  if (Platform.isAndroid || Platform.isIOS) {
    await const MethodChannel('picnique/backend').invokeMethod('selectBackend', {'backend': useRwfit ? 'rwfit' : 'qring'});
  }
  try {
    await DbManager.I.open(filename: useRwfit ? 'rwfit_db.sqlite' : 'db.sqlite');
  } catch (e, st) {
    debugPrint('DbManager.open failed: $e\n$st');
    rethrow;
  }

  if (useRwfit) {
    RingBackend.rwfit = RwfitSession(store: RwfitHistoryStore(DbManager.I.appDB));
    await RingBackend.rwfit!.restoreBinding();
  } else {
    await _ensureBatteryOptExclusion();
    await BatteryNotificationService.initialize();
  }
  runApp(
    MultiProvider(
      providers: [
        Provider<DbManager>(
          create: (_) => DbManager.I,
          dispose: (_, m) => m.close(),
        ),
        ProxyProvider<DbManager, AppDatabase>(
          update: (_, m, _) => m.appDB,
        ),
        ChangeNotifierProvider(create: (_) => Ring()..loadFromPrefs()),
        ChangeNotifierProvider(create: (_) => UserSetting()..loadFromPrefs()),
        ChangeNotifierProvider(create: (_) => MonitoringSetting()),
        ChangeNotifierProvider(create: (_) => RingSyncController()),
        ChangeNotifierProvider(create: (_) => RingLiveActivity()),
        ChangeNotifierProvider(create: (_) => HealthLiveMetrics()),
        ChangeNotifierProvider(create: (_) => HealthDataRefreshNotifier()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Picnique Smart Ring',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Paperlogy',
        scaffoldBackgroundColor: const Color(0xFF1A1028),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF500EAD),
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: AppFontWeight.bold),
          displayMedium: TextStyle(fontWeight: AppFontWeight.bold),
          displaySmall: TextStyle(fontWeight: AppFontWeight.semiBold),
          headlineLarge: TextStyle(fontWeight: AppFontWeight.bold),
          headlineMedium: TextStyle(fontWeight: AppFontWeight.semiBold),
          headlineSmall: TextStyle(fontWeight: AppFontWeight.semiBold),
          titleLarge: TextStyle(fontWeight: AppFontWeight.semiBold),
          titleMedium: TextStyle(fontWeight: AppFontWeight.medium),
          titleSmall: TextStyle(fontWeight: AppFontWeight.medium),
          bodyLarge: TextStyle(fontWeight: AppFontWeight.regular),
          bodyMedium: TextStyle(fontWeight: AppFontWeight.regular),
          bodySmall: TextStyle(fontWeight: AppFontWeight.regular),
          labelLarge: TextStyle(fontWeight: AppFontWeight.semiBold),
          labelMedium: TextStyle(fontWeight: AppFontWeight.medium),
          labelSmall: TextStyle(fontWeight: AppFontWeight.medium),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const MainScreenLayout(),
      routes: {
        '/connect-ring-setting': (_) => RingBackend.isRwfit
            ? RwfitScreen(session: RingBackend.rwfit!) : ConnectRingSettingScreen(),
        '/monitoring-setting': (_) => MonitoringSettingScreen(),
        '/updrade-setting': (_) => MonitoringSettingScreen(),
        '/system-setting': (_) => const SystemSettingScreen(),
        '/health-heart-rate-detail': (_) => const HealthCareHeartScreen(),
        '/health-oxygen-detail': (_) => const HealthCareOxygenScreen(),
        '/health-care-stress-detail': (_) => const HealthCareStressScreen(),
        '/health-care-activity-detail': (_) => const HealthCareActivityScreen(),
        '/health-care-sleep-detail': (_) => const HealthCareSleepScreen(),
        '/catholic-info-screen': (_) => CatholicInfoScreen(),
        '/catholic-rosary-screen': (_) => const CatholicRosaryScreen(),
        '/catholic-rosary-mystery-screen': (_) =>
            const CatholicRosaryMysteryScreen(),
        '/wyd-community': (_) => const WydCommunityPlaceholderScreen(),
        '/catholic-rosary-statistics-screen': (_) =>
            const CatholicRosaryStatisticsScreen(),
      },
    );
  }
}

Future<void> _ensureBatteryOptExclusion() async {
  if (!Platform.isAndroid) return;
  const channel = MethodChannel('com.example.picnique_ring/ble');
  try {
    await channel.invokeMethod<bool>('ensureIgnoreBatteryOptimizations');
  } on MissingPluginException {
    debugPrint('[RING] battery opt not implemented on Android yet');
  } catch (e) {
    debugPrint('[RING] battery opt check failed: $e');
  }
}
