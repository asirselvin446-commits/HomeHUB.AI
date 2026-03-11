import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'family_screen.dart';
import 'emergency_screen.dart';
import 'ai_assistant_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('More')),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          // User Profile Card
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryDark.withOpacity(0.3),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text('👑', style: TextStyle(fontSize: 28)),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.currentUser,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        state.firebaseUser?.email ?? 'Home Admin',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Invite Code Card
          if (state.householdId != null)
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppTheme.accentTeal.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.vpn_key_rounded,
                          color: AppTheme.accentTeal, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Household Invite Code',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentTeal,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Share this code so family members can join:',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                  SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: state.householdId!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Invite code copied! 📋'),
                          backgroundColor: AppTheme.accentTeal,
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkCardAlt
                            : Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              state.householdId!,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.darkText
                                    : AppTheme.lightText,
                              ),
                            ),
                          ),
                          Icon(Icons.copy_rounded,
                              size: 18,
                              color: AppTheme.accentTeal),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: 8),

          // Menu Items
          _menuSection('Features', [
            _MenuItem(
              icon: Icons.auto_awesome,
              title: 'AI Assistant',
              subtitle: 'Ask questions about your home',
              color: AppTheme.primaryDark,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => AIAssistantScreen())),
            ),
            _MenuItem(
              icon: Icons.family_restroom_rounded,
              title: 'Family Members',
              subtitle: '${state.familyMembers.length} members',
              color: AppTheme.accentBlue,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => FamilyScreen())),
            ),
            _MenuItem(
              icon: Icons.emergency_rounded,
              title: 'Emergency Contacts',
              subtitle: '${state.emergencyContacts.length} contacts',
              color: AppTheme.accentOrange,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => EmergencyScreen())),
            ),
          ], isDark),

          SizedBox(height: 16),

          _menuSection('Settings', [
            _MenuItem(
              icon: isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              title: 'Theme',
              subtitle: isDark ? 'Dark Mode' : 'Light Mode',
              color: AppTheme.accentYellow,
              onTap: () => state.toggleTheme(),
              trailing: Switch(
                value: isDark,
                onChanged: (_) => state.toggleTheme(),
                activeColor: AppTheme.primaryDark,
              ),
            ),
            _MenuItem(
              icon: Icons.currency_rupee_rounded,
              title: 'Monthly Income',
              subtitle: state.monthlyIncome > 0
                  ? '₹${state.monthlyIncome.toStringAsFixed(0)}'
                  : 'Not set',
              color: AppTheme.accentTeal,
              onTap: () => _showIncomeDialog(context, state),
            ),
          ], isDark),

          SizedBox(height: 16),

          _menuSection('Account', [
            _MenuItem(
              icon: Icons.info_outline_rounded,
              title: 'About HomeHub AI',
              subtitle: 'Version 1.0.0',
              color: AppTheme.darkTextSecondary,
              onTap: () {},
            ),
            _MenuItem(
              icon: Icons.logout_rounded,
              title: 'Sign Out',
              subtitle: 'Log out of your account',
              color: AppTheme.accentOrange,
              onTap: () => _confirmSignOut(context, state),
            ),
          ], isDark),

          SizedBox(height: 40),

          // App branding
          Center(
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.home_rounded,
                      color: Colors.white, size: 22),
                ),
                SizedBox(height: 8),
                Text(
                  'HomeHub AI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
                Text(
                  'Powered by Firebase 🔥',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.darkTextSecondary.withOpacity(0.5)
                        : AppTheme.lightTextSecondary.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _menuSection(String title, List<_MenuItem> items, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final item = entry.value;
              final isLast = entry.key == items.length - 1;
              return Column(
                children: [
                  ListTile(
                    onTap: item.onTap,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.color, size: 20),
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.darkText
                            : AppTheme.lightText,
                      ),
                    ),
                    subtitle: Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                    ),
                    trailing: item.trailing ??
                        Icon(Icons.chevron_right_rounded,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 72,
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showIncomeDialog(BuildContext context, AppState state) {
    final ctrl = TextEditingController(
      text: state.monthlyIncome > 0
          ? state.monthlyIncome.toStringAsFixed(0)
          : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Monthly Income'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration:
              InputDecoration(hintText: 'Enter monthly income (₹)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final income = double.tryParse(ctrl.text) ?? 0;
              if (income > 0) {
                state.setMonthlyIncome(income);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryDark,
              foregroundColor: Colors.white,
            ),
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign Out'),
        content: Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              state.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentOrange,
              foregroundColor: Colors.white,
            ),
            child: Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.trailing,
  });
}
