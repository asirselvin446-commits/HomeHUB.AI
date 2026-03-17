import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'dashboard_screen.dart';
import 'tasks_screen.dart';
import 'grocery_screen.dart';
import 'finance_screen.dart';
import 'more_screen.dart';
import 'ai_assistant_screen.dart';
import 'family_chat_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final appState = context.watch<AppState>();
    final canViewFinance = appState.canViewFinance;

    final screens = <Widget>[
      const DashboardScreen(),
      const TasksScreen(),
      const FamilyChatScreen(),
      const GroceryScreen(),
      if (canViewFinance) const FinanceScreen(),
    ];

    // Clamp index to valid range if finance tab disappeared
    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: safeIndex,
            children: screens,
          ),
          if (safeIndex != 2)
            Positioned(
              right: 16,
              bottom: (safeIndex == 1 || safeIndex == 3 || (canViewFinance && safeIndex == 4)) ? 88 : 16,
              child: _buildAIFab(),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isDark, canViewFinance),
    );
  }


  Widget _buildAIFab() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppColors.aiGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AIAssistantScreen()),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
        ),
      ),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
     .shimmer(duration: 2.seconds, color: Colors.white24, angle: 1);
  }

  Widget _buildBottomBar(bool isDark, bool canViewFinance) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.dashboard_rounded, 'Home', isDark),
              _navItem(1, Icons.task_alt_rounded, 'Tasks', isDark),
              _navItem(2, Icons.forum_rounded, 'Chat', isDark),
              _navItem(3, Icons.shopping_cart_rounded, 'Grocery', isDark),
              if (canViewFinance)
                _navItem(4, Icons.account_balance_wallet_rounded, 'Finance', isDark),
              if (!canViewFinance)
                _lockedNavItem(Icons.account_balance_wallet_rounded, 'Finance', isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lockedNavItem(IconData icon, String label, bool isDark) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Only parents & admins can access finances'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isDark
                      ? AppColors.darkTextSecondary.withValues(alpha: 0.4)
                      : AppColors.lightTextSecondary.withValues(alpha: 0.4),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Icon(
                    Icons.lock_rounded,
                    size: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary.withValues(alpha: 0.6)
                        : AppColors.lightTextSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.darkTextSecondary.withValues(alpha: 0.4)
                    : AppColors.lightTextSecondary.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, bool isDark) {
    // Map visual index to actual index (accounting for removed More tab from bottom bar)
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? AppColors.primary
                  : isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
            ).animate(target: isSelected ? 1 : 0).scaleXY(begin: 1.0, end: 1.15, duration: 200.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
