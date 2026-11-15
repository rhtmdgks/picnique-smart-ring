import '../../integrations/rwfit/ring_backend.dart';
import '../../core/enum/data_type.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/data/tab_item.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_data_refresh_notifier.dart';
import 'package:picnique_rosary_healthcare_smartring/services/health_live_metrics.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_background_sync.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_connection_coordinator.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_pending_import.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_live_activity.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/bottom_nav_bar.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/main_app_bar.dart';
import 'package:provider/provider.dart';

class MainScreenLayout extends StatefulWidget {
  const MainScreenLayout({
    super.key,
    this.onSignOut,
  });

  final Future<void> Function()? onSignOut;

  @override
  State<MainScreenLayout> createState() => _MainScreenLayoutState();
}

class _MainScreenLayoutState extends State<MainScreenLayout>
    with WidgetsBindingObserver {
  int currentIndex = 0;
  bool _rwfitWasBusy = false;
  void _onRwfitChanged() {
    final session = RingBackend.rwfit;
    if (!mounted || session == null) return;
    if (_rwfitWasBusy && !session.busy) {
      final refresh = context.read<HealthDataRefreshNotifier>();
      for (final type in DataType.values) { refresh.notifyChanged(type); }
    }
    _rwfitWasBusy = session.busy;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCoordinator());
  }

  Future<void> _startCoordinator() async {
    if (!mounted) return;
    if (RingBackend.isRwfit) {
      RingBackend.rwfit!.addListener(_onRwfitChanged);
      return;
    }
    await RingConnectionCoordinator.instance.start(
      ring: context.read<Ring>(),
      liveActivity: context.read<RingLiveActivity>(),
      sync: context.read<RingSyncController>(),
      healthRefresh: context.read<HealthDataRefreshNotifier>(),
      liveMetrics: context.read<HealthLiveMetrics>(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    RingBackend.rwfit?.removeListener(_onRwfitChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !RingBackend.isRwfit) {
      unawaited(RingPendingImport.importAll(
        refreshNotifier: context.read<HealthDataRefreshNotifier>(),
      ));
    }
  }

  void onTapItem(int selectedIndex) {
    setState(() {
      currentIndex = selectedIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: MainAppBar(
          title: tabItems.elementAt(currentIndex).title,
          onSignOut: widget.onSignOut,
        ),
        body: tabItems.elementAt(currentIndex).screen,
        bottomNavigationBar: BottomNavBar(
          index: currentIndex,
          onTap: onTapItem,
        ),
      ),
    );
  }
}
