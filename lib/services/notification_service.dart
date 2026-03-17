import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';
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

    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
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

    // Listen for Firebase Messaging foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        String channel = 'general';
        if (message.data['type'] == 'chat_message') {
          channel = 'chat';
        } else if (message.data['type']?.contains('expense') == true ||
                   message.data['type']?.contains('bill') == true) {
          channel = 'finance';
        } else if (message.data['type']?.contains('task') == true) {
          channel = 'tasks';
        }

        showRemoteNotification(
          title: message.notification!.title ?? 'New Notification',
          body: message.notification!.body ?? '',
          channel: channel,
        );
      }
    });
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

    // FIX 3: DateTime.now().millisecond is 0–999 and causes ID collisions when
    // multiple notifications fire in the same second. Use millisecondsSinceEpoch
    // instead for a unique, monotonically increasing ID.
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
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

  /// Shows immediate overdue notifications for maintenance tasks
  Future<void> scheduleMaintenanceReminders(List<MaintenanceTask> tasks) async {
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      if (task.isCompleted) continue;

      if (task.isOverdue) {
        await _notifications.show(
          task.id.hashCode,
          '🛠️ Maintenance Overdue',
          '${task.name} is past its due date.',
          // FIX 4: AndroidNotificationDetails must match the registered channel's
          // importance. Using a bare channel ID with no importance set here causes
          // the notification to appear silently. Pass the channel name properly.
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _reminderChannelId,
              'Reminders',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
            ),
          ),
        );
      }
    }
  }

  /// Shows immediate overdue notifications for household tasks assigned to the current user
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
          // FIX 4 (same): Add full NotificationDetails with importance & iOS support.
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _taskChannelId,
              'Tasks',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
            ),
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
            android: AndroidNotificationDetails(
              _financeChannelId,
              'Finance & Bills',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
            ),
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
      if (debt.remainingAmount <= 0) continue;

      // FIX 5: This method was a no-op — it skipped every debt silently.
      // Now shows an immediate reminder for any active outstanding debt.
      await _notifications.show(
        debt.id.hashCode,
        '💳 Debt Reminder',
        'Outstanding balance of ₹${debt.remainingAmount.toStringAsFixed(0)} remaining.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _financeChannelId,
            'Finance & Bills',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
      );
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

    // FIX 6: When today IS Sunday, daysUntilSunday was 0, causing the
    // notification to be scheduled in the past (today, potentially minutes ago).
    // Change <= 0 to == 0 so that on Sunday itself we still wait 7 more days.
    int daysUntilSunday = DateTime.sunday - now.weekday;
    if (daysUntilSunday == 0) daysUntilSunday = 7;

    final sundaySixPM = DateTime(
      now.year,
      now.month,
      now.day + daysUntilSunday,
      18,
      0,
    );

    await _notifications.zonedSchedule(
      'weekly_summary'.hashCode,
      '📊 Weekly Home Insights',
      insights,
      tz.TZDateTime.from(sundaySixPM, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _summaryChannelId,
          'Weekly Summaries',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
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

  /// Re-syncs all scheduled notifications based on latest data
  // FIX 7: rescheduleAll was void and fire-and-forget — unawaited Futures from
  // the .then() block could throw silently. Changed to async/await for proper
  // error propagation and so callers can await it if needed.
  Future<void> rescheduleAll({
    required List<UtilityBill> bills,
    required List<Debt> debts,
    required List<MaintenanceTask> maintenanceTasks,
    required List<HouseholdTask> householdTasks,
    String? currentUserId,
  }) async {
    await cancelAllScheduled();
    await scheduleBillReminders(bills);
    await scheduleDebtReminders(debts);
    await scheduleMaintenanceReminders(maintenanceTasks);
    await scheduleTaskOverdueReminders(householdTasks, currentUserId);
  }
}
