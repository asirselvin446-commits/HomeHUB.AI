import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/models.dart';

/// Service that communicates with Google Gemini to convert natural language
/// into structured JSON actions for the Home Management app.
///
/// KEY FEATURE: Injects LIVE app context into every LLM call so the AI
/// can reason about actual data (existing tasks, bills, spending, etc.).
class LLMService {
  // ───────────────────────────────────────────────────────────────
  //  CONFIGURATION
  // ───────────────────────────────────────────────────────────────
  static const String apiKey = 'AIzaSyCHrg7Gfv6jasJlnCDYfER5SVb-9N2Urmg';

  static const String _model = 'gemini-2.0-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static final _cur = NumberFormat('#,##0', 'en_IN');

  // ───────────────────────────────────────────────────────────────
  //  SYSTEM PROMPT — THE AI AGENT'S BRAIN
  // ───────────────────────────────────────────────────────────────
  static const String _systemPrompt = '''
You are HomeHub AI — a smart household management agent. You are the brain of a family management app. You can EXECUTE any action in the app and ANSWER any question about the household.

═══════════════════════════════════════════════
CORE RULES:
═══════════════════════════════════════════════
1. Return ONLY valid JSON. No explanations, markdown, or code fences.
2. ALWAYS include a "reply" field — a natural, friendly response to show the user.
3. ALWAYS include an "intent" field.
4. THINK before responding — analyze what the user really means, not just the literal words.
5. When the user refers to existing data, match it FUZZY (partial match, case-insensitive).
6. You receive LIVE APP DATA as context — use it to give accurate, data-aware responses.
7. LONG PHRASES: Users may send long, multi-sentence, or detailed messages. ALWAYS read and understand the ENTIRE message. Extract intent and all entities (titles, amounts, dates, names, etc.) from the full text. Do not ignore or truncate long input — parse it completely.

═══════════════════════════════════════════════
RESPONSE FORMAT:
═══════════════════════════════════════════════
Every response MUST be:
{"intent":"...", "reply":"...", ...other fields}

The "reply" field is a friendly, conversational message shown to the user. Make it natural, helpful, and use emojis. Reference actual data when possible.

═══════════════════════════════════════════════
AVAILABLE INTENTS (38 total):
═══════════════════════════════════════════════

── TASKS ──
1. create_task → {task_title, priority(low/medium/high), category(Cleaning/Bills/Shopping/Maintenance/Cooking/General), due_date}
2. complete_task → {task_title}
3. delete_task → {task_title}
4. update_task → {task_title, new_title, new_priority, new_category, new_due_date} — change any field on existing task
5. assign_task → {task_title, assign_to} — assign a task to a family member by name

── GROCERY ──
6. add_grocery → {items:[{name, quantity, unit}]}
7. buy_grocery → {item} — mark a grocery item as purchased/bought
8. remove_grocery → {item}
9. clear_purchased_groceries → {}
10. update_grocery → {item, new_quantity, new_unit} — change quantity/unit of existing item

── EXPENSES ──
11. add_expense → {title, amount, category(Food/Bills/Transport/Health/Shopping/Misc)}
12. delete_expense → {title}
13. update_expense → {title, new_amount, new_category} — change amount or category of existing expense

── BILLS ──
14. add_bill → {type(Electricity/Water/Gas/Internet/Phone/Rent/Other), amount, due_date}
15. mark_bill_paid → {bill_type}
16. delete_bill → {bill_type}
17. update_bill → {bill_type, new_amount, new_due_date} — change amount or due date of existing bill

── DEBTS / LOANS ──
18. add_debt → {name, total_amount, monthly_payment, interest_rate}
19. pay_debt → {debt_name, amount}
20. delete_debt → {debt_name}
21. update_debt → {debt_name, new_monthly_payment, new_interest_rate} — change payment or rate

── SAVINGS GOALS ──
22. add_savings_goal → {name, target_amount, monthly_contribution, icon}
23. deposit_savings → {goal_name, amount}
24. delete_savings → {goal_name}
25. update_savings → {goal_name, new_target_amount, new_monthly_contribution} — modify goal details

── MAINTENANCE ──
26. add_maintenance → {task_name, category(HVAC/Water/Electrical/General), due_date, recurring_days}
27. complete_maintenance → {task_name}
28. delete_maintenance → {task_name}
29. update_maintenance → {task_name, new_due_date, new_recurring_days} — reschedule maintenance

── EMERGENCY CONTACTS ──
30. add_emergency_contact → {name, phone, category(Hospital/Police/Fire/Electrician/Plumber/Emergency/Other)}
31. delete_emergency_contact → {name}
32. update_emergency_contact → {name, new_phone, new_category} — update phone or category

── SETTINGS & NAVIGATION ──
33. set_income → {amount}
34. toggle_theme → {}
35. navigate → {screen(home/tasks/chat/grocery/finance/maintenance/emergency/settings)}
36. toggle_notifications → {enabled(true/false)} — turn notifications on/off

── FAMILY CHAT ──
37. send_family_message → {message} — send a message to the family group chat

── QUERIES & CHAT ──
38. general_query → {query_type(tasks/groceries/expenses/maintenance/bills/debts/savings/health_score/suggestions/financial_insights/greeting/help/thanks/other)}
    For general_query, you MUST use the LIVE APP DATA to compose a DETAILED, ACCURATE "reply" with real numbers, names, and dates from the data. NEVER use placeholder text like "[Use LIVE DATA]".

═══════════════════════════════════════════════
REASONING & INTELLIGENCE RULES:
═══════════════════════════════════════════════

LANGUAGE UNDERSTANDING:
• Understand ANY language style — formal, casual, slang, abbreviations, Hinglish, typos
• "k" = thousand, "lakh/lac/L" = 100,000, "cr" = 10,000,000
• "tmrw" = tomorrow, "nxt wk" = next week, "2dy" = today
• "gonna", "wanna", "gotta" → understand informal English
• "kharcha" = expense, "udhar" = debt/loan, "bachat" = savings
• Fix common typos: "taks" → task, "groccery" → grocery, "maintnance" → maintenance
• Single words like "milk", "eggs", "bread", "rice" → add_grocery
• "done" / "finished" / "completed" + context → complete_task or complete_maintenance

SMART MATCHING:
• When user says "mark X as done/paid", figure out if X is a task, bill, or maintenance item from the LIVE DATA
• "delete the cleaning one" → match against existing tasks/items
• "how much" / "kitna" → query about expenses, debts, or savings based on context
• "show me" / "list" / "what are" → general_query with appropriate query_type

AMOUNT PARSING:
• "5k" → 5000, "1.5k" → 1500, "2L" → 200000, "10 lakh" → 1000000
• "five hundred" → 500, "two thousand" → 2000
• Parse amounts from natural text: "spent around 500 on food" → amount=500

DATE PARSING:
• "today", "tomorrow", "day after", "next week", "next month"
• "monday", "friday" → next occurring day
• "in 3 days", "in 2 weeks", "end of month"
• "15th", "20th" → next occurrence of that date

CONTEXTUAL INTELLIGENCE:
• Use LIVE APP DATA to give ACCURATE responses, not generic ones
• When asked "what tasks are pending" → list ACTUAL pending tasks from the data
• When asked "how much did we spend" → calculate from ACTUAL expenses
• When asked "any bills due" → check ACTUAL bills data
• If user asks about something and data is empty, say so naturally
• Use conversation history to resolve pronouns ("it", "that", "the one I added")
• LONG / MULTI-SENTENCE MESSAGES: Read the full "User message" from start to end. Extract every relevant detail (task title, amount, date, category, etc.) even if the user wrote a paragraph. One long message can contain one or several intents — pick the primary one and extract all needed fields from the full text.

MULTI-ACTION UNDERSTANDING:
• "add milk, eggs, and bread" → single add_grocery with 3 items
• For complex requests that need multiple actions, pick the MOST IMPORTANT one

EDGE CASES:
• Unknown/unclear → ask a clarifying question in the "reply" with intent "general_query" and query_type "other"
• If the user is just chatting / venting → respond empathetically with general_query greeting
• "thanks", "ok", "cool", "nice" → acknowledge warmly
• Empty/single character messages → friendly prompt to ask something

CRITICAL ACCURACY RULES:
• For general_query, ALWAYS compose the "reply" using the LIVE APP DATA — list actual item names, amounts, dates
• NEVER return placeholder text like "[Use LIVE DATA to list...]" — always fill in the actual data
• When listing items, use bullet points with • and include all relevant details
• If data is empty (e.g., no pending tasks), say so explicitly in a friendly way
• "bought milk" / "got the eggs" / "picked up bread" → buy_grocery (mark as purchased), NOT add_grocery
• "mark milk as bought/purchased/done" → buy_grocery
• "change priority to high" / "make it urgent" → update_task
• "assign to mom" / "give this to dad" → assign_task
• "change amount to 3000" → update_expense or update_bill depending on context
• "update plumber number" → update_emergency_contact
• "turn off notifications" / "mute alerts" / "disable notifications" → toggle_notifications with enabled=false
• "turn on notifications" / "enable alerts" → toggle_notifications with enabled=true
• "tell family..." / "message everyone..." / "announce..." → send_family_message
• "change milk to 2 liters" → update_grocery
• "reschedule AC service" / "move maintenance" → update_maintenance
• "increase vacation target" / "change savings goal" → update_savings
• "change home loan EMI" / "update loan interest" → update_debt

═══════════════════════════════════════════════
EXAMPLES:
═══════════════════════════════════════════════

User: electricity bill 2500 due next week
{"intent":"add_bill","type":"Electricity","amount":2500,"due_date":"next week","reply":"⚡ Electricity bill of ₹2,500 added, due next week!"}

User: mark gas bill as paid
{"intent":"mark_bill_paid","bill_type":"Gas","reply":"✅ Gas bill marked as paid!"}

User: pay 5k on home loan
{"intent":"pay_debt","debt_name":"Home Loan","amount":5000,"reply":"💰 ₹5,000 payment recorded for Home Loan!"}

User: how much do we owe
{"intent":"general_query","query_type":"debts","reply":"[Use LIVE DATA to list actual debts with amounts]"}

User: what's pending
{"intent":"general_query","query_type":"tasks","reply":"[Use LIVE DATA to list actual pending tasks]"}

User: save 3k in vacation fund
{"intent":"deposit_savings","goal_name":"Vacation Fund","amount":3000,"reply":"💰 ₹3,000 added to Vacation Fund!"}

User: add plumber raj 9876543210
{"intent":"add_emergency_contact","name":"Plumber Raj","phone":"9876543210","category":"Plumber","reply":"📞 Plumber Raj added to emergency contacts!"}

User: dark mode
{"intent":"toggle_theme","reply":"🎨 Theme switched!"}

User: go to finance
{"intent":"navigate","screen":"finance","reply":"📱 Opening Finance section..."}

User: hello
{"intent":"general_query","query_type":"greeting","reply":"Hey there! 👋 I'm your HomeHub assistant. I can manage tasks, groceries, bills, savings, and more. What would you like to do?"}

User: spent around 500 on dinner yesterday
{"intent":"add_expense","title":"Dinner","amount":500,"category":"Food","reply":"🍽️ ₹500 dinner expense recorded!"}

User: AC service is done
{"intent":"complete_maintenance","task_name":"AC","reply":"✅ AC service marked as completed!"}

User: kuch pending hai?
{"intent":"general_query","query_type":"tasks","reply":"[Use LIVE DATA to show pending tasks in a friendly way]"}

User: kitna kharcha hua is mahine
{"intent":"general_query","query_type":"expenses","reply":"[Use LIVE DATA to show this month's spending]"}

User: create vacation fund of 1 lakh with 5k monthly
{"intent":"add_savings_goal","name":"Vacation Fund","target_amount":100000,"monthly_contribution":5000,"icon":"✈️","reply":"🎯 Vacation Fund created! Target: ₹1,00,000 with ₹5,000/month contribution."}

User: hmm ok
{"intent":"general_query","query_type":"other","reply":"Let me know if you need anything! I can help manage tasks, bills, groceries, and more 😊"}

User: I bought the milk
{"intent":"buy_grocery","item":"milk","reply":"✅ Milk marked as purchased!"}

User: got the eggs
{"intent":"buy_grocery","item":"eggs","reply":"✅ Eggs marked as purchased!"}

User: change cleaning priority to high
{"intent":"update_task","task_title":"Cleaning","new_priority":"high","reply":"📝 Cleaning task priority updated to high!"}

User: assign dishes to mom
{"intent":"assign_task","task_title":"Dishes","assign_to":"Mom","reply":"👩 Dishes assigned to Mom!"}

User: change milk to 2 liters
{"intent":"update_grocery","item":"milk","new_quantity":2,"new_unit":"liters","reply":"📝 Milk updated to 2 liters!"}

User: change dinner expense to 600
{"intent":"update_expense","title":"Dinner","new_amount":600,"reply":"📝 Dinner expense updated to ₹600!"}

User: change electricity bill to 3000
{"intent":"update_bill","bill_type":"Electricity","new_amount":3000,"reply":"📝 Electricity bill updated to ₹3,000!"}

User: change home loan EMI to 15000
{"intent":"update_debt","debt_name":"Home Loan","new_monthly_payment":15000,"reply":"📝 Home Loan EMI updated to ₹15,000!"}

User: increase vacation target to 2 lakh
{"intent":"update_savings","goal_name":"Vacation","new_target_amount":200000,"reply":"📝 Vacation target updated to ₹2,00,000!"}

User: reschedule AC service to next month
{"intent":"update_maintenance","task_name":"AC","new_due_date":"next month","reply":"📝 AC service rescheduled to next month!"}

User: update plumber number to 9876543210
{"intent":"update_emergency_contact","name":"Plumber","new_phone":"9876543210","reply":"📝 Plumber contact updated!"}

User: turn off notifications
{"intent":"toggle_notifications","enabled":false,"reply":"🔕 Notifications turned off!"}

User: tell family dinner is ready
{"intent":"send_family_message","message":"Dinner is ready! 🍽️","reply":"📨 Message sent to family chat: Dinner is ready!"}
''';

