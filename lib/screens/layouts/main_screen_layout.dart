import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/data/tab_item.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/background_layout.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/bottom_nav_bar.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/main_app_bar.dart';

class MainScreenLayout extends StatefulWidget {
  const MainScreenLayout({
    super.key,
    this.onSignOut,
  });

  final Future<void> Function()? onSignOut;

  @override
  State<MainScreenLayout> createState() => _MainScreenLayoutState();
}

class _MainScreenLayoutState extends State<MainScreenLayout> {
  int currentIndex = 0;

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
