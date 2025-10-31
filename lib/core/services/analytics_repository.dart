import 'package:smart_receipt/features/storage/models/bill_model.dart';
import 'local_storage_service.dart';
import 'budget_collaboration_service.dart';

enum TimeFilter { week, month, year }
enum DataSource { local, cloud }

class AnalyticsRepository {
  final LocalStorageService localStorage;
  // final CloudStorageService cloudStorage; // For future

  AnalyticsRepository({required this.localStorage});

  Future<List<Bill>> getBills({required TimeFilter filter, DataSource source = DataSource.local}) async {
    if (source == DataSource.local) {
      final allBills = LocalStorageService.getAllBills();
      final now = DateTime.now();
      DateTime start;
      switch (filter) {
        case TimeFilter.week:
          start = now.subtract(Duration(days: now.weekday - 1));
          start = DateTime(start.year, start.month, start.day);
          break;
        case TimeFilter.month:
          start = DateTime(now.year, now.month, 1);
          break;
        case TimeFilter.year:
          start = DateTime(now.year, 1, 1);
          break;
      }
      print('[AnalyticsRepository] Filter: $filter, Start: $start, End: $now');
      final filtered = <Bill>[];
      for (final bill in allBills) {
        if (bill.date != null) {
          final isIncluded = !bill.date!.isBefore(start) && !bill.date!.isAfter(now);
          print('[AnalyticsRepository] Bill: id=${bill.id}, date=${bill.date}, included=$isIncluded');
          if (isIncluded) filtered.add(bill);
        } else {
          print('[AnalyticsRepository] Bill: id=${bill.id}, date=null, included=false');
        }
      }
      return filtered;
    }
    // else if (source == DataSource.cloud) { ... }
    throw UnimplementedError('Cloud source not implemented yet');
  }

  /// Get bills within a specific date range
  Future<List<Bill>> getBillsInDateRange(DateTime startDate, DateTime endDate) async {
    final allBills = LocalStorageService.getAllBills();
    final filtered = <Bill>[];
    
    for (final bill in allBills) {
      if (bill.date != null) {
        final isIncluded = !bill.date!.isBefore(startDate) && !bill.date!.isAfter(endDate);
        if (isIncluded) filtered.add(bill);
      }
    }
    
    return filtered;
  }

  /// Calculate total spent for a given time filter
  /// Includes shared expenses if setting is enabled
  Future<double> getTotalSpent({required TimeFilter filter}) async {
    final List<Bill> bills = await getBills(filter: filter);
    double total = bills.fold<double>(0.0, (double sum, Bill bill) => sum + (bill.total ?? 0.0));
    
    // Add shared expenses if setting is enabled
    final showSharedExpenses = LocalStorageService.getBoolSetting(LocalStorageService.kShowSharedExpenses, defaultValue: false);
    if (showSharedExpenses) {
      final sharedExpenseTotal = await _getSharedExpenseTotal(filter);
      total += sharedExpenseTotal;
    }
    
    return total;
  }

  /// Get total amount from unpaid shared expenses for a time period
  Future<double> _getSharedExpenseTotal(TimeFilter filter) async {
    try {
      final unpaidExpenses = await BudgetCollaborationService.getUnpaidSharedExpenses().first;
      if (unpaidExpenses.isEmpty) return 0.0;
      
      final now = DateTime.now();
      DateTime start;
      switch (filter) {
        case TimeFilter.week:
          start = now.subtract(Duration(days: now.weekday - 1));
          start = DateTime(start.year, start.month, start.day);
          break;
        case TimeFilter.month:
          start = DateTime(now.year, now.month, 1);
          break;
        case TimeFilter.year:
          start = DateTime(now.year, 1, 1);
          break;
      }
      
      double total = 0.0;
      for (final unpaid in unpaidExpenses) {
        final expenseDate = unpaid.expense.date;
        // Include if expense is within the time period
        if (!expenseDate.isBefore(start) && !expenseDate.isAfter(now)) {
          total += unpaid.remainingAmount;
        }
      }
      
      return total;
    } catch (e) {
      print('Error calculating shared expense total: $e');
      return 0.0;
    }
  }

