import '../models/models.dart';
import 'package:intl/intl.dart';

// --- Action & Result Types ---

class AIAction {
  final String type; // 'add_grocery', 'add_task', 'complete_grocery', 'complete_task', 'delete_grocery'
  final Map<String, dynamic> data;

  const AIAction({required this.type, required this.data});
}

class AIResult {
  final String reply;
  final AIAction? action;

  const AIResult({required this.reply, this.action});
}

// --- Helpers ---

final _currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

String _pick(List<String> options) {
  options.shuffle();
  return options.first;
}

// -----------------------------------------------------------
// Main public API
// -----------------------------------------------------------

class AIService {
  /// Process a user message: detect intent, return a human reply + optional action.
  static AIResult processMessage({
    required String message,
    required List<MaintenanceTask> maintenanceTasks,
    required List<HouseholdTask> householdTasks,
    required List<GroceryItem> groceryItems,
    required List<Expense> expenses,
    required List<Debt> debts,
    required List<UtilityBill> bills,
    required double monthlyIncome,
  }) {
    final q = message.trim().toLowerCase();

    // --- ACTION: Add grocery ---
    final addGrocery = _detectAddGrocery(q, message);
    if (addGrocery != null) return addGrocery;

    // --- ACTION: Mark grocery purchased ---
    final buyGrocery = _detectBuyGrocery(q, groceryItems);
    if (buyGrocery != null) return buyGrocery;

    // --- ACTION: Remove grocery ---
    final removeGrocery = _detectRemoveGrocery(q, groceryItems);
    if (removeGrocery != null) return removeGrocery;

    // --- ACTION: Add task ---
    final addTask = _detectAddTask(q, message);
    if (addTask != null) return addTask;

    // --- ACTION: Complete task ---
    final completeTask = _detectCompleteTask(q, householdTasks);
    if (completeTask != null) return completeTask;

    // --- QUERY: tasks due ---
    if ((q.contains('task') || q.contains('to-do') || q.contains('todo')) &&
        (q.contains('week') || q.contains('due') || q.contains('pending') || q.contains('what'))) {
      return AIResult(reply: _queryTasksDue(householdTasks));
    }

    // --- QUERY: grocery list ---
    if (q.contains('grocery') || q.contains('groceries') || q.contains('shopping list')) {
      if (q.contains('how many') || q.contains('count')) {
        final n = groceryItems.where((g) => !g.isPurchased).length;
        return AIResult(reply: _pick([
          'You\'ve got $n items still to pick up from the store 🛒',
          'There are $n things left on your grocery list right now.',
          'Looks like $n items are waiting to be bought! 🛒',
        ]));
      }
      return AIResult(reply: _queryGroceries(groceryItems));
    }

    // --- QUERY: spending / expenses ---
    if (q.contains('spend') || q.contains('spent') || q.contains('expense') || q.contains('budget')) {
      return AIResult(reply: _queryExpenses(expenses, monthlyIncome));
    }

    // --- QUERY: maintenance / service ---
    if (q.contains('maintenance') || q.contains('service') || q.contains('ac') ||
        q.contains('plumb') || q.contains('electr') || q.contains('repair')) {
      return AIResult(reply: _queryMaintenance(q, maintenanceTasks));
    }

    // --- QUERY: debt / loan ---
    if (q.contains('debt') || q.contains('loan') || q.contains('owe') || q.contains('borrow')) {
      return AIResult(reply: _queryDebts(debts));
    }

    // --- QUERY: bills ---
    if (q.contains('bill') || q.contains('utility') || q.contains('electricity') || q.contains('water')) {
      return AIResult(reply: _queryBills(bills));
    }

    // --- QUERY: health / score ---
    if (q.contains('health') || q.contains('score') || q.contains('status') || q.contains('overview')) {
      return AIResult(reply: _queryHealthScore(maintenanceTasks, householdTasks, bills));
    }

    // --- QUERY: hello / greet ---
    if (q.contains('hello') || q.contains('hi') || q.contains('hey') || q.contains('good morning') || q.contains('good evening')) {
      return AIResult(reply: _pick([
        'Hey there! 👋 How can I help you today? I can add tasks, update your grocery list, or answer questions about your home.',
        'Hi! Great to see you 😊 What can I help you with? I can manage tasks, groceries, check your bills — just ask!',
        'Hello! I\'m here to help. Want me to add something to your list, or do you have a question?',
      ]));
    }

    // --- QUERY: help ---
    if (q.contains('help') || q.contains('what can you') || q.contains('what do you')) {
      return AIResult(reply: _helpMessage());
    }

    // --- Default ---
    return AIResult(reply: _pick([
      'Hmm, I\'m not quite sure what you mean by that 🤔 Try saying something like "Add milk to groceries" or "What tasks are due?"',
      'I didn\'t catch that — could you rephrase? You can ask me to add tasks, check groceries, or get a spending summary.',
      'Not sure I understood that one! Try "Add task clean kitchen" or "What\'s on the grocery list?" and I\'ll get right on it.',
    ]));
  }

