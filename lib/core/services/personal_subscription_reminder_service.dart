import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_receipt/features/storage/models/bill_model.dart';

class PersonalSubscriptionReminderService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static const int _renewalReminderId = 1001;
  static const String _preferencesKey = 'personal_subscription_reminder_preferences';
  
  // Reminder preferences
  static PersonalReminderPreferences _preferences = const PersonalReminderPreferences();
  
  static PersonalReminderPreferences get preferences => _preferences;

  // Initialize the service
  static Future<void> initialize() async {
    tz.initializeTimeZones();
    
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
    await _loadPreferences();
  }

  // Initialize reminders for all existing subscriptions (call this when app starts)
  static Future<void> initializeRemindersForAllSubscriptions(List<Bill> allBills) async {
    if (!_preferences.renewalEnabled) return;
    
    // Filter only subscription bills
    final subscriptionBills = allBills.where((bill) => 
      bill.subscriptionType != null && 
      bill.subscriptionType!.isNotEmpty &&
      bill.date != null
    ).toList();
    
    if (subscriptionBills.isNotEmpty) {
      await scheduleAllSubscriptionReminders(subscriptionBills);
    }
  }

  // Load preferences from storage
  static Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_preferencesKey);
      if (jsonString != null) {
        _preferences = PersonalReminderPreferences.fromJson(jsonString);
      }
    } catch (e) {
      _preferences = const PersonalReminderPreferences();
    }
  }

  // Save preferences to storage
  static Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preferencesKey, _preferences.toJson());
    } catch (e) {
      print('Error saving personal subscription reminder preferences: $e');
    }
  }

  // Update preferences
  static Future<void> updatePreferences(PersonalReminderPreferences preferences) async {
    _preferences = preferences;
    await _savePreferences();
  }

  // Update specific preference
  static Future<void> updatePreference({
    bool? renewalEnabled,
    String? userName,
  }) async {
    _preferences = _preferences.copyWith(
      renewalEnabled: renewalEnabled,
      userName: userName,
    );
    await _savePreferences();
  }

  // Schedule reminders for all personal subscriptions
  static Future<void> scheduleAllSubscriptionReminders(List<Bill> subscriptions) async {
    if (!_preferences.renewalEnabled) return;
    
    // Cancel existing reminders
    await cancelAllReminders();
    
    // Filter only subscription bills
    final subscriptionBills = subscriptions.where((bill) => 
      bill.subscriptionType != null && 
      bill.subscriptionType!.isNotEmpty &&
      bill.date != null
    ).toList();
    
    for (final subscription in subscriptionBills) {
      // Schedule renewal reminders
      await scheduleSubscriptionReminder(subscription);
      
      // Schedule end date reminders if end date is set
      if (subscription.subscriptionEndDate != null) {
        await scheduleSubscriptionEndDateReminder(subscription);
      }
    }
  }

  // Update reminders for a specific subscription when frequency changes
  static Future<void> updateSubscriptionReminders(Bill subscription) async {
    if (!_preferences.renewalEnabled) {
      return;
    }
    
    // Cancel existing reminders for this subscription
    await cancelSubscriptionReminders(subscription.id);
    
    // Schedule new reminders with updated frequency
    await scheduleSubscriptionReminder(subscription);
    
    // Schedule end date reminders if end date is set
    if (subscription.subscriptionEndDate != null) {
      await scheduleSubscriptionEndDateReminder(subscription);
      
      // If end date is tomorrow, also send an immediate notification
      final endDate = subscription.subscriptionEndDate!;
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final isTomorrow = endDate.year == tomorrow.year && 
                        endDate.month == tomorrow.month && 
                        endDate.day == tomorrow.day;
      
      if (isTomorrow) {
        await _sendImmediateEndDateNotification(subscription);
      }
    }
  }

  // Schedule reminder for a specific subscription
  static Future<void> scheduleSubscriptionReminder(Bill subscription) async {
    print('🔍 DEBUG: ===== SCHEDULE SUBSCRIPTION REMINDER =====');
    print('🔍 DEBUG: Subscription: ${subscription.title ?? subscription.vendor}');
    print('🔍 DEBUG: renewalEnabled: ${_preferences.renewalEnabled}');
    print('🔍 DEBUG: subscriptionType: ${subscription.subscriptionType}');
    
    if (!_preferences.renewalEnabled || subscription.subscriptionType == null) {
      print('🔍 DEBUG: ❌ SKIPPING - renewalEnabled: ${_preferences.renewalEnabled}, subscriptionType: ${subscription.subscriptionType}');
      return;
    }

    // Use subscription start date if available, otherwise fall back to date field
    final startDate = subscription.subscriptionStartDate ?? subscription.date;
    if (startDate == null) {
      print('🔍 DEBUG: ❌ No start date available for subscription ${subscription.title ?? subscription.vendor}');
      return;
    }

    print('🔍 DEBUG: ✅ Using start date: $startDate');
    final nextRenewalDate = _calculateNextRenewalDate(startDate, subscription.subscriptionType!);
    final reminderTimes = _calculateSmartReminderTimes(nextRenewalDate, subscription.subscriptionType!);
    
    // Separate past, today, and future reminders
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final futureReminders = reminderTimes.where((reminder) => reminder.isAfter(now)).toList();
    final todayReminders = reminderTimes.where((reminder) => 
      reminder.year == today.year && 
      reminder.month == today.month && 
      reminder.day == today.day
    ).toList();
    final pastReminders = reminderTimes.where((reminder) => 
      reminder.isBefore(today) && 
      !(reminder.year == today.year && reminder.month == today.month && reminder.day == today.day)
    ).toList();
    
    print('🔍 DEBUG: Next renewal: $nextRenewalDate');
    print('🔍 DEBUG: All reminder times: $reminderTimes');
    print('🔍 DEBUG: Future reminders: $futureReminders');
    print('🔍 DEBUG: Today reminders: $todayReminders');
    print('🔍 DEBUG: Past reminders: $pastReminders');
    
    // Send immediate notifications for today's reminders or overdue reminders
    print('🔍 DEBUG: Checking immediate notification conditions...');
    print('🔍 DEBUG: nextRenewalDate.isAfter(now): ${nextRenewalDate.isAfter(now)}');
    print('🔍 DEBUG: todayReminders.isNotEmpty: ${todayReminders.isNotEmpty}');
    print('🔍 DEBUG: pastReminders.isNotEmpty: ${pastReminders.isNotEmpty}');
    
    if (nextRenewalDate.isAfter(now) && (todayReminders.isNotEmpty || pastReminders.isNotEmpty)) {
      print('🔍 DEBUG: ✅ Sending immediate notification for today/overdue reminder');
      final daysUntilRenewal = nextRenewalDate.difference(now).inDays;
      print('🔍 DEBUG: Days until renewal: $daysUntilRenewal');
      await _sendImmediateRenewalNotification(subscription, daysUntilRenewal);
    } else {
      print('🔍 DEBUG: ❌ Not sending immediate notification - conditions not met');
    }
    
    // Schedule future reminders
    for (int i = 0; i < futureReminders.length; i++) {
      final reminderTime = futureReminders[i];
      final daysUntilRenewal = nextRenewalDate.difference(reminderTime).inDays;
      
      try {
        await _notifications.zonedSchedule(
          _renewalReminderId + subscription.id.hashCode + i, // Unique ID for each reminder
          _getEnhancedRenewalTitle(subscription, daysUntilRenewal),
          _getEnhancedRenewalBody(subscription, daysUntilRenewal),
          _convertToTZDateTime(reminderTime),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'personal_subscription_reminders',
              'Personal Subscription Reminders',
              channelDescription: 'Reminders for your personal subscription renewals',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              actions: [
                AndroidNotificationAction('view', 'View Subscription'),
                AndroidNotificationAction('dismiss', 'Dismiss'),
              ],
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: 'subscription_reminder_${subscription.id}',
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        // If exact alarms are not permitted, try with inexact scheduling
        if (e.toString().contains('exact_alarms_not_permitted')) {
          try {
            await _notifications.zonedSchedule(
              _renewalReminderId + subscription.id.hashCode + i,
              _getEnhancedRenewalTitle(subscription, daysUntilRenewal),
              _getEnhancedRenewalBody(subscription, daysUntilRenewal),
              _convertToTZDateTime(reminderTime),
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'personal_subscription_reminders',
                  'Personal Subscription Reminders',
                  channelDescription: 'Reminders for your personal subscription renewals',
                  importance: Importance.high,
                  priority: Priority.high,
                  icon: '@mipmap/ic_launcher',
                  actions: [
                    AndroidNotificationAction('view', 'View Subscription'),
                    AndroidNotificationAction('dismiss', 'Dismiss'),
                  ],
                ),
                iOS: DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
              payload: 'subscription_reminder_${subscription.id}',
              androidScheduleMode: AndroidScheduleMode.inexact,
            );
          } catch (fallbackError) {
            print('Failed to schedule reminder with inexact mode: $fallbackError');
          }
        } else {
          print('Failed to schedule subscription reminder: $e');
        }
      }
    }
  }

  // Schedule end date reminders for a subscription
  static Future<void> scheduleSubscriptionEndDateReminder(Bill subscription) async {
    print('🔍 DEBUG: scheduleSubscriptionEndDateReminder called');
    print('🔍 DEBUG: renewalEnabled: ${_preferences.renewalEnabled}');
    print('🔍 DEBUG: subscriptionEndDate: ${subscription.subscriptionEndDate}');
    
    if (!_preferences.renewalEnabled || subscription.subscriptionEndDate == null) {
      print('🔍 DEBUG: Skipping end date reminder - renewalEnabled: ${_preferences.renewalEnabled}, endDate: ${subscription.subscriptionEndDate}');
      return;
    }

    final endDate = subscription.subscriptionEndDate!;
    final reminderTimes = _calculateEndDateReminderTimes(endDate);
    
    print('🔍 DEBUG: End date: $endDate');
    print('🔍 DEBUG: Reminder times: $reminderTimes');
    
    for (int i = 0; i < reminderTimes.length; i++) {
      final reminderTime = reminderTimes[i];
      final daysUntilEnd = endDate.difference(reminderTime).inDays;
      
      try {
        await _notifications.zonedSchedule(
          _renewalReminderId + subscription.id.hashCode + 1000 + i, // Unique ID for end date reminders
          _getEnhancedEndDateTitle(subscription, daysUntilEnd),
          _getEnhancedEndDateBody(subscription, daysUntilEnd),
          _convertToTZDateTime(reminderTime),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'personal_subscription_end_reminders',
              'Personal Subscription End Reminders',
              channelDescription: 'Reminders for your personal subscription end dates',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              actions: [
                AndroidNotificationAction('view', 'View Subscription'),
                AndroidNotificationAction('dismiss', 'Dismiss'),
              ],
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: 'subscription_end_reminder_${subscription.id}',
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        // If exact alarms are not permitted, try with inexact scheduling
        if (e.toString().contains('exact_alarms_not_permitted')) {
          try {
            await _notifications.zonedSchedule(
              _renewalReminderId + subscription.id.hashCode + 1000 + i,
              _getEnhancedEndDateTitle(subscription, daysUntilEnd),
              _getEnhancedEndDateBody(subscription, daysUntilEnd),
              _convertToTZDateTime(reminderTime),
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'personal_subscription_end_reminders',
                  'Personal Subscription End Reminders',
                  channelDescription: 'Reminders for your personal subscription end dates',
                  importance: Importance.high,
                  priority: Priority.high,
                  icon: '@mipmap/ic_launcher',
                  actions: [
                    AndroidNotificationAction('view', 'View Subscription'),
                    AndroidNotificationAction('dismiss', 'Dismiss'),
                  ],
                ),
                iOS: DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
              payload: 'subscription_end_reminder_${subscription.id}',
              androidScheduleMode: AndroidScheduleMode.inexact,
            );
          } catch (fallbackError) {
            print('Failed to schedule end date reminder with inexact mode: $fallbackError');
          }
        } else {
          print('Failed to schedule end date reminder: $e');
        }
      }
    }
  }

  // Calculate next renewal date based on subscription frequency from start date
  static DateTime _calculateNextRenewalDate(DateTime startDate, String frequency) {
    final now = DateTime.now();
    DateTime nextRenewal = startDate;
    
    // Calculate all renewals from start date until we find the next one
    while (nextRenewal.isBefore(now) || nextRenewal.isAtSameMomentAs(now)) {
      switch (frequency.toLowerCase()) {
        case 'weekly':
          nextRenewal = nextRenewal.add(const Duration(days: 7));
          break;
        case 'monthly':
          nextRenewal = DateTime(nextRenewal.year, nextRenewal.month + 1, nextRenewal.day);
          break;
        case 'yearly':
          nextRenewal = DateTime(nextRenewal.year + 1, nextRenewal.month, nextRenewal.day);
          break;
        default:
          // Default to monthly
          nextRenewal = DateTime(nextRenewal.year, nextRenewal.month + 1, nextRenewal.day);
      }
    }
    
    print('🔍 DEBUG: Start date: $startDate, Frequency: $frequency, Next renewal: $nextRenewal');
    return nextRenewal;
  }

  // Calculate smart reminder times based on subscription frequency
  static List<DateTime> _calculateSmartReminderTimes(DateTime renewalDate, String frequency) {
    final now = DateTime.now();
    List<DateTime> reminders = [];
    
    switch (frequency.toLowerCase()) {
      case 'weekly':
        // Weekly subscriptions: remind 2 days and 1 day before
        reminders.addAll([
          renewalDate.subtract(const Duration(days: 2)),
          renewalDate.subtract(const Duration(days: 1)),
        ]);
        break;
      case 'monthly':
        // Monthly subscriptions: remind 7 days, 3 days, and 1 day before
        reminders.addAll([
          renewalDate.subtract(const Duration(days: 7)),
          renewalDate.subtract(const Duration(days: 3)),
          renewalDate.subtract(const Duration(days: 1)),
        ]);
        break;
      case 'yearly':
        // Yearly subscriptions: remind 30 days, 14 days, 7 days, and 3 days before
        reminders.addAll([
          renewalDate.subtract(const Duration(days: 30)),
          renewalDate.subtract(const Duration(days: 14)),
          renewalDate.subtract(const Duration(days: 7)),
          renewalDate.subtract(const Duration(days: 3)),
        ]);
        break;
      default:
        // Default: remind 3 days and 1 day before
        reminders.addAll([
          renewalDate.subtract(const Duration(days: 3)),
          renewalDate.subtract(const Duration(days: 1)),
        ]);
    }
    
    print('🔍 DEBUG: Raw reminders before filtering: $reminders');
    print('🔍 DEBUG: Current time: $now');
    
    // Filter out past reminders but keep today's reminders
    final filteredReminders = reminders.where((date) => 
      date.isAfter(now) || 
      (date.year == now.year && date.month == now.month && date.day == now.day)
    ).toList();
    
    print('🔍 DEBUG: Filtered reminders (including today): $filteredReminders');
    return filteredReminders;
  }

  // Calculate end date reminder times (7, 3, 1 days before)
  static List<DateTime> _calculateEndDateReminderTimes(DateTime endDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<DateTime> reminders = [];
    
    // Always remind 7 days, 3 days, and 1 day before end date
    final sevenDaysBefore = endDate.subtract(const Duration(days: 7));
    final threeDaysBefore = endDate.subtract(const Duration(days: 3));
    final oneDayBefore = endDate.subtract(const Duration(days: 1));
    
    // Add reminders that are today or in the future
    if (sevenDaysBefore.isAfter(today) || sevenDaysBefore.isAtSameMomentAs(today)) {
      reminders.add(sevenDaysBefore);
    }
    if (threeDaysBefore.isAfter(today) || threeDaysBefore.isAtSameMomentAs(today)) {
      reminders.add(threeDaysBefore);
    }
    if (oneDayBefore.isAfter(today) || oneDayBefore.isAtSameMomentAs(today)) {
      reminders.add(oneDayBefore);
    }
    
    print('🔍 DEBUG: End date: $endDate');
    print('🔍 DEBUG: Today: $today');
    print('🔍 DEBUG: Seven days before: $sevenDaysBefore');
    print('🔍 DEBUG: Three days before: $threeDaysBefore');
    print('🔍 DEBUG: One day before: $oneDayBefore');
    print('🔍 DEBUG: Final reminders: $reminders');
    
    return reminders;
  }

  // Enhanced notification titles with subscription details
  static String _getEnhancedRenewalTitle(Bill subscription, int daysUntilRenewal) {
    final userName = _preferences.userName ?? 'there';
    final subscriptionName = subscription.title ?? subscription.vendor ?? 'Your subscription';
    
    if (daysUntilRenewal == 1) {
      return '🔔 Hi $userName! $subscriptionName renews tomorrow';
    } else if (daysUntilRenewal <= 3) {
      return '⏰ $subscriptionName renewal coming up, $userName!';
    } else if (daysUntilRenewal <= 7) {
      return '📅 $subscriptionName renewal reminder';
    } else {
      return '💳 $subscriptionName renewal scheduled';
    }
  }

  static String _getEnhancedRenewalBody(Bill subscription, int daysUntilRenewal) {
    final subscriptionName = subscription.title ?? subscription.vendor ?? 'Your subscription';
    final category = subscription.categoryId ?? 'subscription';
    final amount = subscription.total;
    final currency = subscription.currency ?? 'USD';
    final frequency = subscription.subscriptionType ?? 'monthly';
    
    final amountText = amount != null ? '${amount.toStringAsFixed(2)} $currency' : '';
    final frequencyText = frequency.toLowerCase();
    
    if (daysUntilRenewal == 1) {
      return 'Your $subscriptionName ($category) renews tomorrow!${amountText.isNotEmpty ? ' Amount: $amountText' : ''} Make sure your payment method is up to date.';
    } else {
      return 'Your $subscriptionName ($category) renews in $daysUntilRenewal days.${amountText.isNotEmpty ? ' Amount: $amountText' : ''} Keep enjoying your $frequencyText subscription!';
    }
  }

  // Enhanced end date notification titles
  static String _getEnhancedEndDateTitle(Bill subscription, int daysUntilEnd) {
    final userName = _preferences.userName ?? 'there';
    final subscriptionName = subscription.title ?? subscription.vendor ?? 'Your subscription';
    
    if (daysUntilEnd == 1) {
      return '⚠️ Hi $userName! $subscriptionName expires tomorrow';
    } else if (daysUntilEnd <= 3) {
      return '🚨 $subscriptionName expires soon, $userName!';
    } else if (daysUntilEnd <= 7) {
      return '📅 $subscriptionName expiration reminder';
    } else {
      return '⏰ $subscriptionName will expire soon';
    }
  }

  static String _getEnhancedEndDateBody(Bill subscription, int daysUntilEnd) {
    final subscriptionName = subscription.title ?? subscription.vendor ?? 'Your subscription';
    final category = subscription.categoryId ?? 'subscription';
    final amount = subscription.total;
    final currency = subscription.currency ?? 'USD';
    
    final amountText = amount != null ? '${amount.toStringAsFixed(2)} $currency' : '';
    
    if (daysUntilEnd == 1) {
      return 'Your $subscriptionName ($category) expires tomorrow!${amountText.isNotEmpty ? ' Last payment: $amountText' : ''} Consider renewing to continue your service.';
    } else {
      return 'Your $subscriptionName ($category) expires in $daysUntilEnd days.${amountText.isNotEmpty ? ' Last payment: $amountText' : ''} Don\'t forget to renew if you want to continue!';
    }
  }

  // Show immediate test notification
  static Future<void> showTestNotification() async {
    final userName = _preferences.userName ?? 'there';
    
    await _notifications.show(
      9999, // Use a unique ID for test notifications
      '🔔 Hi $userName! This is a test notification',
      'Your personal subscription reminder system is working perfectly! You\'ll get notified before your subscriptions renew.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_personal_subscriptions',
          'Test Personal Subscriptions',
          channelDescription: 'Test notifications for personal subscription reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          actions: [
            AndroidNotificationAction('test', 'Test Action'),
          ],
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'test_personal_subscription_notification',
    );
  }

  // Test notification with specific subscription data
  static Future<void> showTestSubscriptionNotification({
    required String subscriptionName,
    required String category,
    required String frequency,
    required double amount,
    required String currency,
    required int daysUntilRenewal,
  }) async {
    
    // Create a mock subscription for testing
    final testSubscription = Bill(
      id: 'test_subscription_${DateTime.now().millisecondsSinceEpoch}',
      imagePath: 'test_image',
      vendor: subscriptionName,
      title: subscriptionName,
      date: DateTime.now().subtract(const Duration(days: 30)),
      total: amount,
      currency: currency,
      categoryId: category,
      subscriptionType: frequency.toLowerCase(),
      ocrText: 'Test subscription',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    final title = _getEnhancedRenewalTitle(testSubscription, daysUntilRenewal);
    final body = _getEnhancedRenewalBody(testSubscription, daysUntilRenewal);
    
    await _notifications.show(
      9998, // Use a unique ID for test subscription notifications
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_subscription_reminders',
          'Test Subscription Reminders',
          channelDescription: 'Test notifications for subscription reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          actions: [
            AndroidNotificationAction('view', 'View Subscription'),
            AndroidNotificationAction('dismiss', 'Dismiss'),
          ],
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'test_subscription_reminder',
    );
  }



  // Test end date notification
  static Future<void> showTestEndDateNotification({
    required String subscriptionName,
    required String category,
    required double amount,
    required String currency,
    required int daysUntilEnd,
  }) async {
    
    // Create a mock subscription for testing
    final testSubscription = Bill(
      id: 'test_subscription_${DateTime.now().millisecondsSinceEpoch}',
      imagePath: 'test_image',
      vendor: subscriptionName,
      title: subscriptionName,
      date: DateTime.now().subtract(const Duration(days: 30)),
      total: amount,
      currency: currency,
      categoryId: category,
      subscriptionType: 'monthly',
      subscriptionEndDate: DateTime.now().add(Duration(days: daysUntilEnd)),
      ocrText: 'Test subscription',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    final title = _getEnhancedEndDateTitle(testSubscription, daysUntilEnd);
    final body = _getEnhancedEndDateBody(testSubscription, daysUntilEnd);
    
    await _notifications.show(
      9997, // Use a unique ID for test end date notifications
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_subscription_end_reminders',
          'Test Subscription End Reminders',
          channelDescription: 'Test notifications for subscription end dates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          actions: [
            AndroidNotificationAction('view', 'View Subscription'),
            AndroidNotificationAction('dismiss', 'Dismiss'),
          ],
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'test_subscription_end_reminder',
    );
  }

  // Convert DateTime to TZDateTime
  static tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  // Cancel all subscription reminders
  static Future<void> cancelAllReminders() async {
    final pendingNotifications = await _notifications.pendingNotificationRequests();
    for (final notification in pendingNotifications) {
      if (notification.id >= _renewalReminderId) {
        await _notifications.cancel(notification.id);
      }
    }
  }

  // Cancel reminders for a specific subscription
  static Future<void> cancelSubscriptionReminders(String subscriptionId) async {
    final pendingNotifications = await _notifications.pendingNotificationRequests();
    for (final notification in pendingNotifications) {
      if (notification.payload?.contains('subscription_reminder_$subscriptionId') == true ||
          notification.payload?.contains('subscription_end_reminder_$subscriptionId') == true) {
        await _notifications.cancel(notification.id);
      }
    }
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

  // Get pending notifications
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  // Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await androidImplementation?.areNotificationsEnabled() ?? false;
      print('🔍 DEBUG: Android notifications enabled: $enabled');
      return enabled;
    } else if (Platform.isIOS) {
      final iosImplementation = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final permissions = await iosImplementation?.checkPermissions();
      final enabled = permissions?.isEnabled ?? false;
      print('🔍 DEBUG: iOS notifications enabled: $enabled');
      return enabled;
    }
    print('🔍 DEBUG: Unknown platform, notifications disabled');
    return false;
  }

  // Check notification permission status
  static Future<Map<String, bool>> checkNotificationPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    Map<String, bool> permissions = {};
    
    if (androidPlugin != null) {
      permissions['notificationsEnabled'] = await androidPlugin.areNotificationsEnabled() ?? false;
      permissions['exactAlarmsAllowed'] = await androidPlugin.canScheduleExactNotifications() ?? false;
    }
    
    print('🔍 DEBUG: Notification permissions: $permissions');
    return permissions;
  }

  // Check if exact alarms are permitted (Android 12+)
  static Future<bool> canScheduleExactAlarms() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await androidImplementation?.canScheduleExactNotifications() ?? false;
    }
    return true; // iOS doesn't have this restriction
  }

  // Request exact alarm permission (Android 12+)
  static Future<bool> requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await androidImplementation?.requestExactAlarmsPermission() ?? false;
    }
    return true; // iOS doesn't have this restriction
  }

  // Send immediate renewal notification for overdue reminders
  static Future<void> _sendImmediateRenewalNotification(Bill subscription, int daysUntilRenewal) async {
    print('🔍 DEBUG: ===== SENDING IMMEDIATE RENEWAL NOTIFICATION =====');
    print('🔍 DEBUG: Subscription: ${subscription.title ?? subscription.vendor}');
    print('🔍 DEBUG: Days until renewal: $daysUntilRenewal');
    
    try {
      final title = _getEnhancedRenewalTitle(subscription, daysUntilRenewal);
      final body = _getEnhancedRenewalBody(subscription, daysUntilRenewal);
      
      print('🔍 DEBUG: Notification title: $title');
      print('🔍 DEBUG: Notification body: $body');
      
      await _notifications.show(
        9995, // Use a unique ID for immediate renewal notifications
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'immediate_renewal_reminders',
            'Immediate Renewal Reminders',
            channelDescription: 'Immediate notifications for overdue subscription reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            actions: [
              AndroidNotificationAction('view', 'View Subscription'),
              AndroidNotificationAction('dismiss', 'Dismiss'),
            ],
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'immediate_renewal_reminder_${subscription.id}',
      );
      
      print('🔍 DEBUG: ✅ Immediate renewal notification sent successfully for ${subscription.title ?? subscription.vendor} - $daysUntilRenewal days until renewal');
    } catch (e) {
      print('🔍 DEBUG: ❌ Error sending immediate renewal notification: $e');
      print('🔍 DEBUG: Error details: ${e.toString()}');
    }
  }

  // Send immediate end date notification for tomorrow's end date
  static Future<void> _sendImmediateEndDateNotification(Bill subscription) async {
    try {
      final title = _getEnhancedEndDateTitle(subscription, 1); // 1 day until end
      final body = _getEnhancedEndDateBody(subscription, 1);
      
      await _notifications.show(
        9996, // Use a unique ID for immediate end date notifications
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'immediate_end_reminders',
            'Immediate End Reminders',
            channelDescription: 'Immediate notifications for subscriptions ending tomorrow',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            actions: [
              AndroidNotificationAction('view', 'View Subscription'),
              AndroidNotificationAction('dismiss', 'Dismiss'),
            ],
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'immediate_end_reminder_${subscription.id}',
      );
      
      print('🔍 DEBUG: Immediate end date notification sent for ${subscription.title ?? subscription.vendor}');
    } catch (e) {
      print('🔍 DEBUG: Error sending immediate end date notification: $e');
    }
  }
}

// Personal reminder preferences
class PersonalReminderPreferences {
  final bool renewalEnabled;
  final String? userName;

  const PersonalReminderPreferences({
    this.renewalEnabled = true,
    this.userName,
  });

  PersonalReminderPreferences copyWith({
    bool? renewalEnabled,
    String? userName,
  }) {
    return PersonalReminderPreferences(
      renewalEnabled: renewalEnabled ?? this.renewalEnabled,
      userName: userName ?? this.userName,
    );
  }

  String toJson() {
    return '{"renewalEnabled":$renewalEnabled,"userName":"${userName ?? ''}"}';
  }

  static PersonalReminderPreferences fromJson(String json) {
    try {
      // Simple JSON parsing for this basic structure
      final renewalEnabled = json.contains('"renewalEnabled":true');
      final userNameMatch = RegExp(r'"userName":"([^"]*)"').firstMatch(json);
      final userName = userNameMatch?.group(1);
      
      return PersonalReminderPreferences(
        renewalEnabled: renewalEnabled,
        userName: userName?.isEmpty == true ? null : userName,
      );
    } catch (e) {
      return const PersonalReminderPreferences();
    }
  }
}
