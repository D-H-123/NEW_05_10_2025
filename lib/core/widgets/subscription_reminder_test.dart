import 'package:flutter/material.dart';
import 'package:smart_receipt/core/services/subscription_reminder_service.dart';
import 'package:smart_receipt/core/services/premium_service.dart';

/// Test widget for subscription reminders - for development/testing only
class SubscriptionReminderTest extends StatefulWidget {
  const SubscriptionReminderTest({super.key});

  @override
  State<SubscriptionReminderTest> createState() => _SubscriptionReminderTestState();
}

class _SubscriptionReminderTestState extends State<SubscriptionReminderTest> {
  bool _isLoading = false;
  List<String> _testResults = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Reminder Test'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Subscription Reminders',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Test Buttons
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: _testWeeklyReminders,
                  icon: const Icon(Icons.calendar_view_week),
                  label: const Text('Test Weekly'),
                ),
                ElevatedButton.icon(
                  onPressed: _testMonthlyReminders,
                  icon: const Icon(Icons.calendar_view_month),
                  label: const Text('Test Monthly'),
                ),
                ElevatedButton.icon(
                  onPressed: _testQuarterlyReminders,
                  icon: const Icon(Icons.calendar_view_day),
                  label: const Text('Test Quarterly'),
                ),
                ElevatedButton.icon(
                  onPressed: _testYearlyReminders,
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Test Yearly'),
                ),
                ElevatedButton.icon(
                  onPressed: _testTrialReminders,
                  icon: const Icon(Icons.timer),
                  label: const Text('Test Trial'),
                ),
                ElevatedButton.icon(
                  onPressed: _testUsageReminders,
                  icon: const Icon(Icons.warning),
                  label: const Text('Test Usage'),
                ),
                ElevatedButton.icon(
                  onPressed: _checkPendingNotifications,
                  icon: const Icon(Icons.list),
                  label: const Text('Check Pending'),
                ),
                ElevatedButton.icon(
                  onPressed: _cancelAllReminders,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel All'),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Results
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Results:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _testResults.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '${index + 1}. ${_testResults[index]}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testWeeklyReminders() async {
    setState(() => _isLoading = true);
    _addResult('Testing weekly reminders...');
    
    try {
      await SubscriptionReminderService.scheduleRenewalReminder(
        renewalDate: DateTime.now().add(const Duration(days: 7)),
        subscriptionType: 'smartreceipt_basic_weekly',
        tier: 'Basic',
      );
      _addResult('✅ Weekly reminders scheduled successfully');
    } catch (e) {
      _addResult('❌ Error scheduling weekly reminders: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _testMonthlyReminders() async {
    setState(() => _isLoading = true);
    _addResult('Testing monthly reminders...');
    
    try {
      await SubscriptionReminderService.scheduleRenewalReminder(
        renewalDate: DateTime.now().add(const Duration(days: 30)),
        subscriptionType: 'smartreceipt_basic_monthly',
        tier: 'Basic',
      );
      _addResult('✅ Monthly reminders scheduled successfully');
    } catch (e) {
      _addResult('❌ Error scheduling monthly reminders: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _testQuarterlyReminders() async {
    setState(() => _isLoading = true);
    _addResult('Testing quarterly reminders...');
    
    try {
      await SubscriptionReminderService.scheduleRenewalReminder(
        renewalDate: DateTime.now().add(const Duration(days: 90)),
        subscriptionType: 'smartreceipt_basic_quarterly',
        tier: 'Basic',
      );
      _addResult('✅ Quarterly reminders scheduled successfully');
    } catch (e) {
      _addResult('❌ Error scheduling quarterly reminders: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _testYearlyReminders() async {
    setState(() => _isLoading = true);
    _addResult('Testing yearly reminders...');
    
    try {
      await SubscriptionReminderService.scheduleRenewalReminder(
        renewalDate: DateTime.now().add(const Duration(days: 365)),
        subscriptionType: 'smartreceipt_basic_yearly',
        tier: 'Basic',
      );
      _addResult('✅ Yearly reminders scheduled successfully');
    } catch (e) {
      _addResult('❌ Error scheduling yearly reminders: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _testTrialReminders() async {
    setState(() => _isLoading = true);
    _addResult('Testing trial reminders...');
    
    try {
      await SubscriptionReminderService.scheduleTrialEndingReminder(
        trialEndDate: DateTime.now().add(const Duration(days: 2)),
        tier: 'Pro',
      );
      _addResult('✅ Trial reminders scheduled successfully');
    } catch (e) {
      _addResult('❌ Error scheduling trial reminders: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _testUsageReminders() async {
    setState(() => _isLoading = true);
    _addResult('Testing usage reminders...');
    
    try {
      await SubscriptionReminderService.scheduleUsageLimitReminder(
        currentScans: 1,
        maxScans: 2,
        tier: 'Basic',
      );
      _addResult('✅ Usage reminders scheduled successfully');
    } catch (e) {
      _addResult('❌ Error scheduling usage reminders: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _checkPendingNotifications() async {
    setState(() => _isLoading = true);
    _addResult('Checking pending notifications...');
    
    try {
      final pending = await SubscriptionReminderService.getPendingNotifications();
      _addResult('📋 Found ${pending.length} pending notifications');
      
      for (final notification in pending) {
        _addResult('  - ID: ${notification.id}, Title: ${notification.title}');
      }
    } catch (e) {
      _addResult('❌ Error checking pending notifications: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _cancelAllReminders() async {
    setState(() => _isLoading = true);
    _addResult('Cancelling all reminders...');
    
    try {
      await SubscriptionReminderService.cancelAllReminders();
      _addResult('✅ All reminders cancelled successfully');
    } catch (e) {
      _addResult('❌ Error cancelling reminders: $e');
    }
    
    setState(() => _isLoading = false);
  }

  void _addResult(String result) {
    setState(() {
      _testResults.add('${DateTime.now().toString().substring(11, 19)} - $result');
    });
  }
}
