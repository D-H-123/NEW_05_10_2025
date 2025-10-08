import 'package:flutter/material.dart';

class SubscriptionBadge extends StatefulWidget {
  final String subscriptionType;
  final double? size;
  final bool showText;
  final bool isInteractive;
  final Function(String)? onFrequencyChanged;

  const SubscriptionBadge({
    super.key,
    required this.subscriptionType,
    this.size = 16.0,
    this.showText = true,
    this.isInteractive = false,
    this.onFrequencyChanged,
  });

  @override
  State<SubscriptionBadge> createState() => _SubscriptionBadgeState();
}

class _SubscriptionBadgeState extends State<SubscriptionBadge> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgeData = _getBadgeData(widget.subscriptionType);
    
    Widget badgeWidget = Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.showText ? 8 : 6,
        vertical: widget.showText ? 4 : 3,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: badgeData['colors'] as List<Color>,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: widget.isInteractive ? [
          BoxShadow(
            color: (badgeData['colors'] as List<Color>)[0].withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeData['icon'] as IconData,
            size: widget.size,
            color: Colors.white,
          ),
          if (widget.showText) ...[
            const SizedBox(width: 4),
            Text(
              badgeData['text'] as String,
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.size! * 0.7,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (widget.isInteractive) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: widget.size! * 0.8,
              color: Colors.white,
            ),
          ],
        ],
      ),
    );

    if (widget.isInteractive && widget.onFrequencyChanged != null) {
      return GestureDetector(
        onTapDown: (_) => _animationController.forward(),
        onTapUp: (_) {
          _animationController.reverse();
          _showFrequencySelector(context);
        },
        onTapCancel: () => _animationController.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: badgeWidget,
            );
          },
        ),
      );
    }

    return badgeWidget;
  }

  void _showFrequencySelector(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + size.height + 5,
        position.dx + size.width,
        position.dy + size.height + 5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 8,
      items: [
        _buildFrequencyMenuItem(context, 'Weekly', Icons.calendar_view_week, const Color(0xFF667eea)),
        _buildFrequencyMenuItem(context, 'Monthly', Icons.calendar_view_month, const Color(0xFFf093fb)),
        _buildFrequencyMenuItem(context, 'Yearly', Icons.calendar_today, const Color(0xFF4facfe)),
      ],
    ).then((selectedFrequency) {
      if (selectedFrequency != null) {
        widget.onFrequencyChanged?.call(selectedFrequency);
      }
    });
  }

  PopupMenuItem<String> _buildFrequencyMenuItem(BuildContext context, String frequency, IconData icon, Color color) {
    final isSelected = widget.subscriptionType.toLowerCase() == frequency.toLowerCase();
    
    return PopupMenuItem<String>(
      value: frequency,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              frequency,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Colors.black87,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle,
                color: color,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getBadgeData(String type) {
    switch (type.toLowerCase()) {
      case 'weekly':
        return {
          'icon': Icons.calendar_view_week,
          'text': 'Weekly',
          'colors': [const Color(0xFF667eea), const Color(0xFF764ba2)],
        };
      case 'monthly':
        return {
          'icon': Icons.calendar_view_month,
          'text': 'Monthly',
          'colors': [const Color(0xFFf093fb), const Color(0xFFf5576c)],
        };
      case 'yearly':
        return {
          'icon': Icons.calendar_today,
          'text': 'Yearly',
          'colors': [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
        };
      default:
        return {
          'icon': Icons.subscriptions,
          'text': 'Subscription',
          'colors': [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
        };
    }
  }
}

class SubscriptionIndicator extends StatelessWidget {
  final String? subscriptionType;
  final double size;

  const SubscriptionIndicator({
    super.key,
    this.subscriptionType,
    this.size = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    if (subscriptionType == null) return const SizedBox.shrink();
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.subscriptions,
        color: Colors.white,
        size: 12,
      ),
    );
  }
}

class SubscriptionCardDecoration extends StatelessWidget {
  final Widget child;
  final String? subscriptionType;
  final bool isSubscription;
  final Function(String)? onFrequencyChanged;

  const SubscriptionCardDecoration({
    super.key,
    required this.child,
    this.subscriptionType,
    this.isSubscription = false,
    this.onFrequencyChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSubscription || subscriptionType == null) {
      return child;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getSubscriptionColor(subscriptionType),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          child,
          // Bottom-right subscription badge
          if (subscriptionType != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: SubscriptionBadge(
                subscriptionType: subscriptionType!,
                size: 11,
                showText: true,
                isInteractive: true,
                onFrequencyChanged: onFrequencyChanged,
              ),
            ),
        ],
      ),
    );
  }

  Color _getSubscriptionColor(String? type) {
    if (type == null) return const Color(0xFF43e97b);
    
    switch (type.toLowerCase()) {
      case 'weekly':
        return const Color(0xFF667eea);
      case 'monthly':
        return const Color(0xFFf093fb);
      case 'yearly':
        return const Color(0xFF4facfe);
      default:
        return const Color(0xFF43e97b);
    }
  }
}
