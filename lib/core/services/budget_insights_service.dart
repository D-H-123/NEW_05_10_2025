import 'package:flutter/material.dart';

class BudgetInsight {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final String type; // 'success', 'warning', 'info', 'tip'

  BudgetInsight({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.type,
  });
}

class BudgetInsightsService {
  /// Generates personalized insights based on spending data
  static List<BudgetInsight> generateInsights({
    required List<dynamic> allBills,
    required double? monthlyBudget,
    required double currentMonthSpending,
    required int currentStreak,
  }) {
    final insights = <BudgetInsight>[];
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);

    // Filter bills for current and last month
    final currentMonthBills = allBills.where((bill) {
      final date = bill.date;
      if (date == null) return false;
      return date.year == currentMonth.year &&
          date.month == currentMonth.month;
    }).toList();

    final lastMonthBills = allBills.where((bill) {
      final date = bill.date;
      if (date == null) return false;
      return date.year == lastMonth.year &&
          date.month == lastMonth.month;
    }).toList();

    final lastMonthSpending = lastMonthBills.fold<double>(
      0.0,
      (sum, bill) => sum + ((bill.total as num?)?.toDouble() ?? 0.0),
    );

    // ========== INSIGHT 1: Spending Trend ==========
    if (lastMonthSpending > 0 && monthlyBudget != null) {
      final percentageChange = ((currentMonthSpending - lastMonthSpending) / lastMonthSpending * 100);
      
      if (percentageChange < -10) {
        insights.add(BudgetInsight(
          title: '📉 Great Progress!',
          message: 'You\'re spending ${percentageChange.abs().toStringAsFixed(0)}% less than last month. Keep it up!',
          icon: Icons.trending_down,
          color: const Color(0xFF4CAF50),
          type: 'success',
        ));
      } else if (percentageChange > 20) {
        insights.add(BudgetInsight(
          title: '📈 Spending Alert',
          message: 'Your spending is ${percentageChange.toStringAsFixed(0)}% higher than last month. Review your expenses.',
          icon: Icons.trending_up,
          color: const Color(0xFFFF5722),
          type: 'warning',
        ));
      }
    }

    // ========== INSIGHT 2: Category Analysis ==========
    final categorySpending = <String, double>{};
    for (var bill in currentMonthBills) {
      final category = bill.categoryId ?? 'Other';
      final total = (bill.total as num?)?.toDouble() ?? 0.0;
      categorySpending[category] = (categorySpending[category] ?? 0.0) + total;
    }

    if (categorySpending.isNotEmpty) {
      final topCategory = categorySpending.entries.reduce((a, b) => a.value > b.value ? a : b);
      final percentage = (topCategory.value / currentMonthSpending * 100);
      
      if (percentage > 40) {
        insights.add(BudgetInsight(
          title: '🎯 Top Spending: ${topCategory.key}',
          message: '${percentage.toStringAsFixed(0)}% of your budget goes to ${topCategory.key}. Consider alternatives to save more.',
          icon: Icons.pie_chart,
          color: const Color(0xFF2196F3),
          type: 'info',
        ));
      }
    }

    // ========== INSIGHT 3: Streak Motivation ==========
    if (currentStreak > 0 && currentStreak < 7) {
      insights.add(BudgetInsight(
        title: '🔥 Streak Building',
        message: '$currentStreak day${currentStreak > 1 ? 's' : ''} under budget! Reach 7 days for your first milestone.',
        icon: Icons.local_fire_department,
        color: const Color(0xFFFF9800),
        type: 'success',
      ));
    } else if (currentStreak >= 7) {
      insights.add(BudgetInsight(
        title: '💪 Streak Master!',
        message: 'Amazing! You\'ve stayed under budget for $currentStreak days straight.',
        icon: Icons.emoji_events,
        color: const Color(0xFFFFD700),
        type: 'success',
      ));
    }

    // ========== INSIGHT 4: Budget Pace ==========
    if (monthlyBudget != null && monthlyBudget > 0) {
      final dayOfMonth = now.day;
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final expectedSpending = (monthlyBudget / daysInMonth) * dayOfMonth;
      final difference = currentMonthSpending - expectedSpending;

      if (difference < -50 && dayOfMonth > 5) {
        insights.add(BudgetInsight(
          title: '🎉 Under Target!',
          message: 'You\'re \$${difference.abs().toStringAsFixed(0)} under the expected spending for day $dayOfMonth.',
          icon: Icons.check_circle,
          color: const Color(0xFF4CAF50),
          type: 'success',
        ));
      } else if (difference > 100 && dayOfMonth > 5) {
        insights.add(BudgetInsight(
          title: '⚡ Pace Alert',
          message: 'You\'re \$${difference.toStringAsFixed(0)} ahead of target. Slow down to stay on track.',
          icon: Icons.speed,
          color: const Color(0xFFFF9800),
          type: 'warning',
        ));
      }
    }

