import 'package:flutter/material.dart';
import '../../../core/models/shared_budget.dart';

/// ✅ Optimized: Extracted budget overview card widget
/// Shows budget progress, remaining amount, and status
class BudgetOverviewCard extends StatelessWidget {
  final SharedBudget budget;
  final List<MemberExpense> expenses;

  const BudgetOverviewCard({
    super.key,
    required this.budget,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    final totalSpending = budget.calculateTotalSpending(expenses);
    final remaining = budget.amount - totalSpending;
    final percentage = (totalSpending / budget.amount * 100).clamp(0, 100);

    Color progressColor;
    String statusText;
    IconData statusIcon;

    if (percentage < 70) {
      progressColor = Colors.green;
      statusText = 'On track';
      statusIcon = Icons.check_circle;
    } else if (percentage < 100) {
      progressColor = Colors.orange;
      statusText = 'Watch spending';
      statusIcon = Icons.warning;
    } else {
      progressColor = Colors.red;
      statusText = 'Over budget';
      statusIcon = Icons.error;
    }

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                budget.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: progressColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: progressColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: progressColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                remaining >= 0
                    ? '\$${remaining.toStringAsFixed(2)}'
                    : '\$${remaining.abs().toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  remaining >= 0 ? 'left' : 'overspending',
                  style: TextStyle(
                    fontSize: 14,
                    color: remaining >= 0 ? Colors.grey[600] : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${totalSpending.toStringAsFixed(2)} of \$${budget.amount.toStringAsFixed(2)} spent',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${percentage.toStringAsFixed(1)}% of budget used',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

