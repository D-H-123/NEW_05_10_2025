class SharedBudget {
  final String id;
  final String name;
  final double amount;
  final String ownerId;
  final String ownerName;
  final List<BudgetMember> members;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? inviteCode;

  SharedBudget({
    required this.id,
    required this.name,
    required this.amount,
    required this.ownerId,
    required this.ownerName,
    required this.members,
    required this.createdAt,
    required this.updatedAt,
    this.inviteCode,
  });

  factory SharedBudget.fromMap(Map<String, dynamic> map, String id) {
    try {
      return SharedBudget(
        id: id,
        name: map['name'] ?? 'Unnamed Budget',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        ownerId: map['ownerId'] ?? '',
        ownerName: map['ownerName'] ?? 'Unknown',
        members: (map['members'] as List<dynamic>?)
                ?.map((m) {
                  try {
                    return BudgetMember.fromMap(m as Map<String, dynamic>);
                  } catch (e) {
                    print('⚠️ Error parsing member: $e');
                    return null;
                  }
                })
                .whereType<BudgetMember>()
                .toList() ??
            [],
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? DateTime.now().millisecondsSinceEpoch),
        inviteCode: map['inviteCode'],
      );
    } catch (e) {
      print('❌ Critical error parsing SharedBudget: $e');
      print('❌ Map data: $map');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'members': members.map((m) => m.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'inviteCode': inviteCode,
    };
  }

  double calculateTotalSpending(List<MemberExpense> expenses) {
    return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  double getSpendingByMember(String userId, List<MemberExpense> expenses) {
    return expenses
        .where((e) => e.userId == userId)
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }
}

class BudgetMember {
  final String userId;
  final String name;
  final String? email;
  final String? photoUrl;
  final String role; // 'owner', 'admin', 'member'
  final DateTime joinedAt;

  BudgetMember({
    required this.userId,
    required this.name,
    this.email,
    this.photoUrl,
    required this.role,
    required this.joinedAt,
  });

  factory BudgetMember.fromMap(Map<String, dynamic> map) {
    return BudgetMember(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'],
      photoUrl: map['photoUrl'],
      role: map['role'] ?? 'member',
      joinedAt: DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'role': role,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
    };
  }
}

class MemberExpense {
  final String id;
  final String userId;         // Who paid
  final String userName;
  final double amount;          // Total amount paid
  final String category;
  final String? title;          // User-defined expense title
  final String? description;
  final DateTime date;
  final String? receiptUrl;
  
  // Split expense fields
  final bool isSplit;           // Is this expense split?
  final List<String> splitWith; // UserIds of people involved in split
  final Map<String, double> splitAmounts;     // userId -> amount they owe
  final Map<String, bool> settlementStatus;   // userId -> settled or not
  final Map<String, double> paidAmounts;       // userId -> amount they have paid (for partial payments)

  MemberExpense({
    required this.id,
    required this.userId,
    required this.userName,
    required this.amount,
    required this.category,
    this.title,
    this.description,
    required this.date,
    this.receiptUrl,
    this.isSplit = false,
    this.splitWith = const [],
    this.splitAmounts = const {},
    this.settlementStatus = const {},
    this.paidAmounts = const {},
  });

  factory MemberExpense.fromMap(Map<String, dynamic> map, String id) {
    return MemberExpense(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? '',
      title: map['title'],
      description: map['description'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] ?? 0),
      receiptUrl: map['receiptUrl'],
      isSplit: map['isSplit'] ?? false,
      splitWith: (map['splitWith'] as List<dynamic>?)?.cast<String>() ?? [],
      splitAmounts: (map['splitAmounts'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ) ?? {},
      settlementStatus: (map['settlementStatus'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, value as bool),
      ) ?? {},
      paidAmounts: (map['paidAmounts'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ) ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'amount': amount,
      'category': category,
      'title': title,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'receiptUrl': receiptUrl,
      'isSplit': isSplit,
      'splitWith': splitWith,
      'splitAmounts': splitAmounts,
      'settlementStatus': settlementStatus,
      'paidAmounts': paidAmounts,
    };
  }
  
  // Helper: Get share for a specific user
  double getShareForUser(String userId) {
    return splitAmounts[userId] ?? 0.0;
  }
  
  // Helper: Check if user has settled
  bool hasUserSettled(String userId) {
    return settlementStatus[userId] ?? false;
  }
  
  // Helper: Get amount paid by user (for partial payments)
  double getPaidAmount(String userId) {
    return paidAmounts[userId] ?? 0.0;
  }
  
  // Helper: Get remaining amount for user
  double getRemainingAmount(String userId) {
    final owed = splitAmounts[userId] ?? 0.0;
    final paid = paidAmounts[userId] ?? 0.0;
    return (owed - paid).clamp(0.0, double.infinity);
  }
  
  // Helper: Check if user has fully paid (considering partial payments)
  bool isUserFullyPaid(String userId) {
    final owed = splitAmounts[userId] ?? 0.0;
    final paid = paidAmounts[userId] ?? 0.0;
    return paid >= owed - 0.01; // Allow small rounding differences
  }
  
  // Helper: Get number of people in split
  int get splitCount => splitWith.length;
  
  // Helper: Get pending settlements count
  int get pendingSettlements {
    return settlementStatus.values.where((settled) => !settled).length;
  }
}

