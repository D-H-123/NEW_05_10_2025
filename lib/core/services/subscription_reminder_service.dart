import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:async';
import 'dart:io';

class SubscriptionReminderService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  // Notification IDs
  static const int _renewalReminderId = 1001;
  static const int _trialEndingId = 1002;
  static const int _subscriptionExpiredId = 1003;
  static const int _usageLimitId = 1004;
  
  // Initialize the notification service
  static Future<void> initialize() async {
    // Initialize timezone data
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Request permissions
    await _requestPermissions();
  }
  
  // Request notification permissions
  static Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }
  
  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    // Navigate to subscription page or handle the tap
    print('Notification tapped: ${response.payload}');
  }
  
  // Schedule subscription renewal reminder
  static Future<void> scheduleRenewalReminder({
    required DateTime renewalDate,
    required String subscriptionType,
    required String tier,
  }) async {
    // Cancel existing renewal reminders
    await _notifications.cancel(_renewalReminderId);
    
    // Calculate reminder times based on subscription type
    List<DateTime> reminderTimes = _calculateReminderTimes(renewalDate, subscriptionType);
    
    for (int i = 0; i < reminderTimes.length; i++) {
      final reminderTime = reminderTimes[i];
      final daysUntilRenewal = renewalDate.difference(DateTime.now()).inDays;
      
      if (reminderTime.isAfter(DateTime.now())) {
        await _notifications.zonedSchedule(
          _renewalReminderId + i,
          _getRenewalTitle(daysUntilRenewal),
          _getRenewalBody(tier, daysUntilRenewal),
          _convertToTZDateTime(reminderTime),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'subscription_reminders',
              'Subscription Reminders',
              channelDescription: 'Reminders about subscription renewals',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'subscription_renewal_$tier',
        );
      }
    }
  }
  
  // Schedule trial ending reminder
  static Future<void> scheduleTrialEndingReminder({
    required DateTime trialEndDate,
    required String tier,
  }) async {
    await _notifications.cancel(_trialEndingId);
    
    // Remind 2 days before trial ends
    final reminderDate = trialEndDate.subtract(const Duration(days: 2));
    
    if (reminderDate.isAfter(DateTime.now())) {
      await _notifications.zonedSchedule(
        _trialEndingId,
        'Trial Ending Soon!',
        'Your $tier trial ends in 2 days. Subscribe now to keep your premium features!',
        _convertToTZDateTime(reminderDate),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'trial_reminders',
            'Trial Reminders',
            channelDescription: 'Reminders about trial expiration',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'trial_ending_$tier',
      );
    }
  }
  
  // Schedule usage limit reminder
  static Future<void> scheduleUsageLimitReminder({
    required int currentScans,
    required int maxScans,
    required String tier,
  }) async {
    await _notifications.cancel(_usageLimitId);
    
    // Remind when user has used 80% of their scans
    final threshold = (maxScans * 0.8).round();
    
    if (currentScans >= threshold && currentScans < maxScans) {
      await _notifications.show(
        _usageLimitId,
        'Scan Limit Almost Reached',
        'You\'ve used $currentScans of $maxScans scans this month. Upgrade to $tier for unlimited scans!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'usage_reminders',
            'Usage Reminders',
            channelDescription: 'Reminders about scan usage limits',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'usage_limit_$tier',
      );
    }
  }
  
  // Schedule subscription expired notification
  static Future<void> scheduleSubscriptionExpiredNotification({
    required DateTime expiredDate,
    required String tier,
  }) async {
    await _notifications.cancel(_subscriptionExpiredId);
    
    // Show notification 1 day after expiration
    final notificationDate = expiredDate.add(const Duration(days: 1));
    
    if (notificationDate.isAfter(DateTime.now())) {
      await _notifications.zonedSchedule(
        _subscriptionExpiredId,
        'Subscription Expired',
        'Your $tier subscription has expired. Renew now to restore premium features!',
        _convertToTZDateTime(notificationDate),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'subscription_expired',
            'Subscription Expired',
            channelDescription: 'Notifications about expired subscriptions',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'subscription_expired_$tier',
      );
    }
  }
  
  // Calculate reminder times based on subscription type
  static List<DateTime> _calculateReminderTimes(DateTime renewalDate, String subscriptionType) {
    final now = DateTime.now();
    final daysUntilRenewal = renewalDate.difference(now).inDays;
    
    List<DateTime> reminders = [];
    
    if (subscriptionType.toLowerCase().contains('weekly')) {
      // Weekly subscriptions: remind 3 days, 1 day, and 6 hours before
      if (daysUntilRenewal >= 3) reminders.add(renewalDate.subtract(const Duration(days: 3)));
      if (daysUntilRenewal >= 1) reminders.add(renewalDate.subtract(const Duration(days: 1)));
      if (daysUntilRenewal >= 0) reminders.add(renewalDate.subtract(const Duration(hours: 6)));
    } else if (subscriptionType.toLowerCase().contains('monthly')) {
      // Monthly subscriptions: remind 7 days, 3 days, and 1 day before
      if (daysUntilRenewal >= 7) reminders.add(renewalDate.subtract(const Duration(days: 7)));
      if (daysUntilRenewal >= 3) reminders.add(renewalDate.subtract(const Duration(days: 3)));
      if (daysUntilRenewal >= 1) reminders.add(renewalDate.subtract(const Duration(days: 1)));
    } else if (subscriptionType.toLowerCase().contains('quarterly')) {
      // Quarterly subscriptions: remind 14 days, 7 days, 3 days, and 1 day before
      if (daysUntilRenewal >= 14) reminders.add(renewalDate.subtract(const Duration(days: 14)));
      if (daysUntilRenewal >= 7) reminders.add(renewalDate.subtract(const Duration(days: 7)));
      if (daysUntilRenewal >= 3) reminders.add(renewalDate.subtract(const Duration(days: 3)));
      if (daysUntilRenewal >= 1) reminders.add(renewalDate.subtract(const Duration(days: 1)));
    } else if (subscriptionType.toLowerCase().contains('yearly')) {
      // Yearly subscriptions: remind 30 days, 14 days, 7 days, and 3 days before
      if (daysUntilRenewal >= 30) reminders.add(renewalDate.subtract(const Duration(days: 30)));
      if (daysUntilRenewal >= 14) reminders.add(renewalDate.subtract(const Duration(days: 14)));
      if (daysUntilRenewal >= 7) reminders.add(renewalDate.subtract(const Duration(days: 7)));
      if (daysUntilRenewal >= 3) reminders.add(renewalDate.subtract(const Duration(days: 3)));
    }
    
    return reminders.where((date) => date.isAfter(now)).toList();
  }
  
  // Get renewal reminder title
  static String _getRenewalTitle(int daysUntilRenewal) {
    if (daysUntilRenewal == 1) {
      return 'Subscription Renews Tomorrow!';
    } else if (daysUntilRenewal <= 3) {
      return 'Subscription Renews Soon';
    } else if (daysUntilRenewal <= 7) {
      return 'Subscription Renewal Reminder';
    } else {
      return 'Subscription Renewal Coming Up';
    }
  }
  
  // Get renewal reminder body
  static String _getRenewalBody(String tier, int daysUntilRenewal) {
    final tierName = tier.toUpperCase();
    if (daysUntilRenewal == 1) {
      return 'Your $tierName subscription renews tomorrow. Make sure your payment method is up to date!';
    } else {
      return 'Your $tierName subscription renews in $daysUntilRenewal days. Keep enjoying premium features!';
    }
  }
  
  // Convert DateTime to TZDateTime
  static tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }
  
  // Cancel all subscription reminders
  static Future<void> cancelAllReminders() async {
    await _notifications.cancel(_renewalReminderId);
    await _notifications.cancel(_trialEndingId);
    await _notifications.cancel(_subscriptionExpiredId);
    await _notifications.cancel(_usageLimitId);
  }
  
  // Cancel specific reminder type
  static Future<void> cancelReminder(int reminderId) async {
    await _notifications.cancel(reminderId);
  }
  
  // Get pending notifications
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
  
  // Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await androidImplementation?.areNotificationsEnabled() ?? false;
    } else if (Platform.isIOS) {
      final iosImplementation = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final permissions = await iosImplementation?.checkPermissions();
      return permissions?.isEnabled ?? false;
    }
    return false;
  }
  
  // Open notification settings
  static Future<void> openNotificationSettings() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      // iOS doesn't have a direct way to open notification settings
      // You might want to show an alert directing users to Settings
    }
  }
}

