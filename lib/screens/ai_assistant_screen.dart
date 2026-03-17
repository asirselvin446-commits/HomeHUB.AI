import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../models/models.dart';

import '../theme/colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen>
    with TickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;

  // Quick action + question chips
  final List<Map<String, dynamic>> _quickChips = [
    {'icon': Icons.add_shopping_cart_rounded, 'label': 'Add milk to groceries'},
    {'icon': Icons.task_alt_rounded, 'label': 'Add task clean water tank tomorrow'},
    {'icon': Icons.receipt_long_outlined, 'label': 'Add electricity bill 1200 rupees'},
    {'icon': Icons.home_repair_service_outlined, 'label': 'When should I service the AC?'},
    {'icon': Icons.lightbulb_outline_rounded, 'label': 'Any financial suggestions?'},
    {'icon': Icons.checklist_rounded, 'label': 'What tasks are pending?'},
    {'icon': Icons.currency_rupee_rounded, 'label': 'How much did we spend this month?'},
    {'icon': Icons.health_and_safety_outlined, 'label': "What's our home health score?"},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndSendBriefing();
    });
  }

  void _checkAndSendBriefing() {
    final state = context.read<AppState>();
    if (state.chatMessages.isEmpty && !_isTyping) {
      // Small delay for natural feel
      setState(() => _isTyping = true);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        final briefing = AIService.generateProactiveBriefing(
          householdTasks: state.householdTasks,
          expenses: state.expenses,
        );
        state.addAITextMessage(briefing);
        setState(() => _isTyping = false);
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text(
          'This will delete all AI assistant messages. Your tasks, groceries, and expenses will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AppState>().clearChatHistory();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isTyping) return;

    _textController.clear();
    setState(() => _isTyping = true);

    try {
      await context.read<AppState>().sendChatMessage(text);
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
      }
    }

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messages = state.chatMessages;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Flexible(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                Text(
                  _isTyping ? 'Typing...' : 'Manage your home with a message',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isTyping
                        ? AppColors.primary
                        : isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            )),
          ],
        ),
        actions: [
          if (messages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.help_outline_rounded,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              tooltip: 'What can the assistant do?',
              onPressed: () {
                _textController.text = 'help';
                _sendMessage();
              },
            ),
          if (messages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              tooltip: 'Clear chat history',
              onPressed: _confirmClearChat,
            ),
        ],
      ),
      body: Column(
        children: [
          // Chat area
          Expanded(
            child: messages.isEmpty && !_isTyping
                ? _buildWelcomeView(isDark)
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (ctx, idx) {
                      if (_isTyping && idx == 0) {
                        return _buildTypingIndicator(isDark);
                      }
                      final msgIndex = messages.length - 1 - (idx - (_isTyping ? 1 : 0));
                      final msg = messages[msgIndex];
                      final isLastAi = !msg.isUser && msgIndex == messages.length - 1;
                      return _buildMessageBubble(msg, isDark, isLastAi);
                    },
                  ),
          ),

          // Quick chips (shown when chat is new or short)
          if (messages.length < 4 && !_isTyping)
            _buildQuickChips(isDark),

          // Input bar
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildWelcomeView(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 20),
          Text(
            'Hi! I\'m your Home Assistant 👋',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'I can add tasks, update your grocery list,\ncheck your finances, and much more!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 28),
          _buildCapabilityRow(Icons.add_shopping_cart_rounded, 'Add & manage groceries', isDark),
          const SizedBox(height: 10),
          _buildCapabilityRow(Icons.task_alt_rounded, 'Create & complete tasks', isDark),
          const SizedBox(height: 10),
          _buildCapabilityRow(Icons.bar_chart_rounded, 'Spending & budget insights', isDark),
          const SizedBox(height: 10),
          _buildCapabilityRow(Icons.home_repair_service_rounded, 'Maintenance schedules', isDark),
          const SizedBox(height: 24),
          Text(
            'Tap a suggestion below or type anything!',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You can use long sentences — I\'ll understand the full message.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextSecondary.withValues(alpha: 0.8) : AppColors.lightTextSecondary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilityRow(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChips(bool isDark) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          final chip = _quickChips[idx];
          return GestureDetector(
            onTap: () {
              _textController.text = chip['label'];
              _sendMessage();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(chip['icon'] as IconData, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    chip['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(26),
              ),
              child: TextField(
                controller: _textController,
                enabled: !_isTyping,
                maxLines: 3,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: _isTyping ? 'Thinking...' : 'Add milk, create task, ask anything...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isTyping ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _isTyping ? null : AppColors.primaryGradient,
                color: _isTyping ? (isDark ? AppColors.darkCard : Colors.grey.shade200) : null,
                borderRadius: BorderRadius.circular(24),
                boxShadow: _isTyping
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: _isTyping
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            _TypingDots(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark, bool isLastAi) {
    final isUser = msg.isUser;
    final text = msg.text;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primary
              : isDark
                  ? AppColors.darkCard
                  : AppColors.lightCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'HomeHub AI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            if (isLastAi)
              _buildAnimatedRichText(text, isUser, isDark)
            else
              _buildRichText(text, isUser, isDark),
            
            if (!isUser && msg.actionType != null)
              _buildActionWidget(msg, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedRichText(String text, bool isUser, bool isDark) {
    final baseColor = isUser ? Colors.white : (isDark ? AppColors.darkText : AppColors.lightText);
    final cleanText = text.replaceAll('**', '');
    
    return DefaultTextStyle(
      style: TextStyle(fontSize: 14, height: 1.55, color: baseColor),
      child: AnimatedTextKit(
        animatedTexts: [
          TypewriterAnimatedText(
            cleanText,
            speed: const Duration(milliseconds: 15),
          ),
        ],
        isRepeatingAnimation: false,
        displayFullTextOnTap: true,
      ),
    );
  }

  Widget _buildActionWidget(ChatMessage msg, bool isDark) {
    if (msg.actionType == null || msg.actionData == null) return const SizedBox.shrink();
    
    final type = msg.actionType!;
    final data = msg.actionData!;
    
    IconData icon = Icons.check_circle_outline;
    String title = 'Action completed';
    String subtitle = '';
    Color color = AppColors.primary;
    
    if (type == 'add_task') {
      icon = Icons.task_alt_rounded;
      title = data['title'] ?? 'Task Added';
      subtitle = 'Priority: ${data['priority'] ?? 'Medium'}';
    } else if (type == 'add_expense') {
      icon = Icons.receipt_long_rounded;
      title = data['title'] ?? 'Expense Recorded';
      subtitle = 'Amount: ₹${data['amount']}';
      color = AppColors.error;
    } else if (type == 'add_grocery' || type == 'add_grocery_multi') {
      icon = Icons.shopping_cart_outlined;
      title = type == 'add_grocery' ? (data['name'] ?? 'Grocery Added') : 'Groceries Added';
      subtitle = type == 'add_grocery' ? '${data['quantity']} ${data['unit']}' : '';
      color = const Color(0xFF10b981); // Emerald green
    } else if (type == 'add_maintenance') {
      icon = Icons.home_repair_service_rounded;
      title = data['title'] ?? 'Maintenance Scheduled';
      subtitle = 'Category: ${data['category']}';
      color = Colors.orange;
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87, fontSize: 13)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 600.ms).slideY(begin: 0.1, end: 0, duration: 400.ms, delay: 600.ms);
  }

  /// Renders **bold** markdown in the message text.
  Widget _buildRichText(String text, bool isUser, bool isDark) {
    final baseColor = isUser
        ? Colors.white
        : isDark
            ? AppColors.darkText
            : AppColors.lightText;

    // Simple **bold** parser
    final spans = <TextSpan>[];
    final boldRegex = RegExp(r'\*\*(.+?)\*\*');
    int last = 0;
    for (final m in boldRegex.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 14, height: 1.55, color: baseColor),
        children: spans,
      ),
    );
  }
}

// Animated bouncing dots widget
class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500));
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
    _anims = _controllers
        .map((c) => Tween<double>(begin: 0, end: -5).animate(
            CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (ctx, _) => Transform.translate(
            offset: Offset(0, _anims[i].value),
            child: Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
