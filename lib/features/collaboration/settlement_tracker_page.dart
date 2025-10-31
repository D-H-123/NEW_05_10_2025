import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/shared_budget.dart';
import '../../core/services/budget_collaboration_service.dart';

/// Simplified Settlement Tracker as Bottom Sheet
/// Features:
/// - Tab-based view (You Owe vs Owed to You)
/// - Performance optimized (calculations cached)
/// - Card-based quick actions
/// - Better visual indicators
class SettlementTrackerSheet extends StatefulWidget {
  final SharedBudget budget;

  const SettlementTrackerSheet({
    super.key,
    required this.budget,
  });

  /// Show settlement tracker as bottom sheet
  static void show(BuildContext context, SharedBudget budget) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SettlementTrackerSheet(budget: budget),
    );
  }

  @override
  State<SettlementTrackerSheet> createState() => _SettlementTrackerSheetState();
}

class _SettlementTrackerSheetState extends State<SettlementTrackerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _cachedSummary;
  List<MemberExpense>? _cachedExpenses;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _calculateSummary(List<MemberExpense> expenses) {
    if (_cachedSummary != null && 
        _cachedExpenses == expenses && 
        expenses.isNotEmpty) {
      return _cachedSummary!;
    }

    if (_currentUserId == null) {
      return {
        'youOwe': 0.0,
        'owedToYou': 0.0,
        'youOweDetails': <String, double>{},
        'owedToYouDetails': <String, double>{},
      };
    }

    double youOwe = 0.0;
    double owedToYou = 0.0;
    final Map<String, double> youOweDetails = {};
    final Map<String, double> owedToYouDetails = {};

    for (final expense in expenses) {
      if (!expense.isSplit || expense.splitWith.isEmpty) continue;

      // If current user is NOT the payer but is in the split
      if (expense.userId != _currentUserId && 
          expense.splitWith.contains(_currentUserId!)) {
        final share = expense.getShareForUser(_currentUserId!);
        if (!expense.hasUserSettled(_currentUserId!)) {
          youOwe += share;
          final payerId = expense.userId;
          youOweDetails[payerId] = (youOweDetails[payerId] ?? 0) + share;
        }
      }

      // If current user IS the payer
      if (expense.userId == _currentUserId) {
        for (final userId in expense.splitWith) {
          if (userId != _currentUserId && !expense.hasUserSettled(userId)) {
            final share = expense.getShareForUser(userId);
            owedToYou += share;
            owedToYouDetails[userId] = (owedToYouDetails[userId] ?? 0) + share;
          }
        }
      }
    }

    final summary = {
      'youOwe': youOwe,
      'owedToYou': owedToYou,
      'youOweDetails': youOweDetails,
      'owedToYouDetails': owedToYouDetails,
    };

    // Cache results
    _cachedSummary = summary;
    _cachedExpenses = List.from(expenses);

    return summary;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Container(
        height: 200,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(child: Text('Please log in')),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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

            // Summary Cards (Top Section)
            StreamBuilder<List<MemberExpense>>(
              stream: BudgetCollaborationService.getSharedBudgetExpenses(widget.budget.id),
              builder: (context, snapshot) {
                final expenses = snapshot.data ?? [];
                final summary = _calculateSummary(expenses);

                // Reset cache if expenses changed
                if (_cachedExpenses?.length != expenses.length) {
                  _cachedSummary = null;
                }

                return Column(
                  children: [
                    // Summary Cards Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              label: 'You Owe',
                              amount: summary['youOwe'] as double,
                              color: Colors.red,
                              icon: Icons.arrow_upward,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SummaryCard(
                              label: 'Owed to You',
                              amount: summary['owedToYou'] as double,
                              color: Colors.green,
                              icon: Icons.arrow_downward,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tab Bar
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF4facfe),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF4facfe),
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      tabs: const [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_upward, size: 18),
                              SizedBox(width: 6),
                              Text('You Owe'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_downward, size: 18),
                              SizedBox(width: 6),
                              Text('Owed to You'),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Tab Content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _YouOweTab(
                            budget: widget.budget,
                            expenses: expenses,
                            summary: summary['youOweDetails'] as Map<String, double>,
                          ),
                          _OwedToYouTab(
                            budget: widget.budget,
                            expenses: expenses,
                            summary: summary['owedToYouDetails'] as Map<String, double>,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Summary Card Widget (Reusable)
class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
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
}

/// "You Owe" Tab Content
class _YouOweTab extends StatelessWidget {
  final SharedBudget budget;
  final List<MemberExpense> expenses;
  final Map<String, double> summary;

  const _YouOweTab({
    required this.budget,
    required this.expenses,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: Colors.green[300],
            ),
            const SizedBox(height: 16),
            Text(
              'All Clear!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You don\'t owe anyone',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: summary.length,
      itemBuilder: (context, index) {
        final entry = summary.entries.elementAt(index);
        final member = budget.members.firstWhere(
          (m) => m.userId == entry.key,
          orElse: () => BudgetMember(
            userId: entry.key,
            name: 'Unknown',
            role: 'member',
            joinedAt: DateTime.now(),
          ),
        );

        // Get related expenses for quick settlement
        final relatedExpenses = expenses.where((e) =>
          e.isSplit &&
          e.userId == entry.key &&
          e.splitWith.contains(FirebaseAuth.instance.currentUser?.uid ?? '') &&
          !e.hasUserSettled(FirebaseAuth.instance.currentUser?.uid ?? '')
        ).toList();

        return _SettlementCard(
          member: member,
          amount: entry.value,
          isDebt: true,
          relatedExpenses: relatedExpenses,
          budgetId: budget.id,
        );
      },
    );
  }
}

/// "Owed to You" Tab Content
class _OwedToYouTab extends StatelessWidget {
  final SharedBudget budget;
  final List<MemberExpense> expenses;
  final Map<String, double> summary;

  const _OwedToYouTab({
    required this.budget,
    required this.expenses,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 64,
              color: Colors.blue[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No Pending Payments',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No one owes you anything',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: summary.length,
      itemBuilder: (context, index) {
        final entry = summary.entries.elementAt(index);
        final member = budget.members.firstWhere(
          (m) => m.userId == entry.key,
          orElse: () => BudgetMember(
            userId: entry.key,
            name: 'Unknown',
            role: 'member',
            joinedAt: DateTime.now(),
          ),
        );

        // Get related expenses
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final relatedExpenses = expenses.where((e) =>
          e.isSplit &&
          e.userId == currentUserId &&
          e.splitWith.contains(entry.key) &&
          !e.hasUserSettled(entry.key)
        ).toList();

        return _SettlementCard(
          member: member,
          amount: entry.value,
          isDebt: false,
          relatedExpenses: relatedExpenses,
          budgetId: budget.id,
        );
      },
    );
  }
}

/// Compact Settlement Card with Quick Actions
class _SettlementCard extends StatelessWidget {
  final BudgetMember member;
  final double amount;
  final bool isDebt;
  final List<MemberExpense> relatedExpenses;
  final String budgetId;

  const _SettlementCard({
    required this.member,
    required this.amount,
    required this.isDebt,
    required this.relatedExpenses,
    required this.budgetId,
  });

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

  Future<void> _handleQuickSettle(BuildContext context) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Show confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isDebt ? 'Mark as Paid?' : 'Mark as Received?'),
        content: Text(
          isDebt
              ? 'Confirm that you paid \$${amount.toStringAsFixed(2)} to ${member.name}'
              : 'Confirm that ${member.name} paid you \$${amount.toStringAsFixed(2)}',
        ),
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

    if (confirmed != true) return;

    // Mark all related expenses as settled
    bool allSuccess = true;
    for (final expense in relatedExpenses) {
      final userIdToSettle = isDebt ? currentUserId : member.userId;
      final success = await BudgetCollaborationService.markSettlement(
        budgetId: budgetId,
        expenseId: expense.id,
        userId: userIdToSettle,
        settled: true,
      );
      if (!success) allSuccess = false;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                allSuccess ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(allSuccess
                  ? 'Marked as settled!'
                  : 'Some settlements failed to update'),
            ],
          ),
          backgroundColor: allSuccess ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDebt
              ? Colors.red.withOpacity(0.2)
              : Colors.green.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
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

            // Name and Details
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
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Amount and Quick Action
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
                const SizedBox(height: 8),
                // Quick Settle Button (only for debts)
                if (isDebt)
                  ElevatedButton.icon(
                    onPressed: () => _handleQuickSettle(context),
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('Settle', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'Pending',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
