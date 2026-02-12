import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/storage/bill/bill_provider.dart';

/// ✅ Optimized: Memoized provider for current month spending
final currentMonthSpendingProvider = Provider<double>((ref) {
  final bills = ref.watch(billProvider);
  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month);
  final nextMonth = DateTime(now.year, now.month + 1);

  return bills
      .where((bill) =>
          bill.date != null &&
          bill.date!.isAfter(currentMonth.subtract(const Duration(days: 1))) &&
          bill.date!.isBefore(nextMonth))
      .fold<double>(0.0, (sum, bill) => sum + (bill.total ?? 0.0));
});

/// ✅ Optimized: Memoized provider for monthly spending by year
final monthlySpendingProvider = Provider.family<Map<int, double>, int>((ref, year) {
  final bills = ref.watch(billProvider);
  final monthlyTotals = <int, double>{};

  // Initialize all months from Jan to current month with 0
  for (int month = 1; month <= 12; month++) {
    monthlyTotals[month] = 0.0;
  }

  // Calculate spending for each month
  for (final bill in bills) {
    if (bill.date != null && bill.date!.year == year) {
      final month = bill.date!.month;
      monthlyTotals[month] = (monthlyTotals[month] ?? 0.0) + (bill.total ?? 0.0);
    }
  }

  return monthlyTotals;
});

/// ✅ Optimized: Provider for current year's monthly spending
final currentYearMonthlySpendingProvider = Provider<Map<int, double>>((ref) {
  return ref.watch(monthlySpendingProvider(DateTime.now().year));
});

/// ✅ Optimized: Provider for percentage change between months
final monthlyPercentageChangeProvider = Provider.family<double, int>((ref, selectedMonth) {
  final monthlySpending = ref.watch(currentYearMonthlySpendingProvider);
  final currentAmount = monthlySpending[selectedMonth + 1] ?? 0.0;
  
  if (selectedMonth == 0) return 0.0; // No previous month for January
  
  final previousAmount = monthlySpending[selectedMonth] ?? 0.0;
  
  if (previousAmount == 0) {
    return currentAmount > 0 ? 100.0 : 0.0;
  }
  
  return ((currentAmount - previousAmount) / previousAmount) * 100;
});

/// Data class for daily sparkline (actual spending + forecast)
class DailySparklineData {
  /// Actual spending amount for each day from day 1 to today (length = todayDay)
  final List<double> actualValues;

  /// Projected spending amount for each remaining day (today+1 to end of month)
  final List<double> forecastValues;

  /// Total number of days in the current month
  final int totalDaysInMonth;

  /// Today's day-of-month (1-based)
  final int todayDay;

  const DailySparklineData({
    required this.actualValues,
    required this.forecastValues,
    required this.totalDaysInMonth,
    required this.todayDay,
  });
}

/// Provider that builds daily (per-day) spending for the current month
/// and projects a forecast for remaining days using previous month's daily amounts.
///
/// Both actual and forecast are per-day values (e.g. day 2 shows 100, not 150).
final dailySparklineDataProvider = Provider<DailySparklineData>((ref) {
  final bills = ref.watch(billProvider);
  final now = DateTime.now();
  final today = now.day;
  final totalDaysInMonth = DateTime(now.year, now.month + 1, 0).day;

  // ── Step 1: Actual spending per day (current month, day 1 → today) ──
  final dailySpending = List<double>.filled(totalDaysInMonth + 1, 0.0);
  for (final bill in bills) {
    if (bill.date != null &&
        bill.date!.year == now.year &&
        bill.date!.month == now.month &&
        bill.date!.day <= today) {
      dailySpending[bill.date!.day] += (bill.total ?? 0.0);
    }
  }

  final actualValues = <double>[];
  for (int day = 1; day <= today; day++) {
    actualValues.add(dailySpending[day]);
  }

  // ── Step 2: Previous month's actual spending per day (day 1 .. daysInPrevMonth) ──
  final prevMonth = now.month == 1 ? 12 : now.month - 1;
  final prevYear = now.month == 1 ? now.year - 1 : now.year;
  final daysInPrevMonth = DateTime(prevYear, prevMonth + 1, 0).day;

  final prevMonthDailySpending = List<double>.filled(daysInPrevMonth + 1, 0.0);
  for (final bill in bills) {
    if (bill.date != null &&
        bill.date!.year == prevYear &&
        bill.date!.month == prevMonth) {
      final d = bill.date!.day;
      if (d >= 1 && d <= daysInPrevMonth) {
        prevMonthDailySpending[d] += (bill.total ?? 0.0);
      }
    }
  }

  // ── Step 3: Forecast = per-day amount from previous month (day N → prev month day N) ──
  final forecastValues = <double>[];
  for (int day = today + 1; day <= totalDaysInMonth; day++) {
    final prevDay = day <= daysInPrevMonth ? day : daysInPrevMonth;
    forecastValues.add(prevMonthDailySpending[prevDay]);
  }

  return DailySparklineData(
    actualValues: actualValues,
    forecastValues: forecastValues,
    totalDaysInMonth: totalDaysInMonth,
    todayDay: today,
  );
});

