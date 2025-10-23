import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:smart_receipt/core/services/local_storage_service.dart';

class BudgetNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  /// Initialize notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    _isInitialized = true;
  }

  /// Request notification permissions
  static Future<bool> requestPermissions() async {
    await initialize();
    
    final androidPermission = await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    
    final iosPermission = await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    return androidPermission ?? iosPermission ?? false;
  }

  /// Schedule weekly budget summary (every Monday at 9 AM)
  static Future<void> scheduleWeeklyBudgetSummary({
    required double spent,
    required double budget,
    required double remaining,
    required int daysLeft,
    required String currencySymbol,
  }) async {
    await initialize();

    final percentage = (spent / budget * 100).toInt();
    
    String title;
    String body;
    
    if (percentage < 70) {
      title = '💰 Budget Update: You\'re doing great!';
      body = '$currencySymbol${remaining.toStringAsFixed(0)} remaining • $daysLeft days left';
    } else if (percentage < 100) {
      title = '⚠️ Budget Alert: Watch your spending';
      body = '$currencySymbol${remaining.toStringAsFixed(0)} left • Be careful!';
    } else {
      title = '🚨 Over Budget!';
      body = 'You\'ve exceeded your budget by $currencySymbol${remaining.abs().toStringAsFixed(0)}';
    }

    const androidDetails = AndroidNotificationDetails(
      'budget_weekly',
      'Weekly Budget Updates',
      channelDescription: 'Weekly summary of your budget status',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      title,
      body,
      notificationDetails,
    );
  }

  /// Send threshold alert (e.g., when 80% or 100% budget reached)
  static Future<void> sendThresholdAlert({
    required int threshold,
    required double remaining,
    required String currencySymbol,
  }) async {
    await initialize();

    String title;
    String body;

    if (threshold == 80) {
      title = '⚠️ Budget Alert: 80% Used';
      body = 'You\'ve used 80% of your budget. $currencySymbol${remaining.toStringAsFixed(0)} remaining.';
    } else if (threshold == 100) {
      title = '🚨 Budget Limit Reached!';
      body = 'You\'ve reached your monthly budget limit. Try to save!';
    } else {
      title = '📊 Budget Update';
      body = 'You\'ve used $threshold% of your budget.';
    }

    const androidDetails = AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      channelDescription: 'Alerts when you reach budget thresholds',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      threshold,
      title,
      body,
      notificationDetails,
    );
  }

  /// Send daily reminder notification
  static Future<void> sendDailyReminder({
    required double remaining,
    required int daysLeft,
    required String currencySymbol,
  }) async {
    await initialize();

    final dailyBudget = remaining / daysLeft;

    const androidDetails = AndroidNotificationDetails(
      'budget_daily',
      'Daily Budget Reminders',
      channelDescription: 'Daily reminders about your budget',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999,
      '💡 Daily Budget Tip',
      'You have $currencySymbol${remaining.toStringAsFixed(0)} for $daysLeft days. Spend up to $currencySymbol${dailyBudget.toStringAsFixed(0)}/day',
      notificationDetails,
    );
  }

  /// Send success celebration notification
  static Future<void> sendSuccessNotification({
    required double saved,
    required String currencySymbol,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'budget_success',
      'Budget Success',
      channelDescription: 'Celebrations when you stay under budget',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      888,
      '🎉 Great Job!',
      'You stayed under budget and saved $currencySymbol${saved.toStringAsFixed(0)} this month!',
      notificationDetails,
    );
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Check notification settings status
  static Future<Map<String, bool>> getNotificationSettings() async {
    final budgetEnabled = LocalStorageService.getBoolSetting('notif_budget_enabled', defaultValue: true);
    final thresholdEnabled = LocalStorageService.getBoolSetting('notif_threshold_enabled', defaultValue: true);
    final dailyEnabled = LocalStorageService.getBoolSetting('notif_daily_enabled', defaultValue: false);
    
    return {
      'budget': budgetEnabled,
      'threshold': thresholdEnabled,
      'daily': dailyEnabled,
    };
  }

  /// Save notification settings
  static Future<void> saveNotificationSettings({
    required bool budget,
    required bool threshold,
    required bool daily,
  }) async {
    await LocalStorageService.setBoolSetting('notif_budget_enabled', budget);
    await LocalStorageService.setBoolSetting('notif_threshold_enabled', threshold);
    await LocalStorageService.setBoolSetting('notif_daily_enabled', daily);
  }
}

