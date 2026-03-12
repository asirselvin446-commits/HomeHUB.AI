import '../models/models.dart';
import 'package:intl/intl.dart';

class AIService {
  // Predict next maintenance date based on history
  static DateTime? predictNextMaintenance(MaintenanceTask task) {
    if (task.history.length < 2) {
      // Default: use recurringDays from last service
      if (task.lastServiced != null) {
        return task.lastServiced!.add(Duration(days: task.recurringDays));
      }
      return null;
    }

    // Calculate average interval from history
    task.history.sort();
    int totalDays = 0;
    for (int i = 1; i < task.history.length; i++) {
      totalDays += task.history[i].difference(task.history[i - 1]).inDays;
    }
    int avgInterval = totalDays ~/ (task.history.length - 1);

    return task.history.last.add(Duration(days: avgInterval));
  }

  // Get maintenance suggestions
  static List<String> getMaintenanceSuggestions(List<MaintenanceTask> tasks) {
    List<String> suggestions = [];

    for (var task in tasks) {
      if (task.isOverdue) {
        suggestions.add(
            '⚠️ ${task.name} is overdue! It was due ${_daysAgo(task.nextDue!)}.');
      } else if (task.isDueSoon) {
        suggestions.add(
            '📅 ${task.name} is due in ${task.daysUntilDue} days. Schedule it soon!');
      }

      // Predict based on history
      if (task.history.length >= 2) {
        final predicted = predictNextMaintenance(task);
        if (predicted != null) {
          final avgDays = _getAverageInterval(task);
          suggestions.add(
              '🤖 Based on history, ${task.name} needs service every ~$avgDays days. Next predicted: ${DateFormat('MMM dd').format(predicted)}');
        }
      }
    }

    if (suggestions.isEmpty) {
      suggestions.add('✅ All maintenance tasks are up to date!');
    }

    return suggestions;
  }

  static int _getAverageInterval(MaintenanceTask task) {
    if (task.history.length < 2) return task.recurringDays;
    task.history.sort();
    int totalDays = 0;
    for (int i = 1; i < task.history.length; i++) {
      totalDays += task.history[i].difference(task.history[i - 1]).inDays;
    }
    return totalDays ~/ (task.history.length - 1);
  }

  static String _daysAgo(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return '1 day ago';
    return '$diff days ago';
  }

  // Financial Analysis
  static Map<String, dynamic> analyzeFinances({
    required List<Expense> expenses,
    required List<Debt> debts,
    required List<SavingsGoal> goals,
    required double monthlyIncome,
  }) {
    final now = DateTime.now();
    final thisMonth = expenses.where((e) =>
        e.date.month == now.month && e.date.year == now.year);
    final lastMonth = expenses.where((e) =>
        e.date.month == (now.month == 1 ? 12 : now.month - 1) &&
        e.date.year == (now.month == 1 ? now.year - 1 : now.year));

    double thisMonthTotal = thisMonth.fold(0.0, (sum, e) => sum + e.amount);
    double lastMonthTotal = lastMonth.fold(0.0, (sum, e) => sum + e.amount);

    double totalDebt = debts.fold(0.0, (sum, d) => sum + d.remainingAmount);
    double totalSaved = goals.fold(0.0, (sum, g) => sum + g.currentAmount);

    // Category breakdown
    Map<String, double> categoryBreakdown = {};
    for (var e in thisMonth) {
      categoryBreakdown[e.category] =
          (categoryBreakdown[e.category] ?? 0) + e.amount;
    }

    // Financial health score (0-100)
    double healthScore = 50;
    if (monthlyIncome > 0) {
      double savingsRate = (monthlyIncome - thisMonthTotal) / monthlyIncome;
      healthScore += savingsRate * 30; // Up to 30 from savings rate
    }
    if (totalDebt == 0) healthScore += 20;
    else if (totalDebt < monthlyIncome * 3) healthScore += 10;
    if (totalSaved > monthlyIncome * 3) healthScore += 10;
    healthScore = healthScore.clamp(0, 100);

    return {
      'thisMonthTotal': thisMonthTotal,
      'lastMonthTotal': lastMonthTotal,
      'monthlyChange': lastMonthTotal > 0
          ? ((thisMonthTotal - lastMonthTotal) / lastMonthTotal * 100)
          : 0.0,
      'totalDebt': totalDebt,
      'totalSaved': totalSaved,
      'categoryBreakdown': categoryBreakdown,
      'healthScore': healthScore,
      'suggestions': _getFinancialSuggestions(
        monthlyIncome: monthlyIncome,
        monthlyExpense: thisMonthTotal,
        totalDebt: totalDebt,
        debts: debts,
      ),
    };
  }

