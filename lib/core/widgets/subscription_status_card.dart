import 'package:flutter/material.dart';
import 'package:smart_receipt/core/services/premium_service.dart';

class SubscriptionStatusCard extends StatelessWidget {
  const SubscriptionStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!PremiumService.isPremium && !PremiumService.isTrialActive) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _getGradient(),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getShadowColor(),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getIcon(),
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getTitle(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (PremiumService.isTrialActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'TRIAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _getDescription(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          if (_shouldShowActionButton()) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleAction(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _getButtonColor(),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _getActionText(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  LinearGradient _getGradient() {
    if (PremiumService.isTrialActive) {
      return const LinearGradient(
        colors: [Color(0xFFff6b6b), Color(0xFFee5a24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (PremiumService.isSubscriptionExpiringSoon) {
      return const LinearGradient(
        colors: [Color(0xFFfeca57), Color(0xFFff9ff3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return const LinearGradient(
        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  Color _getShadowColor() {
    if (PremiumService.isTrialActive) {
      return const Color(0xFFff6b6b).withOpacity(0.3);
    } else if (PremiumService.isSubscriptionExpiringSoon) {
      return const Color(0xFFfeca57).withOpacity(0.3);
    } else {
      return const Color(0xFF667eea).withOpacity(0.3);
    }
  }

  IconData _getIcon() {
    if (PremiumService.isTrialActive) {
      return Icons.timer;
    } else if (PremiumService.isSubscriptionExpiringSoon) {
      return Icons.warning;
    } else {
      return Icons.star;
    }
  }

  String _getTitle() {
    if (PremiumService.isTrialActive) {
      return 'Trial Active';
    } else if (PremiumService.isSubscriptionExpiringSoon) {
      return 'Subscription Expiring Soon';
    } else {
      return 'Premium Active';
    }
  }

  String _getDescription() {
    if (PremiumService.isTrialActive) {
      final daysLeft = PremiumService.daysUntilTrialEnds ?? 0;
      return 'Your ${PremiumService.currentTier.name.toUpperCase()} trial ends in $daysLeft days. Subscribe now to keep your premium features!';
    } else if (PremiumService.isSubscriptionExpiringSoon) {
      final daysLeft = PremiumService.daysUntilRenewal ?? 0;
      return 'Your ${PremiumService.subscriptionType} subscription renews in $daysLeft days. Make sure your payment method is up to date!';
    } else {
      return 'You\'re enjoying all premium features. Your ${PremiumService.subscriptionType} subscription is active.';
    }
  }

  bool _shouldShowActionButton() {
    return PremiumService.isTrialActive || PremiumService.isSubscriptionExpiringSoon;
  }

  String _getActionText() {
    if (PremiumService.isTrialActive) {
      return 'Subscribe Now';
    } else if (PremiumService.isSubscriptionExpiringSoon) {
      return 'Manage Subscription';
    } else {
      return 'View Details';
    }
  }

  Color _getButtonColor() {
    if (PremiumService.isTrialActive) {
      return const Color(0xFFff6b6b);
    } else if (PremiumService.isSubscriptionExpiringSoon) {
      return const Color(0xFFfeca57);
    } else {
      return const Color(0xFF667eea);
    }
  }

  void _handleAction(BuildContext context) {
    if (PremiumService.isTrialActive) {
      // Navigate to subscription page
      Navigator.pushNamed(context, '/subscription');
    } else if (PremiumService.isSubscriptionExpiringSoon) {
      // Navigate to subscription management
      Navigator.pushNamed(context, '/subscription');
    } else {
      // Navigate to subscription details
      Navigator.pushNamed(context, '/subscription');
    }
  }
}

// Compact version for smaller spaces
class CompactSubscriptionStatusCard extends StatelessWidget {
  const CompactSubscriptionStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!PremiumService.isPremium && !PremiumService.isTrialActive) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: _getGradient(),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _getShadowColor(),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _getIcon(),
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getCompactText(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (PremiumService.isTrialActive || PremiumService.isSubscriptionExpiringSoon)
            GestureDetector(
              onTap: () => _handleAction(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'View',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  LinearGradient _getGradient() {
    if (PremiumService.isTrialActive) {
      return const LinearGradient(
        colors: [Color(0xFFff6b6b), Color(0xFFee5a24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (PremiumService.isSubscriptionExpiringSoon) {
      return const LinearGradient(
        colors: [Color(0xFFfeca57), Color(0xFFff9ff3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return const LinearGradient(
        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  Color _getShadowColor() {
    if (PremiumService.isTrialActive) {
      return const Color(0xFFff6b6b).withOpacity(0.3);
    } else if (PremiumService.isSubscriptionExpiringSoon) {
      return const Color(0xFFfeca57).withOpacity(0.3);
    } else {
      return const Color(0xFF667eea).withOpacity(0.3);
    }
  }

  IconData _getIcon() {
    if (PremiumService.isTrialActive) {
      return Icons.timer;
    } else if (PremiumService.isSubscriptionExpiringSoon) {
      return Icons.warning;
    } else {
      return Icons.star;
    }
  }

  String _getCompactText() {
    if (PremiumService.isTrialActive) {
      final daysLeft = PremiumService.daysUntilTrialEnds ?? 0;
      return 'Trial ends in $daysLeft days';
    } else if (PremiumService.isSubscriptionExpiringSoon) {
      final daysLeft = PremiumService.daysUntilRenewal ?? 0;
      return 'Renews in $daysLeft days';
    } else {
      return 'Premium Active';
    }
  }

  void _handleAction(BuildContext context) {
    Navigator.pushNamed(context, '/subscription');
  }
}
