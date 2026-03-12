import 'package:cloud_firestore/cloud_firestore.dart';

class MaintenanceTask {
  String id;
  String name;
  String category;
  String? description;
  DateTime? lastServiced;
  DateTime? nextDue;
  int recurringDays;
  bool isCompleted;
  String? assignedTo;
  String? notes;
  List<DateTime> history;

  MaintenanceTask({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.lastServiced,
    this.nextDue,
    this.recurringDays = 90,
    this.isCompleted = false,
    this.assignedTo,
    this.notes,
    List<DateTime>? history,
  }) : history = history ?? [];

  bool get isOverdue =>
      nextDue != null && nextDue!.isBefore(DateTime.now()) && !isCompleted;

  bool get isDueSoon =>
      nextDue != null &&
      nextDue!.difference(DateTime.now()).inDays <= 7 &&
      !isOverdue &&
      !isCompleted;

  int? get daysUntilDue =>
      nextDue != null ? nextDue!.difference(DateTime.now()).inDays : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'description': description,
        'lastServiced': lastServiced?.toIso8601String(),
        'nextDue': nextDue?.toIso8601String(),
        'recurringDays': recurringDays,
        'isCompleted': isCompleted,
        'assignedTo': assignedTo,
        'notes': notes,
        'history': history.map((d) => d.toIso8601String()).toList(),
      };

  factory MaintenanceTask.fromJson(Map<String, dynamic> json) =>
      MaintenanceTask(
        id: json['id'],
        name: json['name'],
        category: json['category'],
        description: json['description'],
        lastServiced: json['lastServiced'] != null
            ? DateTime.parse(json['lastServiced'])
            : null,
        nextDue:
            json['nextDue'] != null ? DateTime.parse(json['nextDue']) : null,
        recurringDays: json['recurringDays'] ?? 90,
        isCompleted: json['isCompleted'] ?? false,
        assignedTo: json['assignedTo'],
        notes: json['notes'],
        history: (json['history'] as List<dynamic>?)
                ?.map((d) => DateTime.parse(d))
                .toList() ??
            [],
      );
}

class HouseholdTask {
  String id;
  String title;
  String category;
  String? assignedTo;
  DateTime? dueDate;
  bool isCompleted;
  String priority;
  String? notes;
  DateTime createdAt;

