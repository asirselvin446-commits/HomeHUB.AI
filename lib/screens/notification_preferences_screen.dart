import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';

class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = AppColors.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Master toggle
          _buildSection(
            context,
            isDark,
            title: 'Global',
            children: [
              _buildToggle(
                context,
                isDark,
                icon: Icons.notifications_rounded,
                color: AppColors.primary,
                title: 'All Notifications',
                subtitle: 'Master toggle for all notifications',
                value: state.notificationsEnabled,
                onChanged: (val) => state.toggleNotificationsEnabled(val),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Category toggles
          AnimatedOpacity(
            opacity: state.notificationsEnabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !state.notificationsEnabled,
              child: Column(
                children: [
                  _buildSection(
                    context,
                    isDark,
                    title: 'Communication',
                    children: [
                      _buildToggle(
                        context,
                        isDark,
                        icon: Icons.chat_bubble_rounded,
                        color: AppColors.info,
                        title: 'Family Chat',
                        subtitle: 'Messages from family members',
                        value: state.chatNotificationsEnabled,
                        onChanged: (val) =>
                            state.setNotificationPref('chat', val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    isDark,
                    title: 'Tasks & Home',
                    children: [
                      _buildToggle(
                        context,
                        isDark,
                        icon: Icons.task_alt_rounded,
                        color: AppColors.primary,
                        title: 'Task Reminders',
                        subtitle: 'Overdue tasks and assignments',
                        value: state.taskNotificationsEnabled,
                        onChanged: (val) =>
                            state.setNotificationPref('task', val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    isDark,
                    title: 'Finance',
                    children: [
                      _buildToggle(
                        context,
                        isDark,
                        icon: Icons.receipt_long_rounded,
                        color: AppColors.accent,
                        title: 'Bill Reminders',
                        subtitle: 'Due dates and payment alerts',
                        value: state.billNotificationsEnabled,
                        onChanged: (val) =>
                            state.setNotificationPref('bill', val),
                      ),
                      _divider(isDark),
                      _buildToggle(
                        context,
                        isDark,
                        icon: Icons.account_balance_wallet_rounded,
                        color: const Color(0xFFE65100),
                        title: 'Expense Alerts',
                        subtitle: 'When family members log expenses',
                        value: state.expenseNotificationsEnabled,
                        onChanged: (val) =>
                            state.setNotificationPref('expense', val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context,
                    isDark,
                    title: 'Summary',
                    children: [
                      _buildToggle(
                        context,
                        isDark,
                        icon: Icons.analytics_rounded,
                        color: const Color(0xFF8B5CF6),
                        title: 'Weekly Summary',
                        subtitle: 'Sunday morning digest of your week',
                        value: state.weeklySummaryEnabled,
                        onChanged: (val) =>
                            state.setNotificationPref('weekly_summary', val),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    bool isDark, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary(context),
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggle(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.text(context),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary(context),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      indent: 72,
      color: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.05),
    );
  }
}
