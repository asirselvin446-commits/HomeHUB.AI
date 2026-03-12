import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

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
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
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
          _scrollController.position.maxScrollExtent,
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
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkText : AppTheme.lightText,
                  ),
                ),
                Text(
                  _isTyping ? 'Typing...' : 'Manage your home with a message',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isTyping
                        ? AppTheme.primaryDark
                        : isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (messages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.help_outline_rounded,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              tooltip: 'What can the assistant do?',
              onPressed: () {
                _textController.text = 'help';
                _sendMessage();
              },
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (ctx, idx) {
                      if (idx == messages.length && _isTyping) {
                        return _buildTypingIndicator(isDark);
                      }
                      final msg = messages[idx];
                      return _buildMessageBubble(msg.text, msg.isUser, isDark);
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
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryDark.withOpacity(0.3),
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
              color: isDark ? AppTheme.darkText : AppTheme.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'I can add tasks, update your grocery list,\ncheck your finances, and much more!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
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
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
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
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryDark.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryDark),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.darkText : AppTheme.lightText,
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
                color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.primaryDark.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(chip['icon'] as IconData, size: 14, color: AppTheme.primaryDark),
                  const SizedBox(width: 6),
                  Text(
                    chip['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkText : AppTheme.lightText,
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
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
                color: isDark ? AppTheme.darkCard : const Color(0xFFF0F2F5),
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
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.darkText : AppTheme.lightText,
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
                gradient: _isTyping ? null : AppTheme.primaryGradient,
                color: _isTyping ? (isDark ? AppTheme.darkCard : Colors.grey.shade200) : null,
                borderRadius: BorderRadius.circular(24),
                boxShadow: _isTyping
                    ? []
                    : [
                        BoxShadow(
                          color: AppTheme.primaryDark.withOpacity(0.4),
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
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 14, color: AppTheme.primaryDark),
            const SizedBox(width: 6),
            _TypingDots(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser, bool isDark) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.primaryDark
              : isDark
                  ? AppTheme.darkCard
                  : AppTheme.lightCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
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
                    Icon(Icons.auto_awesome, size: 13, color: AppTheme.primaryDark),
                    const SizedBox(width: 4),
                    Text(
                      'HomeHub AI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            _buildRichText(text, isUser, isDark),
          ],
        ),
      ),
    );
  }

  /// Renders **bold** markdown in the message text.
  Widget _buildRichText(String text, bool isUser, bool isDark) {
    final baseColor = isUser
        ? Colors.white
        : isDark
            ? AppTheme.darkText
            : AppTheme.lightText;

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
                color: AppTheme.primaryDark.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
