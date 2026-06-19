import 'dart:async';

import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/data/tab_item.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCoordinator());
  }

  Future<void> _startCoordinator() async {
    if (!mounted) return;
    await RingConnectionCoordinator.instance.start(
      ring: context.read<Ring>(),
      liveActivity: context.read<RingLiveActivity>(),
      sync: context.read<RingSyncController>(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(RingPendingImport.importAll());
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
