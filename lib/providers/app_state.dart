import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();
  final StorageService _localStorage = StorageService();
  final _uuid = Uuid();

  // Auth state
  User? _firebaseUser;
  Map<String, dynamic>? _userProfile;
  String? _householdId;
  bool _isInitialized = false;
  bool _isDarkMode = true;
  double _monthlyIncome = 0;

  // Data lists
  List<MaintenanceTask> _maintenanceTasks = [];
  List<HouseholdTask> _householdTasks = [];
  List<GroceryItem> _groceryItems = [];
  List<PantryItem> _pantryItems = [];
  List<Expense> _expenses = [];
  List<Debt> _debts = [];
  List<SavingsGoal> _savingsGoals = [];
  List<UtilityBill> _utilityBills = [];
  List<FamilyMember> _familyMembers = [];
  List<EmergencyContact> _emergencyContacts = [];
  List<ChatMessage> _chatMessages = [];

  // Stream subscriptions
  final List<StreamSubscription> _subscriptions = [];

  // ============ GETTERS ============
  User? get firebaseUser => _firebaseUser;
  bool get isLoggedIn => _firebaseUser != null;
  bool get hasHousehold => _householdId != null;
  bool get isInitialized => _isInitialized;
  bool get isDarkMode => _isDarkMode;
  String? get householdId => _householdId;
  double get monthlyIncome => _monthlyIncome;

  String get currentUser =>
      _firebaseUser?.displayName ?? _userProfile?['name'] ?? 'User';

  List<MaintenanceTask> get maintenanceTasks => _maintenanceTasks;
  List<HouseholdTask> get householdTasks => _householdTasks;
  List<GroceryItem> get groceryItems => _groceryItems;
  List<PantryItem> get pantryItems => _pantryItems;
  List<Expense> get expenses => _expenses;
  List<Debt> get debts => _debts;
  List<SavingsGoal> get savingsGoals => _savingsGoals;
  List<UtilityBill> get utilityBills => _utilityBills;
  List<FamilyMember> get familyMembers => _familyMembers;
  List<EmergencyContact> get emergencyContacts => _emergencyContacts;
  List<ChatMessage> get chatMessages => _chatMessages;

  // Computed getters
  List<MaintenanceTask> get overdueMaintenanceTasks =>
      _maintenanceTasks.where((t) => t.isOverdue).toList();
  List<HouseholdTask> get pendingTasks =>
      _householdTasks.where((t) => !t.isCompleted).toList();
  List<GroceryItem> get unpurchasedGroceries =>
      _groceryItems.where((g) => !g.isPurchased).toList();
  List<PantryItem> get lowPantryItems =>
      _pantryItems.where((p) => p.isLow).toList();
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
        pantryItems: _pantryItems,
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

    // Listen to auth state changes
    _firebase.authStateChanges.listen((user) {
      _firebaseUser = user;
      if (user != null) {
        _loadUserProfile();
      } else {
        _clearData();
      }
      notifyListeners();
    });

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadUserProfile() async {
    if (_firebaseUser == null) return;

    _userProfile = await _firebase.getUserProfile(_firebaseUser!.uid);
    if (_userProfile != null && _userProfile!['householdId'] != null) {
      _householdId = _userProfile!['householdId'];
      await _loadHouseholdData();
      _subscribeToStreams();
    }
    notifyListeners();
  }

  Future<void> _loadHouseholdData() async {
    if (_householdId == null) return;

    final household = await _firebase.getHousehold(_householdId!);
    if (household != null) {
      _monthlyIncome = (household['monthlyIncome'] ?? 0).toDouble();
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
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _firebase.streamHouseholdTasks(_householdId!).listen((data) {
        _householdTasks = data;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _firebase.streamGroceryItems(_householdId!).listen((data) {
        _groceryItems = data;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _firebase.streamPantryItems(_householdId!).listen((data) {
        _pantryItems = data;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _firebase.streamExpenses(_householdId!).listen((data) {
        _expenses = data;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _firebase.streamDebts(_householdId!).listen((data) {
        _debts = data;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _firebase.streamSavingsGoals(_householdId!).listen((data) {
        _savingsGoals = data;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      _firebase.streamUtilityBills(_householdId!).listen((data) {
        _utilityBills = data;
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
  }

  void _cancelSubscriptions() {
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
    _pantryItems = [];
    _expenses = [];
    _debts = [];
    _savingsGoals = [];
    _utilityBills = [];
    _familyMembers = [];
    _emergencyContacts = [];
    _chatMessages = [];
    _cancelSubscriptions();
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
      role: 'Admin',
      avatar: '👑',
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

  // ============ PANTRY ITEMS ============

  Future<void> addPantryItem(PantryItem item) async {
    if (_householdId == null) return;
    await _firebase.savePantryItem(_householdId!, item);
  }

  Future<void> updatePantryItem(PantryItem item) async {
    if (_householdId == null) return;
    await _firebase.savePantryItem(_householdId!, item);
  }

  Future<void> updatePantryQuantity(String id, double quantity) async {
    if (_householdId == null) return;
    final idx = _pantryItems.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _pantryItems[idx].currentQuantity = quantity;
      await _firebase.savePantryItem(_householdId!, _pantryItems[idx]);

      // Auto-suggest for grocery if low
      if (_pantryItems[idx].isLow) {
        _autoSuggestGrocery(_pantryItems[idx]);
      }
    }
  }

  Future<void> deletePantryItem(String id) async {
    if (_householdId == null) return;
    await _firebase.deleteDocument(
      householdId: _householdId!,
      collection: 'pantryItems',
      docId: id,
    );
  }

  void _autoSuggestGrocery(PantryItem pantryItem) {
    bool exists = _groceryItems.any(
        (g) => g.name.toLowerCase() == pantryItem.name.toLowerCase() && !g.isPurchased);
    if (!exists) {
      addGroceryItem(GroceryItem(
        id: '',
        name: pantryItem.name,
        category: pantryItem.category,
        quantity: 1,
        unit: pantryItem.unit,
        addedBy: 'Smart Pantry',
      ));
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
    _familyMembers.removeWhere((m) => m.id == id);
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

  Future<void> sendChatMessage(String text) async {
    if (_householdId == null) return;

    // Add user message
    final userMsg = ChatMessage(
      id: '',
      text: text,
      isUser: true,
    );
    await _firebase.saveChatMessage(_householdId!, userMsg);

    // Generate AI response
    final response = AIService.getChatResponse(
      question: text,
      maintenanceTasks: _maintenanceTasks,
      householdTasks: _householdTasks,
      groceryItems: _groceryItems,
      pantryItems: _pantryItems,
      expenses: _expenses,
      debts: _debts,
      bills: _utilityBills,
      monthlyIncome: _monthlyIncome,
    );

    final aiMsg = ChatMessage(
      id: '',
      text: response,
      isUser: false,
    );
    await _firebase.saveChatMessage(_householdId!, aiMsg);
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

    // Pantry items
    final pantryItems = [
      PantryItem(id: '', name: 'Rice', category: 'Grains', currentQuantity: 2, minimumQuantity: 1, unit: 'kg'),
      PantryItem(id: '', name: 'Milk', category: 'Dairy', currentQuantity: 0.5, minimumQuantity: 1, unit: 'L'),
      PantryItem(id: '', name: 'Cooking Oil', category: 'Cooking', currentQuantity: 0.3, minimumQuantity: 0.5, unit: 'L'),
      PantryItem(id: '', name: 'Sugar', category: 'Essentials', currentQuantity: 1.5, minimumQuantity: 0.5, unit: 'kg'),
      PantryItem(id: '', name: 'Detergent', category: 'Cleaning', currentQuantity: 0.2, minimumQuantity: 0.5, unit: 'kg'),
    ];
    for (var item in pantryItems) {
      await _firebase.savePantryItem(hid, item);
    }

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
