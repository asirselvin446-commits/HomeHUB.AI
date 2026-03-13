import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/models.dart';

/// Singleton service for managing local push notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Notification channel configs ──
  static const _reminderChannelId = 'homehub_reminders';
  static const _reminderChannelName = 'Reminders';
  static const _reminderChannelDesc = 'Bill dues, loan payments, and maintenance alerts';

  static const _taskChannelId = 'homehub_tasks';
  static const _taskChannelName = 'Task Alerts';
  static const _taskChannelDesc = 'Overdue task reminders and assignments';

  static const _financeChannelId = 'homehub_finance';
  static const _financeChannelName = 'Finance Alerts';
  static const _financeChannelDesc = 'Savings milestones and expense alerts';

  static const _chatChannelId = 'homehub_chat';
  static const _chatChannelName = 'Chat Messages';
  static const _chatChannelDesc = 'Family chat message notifications';

  static const _summaryChannelId = 'homehub_summary';
  static const _summaryChannelName = 'Weekly Summary';
  static const _summaryChannelDesc = 'Weekly home health digest';

  // ── Notification ID ranges (to avoid collisions) ──
  static const _billBaseId = 1000;
  static const _debtBaseId = 2000;
  static const _maintBaseId = 3000;
  static const _taskBaseId = 4000;
  static const _instantBaseId = 5000;
  static const _savingsBaseId = 6000;
  static const _summaryId = 7000;
  int _instantCounter = _instantBaseId;

  // ═══════════════════════════════════════════════════════════
  //  INITIALIZATION
  // ═══════════════════════════════════════════════════════════

  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone database
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
    debugPrint('NotificationService initialized');
  }

  void _onNotificationTap(NotificationResponse response) {
    // Future: navigate to specific screen based on response.payload
    debugPrint('Notification tapped: ${response.payload}');
  }

  // ═══════════════════════════════════════════════════════════
  //  PERMISSION REQUEST (Android 13+)
  // ═══════════════════════════════════════════════════════════

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;

    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  // ═══════════════════════════════════════════════════════════
  //  INSTANT NOTIFICATIONS (for FCM foreground display)
  // ═══════════════════════════════════════════════════════════

  Future<void> showRemoteNotification({
    required String title,
    required String body,
    String? payload,
    String channel = 'chat',
  }) async {
    await _showInstant(
      title: title,
      body: body,
      payload: payload ?? 'fcm_message',
      channelId: channel == 'chat' ? _chatChannelId : _reminderChannelId,
      channelName: channel == 'chat' ? _chatChannelName : _reminderChannelName,
      channelDesc: channel == 'chat' ? _chatChannelDesc : _reminderChannelDesc,
    );
  }

  Future<void> _showInstant({
    required String title,
    required String body,
    String? payload,
    String channelId = _chatChannelId,
    String channelName = _chatChannelName,
    String channelDesc = _chatChannelDesc,
  }) async {
    final id = _instantCounter++;
    if (_instantCounter > 9999) _instantCounter = _instantBaseId;

    await _plugin.show(
      id,
      title,
      body,
      _notificationDetails(
        channelId: channelId,
        channelName: channelName,
        channelDesc: channelDesc,
      ),
      payload: payload,
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SCHEDULED: BILL REMINDERS
  // ═══════════════════════════════════════════════════════════

  Future<void> scheduleBillReminders(List<UtilityBill> bills) async {
    // Cancel existing bill notifications
    for (int i = _billBaseId; i < _billBaseId + 500; i++) {
      await _plugin.cancel(i);
    }

    int idOffset = 0;
    for (final bill in bills) {
      if (bill.isPaid) continue;

      final now = DateTime.now();
      final dueDate = bill.dueDate;

      // Schedule 1 day before due
      final dayBefore = dueDate.subtract(const Duration(days: 1));
      if (dayBefore.isAfter(now)) {
        await _scheduleAt(
          id: _billBaseId + idOffset,
          dateTime: dayBefore.copyWith(hour: 9, minute: 0),
          title: '💰 Bill Due Tomorrow',
          body: '${bill.type} bill of ₹${bill.amount.toStringAsFixed(0)} is due tomorrow',
          payload: 'bill_${bill.id}',
          channelId: _financeChannelId,
          channelName: _financeChannelName,
          channelDesc: _financeChannelDesc,
        );
        idOffset++;
      }

      // Schedule on due date if it's today or in the future
      if (dueDate.isAfter(now) ||
          (dueDate.year == now.year &&
              dueDate.month == now.month &&
              dueDate.day == now.day)) {
        await _scheduleAt(
          id: _billBaseId + idOffset,
          dateTime: dueDate.copyWith(hour: 9, minute: 0),
          title: '🚨 Bill Due Today!',
          body: '${bill.type} bill of ₹${bill.amount.toStringAsFixed(0)} is due today',
          payload: 'bill_${bill.id}',
          channelId: _financeChannelId,
          channelName: _financeChannelName,
          channelDesc: _financeChannelDesc,
        );
        idOffset++;
      }

      if (idOffset >= 498) break; // Safety cap
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  SCHEDULED: DEBT / LOAN REMINDERS
  // ═══════════════════════════════════════════════════════════

  Future<void> scheduleDebtReminders(List<Debt> debts) async {
    // Cancel existing debt notifications
    for (int i = _debtBaseId; i < _debtBaseId + 500; i++) {
      await _plugin.cancel(i);
    }

    int idOffset = 0;
    final now = DateTime.now();

    for (final debt in debts) {
      if (debt.monthlyPayment <= 0 || debt.remainingAmount <= 0) continue;

      // Schedule a reminder for the 1st of next month at 9 AM
      DateTime nextFirst;
      if (now.day == 1) {
        nextFirst = DateTime(now.year, now.month, 1, 9, 0);
        if (nextFirst.isBefore(now)) {
          nextFirst = (now.month == 12)
              ? DateTime(now.year + 1, 1, 1, 9, 0)
              : DateTime(now.year, now.month + 1, 1, 9, 0);
        }
      } else {
        nextFirst = (now.month == 12)
            ? DateTime(now.year + 1, 1, 1, 9, 0)
            : DateTime(now.year, now.month + 1, 1, 9, 0);
      }

      await _scheduleAt(
        id: _debtBaseId + idOffset,
        dateTime: nextFirst,
        title: '🏦 Loan Payment Reminder',
        body: '${debt.name}: ₹${debt.monthlyPayment.toStringAsFixed(0)} payment due '
            '(₹${debt.remainingAmount.toStringAsFixed(0)} remaining)',
        payload: 'debt_${debt.id}',
        channelId: _financeChannelId,
        channelName: _financeChannelName,
        channelDesc: _financeChannelDesc,
      );
      idOffset++;
      if (idOffset >= 498) break;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  SCHEDULED: MAINTENANCE REMINDERS
  // ═══════════════════════════════════════════════════════════

  Future<void> scheduleMaintenanceReminders(
      List<MaintenanceTask> tasks) async {
    // Cancel existing maintenance notifications
    for (int i = _maintBaseId; i < _maintBaseId + 500; i++) {
      await _plugin.cancel(i);
    }

    int idOffset = 0;
    final now = DateTime.now();

    for (final task in tasks) {
      if (task.isCompleted || task.nextDue == null) continue;

      final dayBefore = task.nextDue!.subtract(const Duration(days: 1));
      if (dayBefore.isAfter(now)) {
        await _scheduleAt(
          id: _maintBaseId + idOffset,
          dateTime: dayBefore.copyWith(hour: 9, minute: 0),
          title: '🔧 Maintenance Due Tomorrow',
          body: '${task.name} is due for servicing tomorrow',
          payload: 'maintenance_${task.id}',
        );
        idOffset++;
      }

      if (idOffset >= 498) break;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  SCHEDULED: TASK OVERDUE REMINDERS
  // ═══════════════════════════════════════════════════════════

  Future<void> scheduleTaskOverdueReminders(
      List<HouseholdTask> tasks, String? currentUserId) async {
    // Cancel existing task notifications
    for (int i = _taskBaseId; i < _taskBaseId + 500; i++) {
      await _plugin.cancel(i);
    }

    int idOffset = 0;
    final now = DateTime.now();

    for (final task in tasks) {
      if (task.isCompleted || task.dueDate == null) continue;

      // Only schedule for tasks assigned to the current user (or unassigned)
      if (task.assignedTo != null &&
          currentUserId != null &&
          task.assignedTo != currentUserId) continue;

      // If the task is overdue, schedule a reminder for tomorrow 9 AM
      if (task.isOverdue) {
        final tomorrow = DateTime(now.year, now.month, now.day + 1, 9, 0);
        await _scheduleAt(
          id: _taskBaseId + idOffset,
          dateTime: tomorrow,
          title: '⚠️ Overdue Task',
          body: '${task.title} was due ${_formatDaysAgo(task.dueDate!)}',
          payload: 'task_${task.id}',
          channelId: _taskChannelId,
          channelName: _taskChannelName,
          channelDesc: _taskChannelDesc,
        );
        idOffset++;
      }
      // If task is due today, schedule for 9 AM today (if not passed)
      else if (task.dueDate!.year == now.year &&
          task.dueDate!.month == now.month &&
          task.dueDate!.day == now.day) {
        final todayReminder = DateTime(now.year, now.month, now.day, 9, 0);
        if (todayReminder.isAfter(now)) {
          await _scheduleAt(
            id: _taskBaseId + idOffset,
            dateTime: todayReminder,
            title: '📋 Task Due Today',
            body: task.title,
            payload: 'task_${task.id}',
            channelId: _taskChannelId,
            channelName: _taskChannelName,
            channelDesc: _taskChannelDesc,
          );
          idOffset++;
        }
      }
      // If task is due tomorrow, schedule for 9 AM tomorrow
      else {
        final diff = task.dueDate!.difference(now).inDays;
        if (diff == 1) {
          final tomorrowReminder =
              DateTime(now.year, now.month, now.day + 1, 9, 0);
          await _scheduleAt(
            id: _taskBaseId + idOffset,
            dateTime: tomorrowReminder,
            title: '📋 Task Due Tomorrow',
            body: task.title,
            payload: 'task_${task.id}',
            channelId: _taskChannelId,
            channelName: _taskChannelName,
            channelDesc: _taskChannelDesc,
          );
          idOffset++;
        }
      }

      if (idOffset >= 498) break;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  SAVINGS MILESTONE CHECK (instant, not scheduled)
  // ═══════════════════════════════════════════════════════════

  /// Check savings goals and fire milestone notifications.
  /// Pass the previous goals list to detect changes.
  Future<void> checkSavingsMilestones(
      List<SavingsGoal> current, List<SavingsGoal> previous) async {
    const milestones = [0.25, 0.50, 0.75, 1.0];
    const milestoneEmojis = ['🌱', '⭐', '🔥', '🎉'];
    const milestoneLabels = ['25%', '50%', '75%', '100%'];

    for (final goal in current) {
      final prevGoal = previous.where((p) => p.id == goal.id).firstOrNull;
      if (prevGoal == null) continue;

      final prevPercent = prevGoal.progressPercent;
      final currPercent = goal.progressPercent;

      for (int i = 0; i < milestones.length; i++) {
        if (prevPercent < milestones[i] && currPercent >= milestones[i]) {
          await _showInstant(
            title: '${milestoneEmojis[i]} ${goal.name} — ${milestoneLabels[i]} Complete!',
            body: currPercent >= 1.0
                ? 'Congratulations! You reached your goal of ₹${goal.targetAmount.toStringAsFixed(0)}!'
                : '₹${goal.currentAmount.toStringAsFixed(0)} of ₹${goal.targetAmount.toStringAsFixed(0)} saved',
            payload: 'savings_${goal.id}',
            channelId: _financeChannelId,
            channelName: _financeChannelName,
            channelDesc: _financeChannelDesc,
          );
          break; // Only fire the highest milestone crossed
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  SCHEDULED: WEEKLY SUMMARY (Sunday 10 AM)
  // ═══════════════════════════════════════════════════════════

  Future<void> scheduleWeeklySummary({
    required int tasksCompleted,
    required double totalSpent,
    required int billsPaid,
    required int maintenanceDone,
  }) async {
    await _plugin.cancel(_summaryId);

    // Find next Sunday
    final now = DateTime.now();
    int daysUntilSunday = DateTime.sunday - now.weekday;
    if (daysUntilSunday <= 0) daysUntilSunday += 7;
    final nextSunday = DateTime(
      now.year,
      now.month,
      now.day + daysUntilSunday,
      10,
      0,
    );

    final summaryParts = <String>[];
    if (tasksCompleted > 0) summaryParts.add('$tasksCompleted tasks done');
    if (totalSpent > 0) {
      summaryParts.add('₹${totalSpent.toStringAsFixed(0)} spent');
    }
    if (billsPaid > 0) summaryParts.add('$billsPaid bills paid');
    if (maintenanceDone > 0) {
      summaryParts.add('$maintenanceDone maintenance completed');
    }

    final body = summaryParts.isEmpty
        ? 'Check your home dashboard for updates'
        : 'This week: ${summaryParts.join(', ')}';

    await _scheduleAt(
      id: _summaryId,
      dateTime: nextSunday,
      title: '📊 Weekly Home Summary',
      body: body,
      payload: 'weekly_summary',
      channelId: _summaryChannelId,
      channelName: _summaryChannelName,
      channelDesc: _summaryChannelDesc,
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  RESCHEDULE ALL
  // ═══════════════════════════════════════════════════════════

  Future<void> rescheduleAll({
    required List<UtilityBill> bills,
    required List<Debt> debts,
    required List<MaintenanceTask> maintenanceTasks,
    required List<HouseholdTask> householdTasks,
    String? currentUserId,
  }) async {
    await scheduleBillReminders(bills);
    await scheduleDebtReminders(debts);
    await scheduleMaintenanceReminders(maintenanceTasks);
    await scheduleTaskOverdueReminders(householdTasks, currentUserId);
  }

  Future<void> cancelAllScheduled() async {
    await _plugin.cancelAll();
  }

  // ═══════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════

  NotificationDetails _notificationDetails({
    String channelId = _reminderChannelId,
    String channelName = _reminderChannelName,
    String channelDesc = _reminderChannelDesc,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        showWhen: true,
      ),
    );
  }

  Future<void> _scheduleAt({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
    String? payload,
    String channelId = _reminderChannelId,
    String channelName = _reminderChannelName,
    String channelDesc = _reminderChannelDesc,
  }) async {
    final tzDateTime = tz.TZDateTime.from(dateTime, tz.local);

    // Don't schedule notifications in the past
    if (tzDateTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        _notificationDetails(
          channelId: channelId,
          channelName: channelName,
          channelDesc: channelDesc,
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification $id: $e');
    }
  }

  String _formatDaysAgo(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    return '$diff days ago';
  }
}
