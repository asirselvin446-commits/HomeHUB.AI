import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

class HouseholdSetupScreen extends StatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  State<HouseholdSetupScreen> createState() => _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends State<HouseholdSetupScreen>
    with SingleTickerProviderStateMixin {
  int _page = 0; // 0 = choose, 1 = create, 2 = join
  bool _isLoading = false;
  String? _errorMessage;

  final _householdNameCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();
  final _inviteCodeCtrl = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _householdNameCtrl.dispose();
    _incomeCtrl.dispose();
    _inviteCodeCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    setState(() {
      _page = page;
      _errorMessage = null;
    });
    _animController.reset();
    _animController.forward();
  }

  Future<void> _createHousehold() async {
    if (_householdNameCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a household name');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final income = double.tryParse(_incomeCtrl.text) ?? 0;
      await context.read<AppState>().createHousehold(
            name: _householdNameCtrl.text.trim(),
            monthlyIncome: income,
          );
    } catch (e) {
      setState(() => _errorMessage = 'Failed to create household. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinHousehold() async {
    if (_inviteCodeCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter an invite code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await context
          .read<AppState>()
          .joinHousehold(_inviteCodeCtrl.text.trim());
      if (!success) {
        setState(
            () => _errorMessage = 'Invalid invite code. Please check and try again.');
      }
    } catch (e) {
      setState(
          () => _errorMessage = 'Failed to join household. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.darkBg,
              Color(0xFF1A1A3E),
              AppColors.darkBg,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: _page == 0
                  ? _buildChoosePage(state)
                  : _page == 1
                      ? _buildCreatePage()
                      : _buildJoinPage(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoosePage(AppState state) {
    final displayName = state.firebaseUser?.displayName ?? 'there';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Icon(Icons.home_rounded, color: Colors.white, size: 40),
        ),
        SizedBox(height: 32),
        Text(
          'Hey, $displayName! 👋',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Set up your household to get started',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.darkTextSecondary,
          ),
        ),
        SizedBox(height: 48),

        // Create new household
        _optionCard(
          icon: Icons.add_home_rounded,
          title: 'Create New Household',
          subtitle: 'Start fresh and invite your family',
          gradient: AppColors.primaryGradient,
          onTap: () => _goToPage(1),
        ),

        SizedBox(height: 16),

        // Join existing
        _optionCard(
          icon: Icons.group_add_rounded,
          title: 'Join Existing Household',
          subtitle: 'Enter an invite code from a family member',
          gradient: AppColors.primaryGradient,
          onTap: () => _goToPage(2),
        ),

        SizedBox(height: 32),

        TextButton.icon(
          onPressed: () => state.signOut(),
          icon: Icon(Icons.logout_rounded,
              color: AppColors.darkTextSecondary, size: 18),
          label: Text(
            'Sign out',
            style: TextStyle(
                color: AppColors.darkTextSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _optionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatePage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _goToPage(0),
          child: Row(
            children: [
              Icon(Icons.arrow_back_ios_rounded,
                  color: AppColors.darkTextSecondary, size: 18),
              SizedBox(width: 4),
              Text('Back',
                  style: TextStyle(
                      color: AppColors.darkTextSecondary, fontSize: 14)),
            ],
          ),
        ),
        SizedBox(height: 32),
        Text(
          'Create Household',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Give your home a name and set your income for financial insights',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.darkTextSecondary,
          ),
        ),
        SizedBox(height: 32),

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

        TextField(
          controller: _householdNameCtrl,
          style: TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Household Name (e.g. Smith Family)',
            hintStyle: TextStyle(color: AppColors.darkTextSecondary),
            prefixIcon:
                Icon(Icons.home_rounded, color: AppColors.primary),
          ),
        ),
        SizedBox(height: 14),
        TextField(
          controller: _incomeCtrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Monthly Income (₹) - optional',
            hintStyle: TextStyle(color: AppColors.darkTextSecondary),
            prefixIcon: Icon(Icons.currency_rupee_rounded,
                color: AppColors.primary),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'This helps our AI provide financial advice. You can change it later.',
          style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
        ),
        SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _createHousehold,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 8,
              shadowColor: AppColors.primary.withOpacity(0.5),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text('Create Household 🏠',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinPage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _goToPage(0),
          child: Row(
            children: [
              Icon(Icons.arrow_back_ios_rounded,
                  color: AppColors.darkTextSecondary, size: 18),
              SizedBox(width: 4),
              Text('Back',
                  style: TextStyle(
                      color: AppColors.darkTextSecondary, fontSize: 14)),
            ],
          ),
        ),
        SizedBox(height: 32),
        Text(
          'Join Household',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Ask a family member who is an Admin to share their household invite code',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.darkTextSecondary,
          ),
        ),
        SizedBox(height: 32),

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

        TextField(
          controller: _inviteCodeCtrl,
          style: TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Enter Invite Code',
            hintStyle: TextStyle(color: AppColors.darkTextSecondary),
            prefixIcon:
                Icon(Icons.vpn_key_rounded, color: AppColors.primary),
          ),
        ),
        SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _joinHousehold,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 8,
              shadowColor: AppColors.primary.withOpacity(0.5),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text('Join Household 🤝',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
