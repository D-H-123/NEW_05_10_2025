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
  final String userId;
  final String userName;
  final double amount;
  final String category;
  final String? description;
  final DateTime date;
  final String? receiptUrl;

  MemberExpense({
    required this.id,
    required this.userId,
    required this.userName,
    required this.amount,
    required this.category,
    this.description,
    required this.date,
    this.receiptUrl,
  });

  factory MemberExpense.fromMap(Map<String, dynamic> map, String id) {
    return MemberExpense(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? '',
      description: map['description'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] ?? 0),
      receiptUrl: map['receiptUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'amount': amount,
      'category': category,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'receiptUrl': receiptUrl,
    };
  }
}