  /// Calculate total spent for a specific date range
  Future<double> getTotalSpentInRange(DateTime startDate, DateTime endDate) async {
    final List<Bill> bills = await getBillsInDateRange(startDate, endDate);
    return bills.fold<double>(0.0, (double sum, Bill bill) => sum + (bill.total ?? 0.0));
  }

  /// Get previous period bills based on current filter
  Future<List<Bill>> getPreviousPeriodBills(TimeFilter currentFilter) async {
    final now = DateTime.now();
    DateTime start, end;
    
    switch (currentFilter) {
      case TimeFilter.week:
        // Previous week
        final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
        end = currentWeekStart.subtract(const Duration(days: 1));
        start = end.subtract(const Duration(days: 6));
        break;
      case TimeFilter.month:
        // Previous month
        if (now.month == 1) {
          start = DateTime(now.year - 1, 12, 1);
          end = DateTime(now.year, 1, 1);
        } else {
          start = DateTime(now.year, now.month - 1, 1);
          end = DateTime(now.year, now.month, 1).subtract(const Duration(days: 1));
        }
        break;
      case TimeFilter.year:
        // Previous year
        start = DateTime(now.year - 1, 1, 1);
        end = DateTime(now.year, 1, 1);
        break;
    }
    
    return await getBillsInDateRange(start, end);
  }

  /// Calculate percentage change compared to previous period
  Future<double> getPercentageChange({required TimeFilter filter}) async {
    final currentTotal = await getTotalSpent(filter: filter);
    final List<Bill> previousBills = await getPreviousPeriodBills(filter);
    final previousTotal = previousBills.fold<double>(0.0, (double sum, Bill bill) => sum + (bill.total ?? 0.0));
    
    return _calculatePercentageChange(currentTotal, previousTotal);
  }

  /// Robust percentage calculation with proper edge case handling
  double _calculatePercentageChange(double currentTotal, double previousTotal) {
    // Handle negative values (shouldn't happen with bills, but safety check)
    if (currentTotal < 0 || previousTotal < 0) {
      print('[AnalyticsRepository] Warning: Negative values detected - current: $currentTotal, previous: $previousTotal');
      return 0.0;
    }

    // Edge Case 1: Both periods have no spending
    if (currentTotal == 0 && previousTotal == 0) {
      return 0.0; // No change - both periods empty
    }

    // Edge Case 2: Previous period has no spending, current has spending
    if (previousTotal == 0 && currentTotal > 0) {
      return 100.0; // 100% increase (from 0 to current amount)
    }

    // Edge Case 3: Current period has no spending, previous had spending
    if (currentTotal == 0 && previousTotal > 0) {
      return -100.0; // 100% decrease (from previous amount to 0)
    }

    // Edge Case 4: Very small numbers that could cause precision issues
    const double minimumThreshold = 0.01; // $0.01 minimum
    if (previousTotal < minimumThreshold && currentTotal < minimumThreshold) {
      return 0.0; // Both amounts too small to be meaningful
    }

    // Normal calculation
    final percentageChange = ((currentTotal - previousTotal) / previousTotal) * 100;
    
    // Edge Case 5: Cap extreme percentages to prevent display issues
    const double maxPercentage = 999.9; // Cap at 999.9%
    const double minPercentage = -100.0; // Cap at -100% (can't spend less than 0)
    
    if (percentageChange > maxPercentage) {
      print('[AnalyticsRepository] Warning: Percentage capped at $maxPercentage% - calculated: $percentageChange%');
      return maxPercentage;
    }
    
    if (percentageChange < minPercentage) {
      print('[AnalyticsRepository] Warning: Percentage capped at $minPercentage% - calculated: $percentageChange%');
      return minPercentage;
    }

    // Round to 1 decimal place for cleaner display
    return double.parse(percentageChange.toStringAsFixed(1));
  }

