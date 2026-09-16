import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/pp_motion.dart';
import 'camera_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';

/// Post-onboarding shell: the five tabs plus the floating glass tab bar
/// (`.pp-tabbar` in the prototype).
class RootShell extends StatelessWidget {
  const RootShell({super.key});

  static const _tabs = ['home', 'schedule', 'camera', 'history', 'settings'];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final index = _tabs.indexOf(app.activeTab).clamp(0, _tabs.length - 1);
    return Scaffold(
      backgroundColor: PpColors.bg,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: index,
          children: const [
            HomeScreen(),
            ScheduleScreen(),
            CameraScreen(),
            HistoryScreen(),
            SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: PpGlassBar(
          child: Row(
            children: [
              _TabButton(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: app.activeTab == 'home',
                onTap: () => app.goTab('home'),
              ),
              _TabButton(
                icon: Icons.event_note_rounded,
                label: 'Schedule',
                selected: app.activeTab == 'schedule',
                onTap: () => app.goTab('schedule'),
              ),
              _TabButton(
                icon: Icons.videocam_rounded,
                label: 'Camera',
                selected: app.activeTab == 'camera',
                onTap: () => app.goTab('camera'),
              ),
              _TabButton(
                icon: Icons.bar_chart_rounded,
                label: 'History',
                selected: app.activeTab == 'history',
                onTap: () => app.goTab('history'),
              ),
              _TabButton(
                icon: Icons.settings_rounded,
                label: 'Settings',
                selected: app.activeTab == 'settings',
                onTap: () => app.goTab('settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? PpColors.accent700 : PpColors.neutral600;
    return Expanded(
      child: PpPressable(
        onTap: selected ? () {} : onTap,
        haptic: !selected,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style:
                    ppBody(size: 10.5, weight: FontWeight.w700, color: color),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
