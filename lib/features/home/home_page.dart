import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import './dynamic_expense_modal.dart';
import '../storage/bill/bill_provider.dart';
import '../storage/models/bill_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/modern_widgets.dart';
import '../../core/services/premium_service.dart';
import '../../core/widgets/subscription_paywall.dart';
import '../../core/widgets/usage_tracker.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/personal_subscription_reminder_service.dart';

class HomePage extends ConsumerStatefulWidget {
  final double growthPercentage;
  final int achievementsCount;

  const HomePage({super.key, required this.growthPercentage, required this.achievementsCount});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedIndex = 0;
  bool _isMenuOpen = false;
  String _selectedCurrency = 'USD';

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  @override
  void initState() {
    super.initState();
    _ensureCurrencySetup();
  }

  Future<void> _ensureCurrencySetup() async {
    final hasSetup = LocalStorageService.getBoolSetting(LocalStorageService.kHasCompletedCurrencySetup);
    final globalCode = ref.read(currencyProvider).currencyCode;
    setState(() {
      _selectedCurrency = globalCode;
    });
    
    // Only show currency selection on very first app launch
    if (!hasSetup) {
      // Show a small modal to pick default currency
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Choose your currency'),
              content: const Text('Select a default currency for your expenses.'),
              actions: [
                TextButton(
                  onPressed: () async {
                    await LocalStorageService.setBoolSetting(LocalStorageService.kHasCompletedCurrencySetup, true);
                    if (mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Skip'),
                ),
                TextButton(
                  onPressed: () async {
                    if (mounted) Navigator.of(ctx).pop();
                    // Reuse currency picker from settings
                    // Requires lazy import to avoid circular deps; keep route-based approach minimal
                    // Show a lightweight picker here using simple choices
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (c) {
                        final options = [
                          'USD','EUR','GBP','CAD','AUD','CHF','INR','BRL'
                        ];
                        return SafeArea(
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              const ListTile(title: Text('Select currency')),
                              for (final code in options)
                                ListTile(
                                  leading: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text(
                                        ref.read(currencyProvider.notifier).symbolFor(code),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(code),
                                  onTap: () async {
                                    await ref.read(currencyProvider.notifier).setCurrency(code);
                                    await LocalStorageService.setBoolSetting(LocalStorageService.kHasCompletedCurrencySetup, true);
                                    if (mounted) {
                                      setState(() {
                                        _selectedCurrency = code;
                                      });
                                      Navigator.of(c).pop();
                                    }
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      });
    }
  }

  String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'CAD':
        return 'C\$';
      case 'AUD':
        return 'A\$';
      case 'CHF':
        return 'CHF';
      case 'INR':
        return '₹';
      case 'BRL':
        return 'R\$';
      default:
        return '\$';
    }
  }

  IconData _getCurrencyIcon(String currency) {
    switch (currency) {
      case 'USD':
        return Icons.attach_money;
      case 'EUR':
        return Icons.euro;
      case 'GBP':
        return Icons.currency_pound;
      case 'CAD':
        return Icons.attach_money;
      case 'AUD':
        return Icons.attach_money;
      case 'CHF':
        return Icons.attach_money;
      case 'INR':
        return Icons.currency_rupee;
      case 'BRL':
        return Icons.attach_money;
      default:
        return Icons.attach_money;
    }
  }

  Color _getCurrencyColor(String currency) {
    switch (currency) {
      case 'USD':
        return Colors.green;
      case 'EUR':
        return Colors.blue;
      case 'GBP':
        return Colors.red;
      case 'CAD':
        return Colors.red;
      case 'AUD':
        return Colors.green;
      case 'CHF':
        return Colors.red;
      case 'INR':
        return Colors.orange;
      case 'BRL':
        return Colors.green;
      default:
        return Colors.green;
    }
  }

  String _getVendorName(Map<String, dynamic> formData) {
    switch (formData['formType']) {
      case 'FormType.manualExpense':
        return 'Manual Expense - ${formData['category'] ?? 'Other'}';
      case 'FormType.subscription':
        final category = formData['subscriptionCategory'] ?? 'Subscription';
        return 'Subscription - $category';
      default:
        return 'Manual Entry';
    }
  }

  Future<void> _showExpenseModal(String category) async {
    print('🔍 MAGIC HOME: Opening modal for category: $category');
    print('🔍 MAGIC HOME: Menu state before toggle: $_isMenuOpen');
    
    _toggleMenu();
    
    print('🔍 MAGIC HOME: Menu state after toggle: $_isMenuOpen');
    
    FormType formType;
    switch (category) {
      case 'Manual Expense':
        formType = FormType.manualExpense;
        break;
      case 'Subscription':
        formType = FormType.subscription;
        break;
      default:
        formType = FormType.manualExpense;
    }
    
    print('🔍 MAGIC HOME: Form type determined: $formType');
    print('🔍 MAGIC HOME: Form type enum value: ${formType.name}');
    print('🔍 MAGIC HOME: Form type index: ${formType.index}');
    print('🔍 MAGIC HOME: About to show modal...');
    
    try {
      print('🔍 MAGIC HOME: Calling showModalBottomSheet...');
      
      
      
             print('🔍 MAGIC HOME: About to create DynamicExpenseModal widget...');
      
             final result = await showModalBottomSheet(
         context: context,
         isScrollControlled: true,
         backgroundColor: Colors.transparent,
         barrierColor: Colors.black54,
         isDismissible: true,
         enableDrag: true,
         builder: (context) => DynamicExpenseModal(
           formType: formType,
           selectedCurrency: _selectedCurrency,
                     onSubmit: (formData) async {
            print('🔍 MAGIC HOME: Form submitted: $formData');
            
            try {
              // Create a unique ID for the bill
              final billId = DateTime.now().millisecondsSinceEpoch.toString();
              
              // Determine if this is a subscription
              final isSubscription = formData['formType'] == 'FormType.subscription';
              final subscriptionType = isSubscription ? formData['frequency']?.toString().toLowerCase() : null;
              
              // Create the bill object
              final bill = Bill(
                id: billId,
                imagePath: 'assets/test_receipts/sample1.jpg', // Placeholder image for manual entries
                vendor: _getVendorName(formData),
                title: (formData['title'] as String?)?.isNotEmpty == true
                    ? formData['title'] as String
                    : null,
                date: formData['date'] ?? formData['startDate'] ?? DateTime.now(),
                total: formData['amount'] ?? 0.0,
                currency: _selectedCurrency,
                ocrText: isSubscription ? 'Subscription entry' : 'Manual entry',
                categoryId: isSubscription 
                    ? (formData['subscriptionCategory'] ?? 'Other')
                    : (formData['category'] ?? 'Other'),
                tags: isSubscription 
                    ? [formData['subscriptionCategory'] ?? 'Other']
                    : [formData['category'] ?? 'Other'],
                location: null,
                notes: formData['notes'] ?? '',
                subscriptionType: subscriptionType,
                subscriptionEndDate: isSubscription ? formData['endDate'] : null, // Include end date for subscriptions
              );
              
              // Save the bill to database
              ref.read(billProvider.notifier).addBill(bill);
              
              // If this is a subscription, schedule reminders
              if (isSubscription) {
                try {
                  print('🔍 DEBUG: Scheduling reminders for new subscription: ${bill.title ?? bill.vendor}');
                  await PersonalSubscriptionReminderService.updateSubscriptionReminders(bill);
                  print('🔍 DEBUG: Reminders scheduled successfully');
                } catch (e) {
                  print('🔍 DEBUG: Error scheduling reminders: $e');
                }
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${category} added successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              print('🔍 MAGIC HOME: Error saving manual entry: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to save ${category}: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
         ),
       );
      
      print('🔍 MAGIC HOME: Modal result: $result');
    } catch (e) {
      print('🔍 MAGIC HOME: ERROR showing modal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening form: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    print('🔍 MAGIC HOME: Modal should now be visible');
  }

  PreferredSizeWidget _buildCustomAppBar() {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'Smart Receipt',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: const [],
    );
  }

  Widget _buildWelcomeCard() {
    return ResponsiveContainer(
      child: GradientCard(
        gradient: AppTheme.secondaryGradient,
        padding: EdgeInsets.all(context.responsivePadding),
        margin: EdgeInsets.symmetric(horizontal: context.responsivePadding),
        child: ResponsiveLayout(
          mobile: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ResponsiveText(
                          'Welcome back!',
                          style: TextStyle(
                            fontSize: context.isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ResponsiveText(
                          'You\'ve saved ${widget.achievementsCount} receipts this month',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: context.isMobile ? 60 : 80,
                    height: context.isMobile ? 60 : 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: context.isMobile ? 30 : 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Keep it up! 🎉',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResponsiveText(
                      'Welcome back!',
                      style: TextStyle(
                        fontSize: context.isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ResponsiveText(
                      'You\'ve saved ${widget.achievementsCount} receipts this month',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Keep it up! 🎉',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: context.isMobile ? 60 : 80,
                height: context.isMobile ? 60 : 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: context.isMobile ? 30 : 40,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpendingAnalytics(double growthPercentage) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                             Text(
                 'Monthly Spending (${_selectedCurrency})',
                 style: const TextStyle(
                   fontSize: 18,
                   fontWeight: FontWeight.bold,
                   color: Colors.black87,
                 ),
               ),
          Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                  color: growthPercentage >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      growthPercentage >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: growthPercentage >= 0 ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${growthPercentage.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: growthPercentage >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Flexible(
                child: Text(
                  '${_getCurrencySymbol(_selectedCurrency)}2,847',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'this month',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: 0.7,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4facfe)),
          ),
          const SizedBox(height: 8),
          Text(
            '70% of monthly budget used (${_getCurrencySymbol(_selectedCurrency)}4,000)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(int achievementsCount) {
    // All quick action boxes (Scan, Achievements, Storage, Pro subscription) removed
    return const SizedBox.shrink();
  }

  void _showAchievements() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.largeBorderRadius,
        ),
        title: const Text(
          '🏆 Achievements',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAchievementTile('First Receipt', 'Scanned your first receipt!', true),
            _buildAchievementTile('Receipt Pro', 'Scanned 10 receipts', widget.achievementsCount >= 10),
            _buildAchievementTile('Organization Master', 'Saved 50 receipts', widget.achievementsCount >= 50),
            _buildAchievementTile('Receipt Legend', 'Saved 100 receipts', widget.achievementsCount >= 100),
          ],
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

  Widget _buildAchievementTile(String title, String description, bool unlocked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked ? AppTheme.successColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: AppTheme.smallBorderRadius,
        border: Border.all(
          color: unlocked ? AppTheme.successColor.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            unlocked ? Icons.check_circle : Icons.lock,
            color: unlocked ? AppTheme.successColor : Colors.grey,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: unlocked ? Colors.black87 : Colors.grey,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: unlocked ? Colors.black54 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Gradient gradient) {
    return Container(
      height: 120, // Fixed height to make it rectangular
      padding: EdgeInsets.all(context.responsivePadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.largeBorderRadius,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: context.isMobile ? 50 : 60,
            height: context.isMobile ? 50 : 60,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: AppTheme.mediumBorderRadius,
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: context.isMobile ? 24 : 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: context.isMobile ? 14 : 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: context.isMobile ? 11 : 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumActionCard() {
    return Container(
      height: 120,
      margin: EdgeInsets.symmetric(horizontal: context.responsivePadding),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppTheme.largeBorderRadius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4facfe).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.star,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Upgrade to Pro',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Unlimited scans & more',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradePrompt() {
    showDialog(
      context: context,
      builder: (context) => SubscriptionPaywall(
        title: 'Unlock Premium Features',
        subtitle: 'Get unlimited scans, advanced analytics, and more!',
        onDismiss: () => Navigator.of(context).pop(),
        showTrialOption: !PremiumService.isTrialActive,
      ),
    );
  }

  Widget _buildCircularMenu() {
    return Container(
      width: 250,
      height: 250,
             decoration: BoxDecoration(
         color: Colors.transparent,
         borderRadius: BorderRadius.circular(100),
       ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Main Plus Button
          AnimatedRotation(
            turns: _isMenuOpen ? 0.125 : 0.0, // 45 degree rotation when open
            duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: () {
                print('🔍 Plus button tapped. Menu state before: $_isMenuOpen');
                _toggleMenu();
                print('🔍 Menu state after: $_isMenuOpen');
          },
                child: Container(
                width: 60,
                height: 60,
                  decoration: BoxDecoration(
                  color: const Color(0xFF4facfe),
                    shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                    boxShadow: [
                      BoxShadow(
                      color: const Color(0xFF4facfe).withOpacity(0.4),
                        blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                child: Icon(
                  _isMenuOpen ? Icons.close : Icons.add,
                    color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          // Menu items - positioned in a circle when open
          ...(_isMenuOpen ? [
            // Manual Expense - Top (0°)
            Positioned(
              top: 10,
              child: _buildMenuItem(
                'Manual\nExpense',
                Icons.account_balance_wallet,
                Colors.green,
                () async {
                  print('🔍 MAGIC HOME: Manual Expense callback executed!');
                  await _showExpenseModal('Manual Expense');
                },
                size: 60,
              ),
            ),
            // Subscription - Top Right (45°)
            Positioned(
              top: 25,
              right: 25,
              child: _buildMenuItem(
                'Subscription',
                Icons.calendar_today,
                Colors.blue,
                () async {
                  print('🔍 MAGIC HOME: Subscription callback executed!');
                  await _showExpenseModal('Subscription');
                },
                size: 60,
              ),
            ),
          ] : <Widget>[]),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String label, IconData icon, Color color, Future<void> Function() onTap, {double size = 70.0}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) {
      print('🔍 MAGIC HOME: Menu item "$label" tap down detected!');
    },
    onTapUp: (_) {
      print('🔍 MAGIC HOME: Menu item "$label" tap up detected!');
    },
    onTap: () {
      onTap();
    },
    child: Container(
      width: size,        // Use the size parameter
      height: size,       // Use the size parameter
         decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: size * 0.34), // Scale icon with button size
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: size * 0.14, // Scale text with button size
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final bottomPadding = MediaQuery.of(context).padding.bottom;

        const baseScreenWidth = 375.0; // iPhone standard width, adjust to your test device
        const baseScreenHeight = 812.0;

        final widthScale = screenWidth / baseScreenWidth;
        final heightScale = screenHeight / baseScreenHeight;

        final leftPosition = -70 * widthScale;
        final bottomPosition = (kBottomNavigationBarHeight + bottomPadding - 140) * heightScale;

    return Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildCustomAppBar(),
          body: Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildWelcomeCard(),
                    _buildSpendingAnalytics(widget.growthPercentage),
                    // Usage tracker for free users
                    if (!PremiumService.isPremium) const UsageTracker(),
                    _buildQuickActions(widget.achievementsCount),
                    const SizedBox(height: 20),
                    const SizedBox(height: 120), // Space for floating button
                  ],
                ),
              ),
              // Positioned button on left side, 1cm above bottom navigation
              Positioned(
                left: leftPosition, // 24px from left edge
                bottom: bottomPosition, // 1cm above bottom nav
                child: _buildCircularMenu(),
              ),
            ],
          ),
          // Remove floatingActionButton completely
          bottomNavigationBar: ModernBottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
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
                  context.go('/settings');
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
//   @override
//   Widget build(BuildContext context) {
//     final auth = ref.watch(authControllerProvider);

//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Column(
//         children: [
//           _buildCustomAppBar(),
//           Expanded(
//             child: SingleChildScrollView(
//               physics: const BouncingScrollPhysics(),
//               child: Column(
//                 children: [
//                   const SizedBox(height: 20),
//                   _buildWelcomeCard(),
//                   _buildSpendingAnalytics(widget.growthPercentage),
//                                  _buildQuickActions(widget.achievementsCount),
               
//                                                 const SizedBox(height: 20),
               
//                const SizedBox(height: 20), // Space for bottom nav
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: _buildCircularMenu(),
//       floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
//       // floatingActionButton: Container(
//       //   margin: const EdgeInsets.only( bottom: 0, right: 330),
//       //   child: _buildCircularMenu(),
//       // ),
//       bottomNavigationBar: Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           boxShadow: [
//             BoxShadow(
//               color: Colors.grey.withOpacity(0.2),
//               blurRadius: 10,
//               offset: const Offset(0, -5),
//             ),
//           ],
//         ),
//         child: BottomNavigationBar(
//           type: BottomNavigationBarType.fixed,
//           backgroundColor: const Color(0xFF16213e),
//           elevation: 0,
//           currentIndex: _selectedIndex,
//           selectedItemColor: const Color(0xFF4facfe),
//           unselectedItemColor: Colors.grey[600],
//           onTap: (index) {
//             setState(() {
//               _selectedIndex = index;
//             });
//             // ignore: unused_local_variable
//             Widget destination = const HomePage(growthPercentage: 25, achievementsCount: 10,) as Widget;
//             switch (index) {
//               case 0:
//               context.go('/home');
            
//                 break;
//               case 1:
//                 context.go('/analysis');
//                 break;
//               case 2:
//                 // Navigator.push(
//                   context.go('/scan');
//                   // MaterialPageRoute(builder: (context) => const CameraPage()),
//                 // );
//                 break;
//               case 3:
//                 context.go('/bills');
//                 break;
//               case 4:
//                 context.go('/settings');
//                 break;
//             }
//           },
//           items: const [
//             BottomNavigationBarItem(
//               icon: Icon(Icons.home),
//               label: 'Home',
//             ),
//             BottomNavigationBarItem(
//               icon: Icon(Icons.analytics),
//               label: 'Analysis',
//             ),
//             BottomNavigationBarItem(
//               icon: Icon(Icons.camera_alt),
//               label: 'Scan',
//             ),
//             BottomNavigationBarItem(
//               icon: Icon(Icons.folder),
//               label: 'Storage',
//             ),
//             BottomNavigationBarItem(
//               icon: Icon(Icons.person),
//               label: 'Profile',
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
}