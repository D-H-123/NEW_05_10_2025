import 'package:smart_receipt/core/services/local_storage_service.dart';

class BudgetStreakService {
  static const String _streakKey = 'budget_streak_count';
  static const String _lastCheckKey = 'budget_streak_last_check';
  static const String _bestStreakKey = 'budget_streak_best';
  static const String _totalDaysUnderKey = 'budget_total_days_under';

  /// Get current streak count
  static int getCurrentStreak() {
    final value = LocalStorageService.getDoubleSetting(_streakKey);
    return (value ?? 0).toInt();
  }

  /// Get best streak ever
  static int getBestStreak() {
    return (LocalStorageService.getDoubleSetting(_bestStreakKey) ?? 0).toInt();
  }

  /// Get total days under budget (lifetime)
  static int getTotalDaysUnder() {
    return (LocalStorageService.getDoubleSetting(_totalDaysUnderKey) ?? 0).toInt();
  }

  /// Get last check date
  static DateTime? getLastCheckDate() {
    final timestamp = LocalStorageService.getStringSetting(_lastCheckKey);
    if (timestamp == null) return null;
    return DateTime.tryParse(timestamp);
  }

  /// Check and update streak based on current budget status
  static Future<StreakUpdateResult> checkAndUpdateStreak({
    required bool isUnderBudget,
    DateTime? customDate,
  }) async {
    final now = customDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastCheck = getLastCheckDate();
    final lastCheckDay = lastCheck != null
        ? DateTime(lastCheck.year, lastCheck.month, lastCheck.day)
        : null;

    // Don't check twice in same day
    if (lastCheckDay != null && lastCheckDay.isAtSameMomentAs(today)) {
      return StreakUpdateResult(
        currentStreak: getCurrentStreak(),
        bestStreak: getBestStreak(),
        isNewBest: false,
        milestone: null,
        streakBroken: false,
      );
    }

    int currentStreak = getCurrentStreak();
    int bestStreak = getBestStreak();
    int totalDays = getTotalDaysUnder();
    bool isNewBest = false;
    int? milestone;
    bool streakBroken = false;

    if (isUnderBudget) {
      // Check if streak continues (yesterday check)
      if (lastCheckDay != null) {
        final daysSinceLastCheck = today.difference(lastCheckDay).inDays;
        
        if (daysSinceLastCheck == 1) {
          // Consecutive day - increase streak
          currentStreak++;
        } else if (daysSinceLastCheck > 1) {
          // Missed days - reset streak
          currentStreak = 1;
          streakBroken = true;
        }
      } else {
        // First time checking
        currentStreak = 1;
      }

      // Increment total days
      totalDays++;

      // Check for new best
      if (currentStreak > bestStreak) {
        bestStreak = currentStreak;
        isNewBest = true;
      }

      // Check for milestones
      if (currentStreak % 7 == 0 && currentStreak > 0) {
        milestone = currentStreak; // Weekly milestone
      } else if ([30, 60, 90, 180, 365].contains(currentStreak)) {
        milestone = currentStreak; // Major milestone
      }
    } else {
      // Over budget - break streak
      if (currentStreak > 0) {
        streakBroken = true;
      }
      currentStreak = 0;
    }

    // Save updated values
    await LocalStorageService.setDoubleSetting(_streakKey, currentStreak.toDouble());
    await LocalStorageService.setDoubleSetting(_bestStreakKey, bestStreak.toDouble());
    await LocalStorageService.setDoubleSetting(_totalDaysUnderKey, totalDays.toDouble());
    await LocalStorageService.setStringSetting(_lastCheckKey, today.toIso8601String());

    return StreakUpdateResult(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      isNewBest: isNewBest,
      milestone: milestone,
      streakBroken: streakBroken,
    );
  }

  /// Reset streak (for testing or manual reset)
  static Future<void> resetStreak() async {
    await LocalStorageService.setDoubleSetting(_streakKey, 0);
    await LocalStorageService.setStringSetting(_lastCheckKey, '');
  }

  /// Get streak emoji based on count
  static String getStreakEmoji(int streak) {
    if (streak >= 365) return '🏆'; // Champion
    if (streak >= 180) return '👑'; // King
    if (streak >= 90) return '⭐'; // Star
    if (streak >= 30) return '💎'; // Diamond
    if (streak >= 14) return '🔥'; // Fire
    if (streak >= 7) return '⚡'; // Lightning
    if (streak >= 3) return '✨'; // Sparkles
    return '💪'; // Starting
  }

  /// Get streak message
  static String getStreakMessage(int streak) {
    if (streak >= 365) return 'Legendary! A full year!';
    if (streak >= 180) return 'Incredible! Half a year!';
    if (streak >= 90) return 'Amazing! 3 months strong!';
    if (streak >= 30) return 'Fantastic! A full month!';
    if (streak >= 14) return 'Great! Two weeks in a row!';
    if (streak >= 7) return 'Nice! A week streak!';
    if (streak >= 3) return 'Good start! Keep going!';
    if (streak >= 1) return 'You got this!';
    return 'Start your streak today!';
  }

  /// Get streak color based on count
  static int getStreakColor(int streak) {
    if (streak >= 90) return 0xFFFFD700; // Gold
    if (streak >= 30) return 0xFF9C27B0; // Purple
    if (streak >= 14) return 0xFFFF5722; // Deep Orange
    if (streak >= 7) return 0xFFFF9800; // Orange
    return 0xFF4CAF50; // Green
  }
}

class StreakUpdateResult {
  final int currentStreak;
  final int bestStreak;
  final bool isNewBest;
  final int? milestone;
  final bool streakBroken;

  StreakUpdateResult({
    required this.currentStreak,
    required this.bestStreak,
    required this.isNewBest,
    this.milestone,
    required this.streakBroken,
  });
}

