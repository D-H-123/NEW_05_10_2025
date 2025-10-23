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

  /// Add expense to shared budget
  static Future<bool> addExpense({
    required String budgetId,
    required double amount,
    required String category,
    String? description,
    String? receiptUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final expense = MemberExpense(
        id: '',
        userId: user.uid,
        userName: user.displayName ?? 'Unknown',
        amount: amount,
        category: category,
        description: description,
        date: DateTime.now(),
        receiptUrl: receiptUrl,
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

