import 'package:flutter/material.dart';

class WydCommunityPlaceholderScreen extends StatelessWidget {
  const WydCommunityPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1028),
      appBar: AppBar(
        title: const Text('WYD 커뮤니티'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'WYD 커뮤니티 기능은 준비 중입니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
