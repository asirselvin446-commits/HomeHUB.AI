import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/common_widgets.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasks = state.maintenanceTasks;
    final suggestions = state.maintenanceSuggestions;

    return Scaffold(
      appBar: AppBar(
        title: Text('Maintenance'),
        actions: [
          IconButton(
            icon: Icon(Icons.lightbulb_outline_rounded, color: AppColors.accent),
            onPressed: () => _showAISuggestions(context, suggestions),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMaintenanceDialog(context),
        child: Icon(Icons.add_rounded),
      ),
      body: tasks.isEmpty
          ? EmptyState(
              icon: Icons.build_circle_rounded,
              title: 'No Maintenance Tasks',
              subtitle: 'Add appliances and home systems to track their maintenance schedules',
            )
          : ListView(
              padding: EdgeInsets.all(20),
              children: [
                // AI Suggestions Banner
                if (suggestions.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(16),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.15),
                          AppColors.primary.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'AI Predictions',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          suggestions.first,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Task List
                ...tasks.map((task) => _buildTaskCard(context, task, isDark, state)),
              ],
            ),
    );
  }

  Widget _buildTaskCard(
      BuildContext context, MaintenanceTask task, bool isDark, AppState state) {
    Color statusColor = task.isOverdue
        ? AppColors.error
        : task.isDueSoon
            ? AppColors.accent
            : AppColors.primary;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getCategoryIcon(task.category),
                  color: statusColor,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      task.category,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: Icon(Icons.more_vert_rounded,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'complete',
                    child: Row(children: [
                      Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                      SizedBox(width: 8),
                      Text('Mark Serviced'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded, color: AppColors.accent, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete, color: AppColors.error, size: 18),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ]),
                  ),
                ],
                onSelected: (val) {
                  if (val == 'complete') state.completeMaintenanceTask(task.id);
                  if (val == 'edit') _showMaintenanceDialog(context, task: task);
                  if (val == 'delete') state.deleteMaintenanceTask(task.id);
                },
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _infoChip(
                Icons.history_rounded,
                task.lastServiced != null
                    ? 'Last: ${DateFormat('MMM dd').format(task.lastServiced!)}'
                    : 'Never serviced',
                isDark,
              ),
              SizedBox(width: 8),
              _infoChip(
                Icons.event_rounded,
                task.nextDue != null
                    ? 'Next: ${DateFormat('MMM dd').format(task.nextDue!)}'
                    : 'No schedule',
                isDark,
              ),
            ],
          ),
          if (task.isOverdue || task.isDueSoon) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                task.isOverdue
                    ? '⚠️ Overdue by ${(-task.daysUntilDue!)} days'
                    : '📅 Due in ${task.daysUntilDue} days',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
          if (task.history.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              '📊 Service history: ${task.history.length} records (every ~${task.recurringDays} days)',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardAlt : Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'hvac':
        return Icons.ac_unit_rounded;
      case 'water':
        return Icons.water_drop_rounded;
      case 'electrical':
        return Icons.electrical_services_rounded;
      case 'plumbing':
        return Icons.plumbing_rounded;
      default:
        return Icons.build_rounded;
    }
  }

  void _showAISuggestions(BuildContext context, List<String> suggestions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(20),
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
            Text(
              '🤖 AI Maintenance Insights',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 16),
            ...suggestions.map((s) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(s, style: TextStyle(fontSize: 14, height: 1.5)),
                )),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showMaintenanceDialog(BuildContext context, {MaintenanceTask? task}) {
    final nameCtrl = TextEditingController(text: task?.name ?? '');
    String category = task?.category ?? 'HVAC';
    final daysCtrl = TextEditingController(text: task?.recurringDays.toString() ?? '90');

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
              Text(task == null ? 'Add Maintenance Task' : 'Edit Maintenance Task',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(hintText: 'Task name (e.g. AC Servicing)'),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: InputDecoration(hintText: 'Category'),
                items: ['HVAC', 'Water', 'Electrical', 'Plumbing', 'General']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => category = v!),
              ),
              SizedBox(height: 12),
              TextField(
                controller: daysCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: 'Recurring interval (days)'),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty) {
                      final newTask = MaintenanceTask(
                        id: task?.id ?? '',
                        name: nameCtrl.text,
                        category: category,
                        recurringDays: int.tryParse(daysCtrl.text) ?? 90,
                        nextDue: task?.nextDue ?? DateTime.now().add(
                            Duration(days: int.tryParse(daysCtrl.text) ?? 90)),
                        lastServiced: task?.lastServiced,
                        history: task?.history ?? [],
                        description: task?.description ?? '',
                      );
                      if (task == null) {
                        context.read<AppState>().addMaintenanceTask(newTask);
                      } else {
                        context.read<AppState>().updateMaintenanceTask(newTask);
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(task == null ? 'Add Task' : 'Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
