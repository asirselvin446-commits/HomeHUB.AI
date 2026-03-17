import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/common_widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    final isDark = AppColors.isDark(context);

    List<HouseholdTask> tasks = state.householdTasks;
    if (_filter == 'pending') tasks = tasks.where((t) => !t.isCompleted).toList();
    if (_filter == 'completed') tasks = tasks.where((t) => t.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                _filterChip('All', 'all', isDark),
                const SizedBox(width: 8),
                _filterChip('Pending', 'pending', isDark),
                const SizedBox(width: 8),
                _filterChip('Completed', 'completed', isDark),
              ],
            ),
          ),

          Expanded(
            child: tasks.isEmpty
                ? const EmptyState(
                    icon: Icons.task_alt_rounded,
                    title: 'No Tasks',
                    subtitle: 'Create tasks to manage your household',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    itemCount: tasks.length,
                    itemBuilder: (ctx, idx) =>
                        _buildTaskTile(context, tasks[idx], isDark, state)
                            .animate(delay: (idx * 50).ms)
                            .fade(duration: 300.ms)
                            .slideX(begin: 0.05, duration: 300.ms),
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : isDark
                  ? AppColors.darkCard
                  : AppColors.lightSurfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: selected
              ? null
              : Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskTile(
      BuildContext context, HouseholdTask task, bool isDark, AppState state) {
    Color priorityColor = task.priority == 'high'
        ? AppColors.error
        : task.priority == 'medium'
            ? AppColors.accent
            : AppColors.primary;

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => state.deleteHouseholdTask(task.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: task.isOverdue
                ? AppColors.error.withValues(alpha: 0.3)
                : isDark
                    ? AppColors.darkBorder
                    : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Priority bar
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Checkbox
              GestureDetector(
                onTap: () => state.toggleHouseholdTask(task.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: task.isCompleted
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: task.isCompleted
                          ? AppColors.primary
                          : AppColors.textSecondary(context),
                      width: 2,
                    ),
                  ),
                  child: task.isCompleted
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.1),
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
                        const SizedBox(width: 8),
                        Text(
                          task.category,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        if (task.dueDate != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM dd').format(task.dueDate!),
                            style: TextStyle(
                              fontSize: 11,
                              color: task.isOverdue
                                  ? AppColors.error
                                  : AppColors.textSecondary(context),
                              fontWeight: task.isOverdue ? FontWeight.w600 : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (task.assignedTo != null) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    task.assignedTo![0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18),
                color: AppColors.textSecondary(context),
                onPressed: () => _showTaskDialog(context, task: task),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskDialog(BuildContext context, {HouseholdTask? task}) {
    final titleCtrl = TextEditingController(text: task?.title ?? '');
    String category = task?.category ?? 'Cleaning';
    String priority = task?.priority ?? 'medium';
    DateTime? dueDate = task?.dueDate;
    String? assignedTo = task?.assignedTo;
    final members = context.read<AppState>().familyMembers;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
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
                    color: AppColors.textSecondary(context).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                task == null ? 'Add Task' : 'Edit Task',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(hintText: 'Task title'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(hintText: 'Category'),
                      items: [
                        'Cleaning', 'Bills', 'Shopping',
                        'Maintenance', 'Organization', 'Other'
                      ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => category = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: const InputDecoration(hintText: 'Priority'),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) setState(() => dueDate = date);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(
                            color: AppColors.isDark(context)
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 16,
                                color: AppColors.textSecondary(context)),
                            const SizedBox(width: 8),
                            Text(
                              dueDate != null
                                  ? DateFormat('MMM dd').format(dueDate!)
                                  : 'Due date',
                              style: TextStyle(
                                color: dueDate != null
                                    ? AppColors.text(context)
                                    : AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: assignedTo,
                      decoration: const InputDecoration(hintText: 'Assign to'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Unassigned')),
                        ...<String>{
                          if (assignedTo != null) assignedTo!,
                          ...members.map((m) => m.name)
                        }.map((name) =>
                            DropdownMenuItem(value: name, child: Text(name))),
                      ],
                      onChanged: (v) => setState(() => assignedTo = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.isNotEmpty) {
                      final newTask = HouseholdTask(
                        id: task?.id ?? '',
                        title: titleCtrl.text,
                        category: category,
                        priority: priority,
                        dueDate: dueDate,
                        assignedTo: assignedTo,
                        isCompleted: task?.isCompleted ?? false,
                        createdAt: task?.createdAt,
                      );
                      if (task == null) {
                        context.read<AppState>().addHouseholdTask(newTask);
                      } else {
                        context.read<AppState>().updateHouseholdTask(newTask);
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                    elevation: 0,
                  ),
                  child: Text(
                    task == null ? 'Add Task' : 'Save Changes',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