    // ========== INSIGHT 5: Weekend vs Weekday ==========
    double weekendSpending = 0;
    double weekdaySpending = 0;
    for (var bill in currentMonthBills) {
      final date = bill.date;
      if (date != null) {
        final total = (bill.total as num?)?.toDouble() ?? 0.0;
        if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
          weekendSpending += total;
        } else {
          weekdaySpending += total;
        }
      }
    }

    if (weekendSpending > 0 && weekdaySpending > 0) {
      final ratio = weekendSpending / (weekendSpending + weekdaySpending) * 100;
      if (ratio > 50) {
        insights.add(BudgetInsight(
          title: '🎮 Weekend Warrior',
          message: '${ratio.toStringAsFixed(0)}% of spending happens on weekends. Plan ahead to reduce impulse purchases.',
          icon: Icons.weekend,
          color: const Color(0xFF9C27B0),
          type: 'tip',
        ));
      }
    }

    // ========== INSIGHT 6: Average Transaction Size ==========
    if (currentMonthBills.isNotEmpty) {
      final avgTransaction = currentMonthSpending / currentMonthBills.length;
      
      if (avgTransaction > 100) {
        insights.add(BudgetInsight(
          title: '💳 Big Spender Alert',
          message: 'Your average transaction is \$${avgTransaction.toStringAsFixed(0)}. Look for bulk deals to save money.',
          icon: Icons.shopping_bag,
          color: const Color(0xFF00BCD4),
          type: 'tip',
        ));
      } else if (avgTransaction < 20 && currentMonthBills.length > 20) {
        insights.add(BudgetInsight(
          title: '🛒 Frequent Purchases',
          message: 'You make many small purchases (\$${avgTransaction.toStringAsFixed(0)} avg). Batch shopping could save time & money.',
          icon: Icons.receipt_long,
          color: const Color(0xFF00BCD4),
          type: 'tip',
        ));
      }
    }

    // ========== INSIGHT 7: No Budget Set ==========
    if (monthlyBudget == null || monthlyBudget == 0) {
      insights.add(BudgetInsight(
        title: '🎯 Set a Budget',
        message: 'Start tracking your spending progress by setting a monthly budget goal.',
        icon: Icons.flag,
        color: const Color(0xFF16213e),
        type: 'info',
      ));
    }

    // ========== INSIGHT 8: End of Month Rush ==========
    if (monthlyBudget != null && monthlyBudget > 0) {
      final daysLeft = DateTime(now.year, now.month + 1, 0).day - now.day;
      final remaining = monthlyBudget - currentMonthSpending;
      final dailyAllowance = remaining / (daysLeft > 0 ? daysLeft : 1);

      if (daysLeft <= 7 && daysLeft > 0 && remaining > 0) {
        insights.add(BudgetInsight(
          title: '🏁 Final Week',
          message: '$daysLeft days left! Spend \$${dailyAllowance.toStringAsFixed(0)}/day to stay under budget.',
          icon: Icons.calendar_today,
          color: const Color(0xFF16213e),
          type: 'info',
        ));
      }
    }

    // ========== INSIGHT 9: Comparison to Best Month ==========
    if (allBills.isNotEmpty) {
      final monthlyTotals = <String, double>{};
      for (var bill in allBills) {
        final date = bill.date;
        if (date != null) {
          final key = '${date.year}-${date.month}';
          final total = (bill.total as num?)?.toDouble() ?? 0.0;
          monthlyTotals[key] = (monthlyTotals[key] ?? 0.0) + total;
        }
      }

      if (monthlyTotals.length > 1) {
        final sortedMonths = monthlyTotals.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
        final bestMonth = sortedMonths.first;
        final currentMonthKey = '${now.year}-${now.month}';
        
        if (currentMonthKey != bestMonth.key && currentMonthSpending < bestMonth.value * 1.2) {
          final diff = currentMonthSpending - bestMonth.value;
          if (diff.abs() < 50) {
            insights.add(BudgetInsight(
              title: '🏆 Near Your Best!',
              message: 'You\'re close to your lowest spending month! Stay focused.',
              icon: Icons.star,
              color: const Color(0xFFFFD700),
              type: 'success',
            ));
          }
        }
      }
    }

    // Return top 3 most relevant insights
    // Prioritize: warnings > success > tips > info
    final priorityOrder = {'warning': 1, 'success': 2, 'tip': 3, 'info': 4};
    insights.sort((a, b) => (priorityOrder[a.type] ?? 5).compareTo(priorityOrder[b.type] ?? 5));
    
    return insights.take(3).toList();
  }
}

