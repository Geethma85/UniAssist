import 'package:flutter/material.dart';
import '../screens/login_screen.dart' show AppColors;

enum AppTab { home, chat, history, profile }

/// Shared bottom navigation bar for the 4 main student tabs.
/// Used by home_screen, chat_screen, chat_history_screen, profile_screen
/// so nav styling only needs to change in one place.
class AppBottomNav extends StatelessWidget {
  final AppTab currentTab;

  const AppBottomNav({super.key, required this.currentTab});

  void _navigate(BuildContext context, AppTab tab) {
    if (tab == currentTab) return;

    final routes = {
      AppTab.home: '/home',
      AppTab.chat: '/chat',
      AppTab.history: '/chat-history',
      AppTab.profile: '/profile',
    };

      Navigator.of(context).pushNamedAndRemoveUntil(
        routes[tab]!,
        (route) => false,
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTab(context, AppTab.home, Icons.home_rounded, 'Home'),
            _buildTab(context, AppTab.chat, Icons.chat_bubble_outline_rounded, 'Chat'),
            _buildTab(context, AppTab.history, Icons.history_rounded, 'History'),
            _buildTab(context, AppTab.profile, Icons.person_outline_rounded, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context, AppTab tab, IconData icon, String label) {
    final isActive = tab == currentTab;

    return GestureDetector(
      onTap: () => _navigate(context, tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? AppColors.onPrimary : AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.onPrimary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}