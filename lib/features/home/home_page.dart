import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
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
import '../../core/services/budget_streak_service.dart';
import '../collaboration/budget_collaboration_page.dart';

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
  double? _monthlyBudget;
  int _selectedMonthIndex = DateTime.now().month - 1; // 0-based index

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  double _calculateCurrentMonthSpending() {
    final bills = ref.watch(billProvider);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);

    return bills
        .where((bill) =>
            bill.date != null &&
            bill.date!.isAfter(currentMonth.subtract(const Duration(days: 1))) &&
            bill.date!.isBefore(nextMonth))
        .fold<double>(0.0, (sum, bill) => sum + (bill.total ?? 0.0));
  }

  int _getDaysLeftInMonth() {
    final now = DateTime.now();
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    return lastDayOfMonth.day - now.day;
  }

  Map<int, double> _getMonthlySpending() {
    final bills = ref.watch(billProvider);
    final now = DateTime.now();
    final currentYear = now.year;
    final monthlyTotals = <int, double>{};

    // Initialize all months from Jan to current month with 0
    for (int month = 1; month <= now.month; month++) {
      monthlyTotals[month] = 0.0;
    }

    // Calculate spending for each month
    for (final bill in bills) {
      if (bill.date != null && bill.date!.year == currentYear) {
        final month = bill.date!.month;
        if (month <= now.month) {
          monthlyTotals[month] = (monthlyTotals[month] ?? 0.0) + (bill.total ?? 0.0);
        }
      }
    }

    return monthlyTotals;
  }

  double _calculatePercentageChange(int selectedMonth) {
    final monthlySpending = _getMonthlySpending();
    final currentAmount = monthlySpending[selectedMonth + 1] ?? 0.0;
    
    if (selectedMonth == 0) return 0.0; // No previous month for January
    
    final previousAmount = monthlySpending[selectedMonth] ?? 0.0;
    
    if (previousAmount == 0) {
      return currentAmount > 0 ? 100.0 : 0.0;
    }
    
    return ((currentAmount - previousAmount) / previousAmount) * 100;
  }

  void _showBudgetDialog() {
    double currentValue = _monthlyBudget ?? 500;
    if (currentValue < 100) currentValue = 100;
    if (currentValue > 99999) currentValue = 99999;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void setPresetBudget(double amount) {
            setDialogState(() {
              currentValue = amount;
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.largeBorderRadius,
            ),
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.blue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Monthly Budget',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set your monthly spending goal to track your expenses.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Budget Display with Slider
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
                      borderRadius: AppTheme.mediumBorderRadius,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getCurrencySymbol(_selectedCurrency),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              currentValue.toStringAsFixed(0),
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.blue,
                            inactiveTrackColor: Colors.grey[300],
                            thumbColor: Colors.blue,
                            overlayColor: Colors.blue.withOpacity(0.2),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: currentValue,
                            min: 100,
                            max: 99999,
                            divisions: 999,
                            onChanged: (value) {
                              setDialogState(() {
                                currentValue = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Quick Presets Label
                  const Text(
                    'Quick Presets',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Preset Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetButton('\$500', 500, setPresetBudget),
                      _buildPresetButton('\$1K', 1000, setPresetBudget),
                      _buildPresetButton('\$2K', 2000, setPresetBudget),
                      _buildPresetButton('\$3K', 3000, setPresetBudget),
                      _buildPresetButton('\$4K', 4000, setPresetBudget),
                      _buildPresetButton('\$5K', 5000, setPresetBudget),
                      _buildPresetButton('\$10K', 10000, setPresetBudget),
                      _buildPresetButton('\$15K', 15000, setPresetBudget),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Info text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: AppTheme.smallBorderRadius,
                      border: Border.all(color: Colors.blue.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Min: \$100 • Max: \$99,999',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  Row(
                    children: [
                      if (_monthlyBudget != null)
                        TextButton(
                          onPressed: () async {
                            await LocalStorageService.setDoubleSetting(
                              LocalStorageService.kMonthlyBudget,
                              0,
                            );
                            setState(() {
                              _monthlyBudget = null;
                            });
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Budget cleared'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          },
                          child: const Text(
                            'Clear',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await LocalStorageService.setDoubleSetting(
                            LocalStorageService.kMonthlyBudget,
                            currentValue,
                          );
                          setState(() {
                            _monthlyBudget = currentValue;
                          });
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Monthly budget set to ${_getCurrencySymbol(_selectedCurrency)}${currentValue.toStringAsFixed(0)}',
                                ),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16213e),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPresetButton(String label, double value, Function(double) onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onPressed(value),
        borderRadius: AppTheme.smallBorderRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppTheme.smallBorderRadius,
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _ensureCurrencySetup();
    _loadBudget();
  }

  void _loadBudget() {
    setState(() {
      _monthlyBudget = LocalStorageService.getDoubleSetting(LocalStorageService.kMonthlyBudget);
    });
    
    // Check and update streak if budget is set
    if (_monthlyBudget != null && _monthlyBudget! > 0) {
      _checkStreakAsync();
    }
  }

  Future<void> _checkStreakAsync() async {
    final currentSpending = _calculateCurrentMonthSpending();
    final isUnderBudget = _monthlyBudget != null && currentSpending < _monthlyBudget!;
    
    final result = await BudgetStreakService.checkAndUpdateStreak(
      isUnderBudget: isUnderBudget,
    );
    
    // Show celebration for milestones
    if (result.milestone != null && mounted) {
      _showStreakMilestone(result.milestone!);
    } else if (result.isNewBest && result.currentStreak > 7 && mounted) {
      _showNewBestStreak(result.currentStreak);
    }
    
    if (mounted) {
      setState(() {}); // Refresh UI
    }
  }

  void _showStreakMilestone(int milestone) {
    final emoji = BudgetStreakService.getStreakEmoji(milestone);
    final message = BudgetStreakService.getStreakMessage(milestone);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 80),
            ),
            const SizedBox(height: 16),
            Text(
              '$milestone Day Streak!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _shareStreak(milestone);
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16213e),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNewBestStreak(int streak) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text('New Best Streak: $streak days!'),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _shareStreak(int streak) {
    final emoji = BudgetStreakService.getStreakEmoji(streak);
    final message = '''
$emoji $streak Day Budget Streak! $emoji

I've stayed under my budget for $streak consecutive days!

${BudgetStreakService.getStreakMessage(streak)}

Join me on SmartReceipt! 💪
#BudgetStreak #FinancialGoals #SmartReceipt
    ''';
    
    Share.share(message, subject: 'My Budget Streak Achievement');
    HapticFeedback.mediumImpact();
  }

  void _showStreakInfo() {
    final currentStreak = BudgetStreakService.getCurrentStreak();
    final bestStreak = BudgetStreakService.getBestStreak();
    final totalDays = BudgetStreakService.getTotalDaysUnder();
    final emoji = BudgetStreakService.getStreakEmoji(currentStreak);
    final message = BudgetStreakService.getStreakMessage(currentStreak);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Budget Streak',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Current Streak
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(BudgetStreakService.getStreakColor(currentStreak)),
                    Color(BudgetStreakService.getStreakColor(currentStreak)).withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Current Streak',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$currentStreak',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'days',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStreakStat('Best', '$bestStreak', '🏆'),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                _buildStreakStat('Total', '$totalDays', '📊'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _shareStreak(currentStreak);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16213e),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakStat(String label, String value, String emoji) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
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
      print('🔍 MAGIC HOME: Calling showDialog...');
      
      final result = await showDialog(
        context: context,
        barrierDismissible: true,
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

  Widget _buildSpendingAnalytics(double growthPercentage) {
    final currentSpending = _calculateCurrentMonthSpending();
    final daysLeft = _getDaysLeftInMonth();
    final currencySymbol = _getCurrencySymbol(_selectedCurrency);

    // If no budget is set, show "Set Budget" card
    if (_monthlyBudget == null || _monthlyBudget == 0) {
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
                const Text(
                  'Budget',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/analysis'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16213e),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'All Budgets',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Budget Set',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set a monthly budget to track your spending',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _showBudgetDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4facfe),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Set Budget',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

    // Calculate percentage and determine color
    final percentage = (currentSpending / _monthlyBudget!) * 100;
    final remaining = _monthlyBudget! - currentSpending;
    
    Color progressColor;
    Color statusColor;
    String statusIcon;
    String statusText;
    
    if (percentage < 70) {
      progressColor = Colors.green;
      statusColor = Colors.green;
      statusIcon = '✓';
      statusText = 'On track';
    } else if (percentage < 100) {
      progressColor = Colors.orange;
      statusColor = Colors.orange;
      statusIcon = '⚠';
      statusText = 'Watch spending';
    } else {
      progressColor = Colors.red;
      statusColor = Colors.red;
      statusIcon = '✕';
      statusText = 'Over budget';
    }

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
          // Header Row with Streak
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Budget',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  // Streak Badge
                  if (BudgetStreakService.getCurrentStreak() > 0) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _showStreakInfo(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(BudgetStreakService.getStreakColor(BudgetStreakService.getCurrentStreak())).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Color(BudgetStreakService.getStreakColor(BudgetStreakService.getCurrentStreak())),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              BudgetStreakService.getStreakEmoji(BudgetStreakService.getCurrentStreak()),
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${BudgetStreakService.getCurrentStreak()} day${BudgetStreakService.getCurrentStreak() > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(BudgetStreakService.getStreakColor(BudgetStreakService.getCurrentStreak())),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              GestureDetector(
                onTap: () => context.go('/analysis'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213e),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'All Budgets',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Amount Remaining/Overspending
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                remaining >= 0
                    ? '$currencySymbol${remaining.toStringAsFixed(2)}'
                    : '$currencySymbol${remaining.abs().toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  remaining >= 0 ? 'left' : 'overspending',
                  style: TextStyle(
                    fontSize: 14,
                    color: remaining >= 0 ? Colors.grey[600] : Colors.red,
                    fontWeight: remaining >= 0 ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Spent this month
          Text(
            '$currencySymbol${currentSpending.toStringAsFixed(2)} spent this month',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          
          // Progress Bar with Animation
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
            tween: Tween<double>(
              begin: 0,
              end: (percentage / 100).clamp(0.0, 1.0),
            ),
            builder: (context, value, child) {
              return Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          
          // Status and Days Left Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    statusIcon,
                    style: TextStyle(
                      fontSize: 14,
                      color: statusColor,
                    ),
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
              Text(
                '$daysLeft days left',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          // Share Achievement Button (only show if under budget)
          if (percentage < 100) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _shareAchievement(remaining, percentage, daysLeft),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213e), // Dark blue theme
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF16213e).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.share,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '🎉 Share Your Success',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          // Debug: Start Streak Button (only in development)
          if (percentage < 100 && BudgetStreakService.getCurrentStreak() == 0) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                await _checkStreakAsync();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Streak started! 🔥'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow,
                      color: Colors.orange[700],
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Start Your Streak',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _shareAchievement(double remaining, double percentage, int daysLeft) {
    final currencySymbol = _getCurrencySymbol(_selectedCurrency);
    final monthName = DateTime.now().month;
    const monthNames = ['', 'January', 'February', 'March', 'April', 'May', 'June', 
                       'July', 'August', 'September', 'October', 'November', 'December'];
    
    String message;
    
    if (percentage < 70) {
      message = '''
🎉 Great job! I'm crushing my budget this month!

💰 ${currencySymbol}${remaining.toStringAsFixed(0)} remaining
📊 Only ${percentage.toStringAsFixed(0)}% spent
📅 $daysLeft days left in ${monthNames[monthName]}

I'm staying on track with SmartReceipt! 💪
#BudgetGoals #FinancialFreedom #SmartReceipt
      ''';
    } else {
      message = '''
✅ Staying on track with my budget!

💰 ${currencySymbol}${remaining.toStringAsFixed(0)} still available
📊 ${percentage.toStringAsFixed(0)}% of budget used
📅 $daysLeft days to go in ${monthNames[monthName]}

Managing my finances with SmartReceipt! 📱
#BudgetSuccess #SmartSpending #SmartReceipt
      ''';
    }
    
    Share.share(
      message,
      subject: 'My Budget Achievement',
    );
    
    HapticFeedback.mediumImpact();
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Share your success! 🎉'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildMonthlySpendingGraph() {
    final monthlySpending = _getMonthlySpending();
    final now = DateTime.now();
    final selectedAmount = monthlySpending[_selectedMonthIndex + 1] ?? 0.0;
    final percentageChange = _calculatePercentageChange(_selectedMonthIndex);
    final currencySymbol = _getCurrencySymbol(_selectedCurrency);

    // Get max value for scaling bars
    double maxAmount = 1.0;
    monthlySpending.forEach((month, amount) {
      if (amount > maxAmount) maxAmount = amount;
    });

    // Month names
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
          // Header: Amount and Percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$currencySymbol${selectedAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    monthNames[_selectedMonthIndex],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (_selectedMonthIndex > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: percentageChange >= 0
                        ? const Color(0xFF16213e).withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        percentageChange >= 0 ? Icons.trending_up : Icons.trending_down,
                        color: percentageChange >= 0 ? const Color(0xFF16213e) : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${percentageChange >= 0 ? '+' : ''}${percentageChange.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: percentageChange >= 0 ? const Color(0xFF16213e) : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Month Names (Clickable)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(now.month, (index) {
              final isSelected = index == _selectedMonthIndex;
              
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMonthIndex = index;
                    });
                    HapticFeedback.lightImpact();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      monthNames[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isSelected ? 13 : 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF16213e)
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          
          const SizedBox(height: 12),
          
          // Bar Chart
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(now.month, (index) {
                final amount = monthlySpending[index + 1] ?? 0.0;
                final baseBarHeight = maxAmount > 0 ? (amount / maxAmount) * 100 : 0.0;
                final isSelected = index == _selectedMonthIndex;
                
                // Selected bar is 20% taller to "pop out"
                final barHeight = isSelected 
                    ? (baseBarHeight * 1.2).clamp(4.0, 120.0)
                    : baseBarHeight.clamp(4.0, 100.0);
                
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMonthIndex = index;
                        });
                        HapticFeedback.lightImpact();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        height: barHeight,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: isSelected
                                ? [
                                    const Color(0xFF16213e), // Dark blue (footer color)
                                    const Color(0xFF2a3f5f), // Slightly lighter blue
                                  ]
                                : [
                                    const Color(0xFF16213e).withOpacity(0.4),
                                    const Color(0xFF2a3f5f).withOpacity(0.3),
                                  ],
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF16213e).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyBudgetPromo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16213e), Color(0xFF1a2947)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16213e).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BudgetCollaborationPage(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Family Budgets',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Share budgets & track spending together',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange,
                      width: 1.5,
                    ),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
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
                  color: const Color(0xFF16213e),
                    shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                    boxShadow: [
                      BoxShadow(
                      color: const Color(0xFF16213e).withOpacity(0.4),
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
                  size: 38,
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
                    _buildSpendingAnalytics(widget.growthPercentage),
                    _buildMonthlySpendingGraph(),
                    // Family Budget Promo Card
                    _buildFamilyBudgetPromo(),
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