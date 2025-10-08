import 'dart:math';

class SubscriptionUtils {
  /// Returns remaining days based on [startDate] and [planType].
  /// Supported plan types: 'weekly' (7), 'monthly' (30), 'yearly' (365).
  /// Accepts common variants and trims/case-folds input. Falls back to 0 if expired.
  static int getRemainingDays(DateTime startDate, String planType) {
    final normalized = planType.trim().toLowerCase();
    int totalDays;
    if (normalized.startsWith('week')) {
      totalDays = 7;
    } else if (normalized.startsWith('month')) {
      totalDays = 30;
    } else if (normalized.startsWith('year')) {
      totalDays = 365;
    } else {
      // Unknown plan
      totalDays = 0;
    }

    if (totalDays == 0) return 0;

    final endDate = startDate.add(Duration(days: totalDays));
    final now = DateTime.now();
    final remaining = endDate.difference(DateTime(now.year, now.month, now.day)).inDays;
    return max(0, remaining);
  }

  /// Returns total cycle days for supported plan types.
  static int getCycleDays(String planType) {
    final normalized = planType.trim().toLowerCase();
    if (normalized.startsWith('week')) return 7;
    if (normalized.startsWith('month')) return 30;
    if (normalized.startsWith('year')) return 365;
    return 0;
  }
}


