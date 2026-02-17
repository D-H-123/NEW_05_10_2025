import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/currency_service.dart';
import '../../core/services/exchange_rate_service.dart';
import '../storage/bill/bill_provider.dart';

/// Current month spending in display currency (converted at display time).
final currentMonthSpendingProvider = FutureProvider<double>((ref) async {
  final bills = ref.watch(billProvider);
  final displayCurrency = ref.watch(currencyProvider).currencyCode;
  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month);
  final nextMonth = DateTime(now.year, now.month + 1);
  final service = ExchangeRateService.instance;

  double total = 0.0;
  for (final bill in bills) {
    if (bill.date == null) continue;
    if (!bill.date!.isAfter(currentMonth.subtract(const Duration(days: 1))) ||
        !bill.date!.isBefore(nextMonth)) continue;
    final converted = await service.convert(
      bill.total ?? 0.0,
      bill.currency ?? 'USD',
      displayCurrency,
    );
    total += converted;
  }
  return total;
});

/// Monthly spending by year in display currency (converted at display time).
final monthlySpendingProvider =
    FutureProvider.family<Map<int, double>, int>((ref, year) async {
  final bills = ref.watch(billProvider);
  final displayCurrency = ref.watch(currencyProvider).currencyCode;
  final service = ExchangeRateService.instance;
  final monthlyTotals = <int, double>{};
  for (int month = 1; month <= 12; month++) {
    monthlyTotals[month] = 0.0;
  }

  for (final bill in bills) {
    if (bill.date == null || bill.date!.year != year) continue;
    final month = bill.date!.month;
    final converted = await service.convert(
      bill.total ?? 0.0,
      bill.currency ?? 'USD',
      displayCurrency,
    );
    monthlyTotals[month] = (monthlyTotals[month] ?? 0.0) + converted;
  }
  return monthlyTotals;
});

/// Current year's monthly spending (converted).
final currentYearMonthlySpendingProvider =
    FutureProvider<Map<int, double>>((ref) async {
  return ref.watch(monthlySpendingProvider(DateTime.now().year).future);
});

/// Percentage change between months (uses converted amounts).
final monthlyPercentageChangeProvider =
    FutureProvider.family<double, int>((ref, selectedMonth) async {
  final monthlySpending =
      await ref.watch(currentYearMonthlySpendingProvider.future);
  final currentAmount = monthlySpending[selectedMonth + 1] ?? 0.0;
  if (selectedMonth == 0) return 0.0;
  final previousAmount = monthlySpending[selectedMonth] ?? 0.0;
  if (previousAmount == 0) {
    return currentAmount > 0 ? 100.0 : 0.0;
  }
  return ((currentAmount - previousAmount) / previousAmount) * 100;
});

/// Data class for daily sparkline (actual spending + forecast) in display currency.
class DailySparklineData {
  final List<double> actualValues;
  final List<double> forecastValues;
  final int totalDaysInMonth;
  final int todayDay;

  const DailySparklineData({
    required this.actualValues,
    required this.forecastValues,
    required this.totalDaysInMonth,
    required this.todayDay,
  });
}

/// Daily sparkline data with amounts converted to display currency.
final dailySparklineDataProvider = FutureProvider<DailySparklineData>((ref) async {
  final bills = ref.watch(billProvider);
  final displayCurrency = ref.watch(currencyProvider).currencyCode;
  final service = ExchangeRateService.instance;
  final now = DateTime.now();
  final today = now.day;
  final totalDaysInMonth = DateTime(now.year, now.month + 1, 0).day;

  final dailySpending = List<double>.filled(totalDaysInMonth + 1, 0.0);
  for (final bill in bills) {
    if (bill.date == null ||
        bill.date!.year != now.year ||
        bill.date!.month != now.month ||
        bill.date!.day > today) continue;
    final converted = await service.convert(
      bill.total ?? 0.0,
      bill.currency ?? 'USD',
      displayCurrency,
    );
    dailySpending[bill.date!.day] += converted;
  }

  final actualValues = <double>[];
  for (int day = 1; day <= today; day++) {
    actualValues.add(dailySpending[day]);
  }

  final prevMonth = now.month == 1 ? 12 : now.month - 1;
  final prevYear = now.month == 1 ? now.year - 1 : now.year;
  final daysInPrevMonth = DateTime(prevYear, prevMonth + 1, 0).day;
  final prevMonthDailySpending = List<double>.filled(daysInPrevMonth + 1, 0.0);
  for (final bill in bills) {
    if (bill.date == null ||
        bill.date!.year != prevYear ||
        bill.date!.month != prevMonth) continue;
    final d = bill.date!.day;
    if (d < 1 || d > daysInPrevMonth) continue;
    final converted = await service.convert(
      bill.total ?? 0.0,
      bill.currency ?? 'USD',
      displayCurrency,
    );
    prevMonthDailySpending[d] += converted;
  }

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
