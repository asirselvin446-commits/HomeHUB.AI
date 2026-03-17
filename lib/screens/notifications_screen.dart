import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';
import 'tasks_screen.dart';
import 'finance_screen.dart';
import 'grocery_screen.dart';
import 'maintenance_screen.dart';
import 'family_chat_screen.dart';
import 'notification_preferences_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = 'all';

  static const _filters = [
    {'key': 'all', 'label': 'All', 'icon': Icons.inbox_rounded},
    {'key': 'chat', 'label': 'Chat', 'icon': Icons.chat_bubble_rounded},
    {'key': 'task', 'label': 'Tasks', 'icon': Icons.task_alt_rounded},
    {'key': 'bill', 'label': 'Bills', 'icon': Icons.receipt_long_rounded},
    {'key': 'expense', 'label': 'Expenses', 'icon': Icons.account_balance_wallet_rounded},
    {'key': 'maintenance', 'label': 'Home', 'icon': Icons.build_rounded},
    {'key': 'savings', 'label': 'Savings', 'icon': Icons.savings_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = AppColors.isDark(context);
    final appState = context.watch<AppState>();
    final allNotifications = appState.appNotifications;

    // Apply filter
    final notifications = _selectedFilter == 'all'
        ? allNotifications
        : allNotifications.where((n) => n.type == _selectedFilter).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Preferences',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NotificationPreferencesScreen()),
            ),
          ),
          if (allNotifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                switch (value) {
                  case 'read_all':
                    appState.markAllNotificationsAsRead();
                    break;
                  case 'clear_all':
                    _showClearDialog(context, appState);
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'read_all',
                  child: Row(
                    children: [
                      Icon(Icons.done_all_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Mark All Read'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Clear All',
                          style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Chips ──
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final key = filter['key'] as String;
                final label = filter['label'] as String;
                final icon = filter['icon'] as IconData;
                final isSelected = _selectedFilter == key;

                // Count for badge
                final count = key == 'all'
                    ? allNotifications.where((n) => !n.isRead).length
                    : allNotifications
                        .where(
                            (n) => n.type == key && !n.isRead)
                        .length;

                return FilterChip(
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary(context),
                      ),
                      const SizedBox(width: 5),
                      Text(label),
                      if (count > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.3)
                                : AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: isDark
                      ? AppColors.darkCard
                      : AppColors.lightCard,
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : AppColors.text(context),
                  ),
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() => _selectedFilter = key);
                  },
                );
              },
            ),
          ),

          // ── Notification List ──
          Expanded(
            child: notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedFilter == 'all'
                              ? Icons.notifications_off_outlined
                              : Icons.filter_list_off_rounded,
                          size: 64,
                          color: AppColors.textSecondary(context)
                              .withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFilter == 'all'
                              ? 'No notifications yet'
                              : 'No ${_filters.firstWhere((f) => f['key'] == _selectedFilter)['label']} notifications',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'re all caught up! ✨',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary(context)
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: notifications.length,
                    padding: const EdgeInsets.only(bottom: 20),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return Dismissible(
                        key: Key(notification.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red.withValues(alpha: 0.1),
                          child: Icon(Icons.delete_outline_rounded,
                              color: Colors.red.shade400),
                        ),
                        onDismissed: (_) {
                          appState.clearAllNotifications(); // Could add single delete
                        },
                        child: InkWell(
                          onTap: () {
                            if (!notification.isRead) {
                              appState
                                  .markNotificationAsRead(notification.id);
                            }
                            // Deep-link navigation
                            _navigateToRoute(
                                context, notification.actionRoute);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              color: notification.isRead
                                  ? Colors.transparent
                                  : AppColors.primary.withValues(alpha: 0.04),
                              border: Border(
                                bottom: BorderSide(
                                  color: (isDark
                                          ? Colors.white
                                          : Colors.black)
                                      .withValues(alpha: 0.05),
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: notification.isRead
                                        ? (isDark
                                            ? AppColors.darkCardAlt
                                            : Colors.grey.shade100)
                                        : _getColorForType(notification.type)
                                            .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getIconForType(notification.type),
                                    color: notification.isRead
                                        ? AppColors.textSecondary(context)
                                        : _getColorForType(
                                            notification.type),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              notification.title,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight:
                                                    notification.isRead
                                                        ? FontWeight.w500
                                                        : FontWeight.w700,
                                                color:
                                                    AppColors.text(context),
                                              ),
                                            ),
                                          ),
                                          if (!notification.isRead)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notification.body,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              AppColors.textSecondary(
                                                  context),
                                          height: 1.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatDate(
                                            notification.timestamp),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              AppColors.textSecondary(
                                                      context)
                                                  .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Notifications'),
        content: const Text(
            'Are you sure you want to delete all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              appState.clearAllNotifications();
              Navigator.pop(ctx);
            },
            child: const Text('Clear',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _navigateToRoute(BuildContext context, String? route) {
    if (route == null) return;

    // Block finance navigation for unauthorized roles
    if (route == 'finance') {
      final appState = context.read<AppState>();
      if (!appState.canViewFinance) {
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
        return;
      }
    }

    Widget? screen;
    switch (route) {
      case 'tasks':
        screen = const TasksScreen();
        break;
      case 'finance':
        screen = const FinanceScreen();
        break;
      case 'grocery':
        screen = const GroceryScreen();
        break;
      case 'maintenance':
        screen = const MaintenanceScreen();
        break;
      case 'chat':
        screen = const FamilyChatScreen();
        break;
    }

    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'chat':
        return Icons.chat_bubble_rounded;
      case 'task':
        return Icons.task_alt_rounded;
      case 'bill':
        return Icons.receipt_long_rounded;
      case 'expense':
        return Icons.account_balance_wallet_rounded;
      case 'maintenance':
        return Icons.build_circle_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'grocery':
        return Icons.shopping_cart_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'chat':
        return AppColors.info;
      case 'task':
        return AppColors.primary;
      case 'bill':
        return AppColors.accent;
      case 'expense':
        return const Color(0xFFE65100);
      case 'maintenance':
        return const Color(0xFF8B5CF6);
      case 'savings':
        return const Color(0xFF00897B);
      case 'grocery':
        return const Color(0xFF43A047);
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes <= 1) return 'Just now';
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
