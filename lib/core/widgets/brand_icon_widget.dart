import 'package:flutter/material.dart';
import '../services/brand_icon_service.dart';

/// Widget to display brand icons or letter fallbacks for manual entries
class BrandIconWidget extends StatelessWidget {
  final String name;
  final String? category;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;
  final double borderRadius;
  final bool showContainer;

  const BrandIconWidget({
    super.key,
    required this.name,
    this.category,
    this.size = 40.0,
    this.backgroundColor,
    this.iconColor,
    this.borderRadius = 8.0,
    this.showContainer = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showContainer) {
      return BrandIconService.getBrandIcon(
        name: name,
        category: category,
        size: size,
        color: iconColor,
      );
    }

    return BrandIconService.getBrandIconContainer(
      name: name,
      category: category,
      size: size,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      borderRadius: borderRadius,
    );
  }
}

/// Specialized widget for receipt cards
class ReceiptBrandIcon extends StatelessWidget {
  final String name;
  final String? category;
  final double size;
  final bool isSubscription;

  const ReceiptBrandIcon({
    super.key,
    required this.name,
    this.category,
    this.size = 60.0,
    this.isSubscription = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BrandIconService.getBrandIconContainer(
        name: name,
        category: category,
        size: size,
        borderRadius: 8,
      ),
    );
  }
}

/// Widget for displaying brand icons in lists
class BrandIconListItem extends StatelessWidget {
  final String name;
  final String? category;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isSelected;

  const BrandIconListItem({
    super.key,
    required this.name,
    this.category,
    this.subtitle,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: BrandIconWidget(
        name: name,
        category: category,
        size: 32,
        borderRadius: 6,
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
    );
  }
}