  // -----------------------------------------------------------
  // Intent detectors
  // -----------------------------------------------------------

  static final _qtyRegex = RegExp(r'\b(\d+)\s*(kg|g|grams?|litre?s?|l|ml|pcs?|pieces?|packets?|pkt|bottles?|boxes?|cans?|dozens?|doz|bunches?|bags?)?\b', caseSensitive: false);

  static AIResult? _detectAddGrocery(String q, String original) {
    // Patterns: "add X to grocery/list", "buy X", "get X from store", "pick up X", "need X"
    final patterns = [
      RegExp(r'add\s+(.+?)\s+(?:to\s+(?:the\s+)?(?:grocery|shopping|groceries|list))', caseSensitive: false),
      RegExp(r'(?:buy|get|pick up|grab|purchase|order)\s+(?:some\s+)?(.+?)(?:\s+from\s+(?:the\s+)?(?:store|market|shop))?$', caseSensitive: false),
      RegExp(r'(?:put|add)\s+(.+?)\s+(?:on|in)\s+(?:the\s+)?(?:grocery|shopping|list)', caseSensitive: false),
      RegExp(r'(?:need|we need|i need)\s+(?:some\s+)?(.+?)(?:\s+from\s+(?:the\s+)?(?:store|market))?$', caseSensitive: false),
      RegExp(r'(?:remind me to\s+)?(?:get|buy)\s+(.+)', caseSensitive: false),
    ];

    // Exclude if it looks like a task-add intent
    if (q.contains('task') || q.contains('remind me to clean') || q.contains('remind me to pay') || q.contains('remind me to fix')) return null;

    for (final pattern in patterns) {
      final match = pattern.firstMatch(original);
      if (match != null) {
        String itemRaw = match.group(1)?.trim() ?? '';
        if (itemRaw.isEmpty || itemRaw.length > 60) continue;

        // Parse quantity
        int qty = 1;
        String unit = 'pcs';
        final qtyMatch = _qtyRegex.firstMatch(itemRaw);
        if (qtyMatch != null) {
          final numStr = qtyMatch.group(1);
          final unitStr = qtyMatch.group(2);
          if (numStr != null) qty = int.tryParse(numStr) ?? 1;
          if (unitStr != null && unitStr.isNotEmpty) {
            unit = unitStr.toLowerCase();
            itemRaw = itemRaw.replaceAll(qtyMatch.group(0) ?? '', '').trim();
          }
        }

        // Clean filler words
        String itemName = itemRaw
            .replaceAll(RegExp(r'^(some|a|an|the)\s+', caseSensitive: false), '')
            .trim();
        itemName = _toTitleCase(itemName);

        if (itemName.isEmpty || itemName.length > 50) continue;

        final reply = _pick([
          'Sure! I\'ve added **$itemName** to your grocery list 🛒',
          'Done! **$itemName** is now on the shopping list ✅',
          'Got it — **$itemName** has been added to your groceries 🛒',
          'Added **$itemName** to the list! Anything else you need?',
        ]);

        return AIResult(
          reply: reply,
          action: AIAction(type: 'add_grocery', data: {
            'name': itemName,
            'quantity': qty,
            'unit': unit,
            'category': 'General',
          }),
        );
      }
    }
    return null;
  }

