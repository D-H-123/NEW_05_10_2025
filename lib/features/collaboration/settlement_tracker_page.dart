import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/shared_budget.dart';
import '../../core/services/budget_collaboration_service.dart';

class SettlementTrackerPage extends StatefulWidget {
  final SharedBudget budget;
  final List<MemberExpense> expenses;

  const SettlementTrackerPage({
    super.key,
    required this.budget,
    required this.expenses,
  });

  @override
  State<SettlementTrackerPage> createState() => _SettlementTrackerPageState();
}

class _SettlementTrackerPageState extends State<SettlementTrackerPage> {
  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Who Owes What',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<List<MemberExpense>>(
        stream: BudgetCollaborationService.getSharedBudgetExpenses(widget.budget.id),
        builder: (context, snapshot) {
          final expenses = snapshot.data ?? [];
          final summary = _calculateSettlementSummary(currentUserId, expenses);

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4facfe).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
                            SizedBox(width: 12),
                            Text(
                              'Settlement Summary',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryItem(
                                'You Owe',
                                summary['youOwe']!,
                                Icons.arrow_upward,
                                Colors.red[100]!,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildSummaryItem(
                                'Owed to You',
                                summary['owedToYou']!,
                                Icons.arrow_downward,
                                Colors.green[100]!,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // People You Owe
                  if ((summary['youOweDetails']! as Map).isNotEmpty) ...[
                    const Text(
                      'You Owe',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...(summary['youOweDetails']! as Map<String, double>).entries.map((entry) {
                      return _buildDebtCard(
                        entry.key,
                        entry.value,
                        true,
                        expenses,
                      );
                    }).toList(),
                    const SizedBox(height: 24),
                  ],

                  // People Who Owe You
                  if ((summary['owedToYouDetails']! as Map).isNotEmpty) ...[
                    const Text(
                      'Owed to You',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...(summary['owedToYouDetails']! as Map<String, double>).entries.map((entry) {
                      return _buildDebtCard(
                        entry.key,
                        entry.value,
                        false,
                        expenses,
                      );
                    }).toList(),
                  ],

                  // All Settled
                  if ((summary['youOweDetails']! as Map).isEmpty && 
                      (summary['owedToYouDetails']! as Map).isEmpty) ...[
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              size: 80,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'All Settled!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No pending settlements',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, IconData icon, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCard(
    String userId,
    double amount,
    bool isDebt,
    List<MemberExpense> expenses,
  ) {
    final member = widget.budget.members.firstWhere(
      (m) => m.userId == userId,
      orElse: () => BudgetMember(
        userId: userId,
        name: 'Unknown',
        role: 'member',
        joinedAt: DateTime.now(),
      ),
    );

    // Get related expenses
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final relatedExpenses = expenses.where((e) {
      return e.isSplit && 
             e.splitWith.contains(userId) && 
             ((isDebt && e.userId != currentUserId) ||
              (!isDebt && e.userId == currentUserId));
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDebt ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSettlementDetails(member, amount, isDebt, relatedExpenses),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getAvatarColor(member.name),
                  ),
                  child: Center(
                    child: Text(
                      member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${relatedExpenses.length} ${relatedExpenses.length == 1 ? 'expense' : 'expenses'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDebt ? Colors.red : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _calculateSettlementSummary(String currentUserId, List<MemberExpense> expenses) {
    double youOwe = 0.0;
    double owedToYou = 0.0;
    Map<String, double> youOweDetails = {};
    Map<String, double> owedToYouDetails = {};

    for (final expense in expenses) {
      if (!expense.isSplit || expense.splitWith.isEmpty) continue;

      // If current user is NOT the payer but is in the split
      if (expense.userId != currentUserId && expense.splitWith.contains(currentUserId)) {
        final share = expense.getShareForUser(currentUserId);
        if (!expense.hasUserSettled(currentUserId)) {
          youOwe += share;
          youOweDetails[expense.userId] = (youOweDetails[expense.userId] ?? 0) + share;
        }
      }

      // If current user IS the payer
      if (expense.userId == currentUserId) {
        for (final userId in expense.splitWith) {
          if (userId != currentUserId && !expense.hasUserSettled(userId)) {
            final share = expense.getShareForUser(userId);
            owedToYou += share;
            owedToYouDetails[userId] = (owedToYouDetails[userId] ?? 0) + share;
          }
        }
      }
    }

    return {
      'youOwe': youOwe,
      'owedToYou': owedToYou,
      'youOweDetails': youOweDetails,
      'owedToYouDetails': owedToYouDetails,
    };
  }

  void _showSettlementDetails(
    BudgetMember member,
    double totalAmount,
    bool isDebt,
    List<MemberExpense> relatedExpenses,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getAvatarColor(member.name),
                      ),
                      child: Center(
                        child: Text(
                          member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isDebt ? 'You owe \$${totalAmount.toStringAsFixed(2)}' : 'Owes you \$${totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDebt ? Colors.red : Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Expense List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: relatedExpenses.length,
                  itemBuilder: (context, index) {
                    final expense = relatedExpenses[index];
                    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                    final share = expense.getShareForUser(currentUserId!);
                    final isSettled = expense.hasUserSettled(currentUserId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSettled 
                            ? Colors.green.withOpacity(0.05)
                            : Colors.orange.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSettled 
                              ? Colors.green.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  expense.category,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your share: \$${share.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isSettled && isDebt)
                            ElevatedButton(
                              onPressed: () => _markAsSettled(expense, member),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Settle', style: TextStyle(fontSize: 12)),
                            )
                          else if (isSettled)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Settled',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _markAsSettled(MemberExpense expense, BudgetMember member) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mark as Settled?'),
        content: Text('Confirm that you have settled \$${expense.getShareForUser(currentUserId).toStringAsFixed(2)} with ${member.name}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await BudgetCollaborationService.markSettlement(
        budgetId: widget.budget.id,
        expenseId: expense.id,
        userId: currentUserId,
        settled: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(success ? 'Marked as settled!' : 'Failed to update'),
              ],
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        if (success) {
          Navigator.pop(context); // Close the bottom sheet
          setState(() {}); // Refresh the page
        }
      }
    }
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.green,
      Colors.red,
      Colors.teal,
    ];
    return colors[name.hashCode % colors.length];
  }
}

