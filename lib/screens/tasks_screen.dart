import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<HouseholdTask> tasks = state.householdTasks;
    if (_filter == 'pending') tasks = tasks.where((t) => !t.isCompleted).toList();
    if (_filter == 'completed') tasks = tasks.where((t) => t.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Tasks')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _filterChip('All', 'all', isDark),
                SizedBox(width: 8),
                _filterChip('Pending', 'pending', isDark),
                SizedBox(width: 8),
                _filterChip('Completed', 'completed', isDark),
              ],
            ),
          ),

          Expanded(
            child: tasks.isEmpty
                ? EmptyState(
                    icon: Icons.task_alt_rounded,
                    title: 'No Tasks',
                    subtitle: 'Create tasks to manage your household',
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(20),
                    itemCount: tasks.length,
                    itemBuilder: (ctx, idx) =>
                        _buildTaskTile(context, tasks[idx], isDark, state),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, bool isDark) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryDark
              : isDark
                  ? AppTheme.darkCard
                  : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskTile(
      BuildContext context, HouseholdTask task, bool isDark, AppState state) {
    Color priorityColor = task.priority == 'high'
        ? AppTheme.accentOrange
        : task.priority == 'medium'
            ? AppTheme.accentYellow
            : AppTheme.accentTeal;

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => state.deleteHouseholdTask(task.id),
      background: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppTheme.accentOrange,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: task.isOverdue
              ? Border.all(color: AppTheme.accentOrange.withOpacity(0.4))
              : null,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => state.toggleHouseholdTask(task.id),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: task.isCompleted
                      ? AppTheme.accentTeal
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: task.isCompleted
                        ? AppTheme.accentTeal
                        : isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                    width: 2,
                  ),
                ),
                child: task.isCompleted
                    ? Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : null,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkText : AppTheme.lightText,
                      decoration:
                          task.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          task.priority.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: priorityColor,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        task.category,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                      if (task.dueDate != null) ...[
                        SizedBox(width: 8),
                        Text(
                          DateFormat('MMM dd').format(task.dueDate!),
                          style: TextStyle(
                            fontSize: 11,
                            color: task.isOverdue
                                ? AppTheme.accentOrange
                                : isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary,
                            fontWeight:
                                task.isOverdue ? FontWeight.w600 : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (task.assignedTo != null)
              CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.primaryDark.withOpacity(0.2),
                child: Text(
                  task.assignedTo![0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    String category = 'Cleaning';
    String priority = 'medium';
    DateTime? dueDate;
    String? assignedTo;
    final members = context.read<AppState>().familyMembers;

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
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text('Add Task',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(hintText: 'Task title'),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: category,
                      decoration: InputDecoration(hintText: 'Category'),
                      items: [
                        'Cleaning',
                        'Bills',
                        'Shopping',
                        'Maintenance',
                        'Organization',
                        'Other'
                      ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => category = v!),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: priority,
                      decoration: InputDecoration(hintText: 'Priority'),
                      items: ['high', 'medium', 'low']
                          .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p[0].toUpperCase() + p.substring(1))))
                          .toList(),
                      onChanged: (v) => setState(() => priority = v!),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                        );
                        if (date != null) setState(() => dueDate = date);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 16),
                            SizedBox(width: 8),
                            Text(dueDate != null
                                ? DateFormat('MMM dd').format(dueDate!)
                                : 'Due date'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: assignedTo,
                      decoration: InputDecoration(hintText: 'Assign to'),
                      items: [
                        DropdownMenuItem(value: null, child: Text('Unassigned')),
                        ...members.map((m) => m.name).toSet().map((name) =>
                            DropdownMenuItem(value: name, child: Text(name))),
                      ],
                      onChanged: (v) => setState(() => assignedTo = v),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.isNotEmpty) {
                      context.read<AppState>().addHouseholdTask(HouseholdTask(
                            id: '',
                            title: titleCtrl.text,
                            category: category,
                            priority: priority,
                            dueDate: dueDate,
                            assignedTo: assignedTo,
                          ));
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Add Task',
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
