import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/models.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();

  factory NotificationService() => instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // Channel IDs
  static const String _reminderChannelId = 'reminders';
  static const String _taskChannelId = 'tasks';
  static const String _financeChannelId = 'finance';
  static const String _chatChannelId = 'chat';
  static const String _summaryChannelId = 'summary';

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // Create Notification Channels for Android
    if (Platform.isAndroid) {
      await _createChannels();
    }
  }

  Future<void> _createChannels() async {
    final List<AndroidNotificationChannel> channels = [
      const AndroidNotificationChannel(
        _reminderChannelId,
        'Reminders',
        description: 'General household reminders',
        importance: Importance.high,
      ),
      const AndroidNotificationChannel(
        _taskChannelId,
        'Tasks',
        description: 'Assigned household tasks',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      ),
      const AndroidNotificationChannel(
        _financeChannelId,
        'Finance & Bills',
        description: 'Expenses and bill due alerts',
        importance: Importance.high,
      ),
      const AndroidNotificationChannel(
        _chatChannelId,
        'Family Chat',
        description: 'Messages from family members',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      ),
      const AndroidNotificationChannel(
        _summaryChannelId,
        'Weekly Summaries',
        description: 'AI-generated weekly home insights',
        importance: Importance.defaultImportance,
      ),
    ];

    for (var channel in channels) {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  Future<void> requestPermission() async {
    if (Platform.isIOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }
  }

  // ============ REMOTE / INSTANT NOTIFICATIONS ============

  /// Shows a notification immediately (can be used for foreground messages or local events)
  Future<void> showRemoteNotification({
    required String title,
    required String body,
    String channel = 'general',
  }) async {
    String channelId = _reminderChannelId;
    if (channel == 'chat') channelId = _chatChannelId;
    if (channel == 'finance') channelId = _financeChannelId;
    if (channel == 'tasks') channelId = _taskChannelId;

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId.toUpperCase(),
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // ============ SCHEDULED REMINDERS ============

  /// Schedules recurring maintenance reminders based on task frequency
  Future<void> scheduleMaintenanceReminders(List<MaintenanceTask> tasks) async {
    // Only schedule for urgent/pending items
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      if (task.isCompleted) continue;

      // Filter: only notify for tasks that haven't been completed in time
      if (task.isOverdue) {
        await _notifications.show(
          task.id.hashCode,
          '🛠️ Maintenance Overdue',
          '${task.name} is past its due date.',
          const NotificationDetails(
            android: AndroidNotificationDetails(_reminderChannelId, 'Reminders'),
          ),
        );
      }
    }
  }

  /// Schedules alerts for tasks assigned to the current user
  Future<void> scheduleTaskOverdueReminders(
    List<HouseholdTask> tasks,
    String? currentUserId,
  ) async {
    if (currentUserId == null) return;
    
    for (final task in tasks) {
      if (task.isCompleted || task.assignedTo != currentUserId) continue;
      
      final now = DateTime.now();
      if (task.dueDate != null && task.dueDate!.isBefore(now)) {
        await _notifications.show(
          task.id.hashCode,
          '📋 Task Overdue',
          'Your task "${task.title}" is overdue!',
          const NotificationDetails(
            android: AndroidNotificationDetails(_taskChannelId, 'Tasks'),
          ),
        );
      }
    }
  }

  /// Schedules bill payment reminders 1 day before due
  Future<void> scheduleBillReminders(List<UtilityBill> bills) async {
    for (final bill in bills) {
      if (bill.isPaid) continue;
      
      final now = DateTime.now();
      final oneDayBefore = bill.dueDate.subtract(const Duration(days: 1));
      
      if (now.isBefore(oneDayBefore)) {
        await _notifications.zonedSchedule(
          bill.id.hashCode,
          '💸 Bill Reminder',
          '${bill.type} is due tomorrow (₹${bill.amount.toStringAsFixed(0)})',
          tz.TZDateTime.from(oneDayBefore, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(_financeChannelId, 'Finance'),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  /// Schedules debt repayment reminders
  Future<void> scheduleDebtReminders(List<Debt> debts) async {
    for (final debt in debts) {
      // Debt model lacks a dueDate, so we skip scheduling specific reminders for now
      // or implement based on monthlyPayment frequency if needed.
      if (debt.remainingAmount <= 0) continue;
    }
  }

  /// Celebrates savings milestones
  Future<void> checkSavingsMilestones(
    List<SavingsGoal> currentGoals,
    List<SavingsGoal> previousGoals,
  ) async {
    for (final goal in currentGoals) {
      final oldGoal = previousGoals.where((g) => g.id == goal.id).firstOrNull;
      if (oldGoal == null) continue;

      if (goal.progressPercent >= 1.0 && oldGoal.progressPercent < 1.0) {
        await showRemoteNotification(
          title: '🎉 Goal Achieved!',
          body: 'Congratulations! You hit your goal for ${goal.name}!',
          channel: 'finance',
        );
      } else if (goal.progressPercent >= 0.5 && oldGoal.progressPercent < 0.5) {
        await showRemoteNotification(
          title: '⭐️ Halfway There!',
          body: 'You are 50% through your savings goal for ${goal.name}',
          channel: 'finance',
        );
      }
    }
  }

  /// Schedules weekly AI summary insights on Sunday evening
  Future<void> scheduleWeeklySummary(String insights) async {
    final now = DateTime.now();
    
    // Find next Sunday 6 PM
    int daysUntilSunday = DateTime.sunday - now.weekday;
    if (daysUntilSunday <= 0) daysUntilSunday += 7;
    
    final sundaySixPM = DateTime(
      now.year,
      now.month,
      now.day + daysUntilSunday,
      18, 0,
    );

    await _notifications.zonedSchedule(
      'weekly_summary'.hashCode,
      '📊 Weekly Home Insights',
      insights,
      tz.TZDateTime.from(sundaySixPM, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(_summaryChannelId, 'Summaries'),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancelAllScheduled() async {
    await _notifications.cancelAll();
  }

  /// Re-syncs all scheduled based on latest data
  void rescheduleAll({
    required List<UtilityBill> bills,
    required List<Debt> debts,
    required List<MaintenanceTask> maintenanceTasks,
    required List<HouseholdTask> householdTasks,
    String? currentUserId,
  }) {
    cancelAllScheduled().then((_) {
      scheduleBillReminders(bills);
      scheduleDebtReminders(debts);
      scheduleMaintenanceReminders(maintenanceTasks);
      scheduleTaskOverdueReminders(householdTasks, currentUserId);
    });
  }
}