  HouseholdTask({
    required this.id,
    required this.title,
    required this.category,
    this.assignedTo,
    this.dueDate,
    this.isCompleted = false,
    this.priority = 'medium',
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isOverdue =>
      dueDate != null && dueDate!.isBefore(DateTime.now()) && !isCompleted;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'assignedTo': assignedTo,
        'dueDate': dueDate?.toIso8601String(),
        'isCompleted': isCompleted,
        'priority': priority,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HouseholdTask.fromJson(Map<String, dynamic> json) => HouseholdTask(
        id: json['id'],
        title: json['title'],
        category: json['category'],
        assignedTo: json['assignedTo'],
        dueDate:
            json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
        isCompleted: json['isCompleted'] ?? false,
        priority: json['priority'] ?? 'medium',
        notes: json['notes'],
        createdAt: json['createdAt'] != null
            ? (json['createdAt'] is Timestamp 
                ? (json['createdAt'] as Timestamp).toDate() 
                : DateTime.parse(json['createdAt'].toString()))
            : DateTime.now(),
      );
}

class GroceryItem {
  String id;
  String name;
  String category;
  int quantity;
  String unit;
  bool isPurchased;
  String? addedBy;

  GroceryItem({
    required this.id,
    required this.name,
    this.category = 'General',
    this.quantity = 1,
    this.unit = 'pcs',
    this.isPurchased = false,
    this.addedBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'isPurchased': isPurchased,
        'addedBy': addedBy,
      };

  factory GroceryItem.fromJson(Map<String, dynamic> json) => GroceryItem(
        id: json['id'],
        name: json['name'],
        category: json['category'] ?? 'General',
        quantity: json['quantity'] ?? 1,
        unit: json['unit'] ?? 'pcs',
        isPurchased: json['isPurchased'] ?? false,
        addedBy: json['addedBy'],
      );
}


class Expense {
  String id;
  String title;
  double amount;
  String category;
  DateTime date;
  String? notes;
  String? paidBy;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.notes,
    this.paidBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        'notes': notes,
        'paidBy': paidBy,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'],
        title: json['title'],
        amount: (json['amount'] ?? 0).toDouble(),
        category: json['category'],
        date: DateTime.parse(json['date']),
        notes: json['notes'],
        paidBy: json['paidBy'],
      );
}

class Debt {
  String id;
  String name;
  double totalAmount;
  double paidAmount;
  double monthlyPayment;
  double interestRate;
  DateTime startDate;

  Debt({
    required this.id,
    required this.name,
    required this.totalAmount,
    this.paidAmount = 0,
    this.monthlyPayment = 0,
    this.interestRate = 0,
    DateTime? startDate,
  }) : startDate = startDate ?? DateTime.now();

  double get remainingAmount => totalAmount - paidAmount;
  double get progressPercent =>
      totalAmount > 0 ? (paidAmount / totalAmount).clamp(0, 1) : 0;
  int get monthsToPayoff =>
      monthlyPayment > 0 ? (remainingAmount / monthlyPayment).ceil() : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'monthlyPayment': monthlyPayment,
        'interestRate': interestRate,
        'startDate': startDate.toIso8601String(),
      };

  factory Debt.fromJson(Map<String, dynamic> json) => Debt(
        id: json['id'],
        name: json['name'],
        totalAmount: (json['totalAmount'] ?? 0).toDouble(),
        paidAmount: (json['paidAmount'] ?? 0).toDouble(),
        monthlyPayment: (json['monthlyPayment'] ?? 0).toDouble(),
        interestRate: (json['interestRate'] ?? 0).toDouble(),
        startDate: json['startDate'] != null
            ? DateTime.parse(json['startDate'])
            : DateTime.now(),
      );
}

class SavingsGoal {
  String id;
  String name;
  double targetAmount;
  double currentAmount;
  double monthlyContribution;
  DateTime? targetDate;
  String icon;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.monthlyContribution = 0,
    this.targetDate,
    this.icon = '🎯',
  });

  double get progressPercent =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0, 1) : 0;
  double get remainingAmount => targetAmount - currentAmount;
  int get monthsToGoal => monthlyContribution > 0
      ? (remainingAmount / monthlyContribution).ceil()
      : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'monthlyContribution': monthlyContribution,
        'targetDate': targetDate?.toIso8601String(),
        'icon': icon,
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
        id: json['id'],
        name: json['name'],
        targetAmount: (json['targetAmount'] ?? 0).toDouble(),
        currentAmount: (json['currentAmount'] ?? 0).toDouble(),
        monthlyContribution: (json['monthlyContribution'] ?? 0).toDouble(),
        targetDate: json['targetDate'] != null
            ? DateTime.parse(json['targetDate'])
            : null,
        icon: json['icon'] ?? '🎯',
      );
}

class UtilityBill {
  String id;
  String type;
  double amount;
  DateTime billDate;
  DateTime dueDate;
  bool isPaid;
  String? notes;

  UtilityBill({
    required this.id,
    required this.type,
    required this.amount,
    required this.billDate,
    required this.dueDate,
    this.isPaid = false,
    this.notes,
  });

  bool get isOverdue => dueDate.isBefore(DateTime.now()) && !isPaid;
  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'billDate': billDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'isPaid': isPaid,
        'notes': notes,
      };

  factory UtilityBill.fromJson(Map<String, dynamic> json) => UtilityBill(
        id: json['id'],
        type: json['type'],
        amount: (json['amount'] ?? 0).toDouble(),
        billDate: DateTime.parse(json['billDate']),
        dueDate: DateTime.parse(json['dueDate']),
        isPaid: json['isPaid'] ?? false,
        notes: json['notes'],
      );
}

class FamilyMember {
  String id;
  String name;
  String email;
  String role;
  String avatar;

  FamilyMember({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'Member',
    this.avatar = '👤',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'avatar': avatar,
      };

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        role: json['role'] ?? 'Member',
        avatar: json['avatar'] ?? '👤',
      );
}

class EmergencyContact {
  String id;
  String name;
  String phone;
  String category;
  String? notes;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.category,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'category': category,
        'notes': notes,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: json['id'],
        name: json['name'],
        phone: json['phone'],
        category: json['category'],
        notes: json['notes'],
      );
}

class ChatMessage {
  String id;
  String text;
  bool isUser;
  DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'],
        text: json['text'],
        isUser: json['isUser'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

enum AIActionType {
  none,
  addGrocery,
  addTask,
  completeTask,
  addExpense,
}

class AICommand {
  final String responseText;
  final AIActionType actionType;
  final Map<String, dynamic>? actionData;

  AICommand({
    required this.responseText,
    this.actionType = AIActionType.none,
    this.actionData,
  });
}
