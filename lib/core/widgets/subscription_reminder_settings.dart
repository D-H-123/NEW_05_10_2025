import 'package:flutter/material.dart';
import 'package:smart_receipt/core/services/premium_service.dart';
import 'package:smart_receipt/core/services/subscription_reminder_service.dart';

class SubscriptionReminderSettings extends StatefulWidget {
  const SubscriptionReminderSettings({super.key});

  @override
  State<SubscriptionReminderSettings> createState() => _SubscriptionReminderSettingsState();
}

class _SubscriptionReminderSettingsState extends State<SubscriptionReminderSettings> {
  bool _notificationsEnabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _notificationsEnabled = PremiumService.notificationsEnabled;
    });
  }

  Future<void> _toggleNotifications(bool enabled) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await PremiumService.setNotificationsEnabled(enabled);
      setState(() {
        _notificationsEnabled = enabled;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled 
                ? 'Subscription reminders enabled' 
                : 'Subscription reminders disabled',
            ),
            backgroundColor: enabled ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openNotificationSettings() async {
    await SubscriptionReminderService.openNotificationSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Reminders'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Stay Updated',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Get timely reminders about your subscription status and never miss important updates.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Notification Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications,
                    color: _notificationsEnabled ? Colors.blue : Colors.grey,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Subscription Reminders',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _notificationsEnabled
                              ? 'You\'ll receive reminders about renewals and trials'
                              : 'You won\'t receive any subscription reminders',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Switch(
                      value: _notificationsEnabled,
                      onChanged: _toggleNotifications,
                      activeColor: Colors.blue,
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Current Subscription Info
            if (PremiumService.isPremium || PremiumService.isTrialActive) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Current Subscription',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Plan', PremiumService.currentTier.name.toUpperCase()),
                    _buildInfoRow('Type', PremiumService.subscriptionType),
                    if (PremiumService.daysUntilRenewal != null)
                      _buildInfoRow(
                        'Renewal', 
                        '${PremiumService.daysUntilRenewal} days',
                      ),
                    if (PremiumService.daysUntilTrialEnds != null)
                      _buildInfoRow(
                        'Trial Ends', 
                        '${PremiumService.daysUntilTrialEnds} days',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Reminder Types
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What You\'ll Receive',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildReminderType(
                    Icons.update,
                    'Renewal Reminders',
                    'Get notified before your subscription renews',
                    _getReminderScheduleText(),
                  ),
                  const SizedBox(height: 12),
                  _buildReminderType(
                    Icons.timer,
                    'Trial Reminders',
                    'Never miss when your trial is ending',
                    '2 days before trial expires',
                  ),
                  const SizedBox(height: 12),
                  _buildReminderType(
                    Icons.warning,
                    'Usage Alerts',
                    'Know when you\'re approaching scan limits',
                    'When you\'ve used 80% of free scans',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // System Settings Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.settings,
                    color: Colors.grey,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'System Notification Settings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Make sure notifications are enabled in your device settings',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _openNotificationSettings,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderType(IconData icon, String title, String description, String timing) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.blue,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timing,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getReminderScheduleText() {
    final subscriptionType = PremiumService.subscriptionType.toLowerCase();
    
    switch (subscriptionType) {
      case 'weekly':
        return '3 days, 1 day, and 6 hours before renewal';
      case 'monthly':
        return '7, 3, and 1 day before renewal';
      case 'quarterly':
        return '14, 7, 3, and 1 day before renewal';
      case 'yearly':
        return '30, 14, 7, and 3 days before renewal';
      default:
        return 'Based on your subscription frequency';
    }
  }
}