  static List<String> _getFinancialSuggestions({
    required double monthlyIncome,
    required double monthlyExpense,
    required double totalDebt,
    required List<Debt> debts,
  }) {
    List<String> suggestions = [];

    if (monthlyIncome > 0) {
      double savingsRate = (monthlyIncome - monthlyExpense) / monthlyIncome;
      if (savingsRate < 0.1) {
        suggestions.add(
            '💡 You\'re saving less than 10% of income. Try to reduce spending.');
      } else if (savingsRate > 0.3) {
        suggestions.add(
            '🌟 Great job! You\'re saving ${(savingsRate * 100).toInt()}% of your income.');
      }
    }

    if (totalDebt > 0 && monthlyIncome > 0) {
      double suggestedPayment = monthlyIncome * 0.2;
      int monthsToPayoff = (totalDebt / suggestedPayment).ceil();
      suggestions.add(
          '📊 If you save ₹${suggestedPayment.toStringAsFixed(0)}/month, your debt of ₹${totalDebt.toStringAsFixed(0)} can be cleared in ~$monthsToPayoff months.');
    }

    for (var debt in debts) {
      if (debt.monthlyPayment > 0) {
        suggestions.add(
            '📋 ${debt.name}: ₹${debt.remainingAmount.toStringAsFixed(0)} remaining. ${debt.monthsToPayoff} months to payoff at ₹${debt.monthlyPayment.toStringAsFixed(0)}/month.');
      }
    }

    if (suggestions.isEmpty) {
      suggestions.add('✅ Your finances look healthy!');
    }

    return suggestions;
  }

  // Home health scores
  static Map<String, double> getHomeHealthScores({
    required List<MaintenanceTask> maintenanceTasks,
    required List<HouseholdTask> householdTasks,
    required List<UtilityBill> bills,
  }) {
    // Maintenance score
    int totalMaint = maintenanceTasks.length;
    int overdueMaint = maintenanceTasks.where((t) => t.isOverdue).length;
    double maintScore =
        totalMaint > 0 ? ((totalMaint - overdueMaint) / totalMaint * 100) : 100;

    // Task completion score
    int totalTasks = householdTasks.length;
    int completedTasks = householdTasks.where((t) => t.isCompleted).length;
    double taskScore =
        totalTasks > 0 ? (completedTasks / totalTasks * 100) : 100;

    // Bills score
    int totalBills = bills.length;
    int overdueBills = bills.where((b) => b.isOverdue).length;
    double billScore =
        totalBills > 0 ? ((totalBills - overdueBills) / totalBills * 100) : 100;

    double overallScore = (maintScore + taskScore + billScore) / 3;

    return {
      'maintenance': maintScore,
      'tasks': taskScore,
      'bills': billScore,
      'overall': overallScore,
    };
  }

