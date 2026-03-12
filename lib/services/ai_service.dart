import '../models/models.dart';
import 'package:intl/intl.dart';
import 'llm_service.dart';

// ═══════════════════════════════════════════════════════════════
//  Action & Result Types
// ═══════════════════════════════════════════════════════════════

class AIAction {
  final String type;
  final Map<String, dynamic> data;
  const AIAction({required this.type, required this.data});
}

class AIResult {
  final String reply;
  final AIAction? action;
  const AIResult({required this.reply, this.action});
}

// ═══════════════════════════════════════════════════════════════
//  Helpers
// ═══════════════════════════════════════════════════════════════

final _cur = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

String _pick(List<String> o) {
  o.shuffle();
  return o.first;
}

String _titleCase(String s) {
  if (s.isEmpty) return s;
  return s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
}

// ═══════════════════════════════════════════════════════════════
//  Main Public API
// ═══════════════════════════════════════════════════════════════

class AIService {
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

    // ── 1. ACTION: Add Task ──
    // Must be checked BEFORE grocery so "add home cleaning to tasks" works
    final addTask = _detectAddTask(q, message);
    if (addTask != null) return addTask;

    // ── 2. ACTION: Complete Task ──
    final completeTask = _detectCompleteTask(q, householdTasks);
    if (completeTask != null) return completeTask;

    // ── 3. ACTION: Add Expense ──
    final addExpense = _detectAddExpense(q, message);
    if (addExpense != null) return addExpense;

    // ── 4. ACTION: Add Grocery ──
    final addGrocery = _detectAddGrocery(q, message);
    if (addGrocery != null) return addGrocery;

    // ── 5. ACTION: Mark Grocery Purchased ──
    final buyGrocery = _detectBuyGrocery(q, groceryItems);
    if (buyGrocery != null) return buyGrocery;

    // ── 6. ACTION: Remove Grocery ──
    final removeGrocery = _detectRemoveGrocery(q, groceryItems);
    if (removeGrocery != null) return removeGrocery;

    // ── 7. ACTION: Add Maintenance ──
    final addMaint = _detectAddMaintenance(q, message);
    if (addMaint != null) return addMaint;

    // ── 8. QUERY: Tasks ──
    if (_isTaskQuery(q)) {
      return AIResult(reply: _queryTasks(householdTasks));
    }

    // ── 9. QUERY: Grocery List ──
    if (_isGroceryQuery(q)) {
      return AIResult(reply: _queryGroceries(groceryItems));
    }

    // ── 10. QUERY: Expenses ──
    if (_isExpenseQuery(q)) {
      return AIResult(reply: _queryExpenses(expenses, monthlyIncome));
    }

    // ── 11. QUERY: Maintenance ──
    if (_isMaintenanceQuery(q)) {
      return AIResult(reply: _queryMaintenance(q, maintenanceTasks));
    }

    // ── 12. QUERY: Financial Insights ──
    if (_isFinancialQuery(q)) {
      return AIResult(reply: _queryFinancialInsights(expenses, debts, monthlyIncome));
    }

    // ── 13. QUERY: Debts ──
    if (q.contains('debt') || q.contains('loan') || q.contains('owe') || q.contains('borrow')) {
      return AIResult(reply: _queryDebts(debts));
    }

    // ── 14. QUERY: Bills ──
    if (q.contains('bill') || q.contains('utility')) {
      return AIResult(reply: _queryBills(bills));
    }

    // ── 15. QUERY: Home Health ──
    if (q.contains('health') || q.contains('score') || q.contains('overview')) {
      return AIResult(reply: _queryHealthScore(maintenanceTasks, householdTasks, bills));
    }

    // ── 16. QUERY: Smart Suggestions ──
    if (q.contains('suggest') || q.contains('advice') || q.contains('recommend') || q.contains('tip')) {
      return AIResult(reply: _smartSuggestions(groceryItems, maintenanceTasks, expenses, debts, monthlyIncome));
    }

    // ── 17. Greetings ──
    if (q.contains('hello') || q.contains('hey') || q == 'hi' || q.startsWith('hi ') || q.contains('good morning') || q.contains('good evening')) {
      return AIResult(reply: _pick([
        'Hey there! 👋 How can I help you manage your home today?',
        'Hi! Ready to help. Try "Add task clean kitchen" or "What tasks are pending?"',
        'Hello! I can add tasks, manage groceries, track expenses — just ask!',
      ]));
    }

    // ── 18. Help ──
    if (q.contains('help') || q.contains('what can you')) {
      return AIResult(reply: _helpMessage());
    }

    // ── 19. Thank you ──
    if (q.contains('thank') || q.contains('thanks')) {
      return AIResult(reply: _pick([
        'You\'re welcome! Let me know if you need anything else 😊',
        'Happy to help! Just ask anytime.',
        'Anytime! I\'m here whenever you need me 👍',
      ]));
    }

