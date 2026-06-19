import 'package:flutter/material.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({
    super.key,
    required this.onComplete,
  });

  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1028),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.watch_rounded,
                color: Color(0xFFBEA9FF),
                size: 72,
              ),
              const SizedBox(height: 24),
              const Text(
                '스마트링을 연결하고\n묵주기도와 건강 관리를 시작하세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '설정 탭에서 기기를 연결할 수 있습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onComplete,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF500EAD),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '앱으로 이동',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
