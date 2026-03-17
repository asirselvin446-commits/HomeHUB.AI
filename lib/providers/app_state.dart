import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class AppState extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();
  final StorageService _localStorage = StorageService();

  // Auth state
  User? _firebaseUser;
  Map<String, dynamic>? _userProfile;
  String? _householdId;
  bool _isInitialized = false;
  bool _isLoadingProfile = true;
  bool _isDarkMode = true;
  bool _notificationsEnabled = true;
  double _monthlyIncome = 0;
  List<AppNotification> _appNotifications = [];

  // Notification category preferences
  bool _chatNotificationsEnabled = true;
  bool _taskNotificationsEnabled = true;
  bool _billNotificationsEnabled = true;
  bool _expenseNotificationsEnabled = true;
  bool _weeklySummaryEnabled = true;

  // Data lists
  List<MaintenanceTask> _maintenanceTasks = [];
  List<HouseholdTask> _householdTasks = [];
  List<GroceryItem> _groceryItems = [];
  List<Expense> _expenses = [];
  List<Debt> _debts = [];
  List<SavingsGoal> _savingsGoals = [];
  List<UtilityBill> _utilityBills = [];
  List<FamilyMember> _familyMembers = [];
  List<EmergencyContact> _emergencyContacts = [];
  List<ChatMessage> _chatMessages = [];
  List<FamilyChatMessage> _familyChatMessages = [];

  // Stream subscriptions
  final List<StreamSubscription> _subscriptions = [];

  // ============ GETTERS ============
  User? get firebaseUser => _firebaseUser;
  bool get isLoggedIn => _firebaseUser != null;
  bool get hasHousehold => _householdId != null;
  bool get isInitialized => _isInitialized;
  bool get isLoadingProfile => _isLoadingProfile;
  bool get isDarkMode => _isDarkMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get chatNotificationsEnabled => _chatNotificationsEnabled;
  bool get taskNotificationsEnabled => _taskNotificationsEnabled;
  bool get billNotificationsEnabled => _billNotificationsEnabled;
  bool get expenseNotificationsEnabled => _expenseNotificationsEnabled;
  bool get weeklySummaryEnabled => _weeklySummaryEnabled;
  List<AppNotification> get appNotifications => _appNotifications;
  int get unreadNotificationsCount => _appNotifications.where((n) => !n.isRead).length;

  String? get householdId => _householdId;
  double get monthlyIncome => _monthlyIncome;
  String? get nickname => _userProfile?['nickname'];
  String? get familyRole => _userProfile?['role'];
  String? get currentUserId => _firebaseUser?.uid;

  // ============ PERMISSION HELPERS ============
  bool get isAdmin => _userProfile?['isAdmin'] == true;
  bool get canViewFinance {
    final role = familyRole;
    return isAdmin || role == 'Father' || role == 'Mother';
  }
  bool get canEditFinance => canViewFinance;
  bool get canRemoveMembers => isAdmin;
  bool get isProfileComplete =>
      _userProfile != null &&
      _userProfile!['nickname'] != null &&
      _userProfile!['nickname'].toString().isNotEmpty &&
      _userProfile!['role'] != null &&
      _userProfile!['role'] != 'Member';

  String get currentUser =>
      _firebaseUser?.displayName ?? _userProfile?['name'] ?? 'User';

  List<MaintenanceTask> get maintenanceTasks => _maintenanceTasks;
  List<HouseholdTask> get householdTasks => _householdTasks;
  List<GroceryItem> get groceryItems => _groceryItems;
  List<Expense> get expenses => _expenses;
  List<Debt> get debts => _debts;
  List<SavingsGoal> get savingsGoals => _savingsGoals;
  List<UtilityBill> get utilityBills => _utilityBills;
  List<FamilyMember> get familyMembers => _familyMembers;
  List<EmergencyContact> get emergencyContacts => _emergencyContacts;
  List<ChatMessage> get chatMessages => _chatMessages;
  List<FamilyChatMessage> get familyChatMessages => _familyChatMessages;

  // Computed getters
  List<MaintenanceTask> get overdueMaintenanceTasks =>
      _maintenanceTasks.where((t) => t.isOverdue).toList();
  List<HouseholdTask> get pendingTasks =>
      _householdTasks.where((t) => !t.isCompleted).toList();
  List<GroceryItem> get unpurchasedGroceries =>
      _groceryItems.where((g) => !g.isPurchased).toList();
  List<UtilityBill> get unpaidBills =>
      _utilityBills.where((b) => !b.isPaid).toList();

  double get thisMonthExpenseTotal {
    final now = DateTime.now();
    return _expenses
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get totalDebtRemaining =>
      _debts.fold(0.0, (sum, d) => sum + d.remainingAmount);

  Map<String, double> get homeHealthScores => AIService.getHomeHealthScores(
        maintenanceTasks: _maintenanceTasks,
        householdTasks: _householdTasks,
        bills: _utilityBills,
      );

  Map<String, dynamic> get financialAnalysis => AIService.analyzeFinances(
        expenses: _expenses,
        debts: _debts,
        goals: _savingsGoals,
        monthlyIncome: _monthlyIncome,
      );

  List<String> get maintenanceSuggestions =>
      AIService.getMaintenanceSuggestions(_maintenanceTasks);

  // ============ INITIALIZATION ============

  Future<void> init() async {
    await _localStorage.init();
    _isDarkMode = _localStorage.getIsDarkMode();
    _notificationsEnabled = _localStorage.getNotificationsEnabled();
    _chatNotificationsEnabled = _localStorage.getNotificationPref('chat');
    _taskNotificationsEnabled = _localStorage.getNotificationPref('task');
    _billNotificationsEnabled = _localStorage.getNotificationPref('bill');
    _expenseNotificationsEnabled = _localStorage.getNotificationPref('expense');
    _weeklySummaryEnabled = _localStorage.getNotificationPref('weekly_summary');
    _appNotifications = _localStorage.getNotifications();

    // Listen to auth state changes
    _firebase.authStateChanges.listen((user) {
      _firebaseUser = user;
      if (user != null) {
        _isLoadingProfile = true;
        notifyListeners();
        _loadUserProfile();
      } else {
        _clearData();
        _isLoadingProfile = false;
        notifyListeners();
      }
    });

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadUserProfile() async {
    if (_firebaseUser == null) {
      _isLoadingProfile = false;
      notifyListeners();
      return;
    }

    _userProfile = await _firebase.getUserProfile(_firebaseUser!.uid);
    if (_userProfile != null && _userProfile!['householdId'] != null) {
      _householdId = _userProfile!['householdId'];
      await _loadHouseholdData();
      _subscribeToStreams();
    }



    _isLoadingProfile = false;
    notifyListeners();
  }



  Future<void> _loadHouseholdData() async {
    if (_householdId == null) return;

    final household = await _firebase.getHousehold(_householdId!);
    if (household != null) {
      _monthlyIncome = (household['monthlyIncome'] ?? 0).toDouble();

      // Auto-set isAdmin for the household owner if not already set
      final ownerId = household['ownerId'] as String?;
      if (ownerId != null &&
          _firebaseUser != null &&
          ownerId == _firebaseUser!.uid &&
          _userProfile?['isAdmin'] != true) {
        await _firebase.saveUserProfile(
          uid: _firebaseUser!.uid,
          name: _firebaseUser!.displayName ?? 'User',
          email: _firebaseUser!.email ?? '',
          householdId: _householdId,
          role: _userProfile?['role'] ?? 'Member',
          avatar: _userProfile?['avatar'] ?? '👤',
          isAdmin: true,
        );
        // Reload profile to pick up the new isAdmin flag
        _userProfile = await _firebase.getUserProfile(_firebaseUser!.uid);
      }
    }

    // Load all data
    _familyMembers = await _firebase.getFamilyMembers(_householdId!);
    notifyListeners();
  }

  void _subscribeToStreams() {
    // Cancel old subscriptions
    _cancelSubscriptions();

    if (_householdId == null) return;

    _subscriptions.add(
      _firebase.streamMaintenanceTasks(_householdId!).listen((data) {
        _maintenanceTasks = data;
        if (_notificationsEnabled) {
          NotificationService.instance.scheduleMaintenanceReminders(data);
        }
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _firebase.streamHouseholdTasks(_householdId!).listen((data) {
        // Local alternative: detect tasks newly assigned to current user
        if (_notificationsEnabled && _taskNotificationsEnabled && _householdTasks.isNotEmpty) {
          for (final task in data) {
            if (task.assignedTo == currentUserId) {
              final oldTask = _householdTasks.where((t) => t.id == task.id).firstOrNull;
              // Fire only if assignment is new (wasn't assigned to us before)
              if (oldTask != null && oldTask.assignedTo != currentUserId) {
                NotificationService.instance.showRemoteNotification(
                  title: '📋 Task Assigned to You',
                  body: task.title,
                  channel: 'general',
                );
                _addNotificationToHistory(
                  '📋 Task Assigned to You',
                  task.title,
                  type: 'task',
                  actionRoute: 'tasks',
                );
              }
            }
          }
          NotificationService.instance.scheduleTaskOverdueReminders(
            data, currentUserId,
          );
        }
        _householdTasks = data;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _firebase.streamGroceryItems(_householdId!).listen((data) {
        // Local alternative: detect batch grocery additions by other members
        if (_notificationsEnabled && _groceryItems.isNotEmpty) {
          final newItems = data.where(
            (g) => !_groceryItems.any((old) => old.id == g.id),
          ).toList();
          // Only notify if 3+ new items added by someone else
          if (newItems.length >= 3) {
            final addedByOthers = newItems.where(
              (g) => g.addedBy != null && g.addedBy != currentUser,
            ).toList();
            if (addedByOthers.isNotEmpty) {
              final who = addedByOthers.first.addedBy ?? 'Someone';
              NotificationService.instance.showRemoteNotification(
                title: '🛒 Grocery List Updated',
                body: '$who added ${addedByOthers.length} items',
                channel: 'general',
              );
              _addNotificationToHistory(
                '🛒 Grocery List Updated',
                '$who added ${addedByOthers.length} items to the list',
                type: 'grocery',
                actionRoute: 'grocery',
              );
            }
          }
        }
        _groceryItems = data;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _firebase.streamExpenses(_householdId!).listen((data) {
        // Local alternative: alert for significant expenses by other members
        if (_notificationsEnabled && _expenseNotificationsEnabled && _expenses.isNotEmpty) {
          final newExpenses = data.where(
            (e) => !_expenses.any((old) => old.id == e.id),
          ).toList();
          for (final expense in newExpenses) {
            // Only notify for expenses ≥ ₹500 by someone else
            if (expense.amount >= 500 &&
                expense.paidBy != null &&
                expense.paidBy != currentUser) {
              NotificationService.instance.showRemoteNotification(
                title: '💸 ₹${expense.amount.toStringAsFixed(0)} Expense Logged',
                body: '${expense.title} (${expense.category}) by ${expense.paidBy}',
                channel: 'general',
              );
              _addNotificationToHistory(
                '💸 ₹${expense.amount.toStringAsFixed(0)} Expense Logged',
                '${expense.title} (${expense.category}) by ${expense.paidBy}',
                type: 'expense',
                actionRoute: 'finance',
              );
            }
          }
        }
        _expenses = data;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _firebase.streamDebts(_householdId!).listen((data) {
        _debts = data;
        if (_notificationsEnabled) {
          NotificationService.instance.scheduleDebtReminders(data);
        }
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _firebase.streamSavingsGoals(_householdId!).listen((data) {
        final previous = _savingsGoals;
        if (_notificationsEnabled) {
          NotificationService.instance.checkSavingsMilestones(data, previous).then((_) {
            _savingsGoals = data;
            notifyListeners();
          });
        } else {
          _savingsGoals = data;
          notifyListeners();
        }
      }),
    );

    _subscriptions.add(
      _firebase.streamUtilityBills(_householdId!).listen((data) {
        _utilityBills = data;
        if (_notificationsEnabled) {
          NotificationService.instance.scheduleBillReminders(data);
        }
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _firebase.streamEmergencyContacts(_householdId!).listen((data) {
        _emergencyContacts = data;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _firebase.streamChatMessages(_householdId!).listen((data) {
        _chatMessages = data;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _firebase.streamFamilyChatMessages(_householdId!).listen((data) {
        _familyChatMessages = data;
        notifyListeners();
      }),
    );

    // Run AI smart scan after a short delay to let data streams populate
    Future.delayed(const Duration(seconds: 3), () {
      runSmartNotificationScan();
    });
  }

  void _cancelSubscriptions() {
    NotificationService.instance.cancelAllScheduled();
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void _clearData() {
    _userProfile = null;
    _householdId = null;
    _maintenanceTasks = [];
    _householdTasks = [];
    _groceryItems = [];
    _expenses = [];
    _debts = [];
    _savingsGoals = [];
    _utilityBills = [];
    _familyMembers = [];
    _emergencyContacts = [];
    _chatMessages = [];
    _familyChatMessages = [];
    _appNotifications = [];
    _cancelSubscriptions();
  }

  // ============ NOTIFICATIONS ============
  
  void _addNotificationToHistory(
    String title,
    String body, {
    String type = 'system',
    String? actionRoute,
  }) {
    if (!_notificationsEnabled) return;
    
    final notification = AppNotification(
      id: const Uuid().v4(),
      title: title,
      body: body,
      timestamp: DateTime.now(),
      isRead: false,
      type: type,
      actionRoute: actionRoute,
    );
    _appNotifications.insert(0, notification);
    // Keep only last 100 notifications to avoid unbounded growth
    if (_appNotifications.length > 100) {
      _appNotifications = _appNotifications.sublist(0, 100);
    }
    _localStorage.setNotifications(_appNotifications);
    // Use Future.microtask to avoid calling notifyListeners() during build/state update if not safe
    Future.microtask(() => notifyListeners());
  }

  /// Public method to add notification from external sources (e.g., FCM handler)
  void addNotificationFromExternal({
    required String title,
    required String body,
    String type = 'chat',
    String? actionRoute,
  }) {
    _addNotificationToHistory(
      title,
      body,
      type: type,
      actionRoute: actionRoute,
    );
  }

  void markNotificationAsRead(String id) {
    final index = _appNotifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _appNotifications[index].isRead = true;
      _localStorage.setNotifications(_appNotifications);
      notifyListeners();
    }
  }
  
  void markAllNotificationsAsRead() {
    for (var n in _appNotifications) {
      n.isRead = true;
    }
    _localStorage.setNotifications(_appNotifications);
    notifyListeners();
  }
  
  void clearAllNotifications() {
    _appNotifications.clear();
    _localStorage.setNotifications(_appNotifications);
    notifyListeners();
  }

  void toggleNotificationsEnabled(bool value) {
    _notificationsEnabled = value;
    _localStorage.setNotificationsEnabled(value);
    
    // Manage scheduled notifications based on preference
    if (_notificationsEnabled) {
      NotificationService.instance.rescheduleAll(
        bills: _utilityBills,
        debts: _debts,
        maintenanceTasks: _maintenanceTasks,
        householdTasks: _householdTasks,
        currentUserId: currentUserId,
      );
    } else {
      NotificationService.instance.cancelAllScheduled();
    }
    
    notifyListeners();
  }

  // ============ AI SMART NOTIFICATION SCAN ============

  /// Runs the AI smart notification scan.
  /// Throttled to max once per 6 hours to avoid spamming.
  Future<void> runSmartNotificationScan() async {
    if (!_notificationsEnabled) return;
    if (_householdId == null) return;

    // Check throttle: only run once per 6 hours
    final lastScan = _localStorage.getLastSmartScanDate();
    if (lastScan != null) {
      final hoursSince = DateTime.now().difference(lastScan).inHours;
      if (hoursSince < 6) {
        debugPrint('Smart scan skipped: last ran ${hoursSince}h ago');
        return;
      }
    }

    debugPrint('Running AI smart notification scan...');

    final alerts = AIService.generateSmartAlerts(
      householdTasks: _householdTasks,
      groceryItems: _groceryItems,
      expenses: _expenses,
      debts: _debts,
      bills: _utilityBills,
      maintenanceTasks: _maintenanceTasks,
      monthlyIncome: _monthlyIncome,
    );

    if (alerts.isEmpty) {
      debugPrint('Smart scan: no alerts generated');
      await _localStorage.setLastSmartScanDate(DateTime.now());
      return;
    }

    debugPrint('Smart scan: ${alerts.length} alerts generated');

    // Map alert type to notification route
    String routeForType(String type) {
      switch (type) {
        case 'budget':
        case 'bill':
        case 'spending':
        case 'savings':
          return 'finance';
        case 'task':
          return 'tasks';
        case 'maintenance':
          return 'maintenance';
        case 'grocery':
          return 'grocery';
        default:
          return 'home';
      }
    }

    // Fire notifications + add to in-app history
    for (final alert in alerts) {
      // Push notification
      await NotificationService.instance.showRemoteNotification(
        title: alert.title,
        body: alert.body,
        channel: 'general',
      );

      // In-app notification feed
      _addNotificationToHistory(
        alert.title,
        alert.body,
        type: 'ai_smart_${alert.type}',
        actionRoute: routeForType(alert.type),
      );
    }

    await _localStorage.setLastSmartScanDate(DateTime.now());
  }

  void setNotificationPref(String category, bool value) {
    switch (category) {
      case 'chat':
        _chatNotificationsEnabled = value;
        break;
      case 'task':
        _taskNotificationsEnabled = value;
        break;
      case 'bill':
        _billNotificationsEnabled = value;
        break;
      case 'expense':
        _expenseNotificationsEnabled = value;
        break;
      case 'weekly_summary':
        _weeklySummaryEnabled = value;
        break;
    }
    _localStorage.setNotificationPref(category, value);
    notifyListeners();
  }


  // ============ AUTH ============

  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _firebase.signUpWithEmail(
      email: email,
      password: password,
      displayName: name,
    );
    if (credential.user != null) {
      await _firebase.saveUserProfile(
        uid: credential.user!.uid,
        name: name,
        email: email,
      );
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _firebase.signInWithEmail(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    final credential = await _firebase.signInWithGoogle();
    if (credential?.user != null) {
      final user = credential!.user!;
      // Check if user profile exists
      final profile = await _firebase.getUserProfile(user.uid);
      if (profile == null) {
        await _firebase.saveUserProfile(
          uid: user.uid,
          name: user.displayName ?? 'User',
          email: user.email ?? '',
        );
      }
    }
  }

  Future<void> signOut() async {
    _clearData();
    await _firebase.signOut();
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    await _firebase.resetPassword(email);
  }

  Future<void> updateProfile({
    required String nickname,
    required String role,
    required String avatar,
  }) async {
    if (_firebaseUser == null) return;

    await _firebase.saveUserProfile(
      uid: _firebaseUser!.uid,
      name: _firebaseUser!.displayName ?? 'User',
      email: _firebaseUser!.email ?? '',
      nickname: nickname,
      role: role,
      avatar: avatar,
      householdId: _householdId,
    );

    // Reload profile
    _userProfile = await _firebase.getUserProfile(_firebaseUser!.uid);
    notifyListeners();
  }

  // ============ HOUSEHOLD ============

  Future<void> createHousehold({
    required String name,
    required double monthlyIncome,
  }) async {
    if (_firebaseUser == null) return;

    final householdId = await _firebase.createHousehold(
      name: name,
      ownerId: _firebaseUser!.uid,
      monthlyIncome: monthlyIncome,
    );

    await _firebase.saveUserProfile(
      uid: _firebaseUser!.uid,
      name: _firebaseUser!.displayName ?? 'User',
      email: _firebaseUser!.email ?? '',
      householdId: householdId,
      role: _userProfile?['role'] ?? 'Member',
      avatar: _userProfile?['avatar'] ?? '👤',
      isAdmin: true,
    );

    _householdId = householdId;
    _monthlyIncome = monthlyIncome;

    // Seed sample data
    await _seedSampleData();

    await _loadHouseholdData();
    _subscribeToStreams();
    notifyListeners();
  }

  Future<bool> joinHousehold(String inviteCode) async {
    if (_firebaseUser == null) return false;

    final success = await _firebase.joinHousehold(
      householdId: inviteCode,
      userId: _firebaseUser!.uid,
    );

    if (success) {
      await _firebase.saveUserProfile(
        uid: _firebaseUser!.uid,
        name: _firebaseUser!.displayName ?? 'User',
        email: _firebaseUser!.email ?? '',
        householdId: inviteCode,
        role: 'Member',
        avatar: '👤',
        isAdmin: false,
      );

      _householdId = inviteCode;
      await _loadHouseholdData();
      _subscribeToStreams();
      notifyListeners();
    }

    return success;
  }

  // ============ THEME ============

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _localStorage.setIsDarkMode(_isDarkMode);
    notifyListeners();
  }

  // ============ INCOME ============

  void setMonthlyIncome(double income) {
    _monthlyIncome = income;
    if (_householdId != null) {
      _firebase.updateHousehold(_householdId!, {'monthlyIncome': income});
    }
    notifyListeners();
  }

  // ============ MAINTENANCE TASKS ============

  Future<void> addMaintenanceTask(MaintenanceTask task) async {
    if (_householdId == null) return;
    await _firebase.saveMaintenanceTask(_householdId!, task);
  }

  Future<void> updateMaintenanceTask(MaintenanceTask task) async {
    if (_householdId == null) return;
    await _firebase.saveMaintenanceTask(_householdId!, task);
  }

  Future<void> completeMaintenanceTask(String id) async {
    if (_householdId == null) return;
    final idx = _maintenanceTasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final task = _maintenanceTasks[idx];
      task.isCompleted = true;
      task.lastServiced = DateTime.now();
      task.history.add(DateTime.now());

      final nextDate = AIService.predictNextMaintenance(task);
      if (nextDate != null) {
        task.nextDue = nextDate;
        task.isCompleted = false;
      }

      await _firebase.saveMaintenanceTask(_householdId!, task);
    }
  }

  Future<void> deleteMaintenanceTask(String id) async {
    if (_householdId == null) return;
    await _firebase.deleteDocument(
      householdId: _householdId!,
      collection: 'maintenanceTasks',
      docId: id,
    );
  }

  // ============ HOUSEHOLD TASKS ============

  Future<void> addHouseholdTask(HouseholdTask task) async {
    if (_householdId == null) return;
    await _firebase.saveHouseholdTask(_householdId!, task);
  }

  Future<void> updateHouseholdTask(HouseholdTask task) async {
    if (_householdId == null) return;
    await _firebase.saveHouseholdTask(_householdId!, task);
  }

  Future<void> toggleHouseholdTask(String id) async {
    if (_householdId == null) return;
    final idx = _householdTasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _householdTasks[idx].isCompleted = !_householdTasks[idx].isCompleted;
      await _firebase.saveHouseholdTask(_householdId!, _householdTasks[idx]);
    }
  }

  Future<void> deleteHouseholdTask(String id) async {
    if (_householdId == null) return;
    await _firebase.deleteDocument(
      householdId: _householdId!,
      collection: 'householdTasks',
      docId: id,
    );
  }

  // ============ GROCERY ITEMS ============

  Future<void> addGroceryItem(GroceryItem item) async {
    if (_householdId == null) return;
    await _firebase.saveGroceryItem(_householdId!, item);
  }

  Future<void> updateGroceryItem(GroceryItem item) async {
    if (_householdId == null) return;
    await _firebase.saveGroceryItem(_householdId!, item);
  }

  Future<void> toggleGroceryItem(String id) async {
    if (_householdId == null) return;
    final idx = _groceryItems.indexWhere((g) => g.id == id);
    if (idx != -1) {
      _groceryItems[idx].isPurchased = !_groceryItems[idx].isPurchased;
      await _firebase.saveGroceryItem(_householdId!, _groceryItems[idx]);
    }
  }

  Future<void> deleteGroceryItem(String id) async {
    if (_householdId == null) return;
    await _firebase.deleteDocument(
      householdId: _householdId!,
      collection: 'groceryItems',
      docId: id,
    );
  }

  Future<void> clearPurchasedGroceries() async {
    if (_householdId == null) return;
    final purchased = _groceryItems.where((g) => g.isPurchased).toList();
    for (var item in purchased) {
      await _firebase.deleteDocument(
        householdId: _householdId!,
        collection: 'groceryItems',
        docId: item.id,
      );
    }
  }



  // ============ EXPENSES ============

  Future<void> addExpense(Expense expense) async {
    if (_householdId == null) return;
    await _firebase.saveExpense(_householdId!, expense);
  }

  Future<void> updateExpense(Expense expense) async {
    if (_householdId == null) return;
    await _firebase.saveExpense(_householdId!, expense);
  }

  Future<void> deleteExpense(String id) async {
    if (_householdId == null) return;
    await _firebase.deleteDocument(
      householdId: _householdId!,
      collection: 'expenses',
      docId: id,
    );
  }

  // ============ DEBTS ============

  Future<void> addDebt(Debt debt) async {
    if (_householdId == null) return;
    await _firebase.saveDebt(_householdId!, debt);
  }

  Future<void> updateDebt(Debt debt) async {
    if (_householdId == null) return;
    await _firebase.saveDebt(_householdId!, debt);
  }

  Future<void> updateDebtPayment(String id, double amount) async {
    if (_householdId == null) return;
    final idx = _debts.indexWhere((d) => d.id == id);
    if (idx != -1) {
      _debts[idx].paidAmount += amount;
      await _firebase.saveDebt(_householdId!, _debts[idx]);
    }
  }

  Future<void> deleteDebt(String id) async {
    if (_householdId == null) return;
    await _firebase.deleteDocument(
      householdId: _householdId!,
      collection: 'debts',
      docId: id,
    );
  }

  // ============ SAVINGS GOALS ============

  Future<void> addSavingsGoal(SavingsGoal goal) async {
    if (_householdId == null) return;
    await _firebase.saveSavingsGoal(_householdId!, goal);
  }

  Future<void> updateSavingsGoal(SavingsGoal goal) async {
    if (_householdId == null) return;
    await _firebase.saveSavingsGoal(_householdId!, goal);
  }

  Future<void> updateSavingsAmount(String id, double amount) async {
    if (_householdId == null) return;
    final idx = _savingsGoals.indexWhere((g) => g.id == id);
    if (idx != -1) {
      _savingsGoals[idx].currentAmount += amount;
      await _firebase.saveSavingsGoal(_householdId!, _savingsGoals[idx]);
    }
  }

  Future<void> deleteSavingsGoal(String id) async {
    if (_householdId == null) return;
    await _firebase.deleteDocument(
      householdId: _householdId!,
      collection: 'savingsGoals',
      docId: id,
    );
  }

  // ============ UTILITY BILLS ============

  Future<void> addUtilityBill(UtilityBill bill) async {
    if (_householdId == null) return;
    await _firebase.saveUtilityBill(_householdId!, bill);
  }

  Future<void> updateUtilityBill(UtilityBill bill) async {
    if (_householdId == null) return;
    await _firebase.saveUtilityBill(_householdId!, bill);
  }

  Future<void> toggleBillPaid(String id) async {
    if (_householdId == null) return;
    final idx = _utilityBills.indexWhere((b) => b.id == id);
    if (idx != -1) {
      _utilityBills[idx].isPaid = !_utilityBills[idx].isPaid;
      await _firebase.saveUtilityBill(_householdId!, _utilityBills[idx]);
    }
  }

  Future<void> deleteUtilityBill(String id) async {
    if (_householdId == null) return;
    await _firebase.deleteDocument(
      householdId: _householdId!,
      collection: 'utilityBills',
      docId: id,
    );
  }

  // ============ FAMILY MEMBERS ============

  Future<void> addFamilyMember(FamilyMember member) async {
    // In Firebase, family members are managed via household membership
    // This is for display purposes; actual joining is via invite code
    _familyMembers.add(member);
    notifyListeners();
  }

  Future<void> updateFamilyMember(FamilyMember member) async {
    final idx = _familyMembers.indexWhere((m) => m.id == member.id);
    if (idx != -1) {
      _familyMembers[idx] = member;
      notifyListeners();
    }
  }

  Future<void> deleteFamilyMember(String id) async {
    if (_householdId == null) return;
    // Remove from household members array in Firestore
    await _firebase.removeMemberFromHousehold(
      householdId: _householdId!,
      userId: id,
    );
    _familyMembers.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  Future<void> toggleMemberAdminRole(String memberId, bool makeAdmin) async {
    if (_householdId == null || _firebaseUser == null) return;
    // Only admin can do this
    if (!isAdmin) return;

    final idx = _familyMembers.indexWhere((m) => m.id == memberId);
    if (idx == -1) return;

    final member = _familyMembers[idx];

    // Update the isAdmin field in Firebase users collection
    await _firebase.saveUserProfile(
      uid: memberId,
      name: member.name,
      email: member.email,
      role: member.role,
      avatar: member.avatar,
      householdId: _householdId,
      isAdmin: makeAdmin,
    );

    // Update local list
    _familyMembers[idx] = FamilyMember(
      id: member.id,
      name: member.name,
      nickname: member.nickname,
      email: member.email,
      role: member.role,
      avatar: member.avatar,
      isAdmin: makeAdmin,
    );
    notifyListeners();
  }

  // ============ EMERGENCY CONTACTS ============

  Future<void> addEmergencyContact(EmergencyContact contact) async {
    if (_householdId == null) return;
    await _firebase.saveEmergencyContact(_householdId!, contact);
  }

  Future<void> updateEmergencyContact(EmergencyContact contact) async {
    if (_householdId == null) return;
    await _firebase.saveEmergencyContact(_householdId!, contact);
  }

  Future<void> deleteEmergencyContact(String id) async {
    if (_householdId == null) return;
    await _firebase.deleteDocument(
      householdId: _householdId!,
      collection: 'emergencyContacts',
      docId: id,
    );
  }

  // ============ CHAT ============

  Future<void> sendFamilyChatMessage(String text) async {
    if (_householdId == null || _firebaseUser == null) return;
    
    final member = _familyMembers.firstWhere(
      (m) => m.id == _firebaseUser!.uid,
      orElse: () => FamilyMember(
        id: _firebaseUser!.uid,
        name: currentUser,
        email: _firebaseUser!.email ?? '',
      ),
    );

    final msg = FamilyChatMessage(
      id: '',
      text: text,
      senderId: member.id,
      senderName: member.nickname ?? member.name,
      senderAvatar: member.avatar,
    );
    await _firebase.saveFamilyChatMessage(_householdId!, msg);
  }

  Future<void> sendChatMessage(String text) async {
    if (_householdId == null) return;

    // Save user message
    final userMsg = ChatMessage(id: '', text: text, isUser: true);
    await _firebase.saveChatMessage(_householdId!, userMsg);

    // Process with AI — uses Gemini LLM when configured, falls back to regex
    AIResult result;
    try {
      result = await AIService.processMessageWithLLM(
        message: text,
        maintenanceTasks: _maintenanceTasks,
        householdTasks: _householdTasks,
        groceryItems: _groceryItems,
        expenses: _expenses,
        debts: _debts,
        bills: _utilityBills,
        monthlyIncome: _monthlyIncome,
        savingsGoals: _savingsGoals,
        emergencyContacts: _emergencyContacts,
        history: _chatMessages,
      );

      // Execute action if present
      if (result.action != null) {
        await _executeAIAction(result.action!);
      }
    } catch (e) {
      debugPrint('AI Processing error: $e');
      // Fallback if even the AIService fallback fails
      result = AIResult(
        reply: 'I encountered a technical hiccup while processing that. '
               'Could you try again or ask something simpler?',
      );
    }

    // Save AI reply
    final aiMsg = ChatMessage(
      id: '', 
      text: result.reply, 
      isUser: false,
      actionType: result.action?.type,
      actionData: result.action?.data,
    );
    await _firebase.saveChatMessage(_householdId!, aiMsg);
  }

  Future<void> addAITextMessage(String text) async {
    if (_householdId == null) return;
    final aiMsg = ChatMessage(id: '', text: text, isUser: false);
    await _firebase.saveChatMessage(_householdId!, aiMsg);
  }

  /// Clears all AI assistant chat messages from Firebase.
  Future<void> clearChatHistory() async {
    if (_householdId == null) return;
    _chatMessages = [];
    notifyListeners();
    await _firebase.clearChatMessages(_householdId!);
  }

  Future<void> _executeAIAction(AIAction action) async {
    switch (action.type) {
      case 'add_grocery':
        final item = GroceryItem(
          id: '',
          name: action.data['name'] ?? 'Item',
          category: action.data['category'] ?? 'General',
          quantity: action.data['quantity'] ?? 1,
          unit: action.data['unit'] ?? 'pcs',
          addedBy: currentUser,
        );
        await addGroceryItem(item);
        break;

      case 'add_task':
        final task = HouseholdTask(
          id: '',
          title: action.data['title'] ?? 'New Task',
          category: action.data['category'] ?? 'General',
          priority: action.data['priority'] ?? 'medium',
          dueDate: action.data['dueDate'] != null
              ? DateTime.parse(action.data['dueDate'])
              : null,
          assignedTo: currentUser,
        );
        await addHouseholdTask(task);
        break;

      case 'add_expense':
        final expense = Expense(
          id: '',
          title: action.data['title'] ?? 'Misc Expense',
          amount: (action.data['amount'] ?? 0).toDouble(),
          category: action.data['category'] ?? 'Misc',
          date: DateTime.now(),
          paidBy: currentUserId,
        );
        await addExpense(expense);
        break;

      case 'add_maintenance':
        final task = MaintenanceTask(
          id: '',
          name: action.data['title'] ?? 'Maintenance',
          category: action.data['category'] ?? 'General',
          nextDue: action.data['nextDue'] != null
              ? DateTime.parse(action.data['nextDue'])
              : DateTime.now(),
          recurringDays: 90,
          assignedTo: currentUser,
        );
        await addMaintenanceTask(task);
        break;

      case 'complete_grocery':
        await toggleGroceryItem(action.data['id']);
        break;

      case 'complete_task':
        await toggleHouseholdTask(action.data['id']);
        break;

      case 'delete_grocery':
        await deleteGroceryItem(action.data['id']);
        break;

      case 'add_grocery_multi':
        final items = action.data['items'] as List<dynamic>? ?? [];
        for (var itemData in items) {
          final item = GroceryItem(
            id: '',
            name: itemData['name'] ?? 'Item',
            category: itemData['category'] ?? 'General',
            quantity: itemData['quantity'] ?? 1,
            unit: itemData['unit'] ?? 'pcs',
            addedBy: currentUser,
          );
          await addGroceryItem(item);
        }
        break;

      // ── NEW AGENT ACTIONS ──

      case 'delete_task':
        await deleteHouseholdTask(action.data['id']);
        break;

      case 'add_bill':
        final bill = UtilityBill(
          id: '',
          type: action.data['type'] ?? 'Other',
          amount: (action.data['amount'] ?? 0).toDouble(),
          billDate: action.data['billDate'] != null
              ? DateTime.parse(action.data['billDate'])
              : DateTime.now(),
          dueDate: action.data['dueDate'] != null
              ? DateTime.parse(action.data['dueDate'])
              : DateTime.now().add(const Duration(days: 15)),
        );
        await addUtilityBill(bill);
        break;

      case 'mark_bill_paid':
        await toggleBillPaid(action.data['id']);
        break;

      case 'delete_bill':
        await deleteUtilityBill(action.data['id']);
        break;

      case 'add_debt':
        final debt = Debt(
          id: '',
          name: action.data['name'] ?? 'Loan',
          totalAmount: (action.data['totalAmount'] ?? 0).toDouble(),
          monthlyPayment: (action.data['monthlyPayment'] ?? 0).toDouble(),
          interestRate: (action.data['interestRate'] ?? 0).toDouble(),
        );
        await addDebt(debt);
        break;

      case 'pay_debt':
        await updateDebtPayment(
          action.data['id'],
          (action.data['amount'] ?? 0).toDouble(),
        );
        break;

      case 'delete_debt':
        await deleteDebt(action.data['id']);
        break;

      case 'add_savings_goal':
        final goal = SavingsGoal(
          id: '',
          name: action.data['name'] ?? 'Savings',
          targetAmount: (action.data['targetAmount'] ?? 0).toDouble(),
          monthlyContribution: (action.data['monthlyContribution'] ?? 0).toDouble(),
          icon: action.data['icon'] ?? '🎯',
        );
        await addSavingsGoal(goal);
        break;

      case 'deposit_savings':
        final goalName = (action.data['goalName'] ?? '').toString().toLowerCase();
        final amount = (action.data['amount'] ?? 0).toDouble();
        final goal = _savingsGoals.firstWhere(
          (g) => g.name.toLowerCase().contains(goalName),
          orElse: () => SavingsGoal(id: '', name: '', targetAmount: 0),
        );
        if (goal.id.isNotEmpty && amount > 0) {
          await updateSavingsAmount(goal.id, amount);
        }
        break;

      case 'delete_savings':
        final goalName = (action.data['goalName'] ?? '').toString().toLowerCase();
        final goal = _savingsGoals.firstWhere(
          (g) => g.name.toLowerCase().contains(goalName),
          orElse: () => SavingsGoal(id: '', name: '', targetAmount: 0),
        );
        if (goal.id.isNotEmpty) {
          await deleteSavingsGoal(goal.id);
        }
        break;

      case 'complete_maintenance':
        await completeMaintenanceTask(action.data['id']);
        break;

      case 'delete_maintenance':
        await deleteMaintenanceTask(action.data['id']);
        break;

      case 'add_emergency_contact':
        final contact = EmergencyContact(
          id: '',
          name: action.data['name'] ?? 'Contact',
          phone: action.data['phone'] ?? '',
          category: action.data['category'] ?? 'Emergency',
        );
        await addEmergencyContact(contact);
        break;

      case 'delete_emergency_contact':
        final keyword = (action.data['name'] ?? '').toString().toLowerCase();
        final contact = _emergencyContacts.firstWhere(
          (c) => c.name.toLowerCase().contains(keyword),
          orElse: () => EmergencyContact(id: '', name: '', phone: '', category: ''),
        );
        if (contact.id.isNotEmpty) {
          await deleteEmergencyContact(contact.id);
        }
        break;

      case 'clear_purchased_groceries':
        await clearPurchasedGroceries();
        break;

      case 'delete_expense':
        await deleteExpense(action.data['id']);
        break;

      case 'set_income':
        setMonthlyIncome((action.data['amount'] ?? 0).toDouble());
        break;

      case 'toggle_theme':
        toggleTheme();
        break;

      case 'navigate':
        // Store the navigation target — UI will read this
        _pendingNavigation = action.data['screen'];
        notifyListeners();
        break;

      // ── UPDATE TASK ──
      case 'update_task':
        final id = action.data['id'] as String? ?? '';
        if (id.isNotEmpty) {
          final existing = _householdTasks.firstWhere((t) => t.id == id,
              orElse: () => HouseholdTask(id: '', title: '', category: ''));
          if (existing.id.isNotEmpty) {
            DateTime? newDue;
            final ds = action.data['new_due_date']?.toString().toLowerCase();
            if (ds == 'today') {
              newDue = DateTime.now();
            } else if (ds == 'tomorrow') {
              newDue = DateTime.now().add(const Duration(days: 1));
            } else if (ds == 'next week') {
              newDue = DateTime.now().add(const Duration(days: 7));
            } else if (ds == 'next month') {
              newDue = DateTime.now().add(const Duration(days: 30));
            }

            final updated = HouseholdTask(
              id: existing.id,
              title: action.data['new_title'] ?? existing.title,
              category: action.data['new_category'] ?? existing.category,
              priority: action.data['new_priority'] ?? existing.priority,
              dueDate: newDue ?? existing.dueDate,
              isCompleted: existing.isCompleted,
              assignedTo: existing.assignedTo,
            );
            await updateHouseholdTask(updated);
          }
        }
        break;

      // ── ASSIGN TASK ──
      case 'assign_task':
        final id = action.data['id'] as String? ?? '';
        final assignTo = action.data['assign_to']?.toString() ?? '';
        if (id.isNotEmpty) {
          final existing = _householdTasks.firstWhere((t) => t.id == id,
              orElse: () => HouseholdTask(id: '', title: '', category: ''));
          if (existing.id.isNotEmpty) {
            final updated = HouseholdTask(
              id: existing.id,
              title: existing.title,
              category: existing.category,
              priority: existing.priority,
              dueDate: existing.dueDate,
              isCompleted: existing.isCompleted,
              assignedTo: assignTo,
            );
            await updateHouseholdTask(updated);
          }
        }
        break;

      // ── UPDATE GROCERY ──
      case 'update_grocery':
        final id = action.data['id'] as String? ?? '';
        if (id.isNotEmpty) {
          final existing = _groceryItems.firstWhere((g) => g.id == id,
              orElse: () => GroceryItem(id: '', name: ''));
          if (existing.id.isNotEmpty) {
            final updated = GroceryItem(
              id: existing.id,
              name: existing.name,
              quantity: (action.data['new_quantity'] ?? existing.quantity) is int
                  ? (action.data['new_quantity'] ?? existing.quantity)
                  : int.tryParse(action.data['new_quantity'].toString()) ?? existing.quantity,
              unit: action.data['new_unit'] ?? existing.unit,
              category: existing.category,
              isPurchased: existing.isPurchased,
            );
            await updateGroceryItem(updated);
          }
        }
        break;

      // ── UPDATE EXPENSE ──
      case 'update_expense':
        final id = action.data['id'] as String? ?? '';
        if (id.isNotEmpty) {
          final existing = _expenses.firstWhere((e) => e.id == id,
              orElse: () => Expense(id: '', title: '', amount: 0, category: '', date: DateTime.now()));
          if (existing.id.isNotEmpty) {
            final newAmount = action.data['new_amount'] != null
                ? (action.data['new_amount'] as num).toDouble()
                : existing.amount;
            final updated = Expense(
              id: existing.id,
              title: existing.title,
              amount: newAmount,
              category: action.data['new_category'] ?? existing.category,
              date: existing.date,
            );
            await updateExpense(updated);
          }
        }
        break;

      // ── UPDATE BILL ──
      case 'update_bill':
        final id = action.data['id'] as String? ?? '';
        if (id.isNotEmpty) {
          final existing = _utilityBills.firstWhere((b) => b.id == id,
              orElse: () => UtilityBill(id: '', type: '', amount: 0, billDate: DateTime.now(), dueDate: DateTime.now()));
          if (existing.id.isNotEmpty) {
            final newAmount = action.data['new_amount'] != null
                ? (action.data['new_amount'] as num).toDouble()
                : existing.amount;
            DateTime? newDue;
            final ds = action.data['new_due_date']?.toString().toLowerCase();
            if (ds == 'today') {
              newDue = DateTime.now();
            } else if (ds == 'tomorrow') {
              newDue = DateTime.now().add(const Duration(days: 1));
            } else if (ds == 'next week') {
              newDue = DateTime.now().add(const Duration(days: 7));
            } else if (ds == 'next month') {
              newDue = DateTime.now().add(const Duration(days: 30));
            }

            final updated = UtilityBill(
              id: existing.id,
              type: existing.type,
              amount: newAmount,
              billDate: existing.billDate,
              dueDate: newDue ?? existing.dueDate,
              isPaid: existing.isPaid,
            );
            await updateUtilityBill(updated);
          }
        }
        break;

      // ── UPDATE DEBT ──
      case 'update_debt':
        final id = action.data['id'] as String? ?? '';
        if (id.isNotEmpty) {
          final existing = _debts.firstWhere((d) => d.id == id,
              orElse: () => Debt(id: '', name: '', totalAmount: 0));
          if (existing.id.isNotEmpty) {
            final newPayment = action.data['new_monthly_payment'] != null
                ? (action.data['new_monthly_payment'] as num).toDouble()
                : existing.monthlyPayment;
            final newRate = action.data['new_interest_rate'] != null
                ? (action.data['new_interest_rate'] as num).toDouble()
                : existing.interestRate;
            final updated = Debt(
              id: existing.id,
              name: existing.name,
              totalAmount: existing.totalAmount,
              paidAmount: existing.paidAmount,
              monthlyPayment: newPayment,
              interestRate: newRate,
            );
            await updateDebt(updated);
          }
        }
        break;

      // ── UPDATE SAVINGS ──
      case 'update_savings':
        final keyword = (action.data['goalName'] ?? '').toString().toLowerCase();
        final goal = _savingsGoals.firstWhere(
          (g) => g.name.toLowerCase().contains(keyword),
          orElse: () => SavingsGoal(id: '', name: '', targetAmount: 0),
        );
        if (goal.id.isNotEmpty) {
          final newTarget = action.data['new_target_amount'] != null
              ? (action.data['new_target_amount'] as num).toDouble()
              : goal.targetAmount;
          final newContribution = action.data['new_monthly_contribution'] != null
              ? (action.data['new_monthly_contribution'] as num).toDouble()
              : goal.monthlyContribution;
          final updated = SavingsGoal(
            id: goal.id,
            name: goal.name,
            targetAmount: newTarget,
            currentAmount: goal.currentAmount,
            monthlyContribution: newContribution,
            icon: goal.icon,
          );
          await updateSavingsGoal(updated);
        }
        break;

      // ── UPDATE MAINTENANCE ──
      case 'update_maintenance':
        final id = action.data['id'] as String? ?? '';
        if (id.isNotEmpty) {
          final existing = _maintenanceTasks.firstWhere((t) => t.id == id,
              orElse: () => MaintenanceTask(id: '', name: '', category: ''));
          if (existing.id.isNotEmpty) {
            DateTime? newDue;
            final ds = action.data['new_due_date']?.toString().toLowerCase();
            if (ds == 'today') {
              newDue = DateTime.now();
            } else if (ds == 'tomorrow') {
              newDue = DateTime.now().add(const Duration(days: 1));
            } else if (ds == 'next week') {
              newDue = DateTime.now().add(const Duration(days: 7));
            } else if (ds == 'next month') {
              newDue = DateTime.now().add(const Duration(days: 30));
            }

            final newRecurring = action.data['new_recurring_days'] != null
                ? (action.data['new_recurring_days'] as num).toInt()
                : existing.recurringDays;

            final updated = MaintenanceTask(
              id: existing.id,
              name: existing.name,
              category: existing.category,
              nextDue: newDue ?? existing.nextDue,
              recurringDays: newRecurring,
              isCompleted: existing.isCompleted,
            );
            await updateMaintenanceTask(updated);
          }
        }
        break;

      // ── UPDATE EMERGENCY CONTACT ──
      case 'update_emergency_contact':
        final keyword = (action.data['name'] ?? '').toString().toLowerCase();
        final contact = _emergencyContacts.firstWhere(
          (c) => c.name.toLowerCase().contains(keyword),
          orElse: () => EmergencyContact(id: '', name: '', phone: '', category: ''),
        );
        if (contact.id.isNotEmpty) {
          final updated = EmergencyContact(
            id: contact.id,
            name: contact.name,
            phone: action.data['new_phone'] ?? contact.phone,
            category: action.data['new_category'] ?? contact.category,
          );
          await updateEmergencyContact(updated);
        }
        break;

      // ── TOGGLE NOTIFICATIONS ──
      case 'toggle_notifications':
        final enabled = action.data['enabled'];
        toggleNotificationsEnabled(enabled == true || enabled == 'true');
        break;

      // ── SEND FAMILY MESSAGE ──
      case 'send_family_message':
        final message = action.data['message']?.toString() ?? '';
        if (message.isNotEmpty) {
          await sendFamilyChatMessage(message);
        }
        break;
    }
  }

  // Navigation target set by AI agent
  String? _pendingNavigation;
  String? get pendingNavigation => _pendingNavigation;
  void clearPendingNavigation() {
    _pendingNavigation = null;
  }

  // ============ SAMPLE DATA ============

  Future<void> _seedSampleData() async {
    if (_householdId == null) return;
    final hid = _householdId!;
    final now = DateTime.now();

    // Maintenance tasks
    await _firebase.saveMaintenanceTask(hid, MaintenanceTask(
      id: '', name: 'AC Servicing', category: 'HVAC',
      description: 'Annual AC filter cleaning and gas check',
      lastServiced: now.subtract(Duration(days: 80)),
      nextDue: now.add(Duration(days: 10)),
      recurringDays: 90,
      history: [
        now.subtract(Duration(days: 350)),
        now.subtract(Duration(days: 260)),
        now.subtract(Duration(days: 170)),
        now.subtract(Duration(days: 80)),
      ],
    ));
    await _firebase.saveMaintenanceTask(hid, MaintenanceTask(
      id: '', name: 'Water Purifier Filter', category: 'Water',
      description: 'Replace RO filter',
      lastServiced: now.subtract(Duration(days: 160)),
      nextDue: now.subtract(Duration(days: 10)),
      recurringDays: 150,
      history: [now.subtract(Duration(days: 310)), now.subtract(Duration(days: 160))],
    ));
    await _firebase.saveMaintenanceTask(hid, MaintenanceTask(
      id: '', name: 'Water Tank Cleaning', category: 'Water',
      lastServiced: now.subtract(Duration(days: 120)),
      nextDue: now.add(Duration(days: 60)), recurringDays: 180,
    ));

    // Household tasks
    await _firebase.saveHouseholdTask(hid, HouseholdTask(
      id: '', title: 'Deep clean kitchen', category: 'Cleaning',
      dueDate: now.add(Duration(days: 2)), priority: 'high', assignedTo: currentUser,
    ));
    await _firebase.saveHouseholdTask(hid, HouseholdTask(
      id: '', title: 'Pay electricity bill', category: 'Bills',
      dueDate: now.add(Duration(days: 5)), priority: 'high',
    ));
    await _firebase.saveHouseholdTask(hid, HouseholdTask(
      id: '', title: 'Grocery shopping', category: 'Shopping',
      dueDate: now.add(Duration(days: 1)), priority: 'medium',
    ));

    // Expenses
    final expenseData = [
      Expense(id: '', title: 'Electricity Bill', amount: 2500, category: 'Utilities', date: now.subtract(Duration(days: 5))),
      Expense(id: '', title: 'Grocery - Big Basket', amount: 3200, category: 'Groceries', date: now.subtract(Duration(days: 3))),
      Expense(id: '', title: 'Internet Bill', amount: 999, category: 'Utilities', date: now.subtract(Duration(days: 7))),
      Expense(id: '', title: 'Plumber Visit', amount: 800, category: 'Maintenance', date: now.subtract(Duration(days: 10))),
      Expense(id: '', title: 'Vegetables', amount: 650, category: 'Groceries', date: now.subtract(Duration(days: 1))),
      Expense(id: '', title: 'Dining Out', amount: 1800, category: 'Food', date: now.subtract(Duration(days: 2))),
    ];
    for (var e in expenseData) {
      await _firebase.saveExpense(hid, e);
    }

    // Debts
    await _firebase.saveDebt(hid, Debt(id: '', name: 'Home Loan', totalAmount: 2500000, paidAmount: 500000, monthlyPayment: 25000, interestRate: 8.5));
    await _firebase.saveDebt(hid, Debt(id: '', name: 'Credit Card', totalAmount: 45000, paidAmount: 15000, monthlyPayment: 5000, interestRate: 18));

    // Savings goals
    await _firebase.saveSavingsGoal(hid, SavingsGoal(id: '', name: 'Emergency Fund', targetAmount: 300000, currentAmount: 85000, monthlyContribution: 10000, icon: '🛡️'));
    await _firebase.saveSavingsGoal(hid, SavingsGoal(id: '', name: 'Vacation', targetAmount: 100000, currentAmount: 25000, monthlyContribution: 5000, icon: '✈️'));

    // Utility bills
    await _firebase.saveUtilityBill(hid, UtilityBill(id: '', type: 'Electricity', amount: 2500, billDate: now.subtract(Duration(days: 5)), dueDate: now.add(Duration(days: 10))));
    await _firebase.saveUtilityBill(hid, UtilityBill(id: '', type: 'Water', amount: 450, billDate: now.subtract(Duration(days: 8)), dueDate: now.add(Duration(days: 7)), isPaid: true));
    await _firebase.saveUtilityBill(hid, UtilityBill(id: '', type: 'Internet', amount: 999, billDate: now.subtract(Duration(days: 2)), dueDate: now.add(Duration(days: 13))));
    await _firebase.saveUtilityBill(hid, UtilityBill(id: '', type: 'Gas', amount: 800, billDate: now.subtract(Duration(days: 12)), dueDate: now.subtract(Duration(days: 2))));

    // Emergency contacts
    await _firebase.saveEmergencyContact(hid, EmergencyContact(id: '', name: 'City Hospital', phone: '108', category: 'Hospital'));
    await _firebase.saveEmergencyContact(hid, EmergencyContact(id: '', name: 'Fire Station', phone: '101', category: 'Emergency'));
    await _firebase.saveEmergencyContact(hid, EmergencyContact(id: '', name: 'Local Electrician', phone: '9876543210', category: 'Electrician'));
    await _firebase.saveEmergencyContact(hid, EmergencyContact(id: '', name: 'Plumber - Raj', phone: '9876543211', category: 'Plumber'));
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