  static AIResult? _detectBuyGrocery(String q, List<GroceryItem> groceryItems) {
    // "mark milk as bought/purchased", "I bought eggs", "got eggs", "picked up milk"
    final patterns = [
      RegExp(r'(?:mark|set)\s+(.+?)\s+as\s+(?:bought|purchased|done|got|gotten)', caseSensitive: false),
      RegExp(r'(?:i\s+)?(?:bought|purchased|got|picked up|grabbed)\s+(?:the\s+)?(.+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(q);
      if (match != null) {
        final keyword = match.group(1)?.trim().toLowerCase() ?? '';
        if (keyword.isEmpty) continue;
        final item = groceryItems.firstWhere(
          (g) => !g.isPurchased && g.name.toLowerCase().contains(keyword),
          orElse: () => GroceryItem(id: '', name: ''),
        );
        if (item.id.isNotEmpty) {
          final reply = _pick([
            'Perfect! I\'ve marked **${item.name}** as purchased ✅',
            'Done! **${item.name}** is checked off your grocery list 🎉',
            'Got it — **${item.name}** is marked as bought!',
          ]);
          return AIResult(
            reply: reply,
            action: AIAction(type: 'complete_grocery', data: {'id': item.id}),
          );
        } else {
          return AIResult(reply: 'Hmm, I couldn\'t find "$keyword" on your grocery list. Maybe it\'s already purchased or spelled differently?');
        }
      }
    }
    return null;
  }

  static AIResult? _detectRemoveGrocery(String q, List<GroceryItem> groceryItems) {
    // "remove milk from list", "delete eggs from groceries"
    final pattern = RegExp(r'(?:remove|delete|cancel)\s+(.+?)\s+(?:from\s+(?:the\s+)?(?:grocery|shopping|list|groceries))', caseSensitive: false);
    final match = pattern.firstMatch(q);
    if (match != null) {
      final keyword = match.group(1)?.trim().toLowerCase() ?? '';
      if (keyword.isEmpty) return null;
      final item = groceryItems.firstWhere(
        (g) => g.name.toLowerCase().contains(keyword),
        orElse: () => GroceryItem(id: '', name: ''),
      );
      if (item.id.isNotEmpty) {
        final reply = _pick([
          'Okay! I\'ve removed **${item.name}** from your grocery list.',
          'Done — **${item.name}** has been removed from the shopping list.',
        ]);
        return AIResult(
          reply: reply,
          action: AIAction(type: 'delete_grocery', data: {'id': item.id}),
        );
      } else {
        return AIResult(reply: 'I couldn\'t find "$keyword" on your grocery list. It might already be removed!');
      }
    }
    return null;
  }

  static AIResult? _detectAddTask(String q, String original) {
    // "add task X", "create task X", "remind me to X", "add a task to X"
    final patterns = [
      RegExp(r'(?:add|create|new)\s+(?:a\s+)?task\s+(?:to\s+)?(.+)', caseSensitive: false),
      RegExp(r'remind\s+me\s+to\s+(.+)', caseSensitive: false),
      RegExp(r'(?:schedule|set up|create)\s+(?:a\s+)?(?:reminder|todo)\s+(?:for\s+)?(.+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(original);
      if (match != null) {
        String taskRaw = match.group(1)?.trim() ?? '';
        if (taskRaw.isEmpty || taskRaw.length > 100) continue;

        // Parse due date hints
        DateTime? dueDate;
        String priority = 'medium';

        if (taskRaw.contains('today')) {
          dueDate = DateTime.now();
          taskRaw = taskRaw.replaceAll(RegExp(r'\s*today\s*', caseSensitive: false), ' ').trim();
        } else if (taskRaw.contains('tomorrow')) {
          dueDate = DateTime.now().add(const Duration(days: 1));
          taskRaw = taskRaw.replaceAll(RegExp(r'\s*tomorrow\s*', caseSensitive: false), ' ').trim();
        } else if (taskRaw.contains('next week')) {
          dueDate = DateTime.now().add(const Duration(days: 7));
          taskRaw = taskRaw.replaceAll(RegExp(r'\s*next week\s*', caseSensitive: false), ' ').trim();
        } else if (taskRaw.contains('this week')) {
          dueDate = DateTime.now().add(const Duration(days: 5));
          taskRaw = taskRaw.replaceAll(RegExp(r'\s*this week\s*', caseSensitive: false), ' ').trim();
        }

        // Parse priority hints
        if (taskRaw.contains('urgent') || taskRaw.contains('asap') || taskRaw.contains('important') || taskRaw.contains('critical')) {
          priority = 'high';
        }

        // Detect category
        String category = 'General';
        if (taskRaw.contains('clean') || taskRaw.contains('mop') || taskRaw.contains('vacuum') || taskRaw.contains('wash')) {
          category = 'Cleaning';
        } else if (taskRaw.contains('pay') || taskRaw.contains('bill') || taskRaw.contains('bank')) {
          category = 'Bills';
        } else if (taskRaw.contains('buy') || taskRaw.contains('shop') || taskRaw.contains('grocery')) {
          category = 'Shopping';
        } else if (taskRaw.contains('fix') || taskRaw.contains('repair') || taskRaw.contains('service')) {
          category = 'Maintenance';
        } else if (taskRaw.contains('cook') || taskRaw.contains('meal') || taskRaw.contains('food')) {
          category = 'Cooking';
        }

        // Clean trailing punctuation / filler
        taskRaw = taskRaw.replaceAll(RegExp(r'\s+'), ' ').trim();
        taskRaw = taskRaw.replaceAll(RegExp(r'[.!?]+$'), '').trim();
        final taskTitle = _toTitleCase(taskRaw);

        if (taskTitle.isEmpty) continue;

        final dueDateStr = dueDate != null
            ? ' for ${DateFormat('MMM dd').format(dueDate)}'
            : '';
        final reply = _pick([
          'Got it! I\'ve added **"$taskTitle"** to your task list$dueDateStr ✅',
          'Done! **"$taskTitle"** has been added as a task$dueDateStr 📋',
          'Sure thing! **"$taskTitle"** is now on your task list$dueDateStr.',
        ]);

        return AIResult(
          reply: reply,
          action: AIAction(type: 'add_task', data: {
            'title': taskTitle,
            'category': category,
            'priority': priority,
            'dueDate': dueDate?.toIso8601String(),
          }),
        );
      }
    }
    return null;
  }

  static AIResult? _detectCompleteTask(String q, List<HouseholdTask> tasks) {
    // "mark task clean kitchen as done", "complete task pay bills", "done with clean kitchen"
    final patterns = [
      RegExp(r'(?:mark|set|complete|finish)\s+(?:task\s+)?(.+?)\s+(?:as\s+)?(?:done|complete|finished|completed)', caseSensitive: false),
      RegExp(r'(?:done|finished)\s+(?:with\s+)?(?:the\s+)?task\s+(.+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(q);
      if (match != null) {
        final keyword = match.group(1)?.trim().toLowerCase() ?? '';
        if (keyword.isEmpty) continue;
        final task = tasks.firstWhere(
          (t) => !t.isCompleted && t.title.toLowerCase().contains(keyword),
          orElse: () => HouseholdTask(id: '', title: '', category: ''),
        );
        if (task.id.isNotEmpty) {
          final reply = _pick([
            'Awesome! I\'ve marked **"${task.title}"** as done 🎉',
            'Nice work! **"${task.title}"** is now complete ✅',
            'Done! **"${task.title}"** has been checked off your list.',
          ]);
          return AIResult(
            reply: reply,
            action: AIAction(type: 'complete_task', data: {'id': task.id}),
          );
        } else {
          return AIResult(reply: 'I couldn\'t find a pending task matching "$keyword". Could you check the task name in the Tasks screen?');
        }
      }
    }
    return null;
  }

  // -----------------------------------------------------------
  // Query builders
  // -----------------------------------------------------------

  static String _queryTasksDue(List<HouseholdTask> tasks) {
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));
    final dueTasks = tasks
        .where((t) => !t.isCompleted && t.dueDate != null && t.dueDate!.isBefore(weekEnd))
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    if (dueTasks.isEmpty) {
      return _pick([
        'All clear! No tasks due this week — you\'re on top of things 🎉',
        'You\'re all caught up! Nothing is due in the next 7 days.',
        'Looking good! No pending tasks for this week 😊',
      ]);
    }

    final intro = _pick([
      'Here\'s what\'s on the agenda this week:',
      'These tasks need your attention in the next 7 days:',
      'Coming up this week — don\'t forget these:',
    ]);

    String response = '$intro\n\n';
    for (var t in dueTasks) {
      final overdue = t.isOverdue ? ' ⚠️ OVERDUE' : '';
      response += '• ${t.title}${t.assignedTo != null ? ' (${t.assignedTo})' : ''} — Due ${DateFormat('EEE, MMM dd').format(t.dueDate!)}$overdue\n';
    }
    return response.trim();
  }

  static String _queryGroceries(List<GroceryItem> groceryItems) {
    final unpurchased = groceryItems.where((g) => !g.isPurchased).toList();
    if (unpurchased.isEmpty) {
      return _pick([
        'Your grocery list is all clear — nothing left to buy! ✅',
        'The shopping list is empty! You\'re all stocked up 🎉',
        'Nothing on the grocery list right now.',
      ]);
    }
    final intro = _pick([
      'Here\'s what you still need to pick up:',
      'These items are waiting on your grocery list:',
      'Shopping list — things left to buy:',
    ]);
    String response = '$intro\n\n';
    for (var g in unpurchased) {
      response += '• ${g.name} — ${g.quantity} ${g.unit}\n';
    }
    return response.trim();
  }

  static String _queryExpenses(List<Expense> expenses, double monthlyIncome) {
    final now = DateTime.now();
    final thisMonth = expenses.where((e) => e.date.month == now.month && e.date.year == now.year).toList();
    if (thisMonth.isEmpty) {
      return 'No expenses recorded for this month yet. Track your first expense in the Finance screen!';
    }
    double total = thisMonth.fold(0.0, (sum, e) => sum + e.amount);
    Map<String, double> cats = {};
    for (var e in thisMonth) {
      cats[e.category] = (cats[e.category] ?? 0) + e.amount;
    }
    final sortedCats = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final intro = _pick([
      'Here\'s a quick look at your spending this month:',
      'Your expenses so far this month:',
      'Month-to-date spending summary:',
    ]);

    String response = '$intro\n\n💰 **Total: ${_currencyFormat.format(total)}**\n\nBreakdown by category:\n';
    for (var entry in sortedCats) {
      response += '• ${entry.key}: ${_currencyFormat.format(entry.value)}\n';
    }

    if (monthlyIncome > 0) {
      final remaining = monthlyIncome - total;
      if (remaining > 0) {
        response += '\nYou still have **${_currencyFormat.format(remaining)}** left from your monthly budget 👍';
      } else {
        response += '\n⚠️ You\'ve gone **${_currencyFormat.format(-remaining)}** over budget this month.';
      }
    }
    return response.trim();
  }

  static String _queryMaintenance(String q, List<MaintenanceTask> tasks) {
    // Specific item lookup
    final keywords = {'ac': 'ac', 'air condition': 'ac', 'plumb': 'plumb', 'electr': 'electr',
      'water': 'water', 'purifier': 'purif', 'generator': 'generator'};
    for (final kv in keywords.entries) {
      if (q.contains(kv.key)) {
        final task = tasks.firstWhere(
          (t) => t.name.toLowerCase().contains(kv.value) || t.category.toLowerCase().contains(kv.value),
          orElse: () => MaintenanceTask(id: '', name: '', category: ''),
        );
        if (task.id.isNotEmpty && task.nextDue != null) {
          final overdue = task.isOverdue ? ' — ⚠️ This is already overdue!' : '';
          return '${task.name} is scheduled for ${DateFormat('EEE, MMM dd, yyyy').format(task.nextDue!)}$overdue';
        }
      }
    }

    final upcoming = tasks.where((t) => !t.isCompleted && t.nextDue != null).toList()
      ..sort((a, b) => a.nextDue!.compareTo(b.nextDue!));

    if (upcoming.isEmpty) {
      return 'No upcoming maintenance tasks scheduled. You can add one in the Maintenance screen!';
    }

    final intro = _pick([
      'Here\'s your upcoming maintenance schedule:',
      'These maintenance tasks are coming up soon:',
      'Maintenance tasks on the radar:',
    ]);
    String response = '$intro\n\n';
    for (var t in upcoming.take(5)) {
      final overdue = t.isOverdue ? ' ⚠️ OVERDUE' : '';
      response += '• ${t.name} — ${DateFormat('MMM dd').format(t.nextDue!)}$overdue\n';
    }
    return response.trim();
  }

  static String _queryDebts(List<Debt> debts) {
    if (debts.isEmpty) {
      return _pick([
        '🎉 No debts recorded — that\'s amazing!',
        'You have no debts in your records. Keep it up! 💪',
      ]);
    }
    double total = debts.fold(0.0, (sum, d) => sum + d.remainingAmount);
    String response = 'Here\'s your current debt overview:\n\n💳 **Total remaining: ${_currencyFormat.format(total)}**\n\n';
    for (var d in debts) {
      response += '• **${d.name}**: ${_currencyFormat.format(d.remainingAmount)} remaining';
      if (d.monthlyPayment > 0) {
        response += ' (~${d.monthsToPayoff} months to pay off)';
      }
      response += '\n';
    }
    return response.trim();
  }

  static String _queryBills(List<UtilityBill> bills) {
    final unpaid = bills.where((b) => !b.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    if (unpaid.isEmpty) {
      return _pick([
        'All bills paid! You\'re on top of your finances 🎉',
        'No unpaid bills — great job staying on top of things! ✅',
      ]);
    }
    final intro = _pick([
      'Here are your unpaid bills:',
      'Bills that still need to be paid:',
    ]);
    String response = '$intro\n\n';
    for (var b in unpaid) {
      final overdue = b.isOverdue ? ' ⚠️ OVERDUE' : '';
      response += '• **${b.type}**: ${_currencyFormat.format(b.amount)} — Due ${DateFormat('MMM dd').format(b.dueDate)}$overdue\n';
    }
    return response.trim();
  }

  static String _queryHealthScore(
      List<MaintenanceTask> maintenance, List<HouseholdTask> tasks, List<UtilityBill> bills) {
    final scores = getHomeHealthScores(maintenanceTasks: maintenance, householdTasks: tasks, bills: bills);
    final overall = scores['overall']!.toInt();

    String verdict;
    if (overall >= 80) {
      verdict = 'Your home is in great shape! Keep it up 🏠✨';
    } else if (overall >= 60) {
      verdict = 'Things are mostly good, but a few areas need attention.';
    } else {
      verdict = 'There are some things that need your attention soon.';
    }

    return '$verdict\n\n'
        '🏠 **Overall Score: $overall / 100**\n\n'
        '🔧 Maintenance: ${scores['maintenance']!.toInt()}%\n'
        '📋 Tasks: ${scores['tasks']!.toInt()}%\n'
        '📄 Bills: ${scores['bills']!.toInt()}%';
  }

  static String _helpMessage() {
    return 'Here\'s what I can help you with:\n\n'
        '**Add things:**\n'
        '• "Add milk to groceries"\n'
        '• "Add task clean kitchen tomorrow"\n'
        '• "Remind me to pay rent"\n\n'
        '**Mark as done:**\n'
        '• "I bought eggs"\n'
        '• "Mark task clean bathroom as done"\n\n'
        '**Remove items:**\n'
        '• "Remove milk from grocery list"\n\n'
        '**Ask questions:**\n'
        '• "What tasks are due this week?"\n'
        '• "What\'s on the grocery list?"\n'
        '• "How much did we spend this month?"\n'
        '• "When should the AC be serviced?"\n'
        '• "Show unpaid bills"\n'
        '• "What\'s our home health score?"';
  }

  // -----------------------------------------------------------
  // Utility: Title Case
  // -----------------------------------------------------------

  static String _toTitleCase(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }

  // -----------------------------------------------------------
  // Legacy methods (still used by dashboard / finance screens)
  // -----------------------------------------------------------

  static DateTime? predictNextMaintenance(MaintenanceTask task) {
    if (task.history.length < 2) {
      if (task.lastServiced != null) {
        return task.lastServiced!.add(Duration(days: task.recurringDays));
      }
      return null;
    }
    task.history.sort();
    int totalDays = 0;
    for (int i = 1; i < task.history.length; i++) {
      totalDays += task.history[i].difference(task.history[i - 1]).inDays;
    }
    int avgInterval = totalDays ~/ (task.history.length - 1);
    return task.history.last.add(Duration(days: avgInterval));
  }

  static List<String> getMaintenanceSuggestions(List<MaintenanceTask> tasks) {
    List<String> suggestions = [];
    for (var task in tasks) {
      if (task.isOverdue) {
        suggestions.add('⚠️ ${task.name} is overdue! It was due ${_daysAgo(task.nextDue!)}.');
      } else if (task.isDueSoon) {
        suggestions.add('📅 ${task.name} is due in ${task.daysUntilDue} days. Schedule it soon!');
      }
      if (task.history.length >= 2) {
        final predicted = predictNextMaintenance(task);
        if (predicted != null) {
          final avgDays = _getAverageInterval(task);
          suggestions.add('🤖 Based on history, ${task.name} needs service every ~$avgDays days. Next predicted: ${DateFormat('MMM dd').format(predicted)}');
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

  static Map<String, dynamic> analyzeFinances({
    required List<Expense> expenses,
    required List<Debt> debts,
    required List<SavingsGoal> goals,
    required double monthlyIncome,
  }) {
    final now = DateTime.now();
    final thisMonth = expenses.where((e) => e.date.month == now.month && e.date.year == now.year);
    final lastMonth = expenses.where((e) =>
        e.date.month == (now.month == 1 ? 12 : now.month - 1) &&
        e.date.year == (now.month == 1 ? now.year - 1 : now.year));

    double thisMonthTotal = thisMonth.fold(0.0, (sum, e) => sum + e.amount);
    double lastMonthTotal = lastMonth.fold(0.0, (sum, e) => sum + e.amount);
    double totalDebt = debts.fold(0.0, (sum, d) => sum + d.remainingAmount);
    double totalSaved = goals.fold(0.0, (sum, g) => sum + g.currentAmount);

    Map<String, double> categoryBreakdown = {};
    for (var e in thisMonth) {
      categoryBreakdown[e.category] = (categoryBreakdown[e.category] ?? 0) + e.amount;
    }

    double healthScore = 50;
    if (monthlyIncome > 0) {
      double savingsRate = (monthlyIncome - thisMonthTotal) / monthlyIncome;
      healthScore += savingsRate * 30;
    }
    if (totalDebt == 0) healthScore += 20;
    else if (totalDebt < monthlyIncome * 3) healthScore += 10;
    if (totalSaved > monthlyIncome * 3) healthScore += 10;
    healthScore = healthScore.clamp(0, 100);

    return {
      'thisMonthTotal': thisMonthTotal,
      'lastMonthTotal': lastMonthTotal,
      'monthlyChange': lastMonthTotal > 0 ? ((thisMonthTotal - lastMonthTotal) / lastMonthTotal * 100) : 0.0,
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
        suggestions.add('💡 You\'re saving less than 10% of income. Try to reduce spending.');
      } else if (savingsRate > 0.3) {
        suggestions.add('🌟 Great job! You\'re saving ${(savingsRate * 100).toInt()}% of your income.');
      }
    }
    if (totalDebt > 0 && monthlyIncome > 0) {
      double suggestedPayment = monthlyIncome * 0.2;
      int monthsToPayoff = (totalDebt / suggestedPayment).ceil();
      suggestions.add('📊 If you save ₹${suggestedPayment.toStringAsFixed(0)}/month, your debt of ₹${totalDebt.toStringAsFixed(0)} can be cleared in ~$monthsToPayoff months.');
    }
    for (var debt in debts) {
      if (debt.monthlyPayment > 0) {
        suggestions.add('📋 ${debt.name}: ₹${debt.remainingAmount.toStringAsFixed(0)} remaining. ${debt.monthsToPayoff} months to payoff at ₹${debt.monthlyPayment.toStringAsFixed(0)}/month.');
      }
    }
    if (suggestions.isEmpty) {
      suggestions.add('✅ Your finances look healthy!');
    }
    return suggestions;
  }

  static Map<String, double> getHomeHealthScores({
    required List<MaintenanceTask> maintenanceTasks,
    required List<HouseholdTask> householdTasks,
    required List<UtilityBill> bills,
  }) {
    int totalMaint = maintenanceTasks.length;
    int overdueMaint = maintenanceTasks.where((t) => t.isOverdue).length;
    double maintScore = totalMaint > 0 ? ((totalMaint - overdueMaint) / totalMaint * 100) : 100;

    int totalTasks = householdTasks.length;
    int completedTasks = householdTasks.where((t) => t.isCompleted).length;
    double taskScore = totalTasks > 0 ? (completedTasks / totalTasks * 100) : 100;

    int totalBills = bills.length;
    int overdueBills = bills.where((b) => b.isOverdue).length;
    double billScore = totalBills > 0 ? ((totalBills - overdueBills) / totalBills * 100) : 100;

    double overallScore = (maintScore + taskScore + billScore) / 3;

    return {
      'maintenance': maintScore,
      'tasks': taskScore,
      'bills': billScore,
      'overall': overallScore,
    };
  }
<<<<<<< HEAD
=======

  // AI Chat Response
  static AICommand getChatResponse({
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

    // Command Parsing Setup
    // 1. Add Task: "add task [title]"
    final addTaskMatch = RegExp(r'^add task (.+)$').firstMatch(q);
    if (addTaskMatch != null) {
      final title = addTaskMatch.group(1)!.trim();
      return AICommand(
        responseText: 'Adding task "$title" to your to-do list.',
        actionType: AIActionType.addTask,
        actionData: {'title': title},
      );
    }

    // 2. Complete Task: "complete task [title]" or "mark task [title] as done"
    final completeTaskMatch = RegExp(r'^(?:complete task|mark task) (.+?)(?: as done)?$').firstMatch(q);
    if (completeTaskMatch != null) {
      final title = completeTaskMatch.group(1)!.trim();
      return AICommand(
        responseText: 'Marking task "$title" as completed.',
        actionType: AIActionType.completeTask,
        actionData: {'title': title},
      );
    }

    // 3. Add Grocery: "add [item] to groceries" or "buy [item]"
    final addGroceryMatch = RegExp(r'^(?:add|buy) (.+?)(?: to grocer(?:y|ies)(?: list)?)?$').firstMatch(q);
    if (addGroceryMatch != null && !q.startsWith('add task')) {
      final item = addGroceryMatch.group(1)!.trim();
      return AICommand(
        responseText: 'Adding "$item" to your grocery list.',
        actionType: AIActionType.addGrocery,
        actionData: {'name': item},
      );
    }

    // 4. Add Expense: "spent [amount] on [title]" or "log expense [amount] for [title]"
    final addExpenseMatch = RegExp(r'^(?:spent|log expense) (?:rs\.?|₹|\$)?\s*(\d+(?:\.\d+)?)\s+(?:on|for) (.+)$').firstMatch(q);
    if (addExpenseMatch != null) {
      final amount = double.tryParse(addExpenseMatch.group(1)!) ?? 0.0;
      final title = addExpenseMatch.group(2)!.trim();
      return AICommand(
        responseText: 'Logging expense of ${currencyFormat.format(amount)} for "$title".',
        actionType: AIActionType.addExpense,
        actionData: {'amount': amount, 'title': title},
      );
    }

    // Previous standard responses
    String responseText = '';

    // Tasks due this week
    if (q.contains('task') && (q.contains('week') || q.contains('due'))) {
      final weekEnd = now.add(Duration(days: 7));
      final dueTasks = householdTasks.where((t) =>
          !t.isCompleted &&
          t.dueDate != null &&
          t.dueDate!.isBefore(weekEnd));
      if (dueTasks.isEmpty) {
        responseText = '✅ No tasks due this week! You\'re all caught up.';
      } else {
        responseText = '📋 Tasks due this week:\n';
        for (var t in dueTasks) {
          responseText += '• ${t.title} (${t.assignedTo ?? "Unassigned"}) - Due ${DateFormat('MMM dd').format(t.dueDate!)}\n';
        }
      }
      return AICommand(responseText: responseText);
    }

    // Grocery related
    if (q.contains('grocery') || q.contains('groceries')) {
      if (q.contains('how many') || q.contains('count')) {
        int unpurchased = groceryItems.where((g) => !g.isPurchased).length;
        return AICommand(responseText: '🛒 You have $unpurchased items on your grocery list that haven\'t been purchased yet.');
      }
      final unpurchased = groceryItems.where((g) => !g.isPurchased).toList();
      if (unpurchased.isEmpty) return AICommand(responseText: '✅ Your grocery list is all clear!');
      responseText = '🛒 Grocery items to buy:\n';
      for (var g in unpurchased) {
        responseText += '• ${g.name} (${g.quantity} ${g.unit})\n';
      }
      return AICommand(responseText: responseText);
    }

    // Expense related
    if (q.contains('spend') || q.contains('spent') || q.contains('expense')) {
      final thisMonth = expenses.where((e) =>
          e.date.month == now.month && e.date.year == now.year);

      if (q.contains('grocer')) {
        double grocerySpend = thisMonth
            .where((e) => e.category.toLowerCase().contains('grocer'))
            .fold(0.0, (sum, e) => sum + e.amount);
        return AICommand(responseText: '🛒 You\'ve spent ${currencyFormat.format(grocerySpend)} on groceries this month.');
      }

      double total = thisMonth.fold(0.0, (sum, e) => sum + e.amount);
      Map<String, double> categories = {};
      for (var e in thisMonth) {
        categories[e.category] = (categories[e.category] ?? 0) + e.amount;
      }

      responseText = '💰 This month\'s spending: ${currencyFormat.format(total)}\n\nBreakdown:\n';
      categories.forEach((cat, amt) {
        responseText += '• $cat: ${currencyFormat.format(amt)}\n';
      });
      return AICommand(responseText: responseText);
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
            return AICommand(responseText: '🔧 ${task.name} is scheduled for ${DateFormat('MMM dd, yyyy').format(task.nextDue!)}. ${task.isOverdue ? '⚠️ It\'s overdue!' : ''}');
          }
          return AICommand(responseText: '🔧 ${task.name} has no scheduled date. Consider setting one!');
        }
        return AICommand(responseText: 'I couldn\'t find a maintenance task matching "$searchTerm". Try adding one!');
      }

      final upcoming = maintenanceTasks
          .where((t) => !t.isCompleted && t.nextDue != null)
          .toList()
        ..sort((a, b) => a.nextDue!.compareTo(b.nextDue!));

      if (upcoming.isEmpty) return AICommand(responseText: '✅ No upcoming maintenance tasks.');
      responseText = '🔧 Upcoming maintenance:\n';
      for (var t in upcoming.take(5)) {
        responseText += '• ${t.name} - ${DateFormat('MMM dd').format(t.nextDue!)} ${t.isOverdue ? "⚠️ OVERDUE" : ""}\n';
      }
      return AICommand(responseText: responseText);
    }

    // Debt related
    if (q.contains('debt') || q.contains('loan') || q.contains('owe')) {
      if (debts.isEmpty) return AICommand(responseText: '🎉 You have no debts recorded. That\'s great!');
      double totalDebt = debts.fold(0.0, (sum, d) => sum + d.remainingAmount);
      responseText = '💳 Total remaining debt: ${currencyFormat.format(totalDebt)}\n\n';
      for (var d in debts) {
        responseText += '• ${d.name}: ${currencyFormat.format(d.remainingAmount)} remaining';
        if (d.monthlyPayment > 0) {
          responseText += ' (~${d.monthsToPayoff} months to payoff)';
        }
        responseText += '\n';
      }
      return AICommand(responseText: responseText);
    }

    // Bills
    if (q.contains('bill')) {
      final unpaid = bills.where((b) => !b.isPaid).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      if (unpaid.isEmpty) return AICommand(responseText: '✅ All bills are paid!');
      responseText = '📄 Unpaid bills:\n';
      for (var b in unpaid) {
        responseText += '• ${b.type}: ${currencyFormat.format(b.amount)} - Due ${DateFormat('MMM dd').format(b.dueDate)} ${b.isOverdue ? "⚠️ OVERDUE" : ""}\n';
      }
      return AICommand(responseText: responseText);
    }

    // Health / score
    if (q.contains('health') || q.contains('score') || q.contains('status')) {
      final scores = getHomeHealthScores(
        maintenanceTasks: maintenanceTasks,
        householdTasks: householdTasks,
        bills: bills,
      );
      return AICommand(responseText: '🏠 Home Health Score: ${scores['overall']!.toInt()}/100\n\n'
          '🔧 Maintenance: ${scores['maintenance']!.toInt()}%\n'
          '📋 Tasks: ${scores['tasks']!.toInt()}%\n'
          '📄 Bills: ${scores['bills']!.toInt()}%');
    }

    // Default / Help
    return AICommand(responseText: '🤖 I can help you with:\n\n'
        '• "Add task clean the garage"\n'
        '• "Buy milk to groceries"\n'
        '• "Spent 500 on dinner"\n'
        '• "What tasks are due this week?"\n'
        '• "How much did we spend on groceries?"\n'
        'Try asking or commanding me!');
  }
>>>>>>> 93e0ebe (Auto-sync backup: 2026-03-12 14:52:42)
}
