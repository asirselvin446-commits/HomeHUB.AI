import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _tabs = const ['All', 'Tasks', 'Grocery', 'Expenses'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity History'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor:
              isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AllTab(state: state, isDark: isDark),
          _TasksTab(state: state, isDark: isDark),
          _GroceryTab(state: state, isDark: isDark),
          _ExpensesTab(state: state, isDark: isDark),
        ],
      ),
    );
  }
}

// ─── Unified timeline ───────────────────────────────────────────────
class _AllTab extends StatelessWidget {
  final AppState state;
  final bool isDark;
  const _AllTab({required this.state, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final items = <_HistoryEntry>[];

    // Completed tasks
    for (var t in state.householdTasks.where((t) => t.isCompleted)) {
      items.add(_HistoryEntry(
        icon: Icons.task_alt_rounded,
        color: AppColors.primary,
        title: t.title,
        subtitle: 'Task completed',
        date: t.dueDate ?? DateTime.now(),
        category: 'Task',
      ));
    }

    // Purchased groceries
    for (var g in state.groceryItems.where((g) => g.isPurchased)) {
      items.add(_HistoryEntry(
        icon: Icons.shopping_bag_rounded,
        color: AppColors.info,
        title: g.name,
        subtitle: '${g.quantity} ${g.unit} purchased',
        date: DateTime.now(),
        category: 'Grocery',
      ));
    }

    // Expenses
    for (var e in state.expenses) {
      items.add(_HistoryEntry(
        icon: Icons.receipt_long_rounded,
        color: AppColors.error,
        title: e.title,
        subtitle: '₹${e.amount.toStringAsFixed(0)} · ${e.category}',
        date: e.date,
        category: 'Expense',
      ));
    }

    items.sort((a, b) => b.date.compareTo(a.date));

    if (items.isEmpty) {
      return _emptyState('No activity yet');
    }

    return _buildGroupedList(items, isDark);
  }
}

// ─── Tasks tab ──────────────────────────────────────────────────────
class _TasksTab extends StatelessWidget {
  final AppState state;
  final bool isDark;
  const _TasksTab({required this.state, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final completed = state.householdTasks.where((t) => t.isCompleted).toList();
    if (completed.isEmpty) return _emptyState('No completed tasks');

    final items = completed
        .map((t) => _HistoryEntry(
              icon: Icons.task_alt_rounded,
              color: AppColors.primary,
              title: t.title,
              subtitle: t.assignedTo != null ? 'By ${t.assignedTo}' : 'Completed',
              date: t.dueDate ?? DateTime.now(),
              category: 'Task',
            ))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return _buildGroupedList(items, isDark);
  }
}

// ─── Grocery tab ────────────────────────────────────────────────────
class _GroceryTab extends StatelessWidget {
  final AppState state;
  final bool isDark;
  const _GroceryTab({required this.state, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final purchased = state.groceryItems.where((g) => g.isPurchased).toList();
    if (purchased.isEmpty) return _emptyState('No purchased groceries');

    final items = purchased
        .map((g) => _HistoryEntry(
              icon: Icons.shopping_bag_rounded,
              color: AppColors.info,
              title: g.name,
              subtitle: '${g.quantity} ${g.unit} · ${g.category}',
              date: DateTime.now(),
              category: 'Grocery',
            ))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return _buildGroupedList(items, isDark);
  }
}

// ─── Expenses tab ───────────────────────────────────────────────────
class _ExpensesTab extends StatelessWidget {
  final AppState state;
  final bool isDark;
  const _ExpensesTab({required this.state, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final expenses = List.of(state.expenses)
      ..sort((a, b) => b.date.compareTo(a.date));
    if (expenses.isEmpty) return _emptyState('No expenses recorded');

    final items = expenses
        .map((e) => _HistoryEntry(
              icon: Icons.receipt_long_rounded,
              color: AppColors.error,
              title: e.title,
              subtitle: '₹${e.amount.toStringAsFixed(0)} · ${e.category}',
              date: e.date,
              category: 'Expense',
            ))
        .toList();

    return _buildGroupedList(items, isDark);
  }
}

// ─── Shared helpers ─────────────────────────────────────────────────

class _HistoryEntry {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final DateTime date;
  final String category;

  _HistoryEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.category,
  });
}

Widget _emptyState(String message) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(message,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
      ],
    ),
  );
}

Widget _buildGroupedList(List<_HistoryEntry> items, bool isDark) {
  // Group by date label
  final Map<String, List<_HistoryEntry>> groups = {};
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  for (var item in items) {
    final d = DateTime(item.date.year, item.date.month, item.date.day);
    String label;
    if (d == today) {
      label = 'Today';
    } else if (d == yesterday) {
      label = 'Yesterday';
    } else if (d.isAfter(today.subtract(const Duration(days: 7)))) {
      label = DateFormat('EEEE').format(item.date); // e.g. "Monday"
    } else {
      label = DateFormat('MMM dd, yyyy').format(item.date);
    }
    groups.putIfAbsent(label, () => []);
    groups[label]!.add(item);
  }

  return ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    itemCount: groups.length,
    itemBuilder: (context, i) {
      final label = groups.keys.elementAt(i);
      final entries = groups[label]!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
          ...entries.map((e) => _historyTile(e, isDark)),
          const SizedBox(height: 8),
        ],
      );
    },
  );
}

Widget _historyTile(_HistoryEntry entry, bool isDark) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: entry.color.withValues(alpha: 0.15),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: entry.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(entry.icon, color: entry.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
        Text(
          DateFormat('h:mm a').format(entry.date),
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ],
    ),
  );
}
