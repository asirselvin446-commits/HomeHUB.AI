import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nicknameCtrl = TextEditingController();
  String _selectedRole = 'Father';
  String _selectedAvatar = '👨';
  bool _isLoading = false;
  String? _errorMessage;

  final List<Map<String, String>> _roles = [
    {'role': 'Father', 'avatar': '👨'},
    {'role': 'Mother', 'avatar': '👩'},
    {'role': 'Son', 'avatar': '👦'},
    {'role': 'Daughter', 'avatar': '👧'},
    {'role': 'Brother', 'avatar': '👦'},
    {'role': 'Sister', 'avatar': '👧'},
    {'role': 'Grandfather', 'avatar': '👴'},
    {'role': 'Grandmother', 'avatar': '👵'},
    {'role': 'Other', 'avatar': '👤'},
  ];

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_nicknameCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a nickname');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<AppState>().updateProfile(
            nickname: _nicknameCtrl.text.trim(),
            role: _selectedRole,
            avatar: _selectedAvatar,
          );
    } catch (e) {
      setState(() => _errorMessage = 'Failed to save profile. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.darkBg,
              Color(0xFF131332),
              AppColors.darkBg,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Profile',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'How should your family see you?',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                SizedBox(height: 48),

                if (_errorMessage != null) ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_errorMessage!,
                        style: TextStyle(color: AppColors.error, fontSize: 13)),
                  ),
                  SizedBox(height: 16),
                ],

                // Avatar Display
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _selectedAvatar,
                        style: TextStyle(fontSize: 50),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 40),

                Text(
                  'Nick Name',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _nicknameCtrl,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. Papa, Junior, etc.',
                    hintStyle: TextStyle(color: AppColors.darkTextSecondary.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.face_rounded, color: AppColors.primary),
                  ),
                ),
                SizedBox(height: 32),

                Text(
                  'Family Role',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _roles.map((r) {
                    final isSelected = _selectedRole == r['role'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRole = r['role']!;
                          _selectedAvatar = r['avatar']!;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.darkCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.white24 : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(r['avatar']!, style: TextStyle(fontSize: 18)),
                            SizedBox(width: 8),
                            Text(
                              r['role']!,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.darkTextSecondary,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 48),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: AppColors.primary.withOpacity(0.4),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Continue',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                
                SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () => context.read<AppState>().signOut(),
                    child: Text(
                      'Sign out',
                      style: TextStyle(color: AppColors.darkTextSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
