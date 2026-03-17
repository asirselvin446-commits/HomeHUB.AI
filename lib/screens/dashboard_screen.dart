import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/app_card.dart';
import 'tasks_screen.dart';
import 'finance_screen.dart';
import 'grocery_screen.dart';
import 'maintenance_screen.dart';
import 'notifications_screen.dart';
import 'more_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = AppColors.isDark(context);
    final scores = state.homeHealthScores;
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Greeting Header ─────────────────────────────────────
          SliverAppBar(
            expandedHeight: 110,
            floating: true,
            pinned: false,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Hello, ${state.currentUser} 👋',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text(context),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, MMM dd').format(DateTime.now()),
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _headerButton(
                        context,
                        icon: Icons.notifications_none_rounded,
                        badge: state.unreadNotificationsCount,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                      ),
                      const SizedBox(width: 10),
                      _headerButton(
                        context,
                        icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        onTap: () => state.toggleTheme(),
                      ),
                      const SizedBox(width: 10),
                      _headerButton(
                        context,
                        icon: Icons.more_vert_rounded,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const MoreScreen())),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ── Home Health Score ──────────────────────────
                  _buildHealthCard(context, scores, isDark)
                      .animate()
                      .fade(duration: 400.ms)
                      .slideY(begin: 0.05, duration: 400.ms),

                  const SizedBox(height: 20),

                  // ── Quick Actions ─────────────────────────────
                  Text('Quick Actions', style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: AppColors.text(context), letterSpacing: -0.2,
                  )),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                    children: [
                      _quickAction(context, Icons.task_alt_rounded, 'Tasks',
                          AppColors.primary, () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const TasksScreen()))),
                      _quickAction(context, Icons.shopping_cart_rounded, 'Grocery',
                          AppColors.info, () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const GroceryScreen()))),
                      if (state.canViewFinance)
                        _quickAction(context, Icons.account_balance_wallet_rounded, 'Finance',
                            AppColors.accent, () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const FinanceScreen()))),
                      _quickAction(context, Icons.build_rounded, 'Maintain',
                          const Color(0xFF8B5CF6), () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const MaintenanceScreen()))),
                    ],
                  ).animate(delay: 100.ms).fade(duration: 400.ms).slideY(begin: 0.05, duration: 400.ms),

                  const SizedBox(height: 20),

                  // ── Stats Overview ────────────────────────────
                  Text('Overview', style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: AppColors.text(context), letterSpacing: -0.2,
                  )),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.5,
                    children: [
                      _statCard(context, 'Pending Tasks',
                          '${state.pendingTasks.length}', Icons.task_alt_rounded,
                          AppColors.primary,
                          subtitle: '${state.householdTasks.where((t) => t.isOverdue).length} overdue'),
                      if (state.canViewFinance)
                        _statCard(context, 'This Month',
                            currencyFormat.format(state.thisMonthExpenseTotal),
                            Icons.account_balance_wallet_rounded, AppColors.accent),
                      _statCard(context, 'Groceries',
                          '${state.unpurchasedGroceries.length}',
                          Icons.shopping_cart_rounded, AppColors.info,
                          subtitle: 'items needed'),
                      _statCard(context, 'Maintenance',
                          '${state.overdueMaintenanceTasks.length}',
                          Icons.build_rounded, const Color(0xFF8B5CF6),
                          subtitle: 'overdue'),
                    ],
                  ).animate(delay: 200.ms).fade(duration: 400.ms).slideY(begin: 0.05, duration: 400.ms),

                  const SizedBox(height: 20),

                  // ── AI Insights ───────────────────────────────
                  if (state.maintenanceSuggestions.isNotEmpty) ...[
                    Text('AI Insights', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppColors.text(context), letterSpacing: -0.2,
                    )),
                    const SizedBox(height: 12),
                    AppCard(
                      borderColor: AppColors.primary.withValues(alpha: 0.2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  gradient: AppColors.aiGradient,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                              ),
                              const SizedBox(width: 10),
                              Text('HomeHub AI', style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              )),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...state.maintenanceSuggestions.take(2).map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(s, style: TextStyle(
                              fontSize: 13, height: 1.5,
                              color: AppColors.text(context),
                            )),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Upcoming Tasks ────────────────────────────
                  if (state.pendingTasks.isNotEmpty) ...[
                    Text('Upcoming Tasks', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppColors.text(context), letterSpacing: -0.2,
                    )),
                    const SizedBox(height: 12),
                    ...state.pendingTasks.take(4).map((task) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 4, height: 36,
                              decoration: BoxDecoration(
                                color: task.priority == 'high'
                                    ? AppColors.error
                                    : task.priority == 'medium'
                                        ? AppColors.accent
                                        : AppColors.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(task.title, style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600,
                                    color: AppColors.text(context),
                                  )),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${task.category}${task.dueDate != null ? " • ${DateFormat('MMM dd').format(task.dueDate!)}" : ""}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (task.assignedTo != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(task.assignedTo!, style: TextStyle(
                                  fontSize: 11, color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                )),
                              ),
                          ],
                        ),
                      ),
                    )),
                    const SizedBox(height: 20),
                  ],

                  // ── Unpaid Bills ──────────────────────────────
                  if (state.unpaidBills.isNotEmpty) ...[
                    Text('Bills Due', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppColors.text(context), letterSpacing: -0.2,
                    )),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: state.unpaidBills.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          final bill = state.unpaidBills[i];
                          final color = bill.isOverdue ? AppColors.error : AppColors.primary;
                          return Container(
                            width: 140,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.card(context),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                              border: Border.all(color: color.withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(bill.type, style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: AppColors.text(context),
                                )),
                                const SizedBox(height: 6),
                                Text(currencyFormat.format(bill.amount), style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800, color: color,
                                )),
                                const SizedBox(height: 4),
                                Text(
                                  bill.isOverdue ? 'OVERDUE' : 'Due ${DateFormat('MMM dd').format(bill.dueDate)}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header Buttons ──────────────────────────────────────────────────
  Widget _headerButton(BuildContext context, {
    required IconData icon,
    int badge = 0,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: AppColors.isDark(context)
                ? AppColors.darkBorder
                : AppColors.lightBorder,
          ),
        ),
        child: Stack(
          children: [
            Icon(icon, size: 20, color: AppColors.text(context)),
            if (badge > 0)
              Positioned(
                right: -2, top: -2,
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Health Score Card ───────────────────────────────────────────────
  Widget _buildHealthCard(BuildContext context, Map<String, double> scores, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Home Health', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70,
                )),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${scores['overall']!.toInt()}', style: TextStyle(
                      fontSize: 42, fontWeight: FontWeight.w900,
                      color: Colors.white, height: 1,
                    )),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5, left: 3),
                      child: Text('/100', style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white60,
                      )),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              _miniScore('🔧', scores['maintenance']!),
              const SizedBox(width: 14),
              _miniScore('📋', scores['tasks']!),
              const SizedBox(width: 14),
              _miniScore('📄', scores['bills']!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniScore(String emoji, double score) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text('${score.toInt()}%', style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
        )),
      ],
    );
  }

  // ── Quick Action Tile ──────────────────────────────────────────────
  Widget _quickAction(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: AppColors.isDark(context)
                ? AppColors.darkBorder
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: AppColors.text(context),
            )),
          ],
        ),
      ),
    );
  }

  // ── Stat Card ─────────────────────────────────────────────────────
  Widget _statCard(BuildContext context, String title, String value,
      IconData icon, Color color, {String? subtitle}) {
    return Container(
      padding: AppSpacing.paddingCard,
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.isDark(context)
              ? AppColors.darkBorder
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Text(value, style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800,
                color: AppColors.text(context),
              )),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
          )),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600,
            )),
          ],
        ],
      ),
    );
  }
}
