import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/common_widgets.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _tabChip(String label, int index, bool isDark) {
    final selected = _tabController.index == index;
    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : isDark
                  ? AppColors.darkCard
                  : AppColors.lightCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appState = context.watch<AppState>();

    // Fallback guard: block access for unauthorized roles
    if (!appState.canViewFinance) {
      return Scaffold(
        appBar: AppBar(title: const Text('Finance')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(Icons.lock_rounded, size: 40, color: AppColors.primary),
                ),
                const SizedBox(height: 20),
                Text(
                  'Access Restricted',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only parents and admins can view financial information.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _tabChip('Expenses', 0, isDark),
                _tabChip('Debts', 1, isDark),
                _tabChip('Savings', 2, isDark),
                _tabChip('Bills', 3, isDark),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ExpensesTab(currencyFormat: currencyFormat),
                _DebtsTab(currencyFormat: currencyFormat),
                _SavingsTab(currencyFormat: currencyFormat),
                _BillsTab(currencyFormat: currencyFormat),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ========== EXPENSES TAB ==========
class _ExpensesTab extends StatelessWidget {
  final NumberFormat currencyFormat;
  const _ExpensesTab({required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analysis = state.financialAnalysis;
    final expenses = state.expenses..sort((a, b) => b.date.compareTo(a.date));

    final categoryBreakdown =
        analysis['categoryBreakdown'] as Map<String, double>;
    final suggestions = analysis['suggestions'] as List<String>;

    final canEdit = state.canEditFinance;
    return Scaffold(
      floatingActionButton: canEdit
          ? FloatingActionButton(
              heroTag: 'addExpense',
              onPressed: () => _showExpenseDialog(context),
              child: Icon(Icons.add_rounded),
            )
          : null,
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          if (!canEdit)
            Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.info),
                  SizedBox(width: 8),
                  Text('You have view-only access to finances',
                      style: TextStyle(fontSize: 12, color: AppColors.info, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          // Summary Card
          GradientCard(
            gradient: AppColors.primaryGradient,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This Month',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  currencyFormat.format(analysis['thisMonthTotal']),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Health Score: ${(analysis['healthScore'] as double).toInt()}/100',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Category Breakdown Chart
          if (categoryBreakdown.isNotEmpty) ...[
            Text(
              'Category Breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            SizedBox(height: 12),
            Container(
              height: 200,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  sections: _buildPieSections(categoryBreakdown),
                ),
              ),
            ),
            SizedBox(height: 8),
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: categoryBreakdown.entries.toList().asMap().entries.map((
                e,
              ) {
                final colors = [
                  AppColors.primary,
                  AppColors.primary,
                  AppColors.error,
                  AppColors.accent,
                  AppColors.info,
                  Color(0xFFA855F7),
                ];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors[e.key % colors.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '${e.value.key}: ${currencyFormat.format(e.value.value)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            SizedBox(height: 20),
          ],

          // AI Financial Insights
          if (suggestions.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'AI Financial Advisor',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ...suggestions.map(
                    (s) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
          ],

          // Recent Expenses
          Text(
            'Recent Expenses',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          SizedBox(height: 8),
          ...expenses
              .take(15)
              .map(
                (e) => Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _getCategoryColor(
                            e.category,
                          ).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getCategoryIcon(e.category),
                          color: _getCategoryColor(e.category),
                          size: 18,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                              ),
                            ),
                            Text(
                              '${e.category} • ${DateFormat('MMM dd').format(e.date)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '-${currencyFormat.format(e.amount)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                      if (canEdit) ...[                      IconButton(
                        icon: Icon(Icons.edit_rounded, size: 18),
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        onPressed: () =>
                            _showExpenseDialog(context, expense: e),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, size: 18),
                        color: AppColors.error,
                        onPressed: () => state.deleteExpense(e.id),
                      ),
                      ],
                    ],
                  ),
                ),
              )
              .toList(),
          SizedBox(height: 80),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(Map<String, double> data) {
    final colors = [
      AppColors.primary,
      AppColors.primary,
      AppColors.error,
      AppColors.accent,
      AppColors.info,
      Color(0xFFA855F7),
    ];
    final total = data.values.fold(0.0, (sum, v) => sum + v);
    int i = 0;
    return data.entries.map((e) {
      final color = colors[i % colors.length];
      i++;
      return PieChartSectionData(
        value: e.value,
        color: color,
        radius: 30,
        title: '${(e.value / total * 100).toInt()}%',
        titleStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'utilities':
        return AppColors.primary;
      case 'groceries':
        return AppColors.primary;
      case 'maintenance':
        return AppColors.accent;
      case 'food':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'utilities':
        return Icons.receipt_long_rounded;
      case 'groceries':
        return Icons.shopping_bag_rounded;
      case 'maintenance':
        return Icons.build_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  void _showExpenseDialog(BuildContext context, {Expense? expense}) {
    final titleCtrl = TextEditingController(text: expense?.title ?? '');
    final amountCtrl = TextEditingController(
      text: expense?.amount.toString() ?? '',
    );
    String category = expense?.category ?? 'Groceries';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                expense == null ? 'Add Expense' : 'Edit Expense',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(hintText: 'Expense title'),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(hintText: 'Amount (₹)'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: category,
                      items:
                          [
                                'Groceries',
                                'Utilities',
                                'Food',
                                'Maintenance',
                                'Transport',
                                'Health',
                                'Education',
                                'Entertainment',
                                'Other',
                              ]
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => category = v!),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.isNotEmpty &&
                        amountCtrl.text.isNotEmpty) {
                      final appState = context.read<AppState>();
                      final newExpense = Expense(
                        id: expense?.id ?? '',
                        title: titleCtrl.text,
                        amount: double.tryParse(amountCtrl.text) ?? 0,
                        category: category,
                        date: expense?.date ?? DateTime.now(),
                        paidBy: expense?.paidBy ?? appState.currentUserId,
                      );
                      if (expense == null) {
                        appState.addExpense(newExpense);
                      } else {
                        appState.updateExpense(newExpense);
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    expense == null ? 'Add Expense' : 'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== DEBTS TAB ==========
class _DebtsTab extends StatelessWidget {
  final NumberFormat currencyFormat;
  const _DebtsTab({required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final canEdit = state.canEditFinance;
    return Scaffold(
      floatingActionButton: canEdit
          ? FloatingActionButton(
              heroTag: 'addDebt',
              onPressed: () => _showDebtDialog(context),
              child: Icon(Icons.add_rounded),
            )
          : null,
      body: state.debts.isEmpty
          ? EmptyState(
              icon: Icons.celebration_rounded,
              title: 'Debt Free!',
              subtitle: 'You have no debts tracked',
            )
          : ListView(
              padding: EdgeInsets.all(20),
              children: [
                // Total debt summary
                GradientCard(
                  gradient: AppColors.accentGradient,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Debt Remaining',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      SizedBox(height: 4),
                      Text(
                        currencyFormat.format(state.totalDebtRemaining),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                ...state.debts.map(
                  (debt) => _debtCard(context, debt, isDark, state),
                ),
              ],
            ),
    );
  }

  Widget _debtCard(
    BuildContext context,
    Debt debt,
    bool isDark,
    AppState state,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                debt.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              if (state.canEditFinance)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.edit_rounded,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      size: 20,
                    ),
                    onPressed: () => _showDebtDialog(context, debt: debt),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    onPressed: () => state.deleteDebt(debt.id),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: debt.progressPercent,
              minHeight: 10,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Paid: ${currencyFormat.format(debt.paidAmount)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Total: ${currencyFormat.format(debt.totalAmount)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _debtStat(
                'Remaining',
                currencyFormat.format(debt.remainingAmount),
                isDark,
              ),
              SizedBox(width: 16),
              _debtStat(
                'Monthly',
                currencyFormat.format(debt.monthlyPayment),
                isDark,
              ),
              SizedBox(width: 16),
              _debtStat('Months Left', '${debt.monthsToPayoff}', isDark),
            ],
          ),
          SizedBox(height: 12),
          // Make Payment Button
          if (state.canEditFinance)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showPaymentDialog(context, debt, state),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Make Payment',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _debtStat(String label, String value, bool isDark) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, Debt debt, AppState state) {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Make Payment'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'Payment amount (₹)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount > 0) {
                state.updateDebtPayment(debt.id, amount);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('Pay'),
          ),
        ],
      ),
    );
  }

  void _showDebtDialog(BuildContext context, {Debt? debt}) {
    final nameCtrl = TextEditingController(text: debt?.name ?? '');
    final totalCtrl = TextEditingController(
      text: debt?.totalAmount.toString() ?? '',
    );
    final monthlyCtrl = TextEditingController(
      text: debt?.monthlyPayment.toString() ?? '',
    );
    final rateCtrl = TextEditingController(
      text: debt?.interestRate.toString() ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              debt == null ? 'Add Debt' : 'Edit Debt',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                hintText: 'Debt name (e.g. Home Loan)',
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: totalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(hintText: 'Total amount'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: monthlyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(hintText: 'Monthly EMI'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextField(
              controller: rateCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: 'Interest rate (%)'),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.isNotEmpty) {
                    final newDebt = Debt(
                      id: debt?.id ?? '',
                      name: nameCtrl.text,
                      totalAmount: double.tryParse(totalCtrl.text) ?? 0,
                      paidAmount: debt?.paidAmount ?? 0,
                      monthlyPayment: double.tryParse(monthlyCtrl.text) ?? 0,
                      interestRate: double.tryParse(rateCtrl.text) ?? 0,
                    );
                    if (debt == null) {
                      context.read<AppState>().addDebt(newDebt);
                    } else {
                      context.read<AppState>().updateDebt(newDebt);
                    }
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  debt == null ? 'Add Debt' : 'Save Changes',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== SAVINGS TAB ==========
class _SavingsTab extends StatelessWidget {
  final NumberFormat currencyFormat;
  const _SavingsTab({required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final canEdit = state.canEditFinance;
    return Scaffold(
      floatingActionButton: canEdit
          ? FloatingActionButton(
              heroTag: 'addSavings',
              onPressed: () => _showSavingsDialog(context),
              child: Icon(Icons.add_rounded),
            )
          : null,
      body: state.savingsGoals.isEmpty
          ? EmptyState(
              icon: Icons.savings_rounded,
              title: 'No Savings Goals',
              subtitle: 'Set financial goals and track your progress',
            )
          : ListView(
              padding: EdgeInsets.all(20),
              children: state.savingsGoals
                  .map((g) => _goalCard(context, g, isDark, state))
                  .toList(),
            ),
    );
  }

  Widget _goalCard(
    BuildContext context,
    SavingsGoal goal,
    bool isDark,
    AppState state,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(goal.icon, style: TextStyle(fontSize: 24)),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    Text(
                      '${currencyFormat.format(goal.currentAmount)} of ${currencyFormat.format(goal.targetAmount)}',
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
                '${(goal.progressPercent * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: goal.progressPercent,
              minHeight: 8,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              if (goal.monthlyContribution > 0)
                Text(
                  '${currencyFormat.format(goal.monthlyContribution)}/month • ~${goal.monthsToGoal} months remaining',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
            ],
          ),
          SizedBox(height: 10),
          if (state.canEditFinance)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showAddContribution(context, goal, state),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Add Savings',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.edit_rounded,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  size: 20,
                ),
                onPressed: () => _showSavingsDialog(context, goal: goal),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                onPressed: () => state.deleteSavingsGoal(goal.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddContribution(
    BuildContext context,
    SavingsGoal goal,
    AppState state,
  ) {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add to ${goal.name}'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'Amount (₹)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(amountCtrl.text) ?? 0;
              if (amt > 0) {
                state.updateSavingsAmount(goal.id, amt);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showSavingsDialog(BuildContext context, {SavingsGoal? goal}) {
    final nameCtrl = TextEditingController(text: goal?.name ?? '');
    final targetCtrl = TextEditingController(
      text: goal?.targetAmount.toString() ?? '',
    );
    final monthlyCtrl = TextEditingController(
      text: goal?.monthlyContribution.toString() ?? '',
    );
    String icon = goal?.icon ?? '🎯';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                goal == null ? 'Add Savings Goal' : 'Edit Savings Goal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 16),
              // Icon selector
              Wrap(
                spacing: 8,
                children: ['🎯', '🛡️', '✈️', '🏠', '🚗', '📱', '🎓', '💍']
                    .map(
                      (e) => GestureDetector(
                        onTap: () => setState(() => icon = e),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: icon == e
                                ? AppColors.primary.withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(e, style: TextStyle(fontSize: 24)),
                        ),
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(hintText: 'Goal name'),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: targetCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Target amount (₹)',
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: monthlyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(hintText: 'Monthly savings'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty) {
                      final newGoal = SavingsGoal(
                        id: goal?.id ?? '',
                        name: nameCtrl.text,
                        targetAmount: double.tryParse(targetCtrl.text) ?? 0,
                        currentAmount: goal?.currentAmount ?? 0,
                        monthlyContribution:
                            double.tryParse(monthlyCtrl.text) ?? 0,
                        icon: icon,
                      );
                      if (goal == null) {
                        context.read<AppState>().addSavingsGoal(newGoal);
                      } else {
                        context.read<AppState>().updateSavingsGoal(newGoal);
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    goal == null ? 'Create Goal' : 'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== BILLS TAB ==========
class _BillsTab extends StatelessWidget {
  final NumberFormat currencyFormat;
  const _BillsTab({required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bills = state.utilityBills
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final canEdit = state.canEditFinance;
    return Scaffold(
      floatingActionButton: canEdit
          ? FloatingActionButton(
              heroTag: 'addBill',
              onPressed: () => _showBillDialog(context),
              child: Icon(Icons.add_rounded),
            )
          : null,
      body: bills.isEmpty
          ? EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No Bills',
              subtitle: 'Track your utility bills and never miss a due date',
            )
          : ListView(
              padding: EdgeInsets.all(20),
              children: bills.map((bill) {
                Color statusColor = bill.isPaid
                    ? AppColors.primary
                    : bill.isOverdue
                    ? AppColors.error
                    : AppColors.primary;
                IconData typeIcon;
                switch (bill.type.toLowerCase()) {
                  case 'electricity':
                    typeIcon = Icons.bolt_rounded;
                    break;
                  case 'water':
                    typeIcon = Icons.water_drop_rounded;
                    break;
                  case 'internet':
                    typeIcon = Icons.wifi_rounded;
                    break;
                  case 'gas':
                    typeIcon = Icons.local_fire_department_rounded;
                    break;
                  default:
                    typeIcon = Icons.receipt_rounded;
                }

                return Container(
                  margin: EdgeInsets.only(bottom: 10),
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(14),
                    border: bill.isOverdue && !bill.isPaid
                        ? Border.all(
                            color: AppColors.error.withOpacity(0.4),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(typeIcon, color: statusColor, size: 22),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bill.type,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                              ),
                            ),
                            Text(
                              bill.isPaid
                                  ? 'Paid ✓'
                                  : bill.isOverdue
                                  ? 'OVERDUE'
                                  : 'Due ${DateFormat('MMM dd').format(bill.dueDate)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        currencyFormat.format(bill.amount),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                      SizedBox(width: 8),
                      if (canEdit) ...[                      GestureDetector(
                        onTap: () => state.toggleBillPaid(bill.id),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: bill.isPaid
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: bill.isPaid
                                  ? AppColors.primary
                                  : isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              width: 2,
                            ),
                          ),
                          child: bill.isPaid
                              ? Icon(Icons.check, color: Colors.white, size: 16)
                              : null,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_rounded, size: 20),
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        onPressed: () => _showBillDialog(context, bill: bill),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, size: 20),
                        color: AppColors.error,
                        onPressed: () => state.deleteUtilityBill(bill.id),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  void _showBillDialog(BuildContext context, {UtilityBill? bill}) {
    final amountCtrl = TextEditingController(
      text: bill?.amount.toString() ?? '',
    );
    String type = bill?.type ?? 'Electricity';
    DateTime dueDate = bill?.dueDate ?? DateTime.now().add(Duration(days: 15));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                bill == null ? 'Add Utility Bill' : 'Edit Utility Bill',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: type,
                      items:
                          [
                                'Electricity',
                                'Water',
                                'Internet',
                                'Gas',
                                'Phone',
                                'Other',
                              ]
                              .map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => type = v!),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(hintText: 'Amount (₹)'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: dueDate,
                    firstDate: DateTime.now().subtract(Duration(days: 30)),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                  );
                  if (date != null) setState(() => dueDate = date);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).inputDecorationTheme.fillColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Due: ${DateFormat('MMM dd, yyyy').format(dueDate)}',
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (amountCtrl.text.isNotEmpty) {
                      final newBill = UtilityBill(
                        id: bill?.id ?? '',
                        type: type,
                        amount: double.tryParse(amountCtrl.text) ?? 0,
                        billDate: bill?.billDate ?? DateTime.now(),
                        dueDate: dueDate,
                        isPaid: bill?.isPaid ?? false,
                      );
                      if (bill == null) {
                        context.read<AppState>().addUtilityBill(newBill);
                      } else {
                        context.read<AppState>().updateUtilityBill(newBill);
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    bill == null ? 'Add Bill' : 'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
