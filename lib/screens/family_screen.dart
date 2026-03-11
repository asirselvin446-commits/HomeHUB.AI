import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('Family Members')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: Icon(Icons.person_add_rounded),
      ),
      body: state.familyMembers.isEmpty
          ? EmptyState(
              icon: Icons.family_restroom_rounded,
              title: 'No Family Members',
              subtitle: 'Add family members to share tasks and collaborate',
            )
          : ListView(
              padding: EdgeInsets.all(20),
              children: [
                // Invite Banner
                Container(
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.purpleGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.share_rounded, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invite Family Members',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                            Text(
                              'Share the app with your family to collaborate!',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                ...state.familyMembers
                    .map((m) => _memberCard(context, m, isDark, state)),
              ],
            ),
    );
  }

  Widget _memberCard(
      BuildContext context, FamilyMember member, bool isDark, AppState state) {
    Color roleColor = member.role == 'Admin'
        ? AppTheme.accentYellow
        : member.role == 'Member'
            ? AppTheme.accentTeal
            : AppTheme.darkTextSecondary;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primaryDark.withOpacity(0.2),
            child: Text(
              member.avatar,
              style: TextStyle(fontSize: 24),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkText : AppTheme.lightText,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  member.email.isNotEmpty ? member.email : 'No email set',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              member.role,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: roleColor,
              ),
            ),
          ),
          if (member.role != 'Admin')
            IconButton(
              icon: Icon(Icons.remove_circle_outline_rounded,
                  color: AppTheme.accentOrange, size: 20),
              onPressed: () => state.deleteFamilyMember(member.id),
            ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = 'Member';
    String avatar = '👤';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkSurface
          : AppTheme.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
              SizedBox(height: 16),
              Text('Add Family Member',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 16),
              // Avatar selection
              Wrap(
                spacing: 8,
                children: ['👤', '👩', '👨', '👧', '👦', '👵', '👴']
                    .map((e) => GestureDetector(
                          onTap: () => setState(() => avatar = e),
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: avatar == e
                                  ? AppTheme.primaryDark.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(e, style: TextStyle(fontSize: 28)),
                          ),
                        ))
                    .toList(),
              ),
              SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: InputDecoration(hintText: 'Name')),
              SizedBox(height: 12),
              TextField(controller: emailCtrl, decoration: InputDecoration(hintText: 'Email (optional)')),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                items: ['Admin', 'Member', 'Viewer']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => role = v!),
                decoration: InputDecoration(hintText: 'Role'),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty) {
                      context.read<AppState>().addFamilyMember(FamilyMember(
                            id: '',
                            name: nameCtrl.text,
                            email: emailCtrl.text,
                            role: role,
                            avatar: avatar,
                          ));
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Add Member', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
