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

  // ── Notification channel config ──
  static const _channelId = 'homehub_reminders';
  static const _channelName = 'HomeHub Reminders';
  static const _channelDesc = 'Bill dues, loan payments, and item alerts';

  // ── Notification ID ranges (to avoid collisions) ──
  static const _billBaseId = 1000;
  static const _debtBaseId = 2000;
  static const _maintBaseId = 3000;
  static const _instantBaseId = 5000;
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
  //  INSTANT NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════

  Future<void> showTaskAddedNotification(String title) async {
    await _showInstant(
      title: '📋 New Task Added',
      body: title,
      payload: 'task_added',
    );
  }

  Future<void> showGroceryAddedNotification(String name) async {
    await _showInstant(
      title: '🛒 New Grocery Item',
      body: '$name added to the list',
      payload: 'grocery_added',
    );
  }

  Future<void> _showInstant({
    required String title,
    required String body,
    String? payload,
  }) async {
    final id = _instantCounter++;
    if (_instantCounter > 9999) _instantCounter = _instantBaseId;

    await _plugin.show(
      id,
      title,
      body,
      _notificationDetails(),
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
        // Already the 1st — schedule for today at 9 AM if not yet passed
        nextFirst = DateTime(now.year, now.month, 1, 9, 0);
        if (nextFirst.isBefore(now)) {
          // Already passed today, schedule for next month
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
  //  RESCHEDULE ALL
  // ═══════════════════════════════════════════════════════════

  Future<void> rescheduleAll({
    required List<UtilityBill> bills,
    required List<Debt> debts,
    required List<MaintenanceTask> maintenanceTasks,
  }) async {
    await scheduleBillReminders(bills);
    await scheduleDebtReminders(debts);
    await scheduleMaintenanceReminders(maintenanceTasks);
  }

  Future<void> cancelAllScheduled() async {
    await _plugin.cancelAll();
  }

  // ═══════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
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
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification $id: $e');
    }
  }
}