  /// Get detailed percentage change information for debugging
  Future<Map<String, dynamic>> getPercentageChangeDetails({required TimeFilter filter}) async {
    final currentTotal = await getTotalSpent(filter: filter);
    final List<Bill> previousBills = await getPreviousPeriodBills(filter);
    final previousTotal = previousBills.fold<double>(0.0, (double sum, Bill bill) => sum + (bill.total ?? 0.0));
    final percentageChange = _calculatePercentageChange(currentTotal, previousTotal);
    
    return {
      'currentTotal': currentTotal,
      'previousTotal': previousTotal,
      'percentageChange': percentageChange,
      'currentBillsCount': (await getBills(filter: filter)).length,
      'previousBillsCount': previousBills.length,
      'filter': filter.name,
      'isValid': _isValidPercentageChange(currentTotal, previousTotal),
    };
  }

  /// Check if the percentage change calculation is valid and meaningful
  bool _isValidPercentageChange(double currentTotal, double previousTotal) {
    // Check for negative values
    if (currentTotal < 0 || previousTotal < 0) return false;
    
    // Check for both being zero (no meaningful comparison)
    if (currentTotal == 0 && previousTotal == 0) return false;
    
    // Check for very small amounts that might be data entry errors
    const double minimumMeaningfulAmount = 0.01;
    if (currentTotal < minimumMeaningfulAmount && previousTotal < minimumMeaningfulAmount) return false;
    
    return true;
  }

  /// Get spending by category for a given time filter
  Future<Map<String, double>> getSpendingByCategory({required TimeFilter filter}) async {
    final List<Bill> bills = await getBills(filter: filter);
    final categorySpending = <String, double>{};
    
    for (final Bill bill in bills) {
      final category = bill.categoryId ?? 'Uncategorized';
      categorySpending[category] = (categorySpending[category] ?? 0.0) + (bill.total ?? 0.0);
    }
    
    return categorySpending;
  }

  /// Get spending trend data for charts (daily/weekly/monthly)
  Future<List<Map<String, dynamic>>> getSpendingTrend({
    required TimeFilter filter,
    int dataPoints = 7,
  }) async {
    final now = DateTime.now();
    final trendData = <Map<String, dynamic>>[];
    
    switch (filter) {
      case TimeFilter.week:
        // Daily data for the week
        for (int i = 6; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          final startOfDay = DateTime(date.year, date.month, date.day);
          final endOfDay = startOfDay.add(const Duration(days: 1));
          
          final List<Bill> dayBills = await getBillsInDateRange(startOfDay, endOfDay);
          final dayTotal = dayBills.fold<double>(0.0, (double sum, Bill bill) => sum + (bill.total ?? 0.0));
          
          trendData.add({
            'date': startOfDay,
            'amount': dayTotal,
            'label': _getDayLabel(date.weekday),
          });
        }
        break;
        
      case TimeFilter.month:
        // Weekly data for the month
        final monthStart = DateTime(now.year, now.month, 1);
        final weeksInMonth = ((now.day - 1) / 7).ceil();
        
        for (int i = 0; i < weeksInMonth; i++) {
          final weekStart = monthStart.add(Duration(days: i * 7));
          final weekEnd = weekStart.add(const Duration(days: 7));
          
          final List<Bill> weekBills = await getBillsInDateRange(weekStart, weekEnd);
          final weekTotal = weekBills.fold<double>(0.0, (double sum, Bill bill) => sum + (bill.total ?? 0.0));
          
          trendData.add({
            'date': weekStart,
            'amount': weekTotal,
            'label': 'Week ${i + 1}',
          });
        }
        break;
        
      case TimeFilter.year:
        // Monthly data for the year
        for (int i = 1; i <= 12; i++) {
          final monthStart = DateTime(now.year, i, 1);
          final monthEnd = DateTime(now.year, i + 1, 1);
          
          final List<Bill> monthBills = await getBillsInDateRange(monthStart, monthEnd);
          final monthTotal = monthBills.fold<double>(0.0, (double sum, Bill bill) => sum + (bill.total ?? 0.0));
          
          trendData.add({
            'date': monthStart,
            'amount': monthTotal,
            'label': _getMonthLabel(i),
          });
        }
        break;
    }
    
    return trendData;
  }

  String _getDayLabel(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _getMonthLabel(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}
