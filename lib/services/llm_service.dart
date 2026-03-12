import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service that communicates with Google Gemini to convert natural language
/// into structured JSON actions for the Home Management app.
class LLMService {
  // ───────────────────────────────────────────────────────────────
  //  CONFIGURATION — Replace with your own Gemini API key
  // ───────────────────────────────────────────────────────────────
  static const String apiKey = 'AIzaSyCHrg7Gfv6jasJlnCDYfER5SVb-9N2Urmg';

  static const String _model = 'gemini-2.0-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // ───────────────────────────────────────────────────────────────
  //  SYSTEM PROMPT
  // ───────────────────────────────────────────────────────────────
  static const String _systemPrompt = '''
You are an AI assistant for a Home Management application. Your job is to interpret user messages and convert them into structured JSON actions that the app can execute.

The assistant helps users manage:
* Household tasks
* Grocery lists
* Finance summaries

Always return ONLY valid JSON. Do not return explanations, markdown, or code fences.

Available intents:

1. create_task — User wants to create a new task.
   Required fields: "intent", "task_title"
   Optional fields: "priority" (low/medium/high), "category" (Cleaning/Bills/Shopping/Maintenance/Cooking/General), "due_date" (today/tomorrow/next week)

2. complete_task — User wants to mark a task as completed.
   Required fields: "intent", "task_title"

3. add_grocery — User wants to add item(s) to the grocery list.
   Required fields: "intent", "items" (array of {"name": string, "quantity": number, "unit": string})
   For a single item you must still use the "items" array.

4. remove_grocery — User wants to remove an item from the grocery list.
   Required fields: "intent", "item"

5. show_finance_summary — User wants to see spending or finance summary.
   Required fields: "intent"

6. add_expense — User wants to record a spending / expense.
   Required fields: "intent", "title", "amount"
   Optional: "category" (Food/Bills/Transport/Health/Shopping/Misc)

7. general_query — User is asking a question about their home data (tasks, groceries, maintenance, etc.) or greeting / chatting.
   Required fields: "intent", "query_type"
   query_type can be: "tasks", "groceries", "expenses", "maintenance", "bills", "debts", "health_score", "suggestions", "financial_insights", "greeting", "help", "thanks", "other"

Example inputs and outputs:

User: add milk to grocery
{"intent":"add_grocery","items":[{"name":"Milk","quantity":1,"unit":"pcs"}]}

User: add milk and eggs
{"intent":"add_grocery","items":[{"name":"Milk","quantity":1,"unit":"pcs"},{"name":"Eggs","quantity":1,"unit":"pcs"}]}

User: create a task to clean the house
{"intent":"create_task","task_title":"Clean the House","category":"Cleaning","priority":"medium"}

User: mark cleaning task as done
{"intent":"complete_task","task_title":"Cleaning"}

User: show my spending summary
{"intent":"show_finance_summary"}

User: spent 500 on groceries
{"intent":"add_expense","title":"Groceries","amount":500,"category":"Food"}

User: hello
{"intent":"general_query","query_type":"greeting"}

User: what tasks are pending?
{"intent":"general_query","query_type":"tasks"}

The assistant must understand short commands such as:
* "add milk" → add_grocery
* "clean house" → create_task
* "buy eggs" → add_grocery
* "task wash car" → create_task
* "milk" → add_grocery
* "eggs" → add_grocery

If the user message is a single common grocery/food item name (e.g. "milk", "eggs", "bread", "rice", "vegetables"), treat it as add_grocery.
If the user message starts with "task" or describes a chore, treat it as create_task.
If the user message contains a number that looks like an amount along with a description, treat it as add_expense.
''';

  // ───────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ───────────────────────────────────────────────────────────────

  /// Sends [userMessage] to Gemini and returns the parsed JSON map.
  /// Throws on network errors or if the response cannot be parsed.
  static Future<Map<String, dynamic>> sendMessage(String userMessage) async {
    final url = Uri.parse('$_baseUrl/$_model:generateContent?key=$apiKey');

    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userMessage}
          ]
        }
      ],
      'systemInstruction': {
        'parts': [
          {'text': _systemPrompt}
        ]
      },
      'generationConfig': {
        'temperature': 0.1,
        'topP': 0.95,
        'maxOutputTokens': 256,
      },
    });

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 15));

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

    // Strip any markdown code fences the model might add despite instructions
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
