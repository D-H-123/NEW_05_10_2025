import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_receipt/core/services/personal_subscription_reminder_service.dart';
import 'package:smart_receipt/core/theme/app_theme.dart';
import 'package:smart_receipt/core/widgets/responsive_layout.dart';
import 'package:smart_receipt/features/storage/bill/bill_provider.dart';

class SimplifiedSubscriptionReminderSettings extends ConsumerStatefulWidget {
  const SimplifiedSubscriptionReminderSettings({super.key});

  @override
  ConsumerState<SimplifiedSubscriptionReminderSettings> createState() => _SimplifiedSubscriptionReminderSettingsState();
}

class _SimplifiedSubscriptionReminderSettingsState extends ConsumerState<SimplifiedSubscriptionReminderSettings> {
  late PersonalReminderPreferences _preferences;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _preferences = PersonalSubscriptionReminderService.preferences;
      
      // Auto-populate user name from Firebase Auth if available
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && _preferences.userName == null) {
        final displayName = currentUser.displayName;
        if (displayName != null && displayName.isNotEmpty) {
          // Extract first name from display name
          final firstName = displayName.split(' ').first;
          _preferences = _preferences.copyWith(userName: firstName);
          await PersonalSubscriptionReminderService.updatePreference(userName: firstName);
        }
      }
    } catch (e) {
      _preferences = const PersonalReminderPreferences();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await PersonalSubscriptionReminderService.updatePreferences(_preferences);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Personal subscription reminder settings saved!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _updatePreference({
    bool? renewalEnabled,
    String? userName,
  }) async {
    setState(() {
      _preferences = _preferences.copyWith(
        renewalEnabled: renewalEnabled,
        userName: userName,
      );
    });
    
    await _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Subscription Reminders',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveContainer(
              maxWidth: 600,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ResponsiveColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ResponsiveSpacer(height: 24),
                    
                    // Header Section
                    _buildHeaderSection(),
                    
                    const ResponsiveSpacer(height: 32),
                    
                    // Main Settings Card
                    _buildMainSettingsCard(),
                    
                    const ResponsiveSpacer(height: 32),
                    
                    // Actions Section
                    _buildActionsSection(),
                    
                    const ResponsiveSpacer(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderSection() {
    return ResponsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: AppTheme.smallBorderRadius,
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Subscription Reminders',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Get notified before your personal subscriptions renew',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGradientStart.withOpacity(0.1),
              borderRadius: AppTheme.smallBorderRadius,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryGradientStart,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child:                   Text(
                    'We\'ll automatically adjust reminder timing based on your subscription frequency (weekly, monthly, yearly) and send end date reminders (7, 3, 1 days before) if you set an end date. Uses your first name from signup for personalized notifications.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryGradientStart,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainSettingsCard() {
    return ResponsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle Switch
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: AppTheme.smallBorderRadius,
                ),
                child: const Icon(
                  Icons.autorenew,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Renewal Reminders',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Get notified before your subscription renews',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _preferences.renewalEnabled,
                onChanged: (enabled) => _updatePreference(renewalEnabled: enabled),
                activeThumbColor: Colors.blue,
              ),
            ],
          ),
          
          if (_preferences.renewalEnabled) ...[
            const SizedBox(height: 24),
            
            // Timing Information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: AppTheme.smallBorderRadius,
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Smart Timing',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Weekly subscriptions: 2 days and 1 day before renewal\n'
                    '• Monthly subscriptions: 7 days, 3 days, and 1 day before renewal\n'
                    '• Yearly subscriptions: 30 days, 14 days, 7 days, and 3 days before renewal\n'
                    '• End date reminders: 7 days, 3 days, and 1 day before expiration\n'
                    '• Notifications include subscription name, category, and amount',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            
            if (_preferences.userName != null && _preferences.userName!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: AppTheme.smallBorderRadius,
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: Colors.green[600],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Notifications will be personalized with "${_preferences.userName}"',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
          ],
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveText(
          'Actions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const ResponsiveSpacer(height: 16),
        
        // Test Notification Button
        ResponsiveCard(
          onTap: _sendTestNotification,
          child: _buildActionTile(
            context,
            icon: Icons.send,
            title: 'Send Test Notification',
            subtitle: 'Test how your renewal reminder will look',
            color: Colors.green,
          ),
        ),
        
        const ResponsiveSpacer(height: 12),
        
        // Refresh Reminders Button
        ResponsiveCard(
          onTap: _refreshAllReminders,
          child: _buildActionTile(
            context,
            icon: Icons.refresh,
            title: 'Refresh All Reminders',
            subtitle: 'Reschedule all subscription reminders now',
            color: Colors.blue,
          ),
        ),
        
        const ResponsiveSpacer(height: 12),
        
        // Open System Settings Button
        ResponsiveCard(
          onTap: _openSystemNotificationSettings,
          child: _buildActionTile(
            context,
            icon: Icons.settings,
            title: 'System Notification Settings',
            subtitle: 'Manage notification permissions in system settings',
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: AppTheme.smallBorderRadius,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[400],
          size: 16,
        ),
      ],
    );
  }

  Future<void> _sendTestNotification() async {
    try {
      // Send an immediate test notification
      await PersonalSubscriptionReminderService.showTestNotification();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent! Check your notification panel.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending test notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openSystemNotificationSettings() async {
    await PersonalSubscriptionReminderService.openNotificationSettings();
  }

  void _refreshAllReminders() async {
    try {
      // Get all bills from the provider
      final bills = ref.read(billProvider);
      
      // Schedule reminders for all subscriptions
      await PersonalSubscriptionReminderService.scheduleAllSubscriptionReminders(bills);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All subscription reminders refreshed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh reminders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

}