  // AI Chat Response
  static String getChatResponse({
    required String question,
    required List<MaintenanceTask> maintenanceTasks,
    required List<HouseholdTask> householdTasks,
    required List<GroceryItem> groceryItems,
    required List<Expense> expenses,
    required List<Debt> debts,
    required List<UtilityBill> bills,
    required double monthlyIncome,
  }) {
    final q = question.toLowerCase();
    final now = DateTime.now();
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    // Tasks due this week
    if (q.contains('task') && (q.contains('week') || q.contains('due'))) {
      final weekEnd = now.add(Duration(days: 7));
      final dueTasks = householdTasks.where((t) =>
          !t.isCompleted &&
          t.dueDate != null &&
          t.dueDate!.isBefore(weekEnd));
      if (dueTasks.isEmpty) return '✅ No tasks due this week! You\'re all caught up.';
      String response = '📋 Tasks due this week:\n';
      for (var t in dueTasks) {
        response += '• ${t.title} (${t.assignedTo ?? "Unassigned"}) - Due ${DateFormat('MMM dd').format(t.dueDate!)}\n';
      }
      return response;
    }

    // Grocery related
    if (q.contains('grocery') || q.contains('groceries')) {
      if (q.contains('how many') || q.contains('count')) {
        int unpurchased = groceryItems.where((g) => !g.isPurchased).length;
        return '🛒 You have $unpurchased items on your grocery list that haven\'t been purchased yet.';
      }
      final unpurchased = groceryItems.where((g) => !g.isPurchased).toList();
      if (unpurchased.isEmpty) return '✅ Your grocery list is all clear!';
      String response = '🛒 Grocery items to buy:\n';
      for (var g in unpurchased) {
        response += '• ${g.name} (${g.quantity} ${g.unit})\n';
      }
      return response;
    }

    // Expense related
    if (q.contains('spend') || q.contains('spent') || q.contains('expense')) {
      final thisMonth = expenses.where((e) =>
          e.date.month == now.month && e.date.year == now.year);

      if (q.contains('grocer')) {
        double grocerySpend = thisMonth
            .where((e) => e.category.toLowerCase().contains('grocer'))
            .fold(0.0, (sum, e) => sum + e.amount);
        return '🛒 You\'ve spent ${currencyFormat.format(grocerySpend)} on groceries this month.';
      }

      double total = thisMonth.fold(0.0, (sum, e) => sum + e.amount);
      Map<String, double> categories = {};
      for (var e in thisMonth) {
        categories[e.category] = (categories[e.category] ?? 0) + e.amount;
      }

      String response = '💰 This month\'s spending: ${currencyFormat.format(total)}\n\nBreakdown:\n';
      categories.forEach((cat, amt) {
        response += '• $cat: ${currencyFormat.format(amt)}\n';
      });
      return response;
    }

    // Maintenance / AC related
    if (q.contains('maintenance') || q.contains('ac') || q.contains('service')) {
      String searchTerm = '';
      if (q.contains('ac') || q.contains('air condition')) searchTerm = 'ac';
      if (q.contains('plumb')) searchTerm = 'plumb';
      if (q.contains('electric')) searchTerm = 'electric';

      if (searchTerm.isNotEmpty) {
        final task = maintenanceTasks.firstWhere(
          (t) => t.name.toLowerCase().contains(searchTerm) ||
              t.category.toLowerCase().contains(searchTerm),
          orElse: () => MaintenanceTask(
              id: '', name: '', category: ''),
        );
        if (task.id.isNotEmpty) {
          if (task.nextDue != null) {
            return '🔧 ${task.name} is scheduled for ${DateFormat('MMM dd, yyyy').format(task.nextDue!)}. ${task.isOverdue ? '⚠️ It\'s overdue!' : ''}';
          }
          return '🔧 ${task.name} has no scheduled date. Consider setting one!';
        }
        return 'I couldn\'t find a maintenance task matching "$searchTerm". Try adding one!';
      }

      final upcoming = maintenanceTasks
          .where((t) => !t.isCompleted && t.nextDue != null)
          .toList()
        ..sort((a, b) => a.nextDue!.compareTo(b.nextDue!));

      if (upcoming.isEmpty) return '✅ No upcoming maintenance tasks.';
      String response = '🔧 Upcoming maintenance:\n';
      for (var t in upcoming.take(5)) {
        response += '• ${t.name} - ${DateFormat('MMM dd').format(t.nextDue!)} ${t.isOverdue ? "⚠️ OVERDUE" : ""}\n';
      }
      return response;
    }

    // Debt related
    if (q.contains('debt') || q.contains('loan') || q.contains('owe')) {
      if (debts.isEmpty) return '🎉 You have no debts recorded. That\'s great!';
      double totalDebt = debts.fold(0.0, (sum, d) => sum + d.remainingAmount);
      String response = '💳 Total remaining debt: ${currencyFormat.format(totalDebt)}\n\n';
      for (var d in debts) {
        response += '• ${d.name}: ${currencyFormat.format(d.remainingAmount)} remaining';
        if (d.monthlyPayment > 0) {
          response += ' (~${d.monthsToPayoff} months to payoff)';
        }
        response += '\n';
      }
      return response;
    }

    // Bills
    if (q.contains('bill')) {
      final unpaid = bills.where((b) => !b.isPaid).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      if (unpaid.isEmpty) return '✅ All bills are paid!';
      String response = '📄 Unpaid bills:\n';
      for (var b in unpaid) {
        response += '• ${b.type}: ${currencyFormat.format(b.amount)} - Due ${DateFormat('MMM dd').format(b.dueDate)} ${b.isOverdue ? "⚠️ OVERDUE" : ""}\n';
      }
      return response;
    }

    // Health / score
    if (q.contains('health') || q.contains('score') || q.contains('status')) {
      final scores = getHomeHealthScores(
        maintenanceTasks: maintenanceTasks,
        householdTasks: householdTasks,
        bills: bills,
      );
      return '🏠 Home Health Score: ${scores['overall']!.toInt()}/100\n\n'
          '🔧 Maintenance: ${scores['maintenance']!.toInt()}%\n'
          '📋 Tasks: ${scores['tasks']!.toInt()}%\n'
          '📄 Bills: ${scores['bills']!.toInt()}%';
    }

    // Default / Help
    return '🤖 I can help you with:\n\n'
        '• "What tasks are due this week?"\n'
        '• "How much did we spend on groceries?"\n'
        '• "When should the AC be serviced next?"\n'
        '• "What\'s on the grocery list?"\n'
        '• "What\'s our debt status?"\n'
        '• "Show me the home health score"\n'
        '• "Show unpaid bills"\n\n'
        'Try asking one of these questions!';
  }
}