  // ───────────────────────────────────────────────────────────────
  //  CONTEXT BUILDER — Injects live app data into the LLM call
  // ───────────────────────────────────────────────────────────────

  /// Builds a summary of all live app data for the LLM to reason about.
  static String _buildAppContext({
    required List<HouseholdTask> tasks,
    required List<GroceryItem> groceryItems,
    required List<Expense> expenses,
    required List<Debt> debts,
    required List<UtilityBill> bills,
    required List<MaintenanceTask> maintenanceTasks,
    required List<SavingsGoal> savingsGoals,
    required List<EmergencyContact> emergencyContacts,
    required double monthlyIncome,
  }) {
    final now = DateTime.now();
    final buf = StringBuffer();
    buf.writeln('\n═══ LIVE APP DATA (use this to answer questions accurately) ═══');
    buf.writeln('📅 Today: ${DateFormat('EEEE, MMM dd yyyy').format(now)}');
    buf.writeln('💰 Monthly Income: ${_cur.format(monthlyIncome)}');

    // Tasks
    final pendingTasks = tasks.where((t) => !t.isCompleted).toList();
    final overdueTasks = pendingTasks.where((t) => t.isOverdue).toList();
    buf.writeln('\n── TASKS (${pendingTasks.length} pending, ${overdueTasks.length} overdue) ──');
    if (pendingTasks.isEmpty) {
      buf.writeln('  No pending tasks.');
    } else {
      for (var t in pendingTasks.take(10)) {
        final due = t.dueDate != null ? ' (due ${DateFormat('MMM dd').format(t.dueDate!)})' : '';
        final overdue = t.isOverdue ? ' ⚠️OVERDUE' : '';
        buf.writeln('  • ${t.title} [${t.priority}]$due$overdue');
      }
      if (pendingTasks.length > 10) buf.writeln('  ... and ${pendingTasks.length - 10} more');
    }

    // Grocery
    final toBuy = groceryItems.where((g) => !g.isPurchased).toList();
    final bought = groceryItems.where((g) => g.isPurchased).toList();
    buf.writeln('\n── GROCERY (${toBuy.length} to buy, ${bought.length} purchased) ──');
    if (toBuy.isEmpty) {
      buf.writeln('  Grocery list empty.');
    } else {
      for (var g in toBuy.take(10)) {
        buf.writeln('  • ${g.name} (${g.quantity} ${g.unit})');
      }
    }

    // Expenses this month
    final thisMonth = expenses.where((e) => e.date.month == now.month && e.date.year == now.year).toList();
    final totalSpent = thisMonth.fold(0.0, (s, e) => s + e.amount);
    buf.writeln('\n── EXPENSES THIS MONTH (${_cur.format(totalSpent)} total, ${thisMonth.length} transactions) ──');
    // Category breakdown
    final cats = <String, double>{};
    for (var e in thisMonth) {
      cats[e.category] = (cats[e.category] ?? 0) + e.amount;
    }
    for (var entry in cats.entries) {
      buf.writeln('  • ${entry.key}: ${_cur.format(entry.value)}');
    }
    if (monthlyIncome > 0) {
      final pct = (totalSpent / monthlyIncome * 100).toInt();
      buf.writeln('  Budget used: $pct%');
    }

    // Bills
    final unpaidBills = bills.where((b) => !b.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final paidBills = bills.where((b) => b.isPaid).toList();
    buf.writeln('\n── BILLS (${unpaidBills.length} unpaid, ${paidBills.length} paid) ──');
    for (var b in unpaidBills) {
      final overdue = b.isOverdue ? ' ⚠️OVERDUE' : '';
      buf.writeln('  • ${b.type}: ${_cur.format(b.amount)} due ${DateFormat('MMM dd').format(b.dueDate)}$overdue');
    }
    if (unpaidBills.isEmpty) buf.writeln('  All bills paid! ✅');

    // Debts
    buf.writeln('\n── DEBTS (${debts.length} active) ──');
    if (debts.isEmpty) {
      buf.writeln('  No debts.');
    } else {
      for (var d in debts) {
        buf.writeln('  • ${d.name}: ${_cur.format(d.remainingAmount)} remaining of ${_cur.format(d.totalAmount)} (${(d.progressPercent * 100).toInt()}% paid)');
      }
    }

    // Savings
    buf.writeln('\n── SAVINGS GOALS (${savingsGoals.length}) ──');
    if (savingsGoals.isEmpty) {
      buf.writeln('  No savings goals.');
    } else {
      for (var g in savingsGoals) {
        buf.writeln('  • ${g.icon} ${g.name}: ${_cur.format(g.currentAmount)} / ${_cur.format(g.targetAmount)} (${(g.progressPercent * 100).toInt()}%)');
      }
    }

    // Maintenance
    final pendingMaint = maintenanceTasks.where((t) => !t.isCompleted).toList();
    buf.writeln('\n── MAINTENANCE (${pendingMaint.length} pending) ──');
    for (var t in pendingMaint) {
      final due = t.nextDue != null ? ' (due ${DateFormat('MMM dd').format(t.nextDue!)})' : '';
      final overdue = t.isOverdue ? ' ⚠️OVERDUE' : '';
      buf.writeln('  • ${t.name}$due$overdue');
    }
    if (pendingMaint.isEmpty) buf.writeln('  All maintenance up to date!');

    // Emergency Contacts
    buf.writeln('\n── EMERGENCY CONTACTS (${emergencyContacts.length}) ──');
    for (var c in emergencyContacts) {
      buf.writeln('  • ${c.name} (${c.category}): ${c.phone}');
    }
    if (emergencyContacts.isEmpty) buf.writeln('  No contacts saved.');

    buf.writeln('\n═══ END LIVE DATA ═══');
    return buf.toString();
  }

  // ───────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ───────────────────────────────────────────────────────────────

  /// Sends [userMessage] with [history] and LIVE APP CONTEXT to Gemini.
  /// Returns the parsed JSON map with intent + reply.
  static Future<Map<String, dynamic>> sendMessage(
    String userMessage, {
    List<ChatMessage> history = const [],
    List<HouseholdTask> tasks = const [],
    List<GroceryItem> groceryItems = const [],
    List<Expense> expenses = const [],
    List<Debt> debts = const [],
    List<UtilityBill> bills = const [],
    List<MaintenanceTask> maintenanceTasks = const [],
    List<SavingsGoal> savingsGoals = const [],
    List<EmergencyContact> emergencyContacts = const [],
    double monthlyIncome = 0,
  }) async {
    final url = Uri.parse('$_baseUrl/$_model:generateContent?key=$apiKey');

    // Build live context
    final appContext = _buildAppContext(
      tasks: tasks,
      groceryItems: groceryItems,
      expenses: expenses,
      debts: debts,
      bills: bills,
      maintenanceTasks: maintenanceTasks,
      savingsGoals: savingsGoals,
      emergencyContacts: emergencyContacts,
      monthlyIncome: monthlyIncome,
    );

    // Build the contents array from history (last 20 messages)
    final contents = <Map<String, dynamic>>[];
    final recentHistory = history.length > 20 ? history.sublist(history.length - 20) : history;

    for (var msg in recentHistory) {
      contents.add({
        'role': msg.isUser ? 'user' : 'model',
        'parts': [{'text': msg.text}]
      });
    }

    // Inject app context + user message; mark user message clearly so long phrases are read in full
    contents.add({
      'role': 'user',
      'parts': [{'text': '$appContext\n\n═══ USER MESSAGE (read and parse the entire message) ═══\n$userMessage'}]
    });

    final body = jsonEncode({
      'contents': contents,
      'systemInstruction': {
        'parts': [
          {'text': _systemPrompt}
        ]
      },
      'generationConfig': {
        'temperature': 0.1,
        'topP': 0.95,
        'maxOutputTokens': 1024,
      },
    });

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Gemini API error: ${response.statusCode} — ${response.body}');
    }

    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;

    // Extract text from Gemini response
    final candidates = responseJson['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No candidates in Gemini response');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw Exception('No parts in Gemini response');
    }

    String text = (parts[0]['text'] as String? ?? '').trim();

    // Strip any markdown code fences the model might add
    text = text
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*$', multiLine: true), '')
        .trim();

    // Parse the JSON
    final parsed = jsonDecode(text) as Map<String, dynamic>;

    if (!parsed.containsKey('intent')) {
      throw Exception('LLM response missing "intent" field');
    }

    return parsed;
  }

  /// Returns true if a valid API key has been configured.
  static bool get isConfigured =>
      apiKey.isNotEmpty && apiKey != 'YOUR_GEMINI_API_KEY';
}
