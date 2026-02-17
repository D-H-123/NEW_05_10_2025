import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// ✅ UI/UX Improvement: Engaging empty state widget
/// Used throughout the app for better user experience
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color? iconColor;
  final List<Widget>? actions;
  final Widget? customIcon;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.iconColor,
    this.actions,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            if (customIcon != null)
              customIcon!
            else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.primary).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 64,
                  color: iconColor ?? AppColors.primary,
                ),
              ),
            const SizedBox(height: 24),
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Message
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            // Actions
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 32),
              ...actions!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Predefined empty state for no bills/receipts
class NoBillsEmptyState extends StatelessWidget {
  final VoidCallback? onScanPressed;
  final VoidCallback? onManualEntryPressed;

  const NoBillsEmptyState({
    super.key,
    this.onScanPressed,
    this.onManualEntryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: 'No receipts saved yet',
      message: 'Start scanning receipts or create manual entries\nto see them organized here.',
      icon: Icons.receipt_long_outlined,
      iconColor: AppColors.primaryDarkBlue,
      actions: [
        if (onScanPressed != null || onManualEntryPressed != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (onScanPressed != null)
                ElevatedButton.icon(
                  onPressed: onScanPressed,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Scan Receipt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDarkBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              if (onManualEntryPressed != null)
                ElevatedButton.icon(
                  onPressed: onManualEntryPressed,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Manual Entry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDarkBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Predefined empty state for no budget
class NoBudgetEmptyState extends StatelessWidget {
  final VoidCallback? onSetBudgetPressed;

  const NoBudgetEmptyState({
    super.key,
    this.onSetBudgetPressed,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: 'No Budget Set',
      message: 'Set a monthly budget to track your spending\nand stay on top of your finances.',
      icon: Icons.account_balance_wallet_outlined,
      iconColor: AppColors.primaryDarkBlue,
      actions: [
        if (onSetBudgetPressed != null)
          ElevatedButton(
            onPressed: onSetBudgetPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDarkBlue,
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
    );
  }
}

/// Predefined empty state for no expenses in collaboration
class NoExpensesEmptyState extends StatelessWidget {
  final VoidCallback? onAddExpensePressed;

  const NoExpensesEmptyState({
    super.key,
    this.onAddExpensePressed,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: 'No expenses yet',
      message: 'Start tracking expenses by adding your first one.\nEveryone in the budget will see it in real-time.',
      icon: Icons.receipt_long,
      iconColor: AppColors.primary,
      actions: [
        if (onAddExpensePressed != null)
          ElevatedButton.icon(
            onPressed: onAddExpensePressed,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Expense'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }
}

