import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  String _selectedType = 'Feedback';
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _rating = 0;
  bool _isSending = false;

  final _types = ['Feedback', 'Bug Report', 'Feature Request', 'Other'];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = context.read<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback & Report')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF7C3AED).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.feedback_rounded, color: Colors.white, size: 40),
                const SizedBox(height: 10),
                Text(
                  'We value your feedback!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Help us improve HomeHub AI',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Type selector
          Text(
            'Type',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _types.map((type) {
              final selected = _selectedType == type;
              return ChoiceChip(
                label: Text(type),
                selected: selected,
                selectedColor: AppTheme.primaryDark.withOpacity(0.15),
                labelStyle: TextStyle(
                  color: selected
                      ? AppTheme.primaryDark
                      : isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                side: BorderSide(
                  color: selected
                      ? AppTheme.primaryDark
                      : (isDark ? Colors.white12 : Colors.black12),
                ),
                onSelected: (_) => setState(() => _selectedType = type),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Rating row (only for Feedback)
          if (_selectedType == 'Feedback') ...[
            Text(
              'How would you rate the app?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: i < _rating ? Colors.amber : Colors.grey.shade400,
                      size: 36,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
          ],

          // Subject
          _buildField(
            label: 'Subject',
            controller: _subjectCtrl,
            hint: _selectedType == 'Bug Report'
                ? 'e.g. App crashes when adding expense'
                : 'Brief summary',
            isDark: isDark,
          ),

          const SizedBox(height: 16),

          // Description
          _buildField(
            label: 'Description',
            controller: _descCtrl,
            hint: _selectedType == 'Bug Report'
                ? 'Steps to reproduce the issue...'
                : 'Tell us more...',
            isDark: isDark,
            maxLines: 5,
          ),

          const SizedBox(height: 28),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSending ? null : () => _submit(context, state),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isSending
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Submit $_selectedType',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Contact note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.email_outlined,
                    size: 18,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You can also reach us at support@homehub.ai',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppTheme.darkText : AppTheme.lightText,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            filled: true,
            fillColor: isDark ? AppTheme.darkCard : AppTheme.lightCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryDark, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  void _submit(BuildContext context, AppState state) async {
    if (_subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a subject'),
          backgroundColor: AppTheme.accentOrange,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    // Simulate sending (replace with actual API call later)
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    setState(() => _isSending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Thank you! Your $_selectedType has been submitted 🎉'),
        backgroundColor: AppTheme.accentTeal,
      ),
    );

    Navigator.pop(context);
  }
}
