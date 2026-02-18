import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_receipt/core/services/local_storage_service.dart';
import 'package:smart_receipt/core/services/budget_notification_service.dart';
import '../auth/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/currency_service.dart';
import '../../core/widgets/monthly_budget_dialog.dart';
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
  late bool _calendarResults;
  late bool _notes;
  String? _selectedCurrencyCode;
  double? _monthlyBudget;

  @override
  void initState() {
    super.initState();
    _calendarResults = LocalStorageService.getBoolSetting(LocalStorageService.kCalendarResults);
    _notes = LocalStorageService.getBoolSetting(LocalStorageService.kNotes);
    _selectedCurrencyCode = LocalStorageService.getStringSetting(LocalStorageService.kCurrencyCode);
    _monthlyBudget = LocalStorageService.getDoubleSetting(LocalStorageService.kMonthlyBudget);
  }

  static const Color _rowBorder = Color(0xFFf1f5f9);
  static const Color _rowHover = Color(0xFFf8fafc);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFf8fafc),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(context),
            ResponsiveContainer(
              maxWidth: 600,
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel('Financial'),
                      _buildSettingsCard(
                        context,
                        rows: [
                          _buildSettingsRow(
                            context,
                            icon: Icons.attach_money,
                            iconGradient: const [Color(0xFF3b82f6), Color(0xFF2563eb)],
                            title: 'Default Currency',
                            trailing: Consumer(
                              builder: (context, ref, _) {
                                final currentCode = _selectedCurrencyCode ?? ref.read(currencyProvider).currencyCode;
                                final symbol = ref.read(currencyProvider.notifier).symbolFor(currentCode);
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('$symbol $currentCode', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                                    const SizedBox(width: 4),
                                    Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                                  ],
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
                                  if (mounted) setState(() => _selectedCurrencyCode = code);
                                },
                              );
                            },
                            showDivider: true,
                          ),
                          _buildSettingsRow(
                            context,
                            icon: Icons.account_balance_wallet,
                            iconGradient: [AppTheme.darkBlue, AppTheme.darkBlueLight],
                            title: 'Monthly Budget',
                            trailing: Consumer(
                              builder: (context, ref, _) {
                                final sym = ref.read(currencyProvider.notifier).symbolFor(_selectedCurrencyCode ?? ref.read(currencyProvider).currencyCode);
                                final value = _monthlyBudget != null ? '$sym${_monthlyBudget!.toStringAsFixed(0)}' : 'Not set';
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(value, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                                    const SizedBox(width: 4),
                                    Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                                  ],
                                );
                              },
                            ),
                            onTap: () => _showBudgetDialog(),
                            showDivider: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSectionLabel('Customization'),
                      _buildSettingsCard(
                        context,
                        rows: [
                          _buildSettingsRow(
                            context,
                            icon: Icons.folder_open,
                            iconGradient: const [Color(0xFF0ea5e9), Color(0xFF0284c7)],
                            title: 'Custom Categories',
                            trailing: Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                            onTap: () => context.push('/settings/custom-categories'),
                            showDivider: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSectionLabel('Features'),
                      _buildSettingsCard(
                        context,
                        rows: [
                          _buildSettingsRow(
                            context,
                            icon: Icons.calendar_today,
                            iconGradient: const [Color(0xFF3b82f6), Color(0xFF2563eb)],
                            title: 'Calendar Integration',
                            trailing: _buildPillSwitch(
                              value: _calendarResults,
                              onChanged: (v) async {
                                setState(() => _calendarResults = v);
                                await LocalStorageService.setBoolSetting(LocalStorageService.kCalendarResults, v);
                              },
                            ),
                            onTap: () async {
                              setState(() => _calendarResults = !_calendarResults);
                              await LocalStorageService.setBoolSetting(LocalStorageService.kCalendarResults, _calendarResults);
                            },
                            showDivider: true,
                          ),
                          _buildSettingsRow(
                            context,
                            icon: Icons.notifications,
                            iconGradient: const [Color(0xFF6366f1), Color(0xFF4f46e5)],
                            title: 'Notifications',
                            trailing: Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                            onTap: () => _showUnifiedNotificationSettings(context),
                            showDivider: true,
                          ),
                          _buildSettingsRow(
                            context,
                            icon: Icons.note_add,
                            iconGradient: const [Color(0xFF0ea5e9), Color(0xFF0284c7)],
                            title: 'Notes Support',
                            trailing: _buildPillSwitch(
                              value: _notes,
                              onChanged: (v) async {
                                setState(() => _notes = v);
                                await LocalStorageService.setBoolSetting(LocalStorageService.kNotes, v);
                              },
                            ),
                            onTap: () async {
                              setState(() => _notes = !_notes);
                              await LocalStorageService.setBoolSetting(LocalStorageService.kNotes, _notes);
                            },
                            showDivider: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSectionLabel('Support'),
                      _buildSettingsCard(
                        context,
                        rows: [
                          _buildSettingsRow(
                            context,
                            icon: Icons.privacy_tip,
                            iconGradient: const [Color(0xFF0ea5e9), Color(0xFF0284c7)],
                            title: 'Privacy Policy',
                            trailing: Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                            onTap: () => _showPrivacyPolicy(context),
                            showDivider: true,
                          ),
                          _buildSettingsRow(
                            context,
                            icon: Icons.info_outline,
                            iconGradient: [Colors.grey[600]!, Colors.grey[700]!],
                            title: 'About',
                            trailing: Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                            onTap: () => _showAboutDialog(context),
                            showDivider: false,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
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

  Widget _buildProfileHeader(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isSignedIn = authState.status == AuthStatus.signedIn && currentUser != null;
    final displayName = isSignedIn
        ? (currentUser.displayName ?? 'Smart Receipt User')
        : 'Smart Receipt User';
    final email = isSignedIn ? (currentUser.email ?? 'user@smartreceipt.com') : 'user@smartreceipt.com';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppTheme.darkBlueGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.zero,
          bottomRight: Radius.zero,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative circles
          Positioned(
            top: -80,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -64,
            left: -32,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          // Content - blue has no side padding; only top for status bar, bottom for spacing
          Padding(
            padding: EdgeInsets.only(
              left: 0,
              right: 0,
              top: topPadding + 8,
              bottom: 28,
            ),
            child: Row(
              children: [
                // Left: avatar + name/email (tappable for profile options)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (!isSignedIn) context.go('/sign-up');
                        else _showProfileOptions();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.75),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                ),
                // Right: Share button
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _shareProfile(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.share_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
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

  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.smartreceipt.app';
  static const String _shareMessage =
      'Track your expenses effortlessly with Smart Receipt! Download now:\n$_playStoreUrl';

  void _shareProfile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Share Smart Receipt',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Invite friends to try the app',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildShareOption(
                      ctx,
                      label: 'WhatsApp',
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF25D366),
                      onTap: () => _openShareUrl(
                        ctx,
                        'https://wa.me/?text=${Uri.encodeComponent(_shareMessage)}',
                      ),
                    ),
                    _buildShareOption(
                      ctx,
                      label: 'Instagram',
                      icon: Icons.camera_alt_rounded,
                      color: const Color(0xFFE1306C),
                      onTap: () => _openShareUrl(
                        ctx,
                        'https://www.instagram.com/',
                      ),
                    ),
                    _buildShareOption(
                      ctx,
                      label: 'X',
                      icon: Icons.alternate_email,
                      color: Colors.black87,
                      onTap: () => _openShareUrl(
                        ctx,
                        'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(_shareMessage)}',
                      ),
                    ),
                    _buildShareOption(
                      ctx,
                      label: 'Facebook',
                      icon: Icons.facebook_rounded,
                      color: const Color(0xFF1877F2),
                      onTap: () => _openShareUrl(
                        ctx,
                        'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(_playStoreUrl)}',
                      ),
                    ),
                    _buildShareOption(
                      ctx,
                      label: 'Copy Link',
                      icon: Icons.link_rounded,
                      color: AppTheme.darkBlue,
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: _playStoreUrl));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Share.share(_shareMessage);
                    },
                    icon: const Icon(Icons.share_rounded, size: 20),
                    label: const Text('More options'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.darkBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareOption(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openShareUrl(BuildContext context, String url) async {
    Navigator.pop(context);
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      Share.share(_shareMessage);
    }
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, {required List<Widget> rows}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }

  Widget _buildSettingsRow(
    BuildContext context, {
    required IconData icon,
    required List<Color> iconGradient,
    required String title,
    required Widget trailing,
    required VoidCallback onTap,
    required bool showDivider,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            hoverColor: _rowHover,
            splashColor: _rowBorder,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: iconGradient,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: iconGradient.first.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  trailing,
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, thickness: 1, color: _rowBorder, indent: 64),
      ],
    );
  }

  Widget _buildPillSwitch({required bool value, required ValueChanged<bool> onChanged}) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 28,
        decoration: BoxDecoration(
          color: value ? AppTheme.darkBlue : Colors.grey[300],
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
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
        shape: const RoundedRectangleBorder(
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

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(
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
        decoration: const BoxDecoration(
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
        shape: const RoundedRectangleBorder(
          borderRadius: AppTheme.largeBorderRadius,
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
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
                initialValue: 'USD',
                decoration: const InputDecoration(
                  labelText: 'Default Currency',
                  prefixIcon: Icon(Icons.attach_money),
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

  void _showBudgetDialog() {
    MonthlyBudgetDialog.show(
      context,
      ref,
      currencyCode: _selectedCurrencyCode ?? ref.read(currencyProvider).currencyCode,
      onSaved: () {
        if (mounted) {
          setState(() {
            _monthlyBudget = LocalStorageService.getDoubleSetting(
                LocalStorageService.kMonthlyBudget);
          });
        }
      },
    );
  }


  void _showUnifiedNotificationSettings(BuildContext context) async {
    // Request permissions first
    final hasPermission = await BudgetNotificationService.requestPermissions();
    
    if (!hasPermission && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable notifications in app settings'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Get current settings
    final settings = await BudgetNotificationService.getNotificationSettings();
    bool budgetWeeklyEnabled = settings['budget'] ?? true;
    bool budgetThresholdEnabled = settings['threshold'] ?? true;
    bool budgetDailyEnabled = settings['daily'] ?? false;
    
    // Get subscription reminder setting (if exists)
    bool subscriptionEnabled = LocalStorageService.getBoolSetting('subscription_reminders_enabled', defaultValue: true);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: const RoundedRectangleBorder(
              borderRadius: AppTheme.largeBorderRadius,
            ),
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications,
                    color: Colors.orange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage all your app notifications:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // BUDGET SECTION
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          size: 16,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Budget Alerts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Weekly Budget Summary
                  SwitchListTile(
                    value: budgetWeeklyEnabled,
                    onChanged: (value) {
                      setDialogState(() {
                        budgetWeeklyEnabled = value;
                      });
                    },
                    title: const Text(
                      'Weekly Summary',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: const Text('Get weekly updates on your budget', style: TextStyle(fontSize: 12)),
                    activeThumbColor: Colors.blue,
                    contentPadding: const EdgeInsets.only(left: 0),
                  ),
                  
                  // Threshold Alerts
                  SwitchListTile(
                    value: budgetThresholdEnabled,
                    onChanged: (value) {
                      setDialogState(() {
                        budgetThresholdEnabled = value;
                      });
                    },
                    title: const Text(
                      'Spending Alerts',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: const Text('Alert at 80% or 100% budget', style: TextStyle(fontSize: 12)),
                    activeThumbColor: Colors.blue,
                    contentPadding: const EdgeInsets.only(left: 0),
                  ),
                  
                  // Daily Reminders
                  SwitchListTile(
                    value: budgetDailyEnabled,
                    onChanged: (value) {
                      setDialogState(() {
                        budgetDailyEnabled = value;
                      });
                    },
                    title: const Text(
                      'Daily Tips',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: const Text('Daily spending tips', style: TextStyle(fontSize: 12)),
                    activeThumbColor: Colors.blue,
                    contentPadding: const EdgeInsets.only(left: 0),
                  ),
                  
                  const Divider(height: 32),
                  
                  // SUBSCRIPTION SECTION
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.repeat,
                          size: 16,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Subscription Reminders',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Subscription Reminders Toggle
                  SwitchListTile(
                    value: subscriptionEnabled,
                    onChanged: (value) {
                      setDialogState(() {
                        subscriptionEnabled = value;
                      });
                    },
                    title: const Text(
                      'Upcoming Renewals',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: const Text('Remind before subscriptions renew', style: TextStyle(fontSize: 12)),
                    activeThumbColor: Colors.purple,
                    contentPadding: const EdgeInsets.only(left: 0),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Advanced Settings Button
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToSubscriptionReminders(context);
                    },
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('Advanced Subscription Settings'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.purple),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Test Notification Button
                  OutlinedButton.icon(
                    onPressed: () async {
                      await BudgetNotificationService.sendDailyReminder(
                        remaining: 1500,
                        daysLeft: 15,
                        currencySymbol: '\$',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Test notification sent!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Send Test Notification'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Save budget notifications
                  await BudgetNotificationService.saveNotificationSettings(
                    budget: budgetWeeklyEnabled,
                    threshold: budgetThresholdEnabled,
                    daily: budgetDailyEnabled,
                  );
                  
                  // Save subscription reminders
                  await LocalStorageService.setBoolSetting('subscription_reminders_enabled', subscriptionEnabled);
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification settings saved!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16213e),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}



