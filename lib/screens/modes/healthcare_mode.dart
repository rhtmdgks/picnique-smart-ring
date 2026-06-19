import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:picnique_rosary_healthcare_smartring/core/constants/health_goal.dart';
import 'package:picnique_rosary_healthcare_smartring/providers/ring.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/health_care_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/modes/mode_shell_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/setting_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/screens/sub/catholic_info_screen.dart';
import 'package:picnique_rosary_healthcare_smartring/services/ring_live_activity.dart';
import 'package:provider/provider.dart';

class HealthcareModeScreen extends StatelessWidget {
  const HealthcareModeScreen({
    super.key,
    this.onSignOut,
  });

  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    return ModeShellScreen(
      title: '헬스케어',
      onSignOut: onSignOut,
      tabs: [
        const ModeTabItem(
          label: '홈',
          icon: Icons.home_rounded,
          screen: _HealthcareFigmaHome(),
        ),
        ModeTabItem(
          label: '건강 상태',
          icon: Icons.monitor_heart_rounded,
          screen: HealthCareScreen(),
        ),
        ModeTabItem(
          label: '가톨릭 정보',
          icon: Icons.menu_book_rounded,
          screen: CatholicInfoScreen(),
        ),
        const ModeTabItem(
          label: '알림',
          icon: Icons.notifications_active_outlined,
          screen: _AlertsScreen(),
        ),
        const ModeTabItem(
          label: '기관 연결',
          icon: Icons.groups_2_outlined,
          screen: _SimpleInfoScreen(
            title: '보호자/기관 연결',
            description: '담당 생활지원사와 보호자 연결 정보를 표시합니다.',
          ),
        ),
        const ModeTabItem(
          label: '기기 상태',
          icon: Icons.watch_outlined,
          screen: _SimpleInfoScreen(
            title: '반지 상태',
            description: '배터리, 연결 상태, 펌웨어 버전을 표시합니다.',
          ),
        ),
        ModeTabItem(
          label: '설정',
          icon: Icons.settings_outlined,
          screen: SettingScreen(),
        ),
      ],
    );
  }
}

class _HealthcareFigmaHome extends StatelessWidget {
  const _HealthcareFigmaHome();

  @override
  Widget build(BuildContext context) {
    final ring = context.watch<Ring>();
    final live = context.watch<RingLiveActivity>();
    final useLive = ring.isConnected && live.isTracking;
    final steps = useLive ? live.steps : 0;
    const hr = '—';
    const spo2 = '—';
    final status = 'normal';
    final battery = ring.battery?.toString() ?? '—';
    final alerts = '0';
    final dateLabel = _todayKoreanLabel();
    final progress = (steps / HealthGoal.dailyStepGoal).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '요약',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dateLabel,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _glassActionRow(context),
          const SizedBox(height: 14),
          _activityCard(steps: steps, progress: progress),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: (MediaQuery.of(context).size.width - 16 * 2 - 10) / 2,
                child: _metricCard(
                  title: '심박수',
                  value: hr,
                  suffix: 'bpm',
                  icon: Icons.favorite_rounded,
                  tone: const Color(0xFFB04262),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 16 * 2 - 10) / 2,
                child: _metricCard(
                  title: '산소포화도',
                  value: spo2,
                  suffix: '%',
                  icon: Icons.bloodtype_rounded,
                  tone: const Color(0xFF4A4FA2),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 16 * 2 - 10) / 2,
                child: _metricCard(
                  title: '배터리',
                  value: battery,
                  suffix: '%',
                  icon: Icons.battery_charging_full_rounded,
                  tone: const Color(0xFF2C8A66),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 16 * 2 - 10) / 2,
                child: _metricCard(
                  title: '미확인 알림',
                  value: alerts,
                  suffix: '건',
                  icon: Icons.notification_important_rounded,
                  tone: const Color(0xFF8C6543),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statusCard(
            status: status,
            alerts: alerts,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '상태',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusLabel(status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: _statusColor(status), size: 10),
                      const SizedBox(width: 8),
                      Text(
                        '알림 $alerts',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _todayKoreanLabel() {
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[now.weekday - 1];
    return '${now.month}월 ${now.day}일 ($weekday)';
  }

  Widget _glassActionRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _glassButton(
            icon: Icons.show_chart_rounded,
            label: '트렌드',
            onTap: () =>
                Navigator.of(context).pushNamed('/health-heart-rate-detail'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _glassButton(
            icon: Icons.call_rounded,
            label: '긴급 연락',
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _glassButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.12),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _activityCard({required int steps, required double progress}) {
    return _tile(
      color: const Color(0xFF2E2A47),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.favorite_rounded, color: Color(0xFFFF6A7A), size: 18),
              SizedBox(width: 6),
              Text(
                '활동',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$steps',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              height: 1.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Text(
            '걸음',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF6DE2A8)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '목표 ${HealthGoal.dailyStepGoal}걸음',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String suffix,
    required IconData icon,
    required Color tone,
  }) {
    return _tile(
      color: const Color(0xFF2B263F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: tone, size: 20),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                suffix,
                style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusCard({
    required String status,
    required String alerts,
    required Widget child,
  }) {
    final color = switch (status) {
      'danger' => const Color(0xFF5A2733),
      'caution' => const Color(0xFF5A4A2B),
      'disconnected' => const Color(0xFF3E3E46),
      _ => const Color(0xFF224238),
    };
    return _tile(color: color, child: child);
  }

  Widget _tile({required Color color, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'danger':
        return '컨디션 점검';
      case 'caution':
        return '리듬 주의';
      case 'disconnected':
        return '연결 확인';
      default:
        return '안정';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'danger':
        return Colors.redAccent;
      case 'caution':
        return Colors.orangeAccent;
      case 'disconnected':
        return Colors.grey;
      default:
        return Colors.greenAccent;
    }
  }
}

class _AlertsScreen extends StatelessWidget {
  const _AlertsScreen();

  @override
  Widget build(BuildContext context) {
    const List<Map<String, String>> mockAlerts = [];

    if (mockAlerts.isEmpty) {
      return const Center(
        child: Text('알림이 없습니다.', style: TextStyle(color: Colors.white)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: mockAlerts.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = mockAlerts[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2438),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row['alert_type'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                row['message'] ?? '',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SimpleInfoScreen extends StatelessWidget {
  const _SimpleInfoScreen({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          '$title\n\n$description',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
