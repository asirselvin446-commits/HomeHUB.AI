import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  static const Map<String, IconData> categoryIcons = {
    'Hospital': Icons.local_hospital_rounded,
    'Emergency': Icons.emergency_rounded,
    'Electrician': Icons.electrical_services_rounded,
    'Plumber': Icons.plumbing_rounded,
    'Fire': Icons.local_fire_department_rounded,
    'Police': Icons.local_police_rounded,
    'Family': Icons.family_restroom_rounded,
    'Other': Icons.phone_rounded,
  };

  static const Map<String, Color> categoryColors = {
    'Hospital': Color(0xFFFF6B6B),
    'Emergency': Color(0xFFFF4757),
    'Electrician': Color(0xFFFFD93D),
    'Plumber': Color(0xFF4ECDC4),
    'Fire': Color(0xFFFF6348),
    'Police': Color(0xFF3742FA),
    'Family': Color(0xFF6C63FF),
    'Other': Color(0xFFA0A0B8),
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contacts = state.emergencyContacts;

    // Group by category
    Map<String, List<EmergencyContact>> grouped = {};
    for (var c in contacts) {
      grouped.putIfAbsent(c.category, () => []).add(c);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Emergency'),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentOrange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emergency_rounded,
                    color: AppTheme.accentOrange, size: 16),
                SizedBox(width: 4),
                Text(
                  'SOS',
                  style: TextStyle(
                    color: AppTheme.accentOrange,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showContactDialog(context),
        child: Icon(Icons.add_rounded),
      ),
      body: contacts.isEmpty
          ? EmptyState(
              icon: Icons.emergency_rounded,
              title: 'No Emergency Contacts',
              subtitle: 'Add important contacts for quick access during emergencies',
            )
          : ListView(
              padding: EdgeInsets.all(20),
              children: [
                // Quick Dial Section
                Container(
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFFF6B6B).withOpacity(0.15),
                        Color(0xFFFF4757).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.accentOrange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.speed_rounded,
                              color: AppTheme.accentOrange, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Quick Access',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentOrange,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: contacts.take(6).map((c) {
                          final color = categoryColors[c.category] ??
                              categoryColors['Other']!;
                          return GestureDetector(
                            onTap: () => _showContactDetails(context, c, isDark),
                            child: Container(
                              width: (MediaQuery.of(context).size.width - 72) / 3,
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.darkCard
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      categoryIcons[c.category] ??
                                          Icons.phone_rounded,
                                      color: color,
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    c.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppTheme.darkText
                                          : AppTheme.lightText,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                // Contacts by category
                ...grouped.entries.map((entry) {
                  final color = categoryColors[entry.key] ??
                      categoryColors['Other']!;
                  final icon = categoryIcons[entry.key] ?? Icons.phone_rounded;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: color, size: 18),
                          SizedBox(width: 8),
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.darkText
                                  : AppTheme.lightText,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      ...entry.value.map((contact) => Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkCard
                                  : AppTheme.lightCard,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(icon, color: color, size: 20),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? AppTheme.darkText
                                              : AppTheme.lightText,
                                        ),
                                      ),
                                      Text(
                                        contact.phone,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.primaryDark,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentTeal
                                            .withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.phone_rounded,
                                          color: AppTheme.accentTeal,
                                          size: 18),
                                    ),
                                    SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _showContactDialog(context, contact: contact),
                                      child: Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                                              .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(Icons.edit_rounded,
                                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                            size: 18),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () =>
                                          state.deleteEmergencyContact(
                                              contact.id),
                                      child: Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentOrange
                                              .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                            Icons.delete_outline_rounded,
                                            color: AppTheme.accentOrange,
                                            size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )),
                      SizedBox(height: 16),
                    ],
                  );
                }),
                SizedBox(height: 60),
              ],
            ),
    );
  }

  void _showContactDetails(
      BuildContext context, EmergencyContact contact, bool isDark) {
    final color = categoryColors[contact.category] ?? categoryColors['Other']!;
    showModalBottomSheet(
      context: context,
      backgroundColor:
          isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                categoryIcons[contact.category] ?? Icons.phone_rounded,
                color: color,
                size: 30,
              ),
            ),
            SizedBox(height: 16),
            Text(
              contact.name,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text(
              contact.category,
              style: TextStyle(fontSize: 14, color: color),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_rounded, color: AppTheme.primaryDark),
                  SizedBox(width: 8),
                  Text(
                    contact.phone,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  // In production, this would call url_launcher to dial
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Calling ${contact.phone}...'),
                      backgroundColor: AppTheme.accentTeal,
                    ),
                  );
                },
                icon: Icon(Icons.call_rounded),
                label: Text('Call Now',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showContactDialog(BuildContext context, {EmergencyContact? contact}) {
    final nameCtrl = TextEditingController(text: contact?.name ?? '');
    final phoneCtrl = TextEditingController(text: contact?.phone ?? '');
    String category = contact?.category ?? 'Hospital';

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
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(contact == null ? 'Add Emergency Contact' : 'Edit Contact',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(hintText: 'Contact name'),
              ),
              SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(hintText: 'Phone number'),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: InputDecoration(hintText: 'Category'),
                items: [
                  'Hospital',
                  'Emergency',
                  'Electrician',
                  'Plumber',
                  'Fire',
                  'Police',
                  'Family',
                  'Other'
                ]
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => category = v!),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty &&
                        phoneCtrl.text.isNotEmpty) {
                      final newContact = EmergencyContact(
                        id: contact?.id ?? '',
                        name: nameCtrl.text,
                        phone: phoneCtrl.text,
                        category: category,
                      );
                      if (contact == null) {
                        context.read<AppState>().addEmergencyContact(newContact);
                      } else {
                        context.read<AppState>().updateEmergencyContact(newContact);
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(contact == null ? 'Add Contact' : 'Save Changes',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