    // ── Default ──
    return AIResult(reply: _pick([
      'I didn\'t fully understand that. You can ask me to add tasks, manage groceries, or check expenses.',
      'Not sure I got that — try "Add task clean kitchen" or "How much did we spend?"',
      'Could you rephrase? I can add tasks, track groceries, manage expenses, and more!',
    ]));
  }

  // ═══════════════════════════════════════════════════════════════
  //  LLM-POWERED PROCESSING (Gemini)
  // ═══════════════════════════════════════════════════════════════

  /// Sends the message to Gemini LLM for intent classification.
  /// Falls back to the regex-based [processMessage] on any error.
  static Future<AIResult> processMessageWithLLM({
    required String message,
    required List<MaintenanceTask> maintenanceTasks,
    required List<HouseholdTask> householdTasks,
    required List<GroceryItem> groceryItems,
    required List<Expense> expenses,
    required List<Debt> debts,
    required List<UtilityBill> bills,
    required double monthlyIncome,
  }) async {
    // If LLM is not configured, use the regex engine directly
    if (!LLMService.isConfigured) {
      return processMessage(
        message: message,
        maintenanceTasks: maintenanceTasks,
        householdTasks: householdTasks,
        groceryItems: groceryItems,
        expenses: expenses,
        debts: debts,
        bills: bills,
        monthlyIncome: monthlyIncome,
      );
    }

    try {
      final json = await LLMService.sendMessage(message);
      final intent = json['intent'] as String? ?? '';

      switch (intent) {
        case 'create_task':
          final title = _titleCase(json['task_title'] ?? 'New Task');
          final priority = json['priority'] ?? 'medium';
          final category = json['category'] ?? 'General';
          DateTime? due;
          final dueStr = json['due_date']?.toString().toLowerCase();
          if (dueStr == 'today') due = DateTime.now();
          else if (dueStr == 'tomorrow') due = DateTime.now().add(const Duration(days: 1));
          else if (dueStr == 'next week') due = DateTime.now().add(const Duration(days: 7));

          final dateStr = due != null ? ' for **${DateFormat('MMM dd').format(due)}**' : '';
          return AIResult(
            reply: 'Task added successfully: **$title**$dateStr ✅',
            action: AIAction(type: 'add_task', data: {
              'title': title,
              'category': category,
              'priority': priority,
              'dueDate': due?.toIso8601String(),
            }),
          );

        case 'complete_task':
          final keyword = (json['task_title'] ?? '').toString().toLowerCase();
          final task = householdTasks.firstWhere(
            (t) => !t.isCompleted && t.title.toLowerCase().contains(keyword),
            orElse: () => HouseholdTask(id: '', title: '', category: ''),
          );
          if (task.id.isNotEmpty) {
            return AIResult(
              reply: 'Task marked as completed: **${task.title}** ✅',
              action: AIAction(type: 'complete_task', data: {'id': task.id}),
            );
          }
          return AIResult(reply: 'No pending task found matching "${json['task_title']}". Try "What tasks are pending?" to see your list.');

        case 'add_grocery':
          final items = json['items'] as List<dynamic>? ?? [];
          if (items.isEmpty) {
            // Fallback: check if there's a single "item" field
            final singleItem = json['item']?.toString();
            if (singleItem != null && singleItem.isNotEmpty) {
              final name = _titleCase(singleItem);
              return AIResult(
                reply: '**$name** added to your grocery list 🛒',
                action: AIAction(type: 'add_grocery', data: {
                  'name': name, 'quantity': 1, 'unit': 'pcs', 'category': 'General',
                }),
              );
            }
            return AIResult(reply: 'Could not determine the grocery item. Try "add milk to grocery list".');
          }

          if (items.length == 1) {
            final item = items[0] as Map<String, dynamic>;
            final name = _titleCase(item['name'] ?? 'Item');
            return AIResult(
              reply: '**$name** added to your grocery list 🛒',
              action: AIAction(type: 'add_grocery', data: {
                'name': name,
                'quantity': item['quantity'] ?? 1,
                'unit': item['unit'] ?? 'pcs',
                'category': 'General',
              }),
            );
          }

          // Multiple items
          final names = items.map((i) => _titleCase((i as Map<String, dynamic>)['name'] ?? 'Item')).toList();
          final parsedItems = items.map((i) {
            final m = i as Map<String, dynamic>;
            return {
              'name': _titleCase(m['name'] ?? 'Item'),
              'quantity': m['quantity'] ?? 1,
              'unit': m['unit'] ?? 'pcs',
              'category': 'General',
            };
          }).toList();
          return AIResult(
            reply: 'Added ${names.length} items to your grocery list: **${names.join(', ')}** 🛒',
            action: AIAction(type: 'add_grocery_multi', data: {'items': parsedItems}),
          );

        case 'remove_grocery':
          final kw = (json['item'] ?? '').toString().toLowerCase();
          final item = groceryItems.firstWhere(
            (g) => g.name.toLowerCase().contains(kw),
            orElse: () => GroceryItem(id: '', name: ''),
          );
          if (item.id.isNotEmpty) {
            return AIResult(
              reply: 'Grocery item removed: **${item.name}** 🗑️',
              action: AIAction(type: 'delete_grocery', data: {'id': item.id}),
            );
          }
          return AIResult(reply: '"$kw" not found on your grocery list.');

        case 'add_expense':
          final title = _titleCase(json['title'] ?? 'Misc');
          final amount = (json['amount'] ?? 0).toDouble();
          final category = json['category'] ?? 'Misc';
          if (amount <= 0) {
            return AIResult(reply: 'Could not determine the amount. Try "spent 500 on groceries".');
          }
          return AIResult(
            reply: 'Expense recorded: **$title** — ${_cur.format(amount)} 💸',
            action: AIAction(type: 'add_expense', data: {
              'title': title, 'amount': amount, 'category': category,
            }),
          );

        case 'show_finance_summary':
          return AIResult(reply: _queryExpenses(expenses, monthlyIncome));

        case 'general_query':
          final queryType = json['query_type'] ?? 'other';
          switch (queryType) {
            case 'tasks':
              return AIResult(reply: _queryTasks(householdTasks));
            case 'groceries':
              return AIResult(reply: _queryGroceries(groceryItems));
            case 'expenses':
              return AIResult(reply: _queryExpenses(expenses, monthlyIncome));
            case 'maintenance':
              return AIResult(reply: _queryMaintenance(message.toLowerCase(), maintenanceTasks));
            case 'bills':
              return AIResult(reply: _queryBills(bills));
            case 'debts':
              return AIResult(reply: _queryDebts(debts));
            case 'health_score':
              return AIResult(reply: _queryHealthScore(maintenanceTasks, householdTasks, bills));
            case 'suggestions':
              return AIResult(reply: _smartSuggestions(groceryItems, maintenanceTasks, expenses, debts, monthlyIncome));
            case 'financial_insights':
              return AIResult(reply: _queryFinancialInsights(expenses, debts, monthlyIncome));
            case 'greeting':
              return AIResult(reply: _pick([
                'Hey there! 👋 How can I help you manage your home today?',
                'Hi! Ready to help. Try "Add task clean kitchen" or "What tasks are pending?"',
                'Hello! I can add tasks, manage groceries, track expenses — just ask!',
              ]));
            case 'help':
              return AIResult(reply: _helpMessage());
            case 'thanks':
              return AIResult(reply: _pick([
                'You\'re welcome! Let me know if you need anything else 😊',
                'Happy to help! Just ask anytime.',
                'Anytime! I\'m here whenever you need me 👍',
              ]));
            default:
              return AIResult(reply: _helpMessage());
          }

        default:
          // Unknown intent from LLM — fall back to regex
          return processMessage(
            message: message,
            maintenanceTasks: maintenanceTasks,
            householdTasks: householdTasks,
            groceryItems: groceryItems,
            expenses: expenses,
            debts: debts,
            bills: bills,
            monthlyIncome: monthlyIncome,
          );
      }
    } catch (e) {
      // LLM failed — fall back to the regex engine
      return processMessage(
        message: message,
        maintenanceTasks: maintenanceTasks,
        householdTasks: householdTasks,
        groceryItems: groceryItems,
        expenses: expenses,
        debts: debts,
        bills: bills,
        monthlyIncome: monthlyIncome,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  INTENT: Add Task
  // ═══════════════════════════════════════════════════════════════

  static AIResult? _detectAddTask(String q, String original) {
    final patterns = [
      // "add home cleaning to tasks"
      RegExp(r'add\s+(.+?)\s+to\s+(?:my\s+)?(?:task|tasks|to-?do)', caseSensitive: false),
      // "add task clean kitchen tomorrow"
      RegExp(r'(?:add|create|new)\s+(?:a\s+)?task\s+(?:to\s+)?(.+)', caseSensitive: false),
      // "remind me to pay rent tomorrow"
      RegExp(r'remind\s+me\s+to\s+(.+)', caseSensitive: false),
      // "schedule a reminder for X"
      RegExp(r'(?:schedule|set up|create)\s+(?:a\s+)?(?:reminder|todo)\s+(?:for\s+)?(.+)', caseSensitive: false),
    ];

    for (final p in patterns) {
      final m = p.firstMatch(original);
      if (m == null) continue;
      String raw = m.group(1)?.trim() ?? '';
      if (raw.isEmpty || raw.length > 100) continue;

      // Parse due date
      DateTime? due;
      if (raw.toLowerCase().contains('today')) {
        due = DateTime.now();
        raw = raw.replaceAll(RegExp(r'\s*today\s*', caseSensitive: false), ' ').trim();
      } else if (raw.toLowerCase().contains('tomorrow')) {
        due = DateTime.now().add(const Duration(days: 1));
        raw = raw.replaceAll(RegExp(r'\s*tomorrow\s*', caseSensitive: false), ' ').trim();
      } else if (raw.toLowerCase().contains('next week')) {
        due = DateTime.now().add(const Duration(days: 7));
        raw = raw.replaceAll(RegExp(r'\s*next week\s*', caseSensitive: false), ' ').trim();
      } else if (raw.toLowerCase().contains('this week')) {
        due = DateTime.now().add(const Duration(days: 5));
        raw = raw.replaceAll(RegExp(r'\s*this week\s*', caseSensitive: false), ' ').trim();
      }

      // Priority
      String priority = 'medium';
      if (raw.toLowerCase().contains('urgent') || raw.toLowerCase().contains('asap') || raw.toLowerCase().contains('important')) {
        priority = 'high';
        raw = raw.replaceAll(RegExp(r'\s*(urgent|asap|important)\s*', caseSensitive: false), ' ').trim();
      }

      // Category
      String cat = 'General';
      final rl = raw.toLowerCase();
      if (rl.contains('clean') || rl.contains('mop') || rl.contains('vacuum') || rl.contains('wash')) cat = 'Cleaning';
      else if (rl.contains('pay') || rl.contains('bill') || rl.contains('bank')) cat = 'Bills';
      else if (rl.contains('buy') || rl.contains('shop') || rl.contains('grocery')) cat = 'Shopping';
      else if (rl.contains('fix') || rl.contains('repair') || rl.contains('service')) cat = 'Maintenance';
      else if (rl.contains('cook') || rl.contains('meal') || rl.contains('food')) cat = 'Cooking';

      raw = raw.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[.!?]+$'), '').trim();
      final title = _titleCase(raw);
      if (title.isEmpty) continue;

      final dateStr = due != null ? ' for **${DateFormat('MMM dd').format(due)}**' : '';
      return AIResult(
        reply: 'Task added successfully: **$title**$dateStr ✅',
        action: AIAction(type: 'add_task', data: {
          'title': title,
          'category': cat,
          'priority': priority,
          'dueDate': due?.toIso8601String(),
        }),
      );
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  //  INTENT: Complete Task
  // ═══════════════════════════════════════════════════════════════

  static AIResult? _detectCompleteTask(String q, List<HouseholdTask> tasks) {
    final patterns = [
      RegExp(r'(?:mark|set|complete|finish)\s+(?:task\s+)?(.+?)\s+(?:as\s+)?(?:done|complete|finished)', caseSensitive: false),
      RegExp(r'(?:done|finished)\s+(?:with\s+)?(?:the\s+)?(?:task\s+)?(.+)', caseSensitive: false),
      RegExp(r'(?:complete|finish)\s+(?:task\s+)?(.+)', caseSensitive: false),
    ];

    for (final p in patterns) {
      final m = p.firstMatch(q);
      if (m == null) continue;
      final keyword = m.group(1)?.trim().toLowerCase() ?? '';
      if (keyword.isEmpty) continue;

      final task = tasks.firstWhere(
        (t) => !t.isCompleted && t.title.toLowerCase().contains(keyword),
        orElse: () => HouseholdTask(id: '', title: '', category: ''),
      );

      if (task.id.isNotEmpty) {
        return AIResult(
          reply: 'Marked as done: **${task.title}** ✅',
          action: AIAction(type: 'complete_task', data: {'id': task.id}),
        );
      } else {
        return AIResult(reply: 'No pending task found matching "$keyword".');
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  //  INTENT: Add Expense
  // ═══════════════════════════════════════════════════════════════

  static AIResult? _detectAddExpense(String q, String original) {
    final patterns = [
      // "spent 500 on groceries" / "paid 1200 for electricity"
      RegExp(r'(?:spent|paid|cost)\s+(?:rs\.?\s*|₹\s*)?(\d+(?:\.\d+)?)\s+(?:on|for)\s+(.+)', caseSensitive: false),
      // "add electricity bill 1200" / "add expense groceries 500"
      RegExp(r'(?:add|record|log)\s+(?:expense\s+)?(.+?)\s+(?:rs\.?\s*|₹\s*)?(\d+(?:\.\d+)?)(?:\s*(?:rupees|rs|bucks)?)?$', caseSensitive: false),
      // "electricity bill 1200 rupees"
      RegExp(r'(.+?)\s+(?:rs\.?\s*|₹\s*)?(\d+(?:\.\d+)?)\s*(?:rupees|rs)?$', caseSensitive: false),
    ];

    // Must contain a number to be an expense intent
    if (!RegExp(r'\d').hasMatch(q)) return null;
    // Exclude if it's clearly a task or grocery intent
    if (q.contains('task') || q.contains('grocery') || q.contains('groceries')) return null;

    for (final p in patterns) {
      final m = p.firstMatch(original);
      if (m == null) continue;

      String amountStr;
      String titleRaw;

      if (q.startsWith('spent') || q.startsWith('paid') || q.startsWith('cost')) {
        amountStr = m.group(1) ?? '0';
        titleRaw = m.group(2) ?? '';
      } else {
        titleRaw = m.group(1) ?? '';
        amountStr = m.group(2) ?? '0';
      }

      double amount = double.tryParse(amountStr) ?? 0;
      if (amount <= 0) continue;

      titleRaw = titleRaw.replaceAll(RegExp(r'(rupees|rs\.?|₹|dollars|\$|bucks)', caseSensitive: false), '').trim();
      if (titleRaw.isEmpty) titleRaw = 'Misc';

      // Clean filler
      titleRaw = titleRaw.replaceAll(RegExp(r'^(add|record|log|an?\s+|expense\s+)', caseSensitive: false), '').trim();
      if (titleRaw.isEmpty) titleRaw = 'Misc';

      String cat = 'Misc';
      final tl = titleRaw.toLowerCase();
      if (tl.contains('grocer') || tl.contains('food') || tl.contains('meal') || tl.contains('vegetable')) cat = 'Food';
      else if (tl.contains('bill') || tl.contains('electric') || tl.contains('water') || tl.contains('rent') || tl.contains('gas')) cat = 'Bills';
      else if (tl.contains('petrol') || tl.contains('diesel') || tl.contains('travel') || tl.contains('uber') || tl.contains('cab')) cat = 'Transport';
      else if (tl.contains('medicine') || tl.contains('doctor') || tl.contains('hospital')) cat = 'Health';
      else if (tl.contains('shop') || tl.contains('cloth') || tl.contains('amazon') || tl.contains('flipkart')) cat = 'Shopping';

      final title = _titleCase(titleRaw);

      return AIResult(
        reply: 'Expense recorded: **$title** — ${_cur.format(amount)} 💸',
        action: AIAction(type: 'add_expense', data: {
          'title': title,
          'amount': amount,
          'category': cat,
        }),
      );
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  //  INTENT: Add Grocery
  // ═══════════════════════════════════════════════════════════════

  static final _qtyRx = RegExp(r'\b(\d+)\s*(kg|g|grams?|litre?s?|l|ml|pcs?|pieces?|packets?|pkt|bottles?|boxes?|cans?|dozens?|doz|bunches?|bags?)?\b', caseSensitive: false);

  static AIResult? _detectAddGrocery(String q, String original) {
    final patterns = [
      RegExp(r'add\s+(.+?)\s+(?:to\s+(?:the\s+)?(?:grocery|shopping|groceries|list))', caseSensitive: false),
      RegExp(r'(?:put|add)\s+(.+?)\s+(?:on|in)\s+(?:the\s+)?(?:grocery|shopping|list)', caseSensitive: false),
      RegExp(r'(?:buy|get|pick up|grab|purchase|order)\s+(?:some\s+)?(.+?)(?:\s+from\s+(?:the\s+)?(?:store|market|shop))?$', caseSensitive: false),
      RegExp(r'(?:need|we need|i need)\s+(?:some\s+)?(.+?)$', caseSensitive: false),
    ];

    // Exclude if clearly a task/expense/maintenance intent
    if (q.contains('task') || q.contains('remind me to clean') || q.contains('remind me to pay') || q.contains('remind me to fix')) return null;
    if (RegExp(r'\d{3,}').hasMatch(q)) return null; // large numbers = likely expense

    for (final p in patterns) {
      final m = p.firstMatch(original);
      if (m == null) continue;
      String raw = m.group(1)?.trim() ?? '';
      if (raw.isEmpty || raw.length > 60) continue;

      // Multi-item: "milk and eggs" / "milk, eggs, bread"
      List<String> items = [];
      if (raw.contains(' and ') || raw.contains(',')) {
        items = raw.split(RegExp(r'\s+and\s+|,\s*')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      } else {
        items = [raw];
      }

      if (items.length == 1) {
        // Single item
        final parsed = _parseGroceryItem(items[0]);
        return AIResult(
          reply: '**${parsed['name']}** added to your grocery list 🛒',
          action: AIAction(type: 'add_grocery', data: parsed),
        );
      } else {
        // Multiple items — return first item action, mention all in reply
        final names = items.map((i) => _titleCase(i.replaceAll(RegExp(r'^(some|a|an|the)\s+', caseSensitive: false), '').trim())).toList();
        final parsed = _parseGroceryItem(items[0]);
        String reply = 'Added ${names.length} items to your grocery list: **${names.join(', ')}** 🛒';
        return AIResult(
          reply: reply,
          action: AIAction(type: 'add_grocery_multi', data: {
            'items': items.map((i) => _parseGroceryItem(i)).toList(),
          }),
        );
      }
    }
    return null;
  }

  static Map<String, dynamic> _parseGroceryItem(String raw) {
    int qty = 1;
    String unit = 'pcs';
    final qm = _qtyRx.firstMatch(raw);
    if (qm != null) {
      qty = int.tryParse(qm.group(1) ?? '') ?? 1;
      if (qm.group(2) != null && qm.group(2)!.isNotEmpty) {
        unit = qm.group(2)!.toLowerCase();
        raw = raw.replaceAll(qm.group(0) ?? '', '').trim();
      }
    }
    String name = raw.replaceAll(RegExp(r'^(some|a|an|the)\s+', caseSensitive: false), '').trim();
    name = _titleCase(name);
    if (name.isEmpty) name = 'Item';
    return {'name': name, 'quantity': qty, 'unit': unit, 'category': 'General'};
  }

  // ═══════════════════════════════════════════════════════════════
  //  INTENT: Mark Grocery Purchased
  // ═══════════════════════════════════════════════════════════════

  static AIResult? _detectBuyGrocery(String q, List<GroceryItem> items) {
    final patterns = [
      RegExp(r'(?:mark|set)\s+(.+?)\s+as\s+(?:bought|purchased|done)', caseSensitive: false),
      RegExp(r'(?:i\s+)?(?:bought|purchased|got|picked up)\s+(?:the\s+)?(.+)', caseSensitive: false),
    ];

    for (final p in patterns) {
      final m = p.firstMatch(q);
      if (m == null) continue;
      final kw = m.group(1)?.trim().toLowerCase() ?? '';
      if (kw.isEmpty) continue;

      final item = items.firstWhere(
        (g) => !g.isPurchased && g.name.toLowerCase().contains(kw),
        orElse: () => GroceryItem(id: '', name: ''),
      );

      if (item.id.isNotEmpty) {
        return AIResult(
          reply: '**${item.name}** marked as purchased ✅',
          action: AIAction(type: 'complete_grocery', data: {'id': item.id}),
        );
      } else {
        return AIResult(reply: 'Could not find "$kw" on your grocery list.');
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  //  INTENT: Remove Grocery
  // ═══════════════════════════════════════════════════════════════

  static AIResult? _detectRemoveGrocery(String q, List<GroceryItem> items) {
    final p = RegExp(r'(?:remove|delete|cancel)\s+(.+?)\s+(?:from\s+(?:the\s+)?(?:grocery|shopping|list|groceries))', caseSensitive: false);
    final m = p.firstMatch(q);
    if (m == null) return null;

    final kw = m.group(1)?.trim().toLowerCase() ?? '';
    if (kw.isEmpty) return null;

    final item = items.firstWhere(
      (g) => g.name.toLowerCase().contains(kw),
      orElse: () => GroceryItem(id: '', name: ''),
    );

    if (item.id.isNotEmpty) {
      return AIResult(
        reply: '**${item.name}** removed from grocery list.',
        action: AIAction(type: 'delete_grocery', data: {'id': item.id}),
      );
    }
    return AIResult(reply: '"$kw" not found on your grocery list.');
  }

  // ═══════════════════════════════════════════════════════════════
  //  INTENT: Add Maintenance
  // ═══════════════════════════════════════════════════════════════

  static AIResult? _detectAddMaintenance(String q, String original) {
    final patterns = [
      RegExp(r'(?:schedule|book)\s+(?:a\s+)?(?:maintenance\s+|service\s+|servicing\s+)?(?:for\s+)?(.+?)\s+(today|tomorrow|next week|this week|in \d+ days)', caseSensitive: false),
      RegExp(r'add\s+(.+?)\s+(today|tomorrow|next week|this week|in \d+ days)', caseSensitive: false),
    ];

    // Must contain a time keyword to be maintenance
    if (!q.contains('today') && !q.contains('tomorrow') && !q.contains('next week') && !q.contains('this week') && !RegExp(r'in \d+ days').hasMatch(q)) return null;
    // Exclude explicit task intent
    if (q.contains('task')) return null;

    for (final p in patterns) {
      final m = p.firstMatch(original);
      if (m == null) continue;
      String raw = m.group(1)?.trim() ?? '';
      String time = m.group(2)?.trim().toLowerCase() ?? '';
      if (raw.isEmpty) continue;

      // Check if this looks like a maintenance item (contains service-related keywords)
      final rl = raw.toLowerCase();
      bool isMaintenance = rl.contains('service') || rl.contains('servic') || rl.contains('clean') ||
          rl.contains('repair') || rl.contains('fix') || rl.contains('plumb') || rl.contains('ac') ||
          rl.contains('filter') || rl.contains('tank') || rl.contains('purif');
      if (!isMaintenance && !q.contains('schedule') && !q.contains('book')) continue;

      DateTime due = DateTime.now();
      if (time == 'tomorrow') due = due.add(const Duration(days: 1));
      else if (time == 'next week') due = due.add(const Duration(days: 7));
      else if (time == 'this week') due = due.add(const Duration(days: 4));
      else if (time.startsWith('in ')) {
        final d = RegExp(r'\d+').firstMatch(time);
        if (d != null) due = due.add(Duration(days: int.tryParse(d.group(0)!) ?? 0));
      }

      String cat = 'General';
      if (rl.contains('ac') || rl.contains('hvac')) cat = 'HVAC';
      else if (rl.contains('water') || rl.contains('plumb') || rl.contains('tank')) cat = 'Water';
      else if (rl.contains('electr')) cat = 'Electrical';

      final title = _titleCase(raw);
      return AIResult(
        reply: 'Maintenance scheduled: **$title** on **${DateFormat('MMM dd').format(due)}** 🔧',
        action: AIAction(type: 'add_maintenance', data: {
          'title': title,
          'category': cat,
          'nextDue': due.toIso8601String(),
        }),
      );
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  //  QUERY MATCHERS
  // ═══════════════════════════════════════════════════════════════

  static bool _isTaskQuery(String q) =>
      (q.contains('task') || q.contains('to-do') || q.contains('todo') || q.contains('pending')) &&
      (q.contains('what') || q.contains('show') || q.contains('list') || q.contains('due') || q.contains('pending') || q.contains('how many'));

  static bool _isGroceryQuery(String q) =>
      (q.contains('grocery') || q.contains('groceries') || q.contains('shopping list')) &&
      (q.contains('what') || q.contains('show') || q.contains('list') || q.contains('need') || q.contains('how many'));

  static bool _isExpenseQuery(String q) =>
      (q.contains('spend') || q.contains('spent') || q.contains('expense') || q.contains('budget') || q.contains('how much'));

  static bool _isMaintenanceQuery(String q) =>
      (q.contains('maintenance') || q.contains('service') || q.contains('servicing') || q.contains('ac') || q.contains('plumb'));

  static bool _isFinancialQuery(String q) =>
      q.contains('financial') || q.contains('finance') || q.contains('saving') || q.contains('insight') || q.contains('invest');

  // ═══════════════════════════════════════════════════════════════
  //  QUERY: Tasks
  // ═══════════════════════════════════════════════════════════════

  static String _queryTasks(List<HouseholdTask> tasks) {
    final pending = tasks.where((t) => !t.isCompleted).toList()
      ..sort((a, b) => (a.dueDate ?? DateTime(2099)).compareTo(b.dueDate ?? DateTime(2099)));

    if (pending.isEmpty) return 'No pending tasks. You\'re all caught up! 🎉';

    if (pending.length <= 3) {
      final names = pending.map((t) => t.title).join(', ');
      return 'You have ${pending.length} pending task${pending.length > 1 ? 's' : ''}: $names.';
    }

    String r = 'You have **${pending.length} pending tasks**:\n\n';
    for (var t in pending.take(7)) {
      final due = t.dueDate != null ? ' — ${DateFormat('MMM dd').format(t.dueDate!)}' : '';
      final overdue = t.isOverdue ? ' ⚠️' : '';
      r += '• ${t.title}$due$overdue\n';
    }
    if (pending.length > 7) r += '\n...and ${pending.length - 7} more.';
    return r.trim();
  }

  // ═══════════════════════════════════════════════════════════════
  //  QUERY: Groceries
  // ═══════════════════════════════════════════════════════════════

  static String _queryGroceries(List<GroceryItem> items) {
    final list = items.where((g) => !g.isPurchased).toList();
    if (list.isEmpty) return 'Your grocery list is empty. Nothing to buy! ✅';

    if (list.length <= 3) {
      final names = list.map((g) => g.name).join(', ');
      return 'You need: $names.';
    }

    String r = 'You have **${list.length} items** on your grocery list:\n\n';
    for (var g in list) {
      r += '• ${g.name} (${g.quantity} ${g.unit})\n';
    }
    return r.trim();
  }

  // ═══════════════════════════════════════════════════════════════
  //  QUERY: Expenses
  // ═══════════════════════════════════════════════════════════════

  static String _queryExpenses(List<Expense> expenses, double income) {
    final now = DateTime.now();
    final thisMonth = expenses.where((e) => e.date.month == now.month && e.date.year == now.year).toList();

    if (thisMonth.isEmpty) return 'No expenses recorded this month.';

    double total = thisMonth.fold(0.0, (s, e) => s + e.amount);

    // Category breakdown
    Map<String, double> cats = {};
    for (var e in thisMonth) {
      cats[e.category] = (cats[e.category] ?? 0) + e.amount;
    }
    final sorted = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    String r = 'You spent **${_cur.format(total)}** this month.\n\n';
    for (var c in sorted) {
      r += '• ${c.key}: ${_cur.format(c.value)}\n';
    }

    if (income > 0) {
      final rem = income - total;
      if (rem > 0) {
        r += '\n${_cur.format(rem)} remaining in budget 👍';
      } else {
        r += '\n⚠️ Over budget by ${_cur.format(-rem)}!';
      }
    }
    return r.trim();
  }

  // ═══════════════════════════════════════════════════════════════
  //  QUERY: Maintenance
  // ═══════════════════════════════════════════════════════════════

  static String _queryMaintenance(String q, List<MaintenanceTask> tasks) {
    // Specific lookup
    final kw = {'ac': 'ac', 'air condition': 'ac', 'plumb': 'plumb', 'electr': 'electr', 'water': 'water', 'purifier': 'purif'};
    for (final e in kw.entries) {
      if (!q.contains(e.key)) continue;
      final t = tasks.firstWhere(
        (t) => t.name.toLowerCase().contains(e.value) || t.category.toLowerCase().contains(e.value),
        orElse: () => MaintenanceTask(id: '', name: '', category: ''),
      );
      if (t.id.isNotEmpty && t.nextDue != null) {
        final od = t.isOverdue ? ' ⚠️ OVERDUE' : '';
        return '${t.name}: scheduled for **${DateFormat('MMM dd, yyyy').format(t.nextDue!)}**$od';
      }
    }

    // General list
    final upcoming = tasks.where((t) => !t.isCompleted && t.nextDue != null).toList()
      ..sort((a, b) => a.nextDue!.compareTo(b.nextDue!));
    if (upcoming.isEmpty) return 'No maintenance tasks scheduled.';

    String r = '**${upcoming.length} maintenance task${upcoming.length > 1 ? 's' : ''}** upcoming:\n\n';
    for (var t in upcoming.take(5)) {
      final od = t.isOverdue ? ' ⚠️' : '';
      r += '• ${t.name} — ${DateFormat('MMM dd').format(t.nextDue!)}$od\n';
    }
    return r.trim();
  }

  // ═══════════════════════════════════════════════════════════════
  //  QUERY: Financial Insights
  // ═══════════════════════════════════════════════════════════════

  static String _queryFinancialInsights(List<Expense> expenses, List<Debt> debts, double income) {
    List<String> insights = [];
    final now = DateTime.now();

    // Monthly spending
    final thisMonth = expenses.where((e) => e.date.month == now.month && e.date.year == now.year);
    final lastMonth = expenses.where((e) =>
        e.date.month == (now.month == 1 ? 12 : now.month - 1) &&
        e.date.year == (now.month == 1 ? now.year - 1 : now.year));

    double thisTotal = thisMonth.fold(0.0, (s, e) => s + e.amount);
    double lastTotal = lastMonth.fold(0.0, (s, e) => s + e.amount);

    if (income > 0) {
      double savingsRate = ((income - thisTotal) / income * 100);
      if (savingsRate >= 30) {
        insights.add('Great saving rate of ${savingsRate.toInt()}% this month! 🌟');
      } else if (savingsRate >= 10) {
        insights.add('You are saving ${savingsRate.toInt()}% of your income. A 20%+ target is recommended.');
      } else {
        insights.add('⚠️ You are saving only ${savingsRate.toInt()}% this month. Try to cut some spending.');
      }
    }

    if (lastTotal > 0 && thisTotal > lastTotal) {
      final pct = ((thisTotal - lastTotal) / lastTotal * 100).toInt();
      insights.add('You spent $pct% more than last month.');
    } else if (lastTotal > 0 && thisTotal < lastTotal) {
      final pct = ((lastTotal - thisTotal) / lastTotal * 100).toInt();
      insights.add('You spent $pct% less than last month 👍');
    }

    if (debts.isNotEmpty && income > 0) {
      double totalDebt = debts.fold(0.0, (s, d) => s + d.remainingAmount);
      double suggested = income * 0.2;
      int months = (totalDebt / suggested).ceil();
      insights.add('If you save ${_cur.format(suggested)}/month, you can clear ${_cur.format(totalDebt)} debt in **$months months**.');
    }

    if (insights.isEmpty) return 'Your finances look healthy! ✅';
    return insights.join('\n\n');
  }

  // ═══════════════════════════════════════════════════════════════
  //  QUERY: Debts
  // ═══════════════════════════════════════════════════════════════

  static String _queryDebts(List<Debt> debts) {
    if (debts.isEmpty) return 'No debts recorded. Great job! 🎉';
    double total = debts.fold(0.0, (s, d) => s + d.remainingAmount);
    String r = 'Total debt: **${_cur.format(total)}**\n\n';
    for (var d in debts) {
      r += '• ${d.name}: ${_cur.format(d.remainingAmount)}';
      if (d.monthlyPayment > 0) r += ' (~${d.monthsToPayoff} months left)';
      r += '\n';
    }
    return r.trim();
  }

  // ═══════════════════════════════════════════════════════════════
  //  QUERY: Bills
  // ═══════════════════════════════════════════════════════════════

  static String _queryBills(List<UtilityBill> bills) {
    final unpaid = bills.where((b) => !b.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    if (unpaid.isEmpty) return 'All bills paid! ✅';

    String r = '${unpaid.length} unpaid bill${unpaid.length > 1 ? 's' : ''}:\n\n';
    for (var b in unpaid) {
      final od = b.isOverdue ? ' ⚠️' : '';
      r += '• ${b.type}: ${_cur.format(b.amount)} — Due ${DateFormat('MMM dd').format(b.dueDate)}$od\n';
    }
    return r.trim();
  }

  // ═══════════════════════════════════════════════════════════════
  //  QUERY: Home Health Score
  // ═══════════════════════════════════════════════════════════════

  static String _queryHealthScore(List<MaintenanceTask> maint, List<HouseholdTask> tasks, List<UtilityBill> bills) {
    final scores = getHomeHealthScores(maintenanceTasks: maint, householdTasks: tasks, bills: bills);
    final overall = scores['overall']!.toInt();

    String status;
    if (overall >= 80) status = 'Your home is in great shape! 🏠✨';
    else if (overall >= 60) status = 'Mostly good, a few areas need attention.';
    else status = 'Some things need your attention soon.';

    return '$status\n\n'
        '🏠 Overall: **$overall/100**\n'
        '🔧 Maintenance: ${scores['maintenance']!.toInt()}%\n'
        '📋 Tasks: ${scores['tasks']!.toInt()}%\n'
        '📄 Bills: ${scores['bills']!.toInt()}%';
  }

  // ═══════════════════════════════════════════════════════════════
  //  Smart Suggestions
  // ═══════════════════════════════════════════════════════════════

  static String _smartSuggestions(List<GroceryItem> groceries, List<MaintenanceTask> maint, List<Expense> expenses, List<Debt> debts, double income) {
    List<String> tips = [];
    final now = DateTime.now();

    // Maintenance due soon
    for (var t in maint.where((m) => m.isDueSoon)) {
      tips.add('${t.name} is due in ${t.daysUntilDue} days.');
    }
    for (var t in maint.where((m) => m.isOverdue)) {
      tips.add('⚠️ ${t.name} is overdue!');
    }

    // Spending comparison
    final thisMonth = expenses.where((e) => e.date.month == now.month && e.date.year == now.year);
    final lastMonth = expenses.where((e) =>
        e.date.month == (now.month == 1 ? 12 : now.month - 1) &&
        e.date.year == (now.month == 1 ? now.year - 1 : now.year));
    double thisTotal = thisMonth.fold(0.0, (s, e) => s + e.amount);
    double lastTotal = lastMonth.fold(0.0, (s, e) => s + e.amount);
    if (lastTotal > 0 && thisTotal > lastTotal * 1.1) {
      tips.add('You spent more this month than last month. Consider reviewing your spending.');
    }

    // Debt payoff
    if (income > 0 && debts.isNotEmpty) {
      double totalDebt = debts.fold(0.0, (s, d) => s + d.remainingAmount);
      double save = income * 0.2;
      int months = (totalDebt / save).ceil();
      tips.add('If you save ${_cur.format(save)}/month, you can clear your debt in $months months.');
    }

    // Grocery reminder
    bool hasMilk = groceries.any((g) => g.name.toLowerCase().contains('milk') && !g.isPurchased);
    if (!hasMilk) tips.add('You usually buy milk every week. Should I add it to the grocery list?');

    if (tips.isEmpty) return 'Everything looks great! No suggestions right now. ✅';
    return 'Here are my suggestions:\n\n• ${tips.join('\n• ')}';
  }

  // ═══════════════════════════════════════════════════════════════
  //  Help
  // ═══════════════════════════════════════════════════════════════

  static String _helpMessage() {
    return 'I can manage your entire home! Try:\n\n'
        '📋 **Tasks**: "Add home cleaning to tasks" · "What tasks are pending?"\n'
        '🛒 **Grocery**: "Add milk and eggs to grocery list" · "Remove bread from list"\n'
        '💸 **Expenses**: "Add electricity bill 1200" · "How much did we spend?"\n'
        '🔧 **Maintenance**: "Schedule AC servicing next week" · "When is AC due?"\n'
        '📊 **Insights**: "Give me financial advice" · "Any suggestions?"';
  }

  // ═══════════════════════════════════════════════════════════════
  //  Legacy Methods (used by dashboard / finance screens)
  // ═══════════════════════════════════════════════════════════════

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
        suggestions.add('⚠️ ${task.name} is overdue!');
      } else if (task.isDueSoon) {
        suggestions.add('📅 ${task.name} is due in ${task.daysUntilDue} days.');
      }
    }
    if (suggestions.isEmpty) suggestions.add('✅ All maintenance tasks are up to date!');
    return suggestions;
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
      'suggestions': _getLegacySuggestions(
        monthlyIncome: monthlyIncome,
        monthlyExpense: thisMonthTotal,
        totalDebt: totalDebt,
        debts: debts,
      ),
    };
  }

  static List<String> _getLegacySuggestions({
    required double monthlyIncome,
    required double monthlyExpense,
    required double totalDebt,
    required List<Debt> debts,
  }) {
    List<String> suggestions = [];
    if (monthlyIncome > 0) {
      double savingsRate = (monthlyIncome - monthlyExpense) / monthlyIncome;
      if (savingsRate < 0.1) {
        suggestions.add('💡 Saving less than 10%. Try to reduce spending.');
      } else if (savingsRate > 0.3) {
        suggestions.add('🌟 Great! Saving ${(savingsRate * 100).toInt()}% of income.');
      }
    }
    if (totalDebt > 0 && monthlyIncome > 0) {
      double pay = monthlyIncome * 0.2;
      int months = (totalDebt / pay).ceil();
      suggestions.add('📊 Save ${_cur.format(pay)}/month to clear debt in ~$months months.');
    }
    if (suggestions.isEmpty) suggestions.add('✅ Finances look healthy!');
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
  // AI Chat Response (Legacy)
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
}
