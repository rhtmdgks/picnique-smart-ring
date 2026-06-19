import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/setting/ring_status_card.dart';
import 'package:picnique_rosary_healthcare_smartring/widgets/setting/setting_card.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const RingStatusCard(),
          const SizedBox(height: 16),
          const SettingCard(),
        ],
      ),
    );
  }
}
