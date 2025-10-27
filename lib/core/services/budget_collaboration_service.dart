import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shared_budget.dart';

class BudgetCollaborationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generate a unique 6-character invite code
  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Create a shared budget
  static Future<SharedBudget?> createSharedBudget({
    required String name,
    required double amount,
  }) async {
    try {
      print('🔐 Checking user authentication...');
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ User not authenticated!');
        throw Exception('User not authenticated');
      }
      print('✅ User authenticated: ${user.email} (${user.uid})');

      final inviteCode = _generateInviteCode();
      final now = DateTime.now();
      
      print('🎲 Generated invite code: $inviteCode');

      final budgetData = {
        'name': name,
        'amount': amount,
        'ownerId': user.uid,
        'ownerName': user.displayName ?? 'Unknown',
        'memberIds': [user.uid], // Simple array for efficient queries
        'members': [
          {
            'userId': user.uid,
            'name': user.displayName ?? 'Unknown',
            'email': user.email,
            'photoUrl': user.photoURL,
            'role': 'owner',
            'joinedAt': now.millisecondsSinceEpoch,
          }
        ],
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
        'inviteCode': inviteCode,
      };

      print('💾 Saving to Firebase...');
      final docRef = await _firestore.collection('shared_budgets').add(budgetData);
      print('✅ Saved to Firebase with ID: ${docRef.id}');
      
      final budget = SharedBudget.fromMap(budgetData, docRef.id);
      print('✅ Budget object created successfully');
      return budget;
    } catch (e) {
      print('❌ Error creating shared budget: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Join a shared budget using invite code
  /// Returns: 'success', 'already_member', 'invalid_code', or 'error'
  static Future<String> joinSharedBudget(String inviteCode) async {
    try {
      print('🔍 Joining budget with code: $inviteCode');
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ User not authenticated');
        return 'error';
      }

      // Find budget with this invite code
      print('📡 Searching for budget...');
      final querySnapshot = await _firestore
          .collection('shared_budgets')
          .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('❌ No budget found with code: $inviteCode');
        return 'invalid_code';
      }

      final budgetDoc = querySnapshot.docs.first;
      final budget = SharedBudget.fromMap(budgetDoc.data(), budgetDoc.id);
      print('✅ Found budget: ${budget.name}');

      // Check if user is already a member
      if (budget.members.any((m) => m.userId == user.uid)) {
        print('⚠️ User is already a member of this budget');
        return 'already_member';
      }

      // Add user to members
      print('➕ Adding user to budget...');
      final newMember = BudgetMember(
        userId: user.uid,
        name: user.displayName ?? 'Unknown',
        email: user.email,
        photoUrl: user.photoURL,
        role: 'member',
        joinedAt: DateTime.now(),
      );

      await budgetDoc.reference.update({
        'memberIds': FieldValue.arrayUnion([user.uid]), // Add to simple array
        'members': FieldValue.arrayUnion([newMember.toMap()]),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      print('✅ Successfully joined budget!');
      return 'success';
    } catch (e) {
      print('❌ Error joining shared budget: $e');
      return 'error';
    }
  }

  /// Get all shared budgets for current user
  static Stream<List<SharedBudget>> getUserSharedBudgets() {
    final user = _auth.currentUser;
    print('🔍 Getting budgets for user: ${user?.email ?? "not logged in"}');
    
    if (user == null) {
      print('❌ No user logged in, returning empty stream');
      return Stream.value([]);
    }

    print('⚡ Using fast query (only your budgets)...');
    
    // FAST: Query by ownerId (budgets you created)
    return _firestore
        .collection('shared_budgets')
        .where('ownerId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      print('📦 Loaded ${snapshot.docs.length} budget(s) instantly');
      
      final userBudgets = snapshot.docs
          .map((doc) {
            try {
              final budget = SharedBudget.fromMap(doc.data(), doc.id);
              print('   ✅ ${budget.name}');
              return budget;
            } catch (e) {
              print('   ⚠️ Error: $e');
              return null;
            }
          })
          .whereType<SharedBudget>()
          .toList();
      
      return userBudgets;
    });
  }

  /// Get expenses for a shared budget
  static Stream<List<MemberExpense>> getSharedBudgetExpenses(String budgetId) {
    return _firestore
        .collection('shared_budgets')
        .doc(budgetId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MemberExpense.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Add expense to shared budget (with optional split)
  static Future<bool> addExpense({
    required String budgetId,
    required double amount,
    required String category,
    String? title,
    String? description,
    String? receiptUrl,
    bool isSplit = false,
    List<String>? splitWith,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Calculate split amounts if splitting
      Map<String, double> splitAmounts = {};
      Map<String, bool> settlementStatus = {};
      List<String> finalSplitWith = splitWith ?? [];

      if (isSplit && finalSplitWith.isNotEmpty) {
        // Equal split among all participants
        final shareAmount = amount / finalSplitWith.length;
        for (String userId in finalSplitWith) {
          splitAmounts[userId] = shareAmount;
          // Person who paid is automatically settled
          settlementStatus[userId] = (userId == user.uid);
        }
      }

      final expense = MemberExpense(
        id: '',
        userId: user.uid,
        userName: user.displayName ?? 'Unknown',
        amount: amount,
        category: category,
        title: title,
        description: description,
        date: DateTime.now(),
        receiptUrl: receiptUrl,
        isSplit: isSplit,
        splitWith: finalSplitWith,
        splitAmounts: splitAmounts,
        settlementStatus: settlementStatus,
      );

      await _firestore
          .collection('shared_budgets')
          .doc(budgetId)
          .collection('expenses')
          .add(expense.toMap());

      // Update budget's updatedAt timestamp
      await _firestore.collection('shared_budgets').doc(budgetId).update({
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // TODO: Send notifications to split participants
      if (isSplit && finalSplitWith.isNotEmpty) {
        for (String userId in finalSplitWith) {
          if (userId != user.uid) {
            // Will implement notification system
            print('📬 Notification: User $userId owes ${splitAmounts[userId]}');
          }
        }
      }

      return true;
    } catch (e) {
      print('Error adding expense: $e');
      return false;
    }
  }

  /// Update expense in shared budget
  static Future<bool> updateExpense({
    required String budgetId,
    required String expenseId,
    required double amount,
    required String category,
    String? title,
    String? description,
  }) async {
    try {
      await _firestore
          .collection('shared_budgets')
          .doc(budgetId)
          .collection('expenses')
          .doc(expenseId)
          .update({
        'amount': amount,
        'category': category,
        'title': title,
        'description': description,
        'date': DateTime.now().millisecondsSinceEpoch, // Update timestamp
      });

      // Update budget's updatedAt timestamp
      await _firestore.collection('shared_budgets').doc(budgetId).update({
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      return true;
    } catch (e) {
      print('Error updating expense: $e');
      return false;
    }
  }

  /// Delete expense from shared budget
  static Future<bool> deleteExpense({
    required String budgetId,
    required String expenseId,
  }) async {
    try {
      await _firestore
          .collection('shared_budgets')
          .doc(budgetId)
          .collection('expenses')
          .doc(expenseId)
          .delete();

      // Update budget's updatedAt timestamp
      await _firestore.collection('shared_budgets').doc(budgetId).update({
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      return true;
    } catch (e) {
      print('Error deleting expense: $e');
      return false;
    }
  }

  /// Mark a split settlement as paid
  static Future<bool> markSettlement({
    required String budgetId,
    required String expenseId,
    required String userId,
    required bool settled,
  }) async {
    try {
      final expenseDoc = await _firestore
          .collection('shared_budgets')
          .doc(budgetId)
          .collection('expenses')
          .doc(expenseId)
          .get();
      
      if (!expenseDoc.exists) return false;
      
      final expense = MemberExpense.fromMap(expenseDoc.data()!, expenseId);
      final updatedSettlementStatus = Map<String, bool>.from(expense.settlementStatus);
      updatedSettlementStatus[userId] = settled;

      await expenseDoc.reference.update({
        'settlementStatus': updatedSettlementStatus,
      });

      // TODO: Send notification to expense owner
      print('✅ Settlement marked: $userId -> $settled');

      return true;
    } catch (e) {
      print('Error marking settlement: $e');
      return false;
    }
  }

  /// Get who owes what summary for a specific user
  static Future<Map<String, dynamic>> getOweSummary({
    required String budgetId,
    required String userId,
  }) async {
    try {
      final expensesSnapshot = await _firestore
          .collection('shared_budgets')
          .doc(budgetId)
          .collection('expenses')
          .get();
      
      final expenses = expensesSnapshot.docs
          .map((doc) => MemberExpense.fromMap(doc.data(), doc.id))
          .where((e) => e.isSplit)
          .toList();

      double youOwe = 0.0;
      double owedToYou = 0.0;
      Map<String, double> oweToOthers = {};
      Map<String, double> othersOweYou = {};

      for (var expense in expenses) {
        // Expenses where you owe money
        if (expense.splitWith.contains(userId) && 
            expense.userId != userId &&
            !expense.hasUserSettled(userId)) {
          final amount = expense.getShareForUser(userId);
          youOwe += amount;
          oweToOthers[expense.userId] = (oweToOthers[expense.userId] ?? 0.0) + amount;
        }
        
        // Expenses where others owe you
        if (expense.userId == userId) {
          for (String memberId in expense.splitWith) {
            if (memberId != userId && !expense.hasUserSettled(memberId)) {
              final amount = expense.getShareForUser(memberId);
              owedToYou += amount;
              othersOweYou[memberId] = (othersOweYou[memberId] ?? 0.0) + amount;
            }
          }
        }
      }

      return {
        'youOwe': youOwe,
        'owedToYou': owedToYou,
        'netBalance': owedToYou - youOwe,
        'oweToOthers': oweToOthers,
        'othersOweYou': othersOweYou,
      };
    } catch (e) {
      print('Error getting owe summary: $e');
      return {
        'youOwe': 0.0,
        'owedToYou': 0.0,
        'netBalance': 0.0,
        'oweToOthers': {},
        'othersOweYou': {},
      };
    }
  }

  /// Update shared budget amount
  static Future<bool> updateBudgetAmount({
    required String budgetId,
    required double newAmount,
  }) async {
    try {
      await _firestore.collection('shared_budgets').doc(budgetId).update({
        'amount': newAmount,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    } catch (e) {
      print('Error updating budget amount: $e');
      return false;
    }
  }

  /// Remove member from shared budget
  static Future<bool> removeMember({
    required String budgetId,
    required String userId,
  }) async {
    try {
      final budgetDoc = await _firestore.collection('shared_budgets').doc(budgetId).get();
      final budget = SharedBudget.fromMap(budgetDoc.data()!, budgetId);

      final updatedMembers = budget.members
          .where((m) => m.userId != userId)
          .map((m) => m.toMap())
          .toList();

      await budgetDoc.reference.update({
        'memberIds': FieldValue.arrayRemove([userId]), // Remove from simple array
        'members': updatedMembers,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      return true;
    } catch (e) {
      print('Error removing member: $e');
      return false;
    }
  }

  /// Leave shared budget
  static Future<bool> leaveSharedBudget(String budgetId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      return await removeMember(budgetId: budgetId, userId: user.uid);
    } catch (e) {
      print('Error leaving shared budget: $e');
      return false;
    }
  }

  /// Delete shared budget (owner only)
  static Future<bool> deleteSharedBudget(String budgetId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final budgetDoc = await _firestore.collection('shared_budgets').doc(budgetId).get();
      final budget = SharedBudget.fromMap(budgetDoc.data()!, budgetId);

      if (budget.ownerId != user.uid) {
        throw Exception('Only the owner can delete this budget');
      }

      // Delete all expenses
      final expensesSnapshot = await _firestore
          .collection('shared_budgets')
          .doc(budgetId)
          .collection('expenses')
          .get();

      for (var doc in expensesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete budget
      await budgetDoc.reference.delete();

      return true;
    } catch (e) {
      print('Error deleting shared budget: $e');
      return false;
    }
  }

  /// Regenerate invite code
  static Future<String?> regenerateInviteCode(String budgetId) async {
    try {
      final newCode = _generateInviteCode();
      await _firestore.collection('shared_budgets').doc(budgetId).update({
        'inviteCode': newCode,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return newCode;
    } catch (e) {
      print('Error regenerating invite code: $e');
      return null;
    }
  }
}

