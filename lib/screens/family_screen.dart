import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../theme/colors.dart';
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
        onPressed: () => _showMemberDialog(context),
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
                GestureDetector(
                  onTap: () async {
                    if (state.householdId != null) {
                      await Clipboard.setData(ClipboardData(text: state.householdId!));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Invite code copied: ${state.householdId!}'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(16),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: AppColors.aiGradient,
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
                ),

                ...state.familyMembers
                    .map((m) => _memberCard(context, m, isDark, state)),
              ],
            ),
    );
  }

  Widget _memberCard(
      BuildContext context, FamilyMember member, bool isDark, AppState state) {
    final isCurrentUser = member.id == state.currentUserId;

    // Role badge color
    Color roleColor = AppColors.primary;
    if (member.role == 'Father' || member.role == 'Mother') {
      roleColor = AppColors.primary;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: isCurrentUser
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      SizedBox(width: 6),
                      Text(
                        'You',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  member.email.isNotEmpty ? member.email : 'No email set',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Role + Admin badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Admin badge
              if (member.isAdmin)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_rounded, size: 12, color: AppColors.accent),
                      SizedBox(width: 4),
                      Text(
                        'Admin',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              // Family role badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.15),
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
            ],
          ),
          // Admin actions popup menu (WhatsApp-style) — only shown to admins, not on own card
          if (state.isAdmin && !isCurrentUser)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                size: 20,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              itemBuilder: (ctx) => [
                // Make Admin / Dismiss Admin
                if (!member.isAdmin)
                  PopupMenuItem(
                    value: 'make_admin',
                    child: Row(
                      children: [
                        Icon(Icons.shield_rounded, size: 18, color: AppColors.accent),
                        SizedBox(width: 10),
                        Text('Make Admin'),
                      ],
                    ),
                  )
                else
                  PopupMenuItem(
                    value: 'dismiss_admin',
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 18, color: AppColors.darkTextSecondary),
                        SizedBox(width: 10),
                        Text('Dismiss as Admin'),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('Edit Info'),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove_rounded, size: 18, color: AppColors.error),
                      SizedBox(width: 10),
                      Text('Remove', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
              onSelected: (action) {
                switch (action) {
                  case 'make_admin':
                    _confirmAction(
                      context,
                      title: 'Make Admin',
                      message: 'Make ${member.name} an admin? They will have full control over the household.',
                      confirmLabel: 'Make Admin',
                      confirmColor: AppColors.accent,
                      onConfirm: () => state.toggleMemberAdminRole(member.id, true),
                    );
                    break;
                  case 'dismiss_admin':
                    _confirmAction(
                      context,
                      title: 'Dismiss Admin',
                      message: 'Remove admin privileges from ${member.name}?',
                      confirmLabel: 'Dismiss',
                      confirmColor: AppColors.error,
                      onConfirm: () => state.toggleMemberAdminRole(member.id, false),
                    );
                    break;
                  case 'edit':
                    _showMemberDialog(context, member: member);
                    break;
                  case 'remove':
                    _confirmAction(
                      context,
                      title: 'Remove Member',
                      message: 'Remove ${member.name} from the family? They will lose access to all household data.',
                      confirmLabel: 'Remove',
                      confirmColor: Colors.red,
                      onConfirm: () => state.deleteFamilyMember(member.id),
                    );
                    break;
                }
              },
            )
          else
            SizedBox(width: 8),
        ],
      ),
    );
  }

  void _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.darkTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _showMemberDialog(BuildContext context, {FamilyMember? member}) {
    final nameCtrl = TextEditingController(text: member?.name ?? '');
    final emailCtrl = TextEditingController(text: member?.email ?? '');
    String role = member?.role ?? 'Other';
    String avatar = member?.avatar ?? '👤';

    final rolesList = [
      'Father', 'Mother', 'Son', 'Daughter',
      'Brother', 'Sister', 'Grandfather', 'Grandmother', 'Other',
    ];
    final dropdownValue = rolesList.contains(role) ? role : 'Other';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
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
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
              SizedBox(height: 16),
              Text(member == null ? 'Add Family Member' : 'Edit Family Member',
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
                                  ? AppColors.primary.withValues(alpha: 0.2)
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
                initialValue: dropdownValue,
                items: rolesList
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => role = v!),
                decoration: InputDecoration(hintText: 'Family Role'),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty) {
                      final newMember = FamilyMember(
                        id: member?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text,
                        email: emailCtrl.text,
                        role: role,
                        avatar: avatar,
                        isAdmin: member?.isAdmin ?? false,
                      );
                      if (member == null) {
                        context.read<AppState>().addFamilyMember(newMember);
                      } else {
                        context.read<AppState>().updateFamilyMember(newMember);
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(member == null ? 'Add Member' : 'Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
