import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scores = state.homeHealthScores;
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: false,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Hello, ${state.currentUser} 👋',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTheme.darkText : AppTheme.lightText,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            DateFormat('EEEE, MMM dd').format(DateTime.now()),
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => state.toggleTheme(),
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            color: isDark ? AppTheme.accentYellow : AppTheme.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),

                // Home Health Score Card
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: GradientCard(
                    gradient: AppTheme.primaryGradient,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Home Health',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white70,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${scores['overall']!.toInt()}',
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 6, left: 4),
                                      child: Text(
                                        '/100',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Mini score rings
                            Row(
                              children: [
                                _miniScore('🔧', scores['maintenance']!),
                                SizedBox(width: 12),
                                _miniScore('📋', scores['tasks']!),
                                SizedBox(width: 12),
                                _miniScore('📦', scores['pantry']!),
                                SizedBox(width: 12),
                                _miniScore('📄', scores['bills']!),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // Quick Stats Grid
                SectionHeader(title: 'Overview'),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      StatCard(
                        title: 'Pending Tasks',
                        value: '${state.pendingTasks.length}',
                        icon: Icons.task_alt_rounded,
                        color: AppTheme.primaryDark,
                        subtitle: '${state.householdTasks.where((t) => t.isOverdue).length} overdue',
                      ),
                      StatCard(
                        title: 'This Month',
                        value: currencyFormat.format(state.thisMonthExpenseTotal),
                        icon: Icons.account_balance_wallet_rounded,
                        color: AppTheme.accentTeal,
                      ),
                      StatCard(
                        title: 'Groceries Needed',
                        value: '${state.unpurchasedGroceries.length}',
                        icon: Icons.shopping_cart_rounded,
                        color: AppTheme.accentOrange,
                        subtitle: '${state.lowPantryItems.length} pantry items low',
                      ),
                      StatCard(
                        title: 'Maintenance',
                        value: '${state.overdueMaintenanceTasks.length}',
                        icon: Icons.build_rounded,
                        color: AppTheme.accentYellow,
                        subtitle: 'overdue tasks',
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // AI Insights
                SectionHeader(title: '🤖 AI Insights'),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryDark.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        ...state.maintenanceSuggestions.take(3).map((s) => Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      s,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: isDark ? AppTheme.darkText : AppTheme.lightText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // Upcoming Tasks
                if (state.pendingTasks.isNotEmpty) ...[
                  SectionHeader(title: 'Upcoming Tasks'),
                  ...state.pendingTasks.take(4).map((task) => Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        child: Container(
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: task.priority == 'high'
                                      ? AppTheme.accentOrange
                                      : task.priority == 'medium'
                                          ? AppTheme.accentYellow
                                          : AppTheme.accentTeal,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppTheme.darkText : AppTheme.lightText,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '${task.category} ${task.dueDate != null ? "• ${DateFormat('MMM dd').format(task.dueDate!)}" : ""}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (task.assignedTo != null)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryDark.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    task.assignedTo!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.primaryDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )),
                ],

                SizedBox(height: 24),

                // Unpaid Bills
                if (state.unpaidBills.isNotEmpty) ...[
                  SectionHeader(title: 'Bills Due'),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: state.unpaidBills.map((bill) {
                        final color = bill.isOverdue
                            ? AppTheme.accentOrange
                            : AppTheme.accentTeal;
                        return Container(
                          width: 140,
                          margin: EdgeInsets.only(right: 12),
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: color.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bill.type,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppTheme.darkText : AppTheme.lightText,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                currencyFormat.format(bill.amount),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                bill.isOverdue
                                    ? 'OVERDUE'
                                    : 'Due ${DateFormat('MMM dd').format(bill.dueDate)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniScore(String emoji, double score) {
    return Column(
      children: [
        Text(emoji, style: TextStyle(fontSize: 16)),
        SizedBox(height: 4),
        Text(
          '${score.toInt()}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
