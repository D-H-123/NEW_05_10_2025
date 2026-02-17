import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../services/local_storage_service.dart';
import '../services/currency_service.dart';
import '../services/budget_notification_service.dart';
import '../../features/home/home_spending_providers.dart';

/// Keys for quick action settings
const String _kBudgetRolloverEnabled = 'budget_rollover_enabled';

/// Shared Monthly Budget dialog (scale 0–5000). Use [show] to open from any "set budget" entry point.
class MonthlyBudgetDialog {
  static const double minBudget = 0;
  static const double maxBudget = 5000;

  static const List<double> _presetAmounts = [300, 500, 1000, 2000];

  /// Opens the monthly budget dialog. [onSaved] is called after a successful save so the caller can refresh state.
  static void show(
    BuildContext context,
    WidgetRef ref, {
    String? currencyCode,
    required VoidCallback onSaved,
  }) {
    final effectiveCurrencyCode =
        currencyCode ?? ref.read(currencyProvider).currencyCode;
    final symbol =
        ref.read(currencyProvider.notifier).symbolFor(effectiveCurrencyCode);
    final currentSpending =
        ref.read(currentMonthSpendingProvider).valueOrNull ?? 0.0;

    double currentValue =
        LocalStorageService.getDoubleSetting(LocalStorageService.kMonthlyBudget) ??
            500;
    if (currentValue < minBudget) currentValue = minBudget;
    if (currentValue > maxBudget) currentValue = maxBudget;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final budgetLimit = currentValue;
          final percentage =
              budgetLimit > 0 ? (currentSpending / budgetLimit * 100) : 0.0;
          final remaining = (budgetLimit - currentSpending).clamp(0.0, double.infinity);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.largeBorderRadius,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header: title + close
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Monthly Budget',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close,
                                color: AppColors.textPrimary, size: 24),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 40, minHeight: 40),
                          ),
                        ],
                      ),
                      Divider(height: 24, color: AppColors.borderLight),
                      // Budget overview box
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: AppTheme.mediumBorderRadius,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Current Spending',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '$symbol${currentSpending.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Budget Limit',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '$symbol${budgetLimit.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDarkBlue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Adjust Budget label only (no Comfortable/status)
                      Text(
                        'Adjust Budget',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Slider (0–5000), no value label on bar
                      LayoutBuilder(
                        builder: (context, constraints) {
                          const min = minBudget;
                          const max = maxBudget;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: AppColors.primaryDarkBlue,
                                  inactiveTrackColor: AppColors.borderLight,
                                  thumbColor: AppColors.primaryDarkBlue,
                                  overlayColor: AppColors.primaryDarkBlue
                                      .withOpacity(0.2),
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 10),
                                  trackHeight: 6,
                                ),
                                child: Slider(
                                  value: currentValue,
                                  min: min,
                                  max: max,
                                  divisions: 500,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      currentValue = value;
                                    });
                                  },
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$symbol${min.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                  Text(
                                    '$symbol${max.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      // Input + preset buttons (no headline)
                      const SizedBox(height: 16),
                      // Input: full width, € on left inside field, number input, rounded-xl, bg grey-100
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text(
                                symbol,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextFormField(
                                key: ValueKey(currentValue.toStringAsFixed(0)),
                                initialValue: currentValue.toStringAsFixed(0),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[\d.]')),
                                ],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 14),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: true,
                                  fillColor: Colors.transparent,
                                ),
                                onChanged: (text) {
                                  final parsed = double.tryParse(text);
                                  if (parsed != null) {
                                    final clamped = parsed
                                        .clamp(minBudget, maxBudget);
                                    setDialogState(() {
                                      currentValue = clamped;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Preset buttons: flex gap-2, flex-1 each, rounded-full, selected = primary bg + white text
                      Row(
                        children: _presetAmounts.asMap().entries.map((entry) {
                          final index = entry.key;
                          final amount = entry.value;
                          final isSelected = (currentValue - amount).abs() < 1;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: index < _presetAmounts.length - 1 ? 8 : 0),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      currentValue = amount;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primaryDarkBlue
                                          : const Color(0xFFF5F5F5),
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$symbol${amount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      // Budget used: pill shape, light green bg, bold % + regular "of budget used"
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFe6ffe6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.3,
                              ),
                              children: [
                                TextSpan(
                                  text: '${percentage.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2e7d32),
                                  ),
                                ),
                                const TextSpan(
                                  text: ' of budget used',
                                  style: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    color: Color(0xFF3cb371),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Quick Actions (own state so toggles load and update correctly)
                      _QuickActionsSection(
                        symbol: symbol,
                        remaining: remaining,
                      ),
                      const SizedBox(height: 24),
                      // Save Changes button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await LocalStorageService.setDoubleSetting(
                              LocalStorageService.kMonthlyBudget,
                              currentValue,
                            );
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Monthly budget set to $symbol${currentValue.toStringAsFixed(0)}',
                                ),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                            onSaved();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDarkBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickActionsSection extends StatefulWidget {
  const _QuickActionsSection({
    required this.symbol,
    required this.remaining,
  });

  final String symbol;
  final double remaining;

  @override
  State<_QuickActionsSection> createState() => _QuickActionsSectionState();
}

class _QuickActionsSectionState extends State<_QuickActionsSection> {
  bool? _budgetAlertEnabled;
  bool? _rollOverEnabled;
  Map<String, bool>? _notifSettings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings =
        await BudgetNotificationService.getNotificationSettings();
    final rollOver = LocalStorageService.getBoolSetting(
        _kBudgetRolloverEnabled, defaultValue: false);
    if (mounted) {
      setState(() {
        _notifSettings = settings;
        _budgetAlertEnabled = settings['threshold'] ?? true;
        _rollOverEnabled = rollOver;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _QuickActionRow(
          icon: Icons.notifications_active,
          iconColor: AppColors.warning,
          title: 'Budget Alert',
          subtitle: 'Notify at 80% usage',
          value: _budgetAlertEnabled ?? true,
          onChanged: (value) async {
            await BudgetNotificationService.saveNotificationSettings(
              budget: _notifSettings?['budget'] ?? true,
              threshold: value,
              daily: _notifSettings?['daily'] ?? false,
            );
            if (mounted) setState(() => _budgetAlertEnabled = value);
          },
        ),
        const SizedBox(height: 12),
        _QuickActionRow(
          icon: Icons.calendar_today,
          iconColor: AppColors.success,
          title: 'Roll Over Unused',
          subtitle:
              'Add ${widget.symbol}${widget.remaining.toStringAsFixed(0)} to next month',
          value: _rollOverEnabled ?? false,
          onChanged: (value) async {
            await LocalStorageService.setBoolSetting(
                _kBudgetRolloverEnabled, value);
            if (mounted) setState(() => _rollOverEnabled = value);
          },
        ),
      ],
    );
  }
}

/// Pill-style toggle matching reference: w-12 h-7 track, white sliding thumb.
class _PillToggle extends StatelessWidget {
  const _PillToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  static const double width = 48;
  static const double height = 28;
  static const double thumbSize = 20;
  static const double thumbMargin = 4;

  @override
  Widget build(BuildContext context) {
    final thumbLeft = value ? (width - thumbSize - thumbMargin) : thumbMargin;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: value ? AppColors.primaryDarkBlue : const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              left: thumbLeft,
              top: (height - thumbSize) / 2,
              child: Container(
                width: thumbSize,
                height: thumbSize,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 2,
                      offset: Offset(0, 1),
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
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          _PillToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
