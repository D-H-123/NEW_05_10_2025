import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_receipt/core/services/local_storage_service.dart';
import '../auth/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/currency_service.dart';
import '../../core/widgets/currency_picker.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/modern_widgets.dart';
import '../../core/services/premium_service.dart';
import '../../core/widgets/simplified_subscription_reminder_settings.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late bool _location;
  late bool _calendarResults;
  late bool _notes;
  String? _selectedCurrencyCode;

  @override
  void initState() {
    super.initState();
    _location = LocalStorageService.getBoolSetting(LocalStorageService.kLocation);
    _calendarResults = LocalStorageService.getBoolSetting(LocalStorageService.kCalendarResults);
    _notes = LocalStorageService.getBoolSetting(LocalStorageService.kNotes);
    _selectedCurrencyCode = LocalStorageService.getStringSetting(LocalStorageService.kCurrencyCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Profile & Settings',
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
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black87,
          ),
          onPressed: () {
            // Check if we can pop the route, otherwise go to home
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              // If accessed from bottom navigation, go to home
              context.go('/home');
            }
          },
        ),
        actions: [],
      ),
      body: ResponsiveContainer(
        maxWidth: 600,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ResponsiveColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ResponsiveSpacer(height: 24),
              
              // Profile Section - Rectangular and Clickable
              _buildProfileSection(),
              
              const ResponsiveSpacer(height: 32),
              
              // Priority 1: Essential Settings
              _buildSectionHeader('Essential Settings', Icons.settings, Colors.blue),
              const ResponsiveSpacer(height: 16),
              
              // Currency - Most Important
              _buildModernSettingCard(
                context,
                icon: Icons.currency_exchange,
                iconColor: Colors.green,
                title: 'Default Currency',
                subtitle: 'Set your preferred currency for receipts',
                trailing: Consumer(
                  builder: (context, ref, child) {
                    final currentCode = _selectedCurrencyCode ?? ref.read(currencyProvider).currencyCode;
                    final symbol = ref.read(currencyProvider.notifier).symbolFor(currentCode);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            symbol,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            currentCode,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                onTap: () async {
                  final current = ref.read(currencyProvider).currencyCode;
                  await showCurrencyPicker(
                    context: context,
                    selectedCode: _selectedCurrencyCode ?? current,
                    onSelected: (code) async {
                      await ref.read(currencyProvider.notifier).setCurrency(code);
                      if (mounted) {
                        setState(() {
                          _selectedCurrencyCode = code;
                        });
                      }
                    },
                  );
                },
              ),
              
              
              const ResponsiveSpacer(height: 32),
              
              // Priority 2: Premium Features
              _buildSectionHeader('Premium Features', Icons.star, Colors.amber),
              const ResponsiveSpacer(height: 16),
              
              // Location Services
              _buildModernSettingCard(
                context,
                icon: Icons.location_on,
                iconColor: Colors.orange,
                title: 'Location Services',
                subtitle: 'Track receipt locations automatically',
                isPremium: true,
                trailing: Switch(
                  value: _location,
                  onChanged: (v) async {
                    setState(() => _location = v);
                    await LocalStorageService.setBoolSetting(LocalStorageService.kLocation, v);
                  },
                  activeColor: Colors.orange,
                ),
                onTap: () async {
                  setState(() => _location = !_location);
                  await LocalStorageService.setBoolSetting(LocalStorageService.kLocation, _location);
                },
              ),
              
              const ResponsiveSpacer(height: 12),
              
              // Calendar Integration
              _buildModernSettingCard(
                context,
                icon: Icons.calendar_today,
                iconColor: Colors.purple,
                title: 'Calendar Integration',
                subtitle: 'Show receipts in calendar view',
                trailing: Switch(
                  value: _calendarResults,
                  onChanged: (v) async {
                    setState(() => _calendarResults = v);
                    await LocalStorageService.setBoolSetting(LocalStorageService.kCalendarResults, v);
                  },
                  activeColor: Colors.purple,
                ),
                onTap: () async {
                  setState(() => _calendarResults = !_calendarResults);
                  await LocalStorageService.setBoolSetting(LocalStorageService.kCalendarResults, _calendarResults);
                },
              ),
              
              const ResponsiveSpacer(height: 12),
              
              // Notes Support
              _buildModernSettingCard(
                context,
                icon: Icons.note_add,
                iconColor: Colors.teal,
                title: 'Notes Support',
                subtitle: 'Add notes to your receipts',
                trailing: Switch(
                  value: _notes,
                  onChanged: (v) async {
                    setState(() => _notes = v);
                    await LocalStorageService.setBoolSetting(LocalStorageService.kNotes, v);
                  },
                  activeColor: Colors.teal,
                ),
                onTap: () async {
                  setState(() => _notes = !_notes);
                  await LocalStorageService.setBoolSetting(LocalStorageService.kNotes, _notes);
                },
              ),
              
              const ResponsiveSpacer(height: 32),
              
              // Priority 3: Subscription Management
              _buildSectionHeader('Subscription Management', Icons.account_balance_wallet, Colors.indigo),
              const ResponsiveSpacer(height: 16),
              
              // Subscription Reminders
              _buildModernSettingCard(
                context,
                icon: Icons.notifications_active,
                iconColor: Colors.blue,
                title: 'Subscription Reminders',
                subtitle: 'Manage your subscription reminder notifications',
                isNew: true,
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 16,
                ),
                onTap: () => _navigateToSubscriptionReminders(context),
              ),
              
              const ResponsiveSpacer(height: 32),
              
              // Testing Section (only show in debug mode)
              if (const bool.fromEnvironment('dart.vm.product') == false) ...[
                ResponsiveText(
                  'Testing Tools',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                
                const ResponsiveSpacer(height: 16),
                
                // Premium Testing
                ResponsiveCard(
                  child: _buildTestingTile(
                    context,
                    icon: Icons.star,
                    title: 'Premium Status',
                    subtitle: 'Current: ${PremiumService.isPremium ? "Premium" : "Free"} (${PremiumService.scanCount}/2 scans used)',
                    onTap: _togglePremiumStatus,
                  ),
                ),
                
                // Reset Scan Count
                ResponsiveCard(
                  child: _buildTestingTile(
                    context,
                    icon: Icons.refresh,
                    title: 'Reset Scan Count',
                    subtitle: 'Reset free scan counter for testing',
                    onTap: _resetScanCount,
                  ),
                ),
                
                // Start Free Trial
                ResponsiveCard(
                  child: _buildTestingTile(
                    context,
                    icon: Icons.timer,
                    title: 'Start Free Trial',
                    subtitle: 'Activate 7-day free trial for testing',
                    onTap: _startFreeTrial,
                  ),
                ),
                
                const ResponsiveSpacer(height: 32),
              ],
              
              // Priority 4: Additional Options
              _buildSectionHeader('Additional Options', Icons.more_horiz, Colors.grey),
              const ResponsiveSpacer(height: 16),
              
              // Export Data
              _buildModernSettingCard(
                context,
                icon: Icons.download,
                iconColor: AppTheme.primaryGradientStart,
                title: 'Export Data',
                subtitle: 'Export all receipts as CSV or PDF',
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 16,
                ),
                onTap: () => _showExportDialog(context),
              ),
              
              const ResponsiveSpacer(height: 12),
              
              // Privacy Policy
              _buildModernSettingCard(
                context,
                icon: Icons.privacy_tip,
                iconColor: AppTheme.infoColor,
                title: 'Privacy Policy',
                subtitle: 'View our privacy policy',
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 16,
                ),
                onTap: () => _showPrivacyPolicy(context),
              ),
              
              const ResponsiveSpacer(height: 12),
              
              // About
              _buildModernSettingCard(
                context,
                icon: Icons.info,
                iconColor: Colors.grey[600]!,
                title: 'About',
                subtitle: 'App version and information',
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 16,
                ),
                onTap: () => _showAboutDialog(context),
              ),
              
              const ResponsiveSpacer(height: 80), // Space for bottom navigation
            ],
          ),
        ),
      ),
      bottomNavigationBar: ModernBottomNavigationBar(
        currentIndex: 4, // Settings is active
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/analysis');
              break;
            case 2:
              context.go('/scan');
              break;
            case 3:
              context.go('/bills');
              break;
            case 4:
              // Already on settings page
              break;
          }
        },
        items: const [
          ModernBottomNavigationBarItem(
            icon: Icons.home,
            label: 'Home',
          ),
          ModernBottomNavigationBarItem(
            icon: Icons.analytics,
            label: 'Analysis',
          ),
          ModernBottomNavigationBarItem(
            icon: Icons.camera_alt,
            label: 'Scan',
          ),
          ModernBottomNavigationBarItem(
            icon: Icons.folder,
            label: 'Storage',
          ),
          ModernBottomNavigationBarItem(
            icon: Icons.person,
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    final authState = ref.watch(authControllerProvider);
    final currentUser = FirebaseAuth.instance.currentUser;
    
    // Determine if user is signed in and get user info
    final bool isSignedIn = authState.status == AuthStatus.signedIn && currentUser != null;
    
    String displayName = 'Smart Receipt User';
    String subtitle = 'Sign up to sync your data';
    
    if (isSignedIn) {
      displayName = currentUser.displayName ?? 'Smart Receipt User';
      subtitle = currentUser.email ?? 'user@smartreceipt.com';
    }
    final IconData actionIcon = isSignedIn ? Icons.person : Icons.login;
    
    return ResponsiveCard(
      onTap: () {
        if (!isSignedIn) {
          // Navigate to sign up page if not signed in
          context.go('/sign-up');
        } else {
          // Show profile options if signed in
          _showProfileOptions();
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.responsivePadding),
        child: Row(
          children: [
            // Profile Avatar - Circular
            Container(
              width: context.isMobile ? 60 : 70,
              height: context.isMobile ? 60 : 70,
              decoration: BoxDecoration(
                gradient: isSignedIn ? AppTheme.primaryGradient : AppTheme.secondaryGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.cardShadow,
              ),
              child: Icon(
                isSignedIn ? Icons.person : Icons.person_add,
                size: context.isMobile ? 30 : 35,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Profile Info - Takes remaining space
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResponsiveText(
                    displayName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ResponsiveText(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSignedIn ? AppTheme.primaryGradientStart : Colors.orange[600],
                      fontWeight: isSignedIn ? FontWeight.w500 : FontWeight.w600,
                    ),
                  ),
                  
                  // Subscription Status Indicator
                  if (isSignedIn) ...[
                    const SizedBox(height: 8),
                    _buildSubscriptionStatus(),
                  ],
                  
                  if (!isSignedIn) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: AppTheme.smallBorderRadius,
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Tap to Sign Up',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Action Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSignedIn 
                    ? AppTheme.primaryGradientStart.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: AppTheme.smallBorderRadius,
              ),
              child: Icon(
                actionIcon,
                color: isSignedIn ? AppTheme.primaryGradientStart : Colors.orange[600],
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            const Text(
              'Profile Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Edit Profile
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGradientStart.withOpacity(0.1),
                  borderRadius: AppTheme.smallBorderRadius,
                ),
                child: const Icon(
                  Icons.edit,
                  color: AppTheme.primaryGradientStart,
                ),
              ),
              title: const Text('Edit Profile'),
              subtitle: const Text('Update your profile information'),
              onTap: () {
                Navigator.pop(context);
                _showEditProfileDialog(context);
              },
            ),
            
            // Sign Out
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: AppTheme.smallBorderRadius,
                ),
                child: const Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
              ),
              title: const Text('Sign Out'),
              subtitle: const Text('Sign out of your account'),
              onTap: () {
                Navigator.pop(context);
                _showSignOutDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.largeBorderRadius,
        ),
        title: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to sign out? You can always sign back in later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ModernButton(
            text: 'Sign Out',
            backgroundColor: Colors.red,
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(authControllerProvider.notifier).signOut();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Successfully signed out'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error signing out: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }


  // Modern Section Header
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // Modern Setting Card
  Widget _buildModernSettingCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
    bool isPremium = false,
    bool isNew = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (isPremium) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: Colors.amber[700],
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Premium',
                                    style: TextStyle(
                                      color: Colors.amber[700],
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (isNew) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Trailing
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.largeBorderRadius,
        ),
        title: const Text(
          'Export Data',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Choose the format to export your receipt data:',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ModernButton(
            text: 'Export CSV',
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement CSV export
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV export feature coming soon!')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.largeBorderRadius,
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'SmartReceipt Privacy Policy\n\n'
            'We respect your privacy and are committed to protecting your personal data. '
            'This privacy policy explains how we collect, use, and protect your information.\n\n'
            '1. Data Collection: We only collect data necessary for app functionality.\n'
            '2. Data Usage: Your data is used solely to provide our services.\n'
            '3. Data Protection: We implement security measures to protect your data.\n'
            '4. Data Sharing: We do not share your personal data with third parties.\n\n'
            'For questions, contact us at privacy@smartreceipt.com',
          ),
        ),
        actions: [
          ModernButton(
            text: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'SmartReceipt',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: AppTheme.mediumBorderRadius,
        ),
        child: const Icon(
          Icons.receipt_long,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: [
        const Text(
          'SmartReceipt is your personal receipt scanner and expense assistant. '
          'Easily scan, organize, and analyze your receipts with AI-powered OCR technology.',
        ),
      ],
    );
  }

  void _navigateToSubscriptionReminders(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SimplifiedSubscriptionReminderSettings(),
      ),
    );
  }

  Widget _buildSubscriptionStatus() {
    final isPremium = PremiumService.isPremium;
    final isTrialActive = PremiumService.isTrialActive;
    final subscriptionType = PremiumService.subscriptionType;
    
    if (!isPremium && !isTrialActive) {
      return const SizedBox.shrink();
    }
    
    String statusText;
    Color statusColor;
    IconData statusIcon;
    
    if (isTrialActive) {
      final daysLeft = PremiumService.daysUntilTrialEnds ?? 0;
      statusText = 'Trial - $daysLeft days left';
      statusColor = Colors.orange;
      statusIcon = Icons.timer;
    } else if (isPremium) {
      statusText = '$subscriptionType Plan Active';
      statusColor = Colors.green;
      statusIcon = Icons.star;
    } else {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: AppTheme.smallBorderRadius,
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 12,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final nameController = TextEditingController(text: 'Smart Receipt User');
    final emailController = TextEditingController(text: 'user@smartreceipt.com');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.largeBorderRadius,
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Edit Profile',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile Picture Section
              GestureDetector(
                onTap: () {
                  // TODO: Implement image picker for profile picture
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile picture upload coming soon!'),
                    ),
                  );
                },
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGradientStart,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Name Field
              ModernTextField(
                controller: nameController,
                label: 'Full Name',
                prefixIcon: Icons.person,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Name is required';
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Email Field
              ModernTextField(
                controller: emailController,
                label: 'Email Address',
                prefixIcon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Email is required';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Currency Preference
              DropdownButtonFormField<String>(
                value: 'USD',
                decoration: InputDecoration(
                  labelText: 'Default Currency',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: AppTheme.mediumBorderRadius,
                  ),
                ),
                items: ['USD', 'EUR', 'GBP', 'CAD', 'AUD']
                    .map((currency) => DropdownMenuItem(
                          value: currency,
                          child: Text(currency),
                        ))
                    .toList(),
                onChanged: (value) {
                  // TODO: Save currency preference
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ModernButton(
            text: 'Save Changes',
            onPressed: () {
              // TODO: Implement profile save functionality
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile updated successfully!'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Testing methods
  void _togglePremiumStatus() {
    setState(() {
      // Toggle premium status for testing
      if (PremiumService.isPremium) {
        // Reset to free
        PremiumService.setPremiumStatus(false);
      } else {
        // Set to premium
        PremiumService.setPremiumStatus(true);
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          PremiumService.isPremium 
            ? 'Premium activated for testing!' 
            : 'Switched to free tier for testing!'
        ),
        backgroundColor: PremiumService.isPremium ? Colors.green : Colors.orange,
      ),
    );
  }

  void _resetScanCount() async {
    // Reset scan count for testing
    await PremiumService.resetScanCount();
    setState(() {});
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scan count reset for testing!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _startFreeTrial() async {
    await PremiumService.startFreeTrial();
    setState(() {});
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('7-day free trial started for testing!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildTestingTile(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}


