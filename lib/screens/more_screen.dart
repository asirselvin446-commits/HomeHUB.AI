import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'family_screen.dart';
import 'emergency_screen.dart';
import 'ai_assistant_screen.dart';
import 'history_screen.dart';
import 'feedback_screen.dart';

import 'notification_preferences_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('More')),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          // User Profile Card
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text('👑', style: TextStyle(fontSize: 28)),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.currentUser,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        state.firebaseUser?.email ?? 'Home Admin',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Invite Code Card
          if (state.householdId != null)
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.vpn_key_rounded,
                          color: AppColors.primary, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Household Invite Code',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Share this code so family members can join:',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: state.householdId!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Invite code copied! 📋'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCardAlt
                            : Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              state.householdId!,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                              ),
                            ),
                          ),
                          Icon(Icons.copy_rounded,
                              size: 18,
                              color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: 8),

          // Menu Items
          _menuSection('Features', [
            _MenuItem(
              icon: Icons.auto_awesome,
              title: 'AI Assistant',
              subtitle: 'Ask questions about your home',
              color: AppColors.primary,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => AIAssistantScreen())),
            ),
            _MenuItem(
              icon: Icons.family_restroom_rounded,
              title: 'Family Members',
              subtitle: '${state.familyMembers.length} members',
              color: AppColors.info,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => FamilyScreen())),
            ),
            _MenuItem(
              icon: Icons.emergency_rounded,
              title: 'Emergency Contacts',
              subtitle: '${state.emergencyContacts.length} contacts',
              color: AppColors.error,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => EmergencyScreen())),
            ),
            _MenuItem(
              icon: Icons.history_rounded,
              title: 'Activity History',
              subtitle: 'Tasks, groceries & expenses',
              color: Color(0xFF8E24AA),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => HistoryScreen())),
            ),
          ], isDark),

          SizedBox(height: 16),

          _menuSection('Settings', [
            _MenuItem(
              icon: isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              title: 'Theme',
              subtitle: isDark ? 'Dark Mode' : 'Light Mode',
              color: AppColors.accent,
              onTap: () => state.toggleTheme(),
              trailing: Switch(
                value: isDark,
                onChanged: (_) => state.toggleTheme(),
                activeColor: AppColors.primary,
              ),
            ),
            _MenuItem(
              icon: Icons.notifications_active_rounded,
              title: 'Notification Preferences',
              subtitle: state.notificationsEnabled ? 'Enabled' : 'Disabled',
              color: AppColors.info,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotificationPreferencesScreen())),
            ),
            _MenuItem(
              icon: Icons.currency_rupee_rounded,
              title: 'Monthly Income',
              subtitle: state.monthlyIncome > 0
                  ? '₹${state.monthlyIncome.toStringAsFixed(0)}'
                  : 'Not set',
              color: AppColors.primary,
              onTap: () => _showIncomeDialog(context, state),
            ),
          ], isDark),

          SizedBox(height: 16),

          _menuSection('Account', [
            _MenuItem(
              icon: Icons.info_outline_rounded,
              title: 'About HomeHub AI',
              subtitle: 'Version 1.0.0',
              color: AppColors.darkTextSecondary,
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'HomeHub AI',
                  applicationVersion: '1.0.0',
                  applicationIcon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.home_rounded, size: 40, color: AppColors.primary),
                  ),
                  applicationLegalese: '© 2026 HomeHub AI',
                  children: [
                    SizedBox(height: 16),
                    Text(
                      'A comprehensive family management solution with AI-powered insights for chores, finances, and maintenance.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                );
              },
            ),
            _MenuItem(
              icon: Icons.feedback_rounded,
              title: 'Feedback & Report',
              subtitle: 'Send feedback or report issues',
              color: Color(0xFF7C3AED),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => FeedbackScreen())),
            ),
            _MenuItem(
              icon: Icons.logout_rounded,
              title: 'Sign Out',
              subtitle: 'Log out of your account',
              color: AppColors.error,
              onTap: () => _confirmSignOut(context, state),
            ),
          ], isDark),

          SizedBox(height: 40),

          // App branding
          Center(
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.home_rounded,
                      color: Colors.white, size: 22),
                ),
                SizedBox(height: 8),
                Text(
                  'HomeHub AI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                Text(
                  'Powered by Firebase 🔥',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary.withOpacity(0.5)
                        : AppColors.lightTextSecondary.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _menuSection(String title, List<_MenuItem> items, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final item = entry.value;
              final isLast = entry.key == items.length - 1;
              return Column(
                children: [
                  ListTile(
                    onTap: item.onTap,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.color, size: 20),
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    subtitle: Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    trailing: item.trailing ??
                        Icon(Icons.chevron_right_rounded,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 72,
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showIncomeDialog(BuildContext context, AppState state) {
    final ctrl = TextEditingController(
      text: state.monthlyIncome > 0
          ? state.monthlyIncome.toStringAsFixed(0)
          : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Monthly Income'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration:
              InputDecoration(hintText: 'Enter monthly income (₹)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final income = double.tryParse(ctrl.text) ?? 0;
              if (income > 0) {
                state.setMonthlyIncome(income);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign Out'),
        content: Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              state.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.trailing,
  });
}
