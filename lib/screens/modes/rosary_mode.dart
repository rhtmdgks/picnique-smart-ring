import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/layouts/main_screen_layout.dart';

class RosaryModeScreen extends StatelessWidget {
  const RosaryModeScreen({
    super.key,
    this.onSignOut,
  });

  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    return MainScreenLayout(onSignOut: onSignOut);
  }
}
