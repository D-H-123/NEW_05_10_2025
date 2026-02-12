import 'package:flutter/material.dart';

/// Service to provide brand icons and fallback letters for manual entries
class BrandIconService {
  // Popular subscription services and their corresponding icons
  static const Map<String, IconData> _brandIcons = {
    // Streaming Services
    'netflix': Icons.movie,
    'spotify': Icons.music_note,
    'youtube': Icons.play_circle,
    'youtube premium': Icons.play_circle,
    'disney': Icons.movie,
    'disney+': Icons.movie,
    'disney plus': Icons.movie,
    'hulu': Icons.play_circle,
    'amazon prime': Icons.shopping_cart,
    'prime video': Icons.shopping_cart,
    'hbo': Icons.movie,
    'hbo max': Icons.movie,
    'max': Icons.movie,
    'apple tv': Icons.play_circle,
    'paramount': Icons.movie,
    'peacock': Icons.play_circle,
    'crunchyroll': Icons.play_circle,
    'funimation': Icons.play_circle,
    
    // Software & Productivity
    'adobe': Icons.design_services,
    'microsoft': Icons.computer,
    'office 365': Icons.computer,
    'google': Icons.search,
    'google drive': Icons.cloud,
    'google one': Icons.cloud,
    'dropbox': Icons.cloud,
    'notion': Icons.note,
    'slack': Icons.chat,
    'zoom': Icons.videocam,
    'figma': Icons.design_services,
    'canva': Icons.design_services,
    
    // Gaming
    'steam': Icons.games,
    'xbox': Icons.games,
    'playstation': Icons.games,
    'nintendo': Icons.games,
    'epic games': Icons.games,
    'ubisoft': Icons.games,
    'ea': Icons.games,
    'electronic arts': Icons.games,
    
    // Food & Delivery
    'uber': Icons.local_taxi,
    'uber eats': Icons.restaurant,
    'doordash': Icons.restaurant,
    'grubhub': Icons.restaurant,
    'postmates': Icons.restaurant,
    'deliveroo': Icons.restaurant,
    'just eat': Icons.restaurant,
    
    // Transportation
    'lyft': Icons.local_taxi,
    'bird': Icons.electric_scooter,
    'lime': Icons.electric_scooter,
    'zipcar': Icons.directions_car,
    'turo': Icons.directions_car,
    
    // Fitness & Health
    'peloton': Icons.fitness_center,
    'nike': Icons.sports,
    'adidas': Icons.sports,
    'myfitnesspal': Icons.fitness_center,
    'strava': Icons.directions_run,
    'fitbit': Icons.fitness_center,
    'apple fitness': Icons.fitness_center,
    'calm': Icons.spa,
    'headspace': Icons.spa,
    
    // News & Media
    'new york times': Icons.newspaper,
    'washington post': Icons.newspaper,
    'wall street journal': Icons.newspaper,
    'medium': Icons.article,
    'substack': Icons.article,
    'patreon': Icons.favorite,
    
    // Cloud & Storage
    'aws': Icons.cloud,
    'azure': Icons.cloud,
    'digitalocean': Icons.cloud,
    'linode': Icons.cloud,
    'vultr': Icons.cloud,
    
    // Communication
    'discord': Icons.chat,
    'telegram': Icons.chat,
    'whatsapp': Icons.chat,
    'signal': Icons.chat,
    'skype': Icons.videocam,
    'teams': Icons.videocam,
    
    // Finance
    'paypal': Icons.payment,
    'stripe': Icons.payment,
    'square': Icons.payment,
    'venmo': Icons.payment,
    'cash app': Icons.payment,
    'zelle': Icons.payment,
    
    // E-commerce
    'amazon': Icons.shopping_cart,
    'ebay': Icons.shopping_cart,
    'etsy': Icons.shopping_cart,
    'shopify': Icons.store,
    'woocommerce': Icons.store,
    
    // Education
    'coursera': Icons.school,
    'udemy': Icons.school,
    'linkedin learning': Icons.school,
    'masterclass': Icons.school,
    'skillshare': Icons.school,
    'khan academy': Icons.school,
    
    // Dating & Social
    'tinder': Icons.favorite,
    'bumble': Icons.favorite,
    'hinge': Icons.favorite,
    'match': Icons.favorite,
    'okcupid': Icons.favorite,
    
    // Utilities
    'icloud': Icons.cloud,
    'onedrive': Icons.cloud,
    'lastpass': Icons.lock,
    '1password': Icons.lock,
    'bitwarden': Icons.lock,
    'dashlane': Icons.lock,
  };

  // Category-based fallback icons
  static const Map<String, IconData> _categoryIcons = {
    'entertainment': Icons.movie,
    'streaming': Icons.play_circle,
    'music': Icons.music_note,
    'gaming': Icons.games,
    'software': Icons.computer,
    'productivity': Icons.work,
    'fitness': Icons.fitness_center,
    'health': Icons.health_and_safety,
    'food': Icons.restaurant,
    'transportation': Icons.directions_car,
    'shopping': Icons.shopping_cart,
    'news': Icons.newspaper,
    'education': Icons.school,
    'finance': Icons.account_balance,
    'utilities': Icons.build,
    'communication': Icons.chat,
    'social': Icons.people,
    'travel': Icons.flight,
    'subscription': Icons.subscriptions,
    'other': Icons.category,
  };

  /// Get the appropriate icon for a given brand name or title
  static Widget getBrandIcon({
    required String name,
    String? category,
    double size = 24.0,
    Color? color,
    bool forceLetterFallback = false,
  }) {
    final normalizedName = _normalizeName(name);
    
    // If forceLetterFallback is true, skip brand/category matching
    if (forceLetterFallback) {
      return _buildLetterFallback(name, size, color);
    }
    
    // First, try to find exact match
    IconData? iconData = _brandIcons[normalizedName];
    
    // If no exact match, try partial matching for common patterns
    iconData ??= _findPartialMatch(normalizedName);
    
    // If still no match, try category-based icon
    if (iconData == null && category != null) {
      final normalizedCategory = _normalizeName(category);
      iconData = _categoryIcons[normalizedCategory];
    }
    
    // If still no match, use first letter fallback
    if (iconData == null) {
      return _buildLetterFallback(name, size, color);
    }
    
    return Icon(
      iconData,
      size: size,
      color: color,
    );
  }

  /// Get a colored container with brand icon or letter
  static Widget getBrandIconContainer({
    required String name,
    String? category,
    double size = 40.0,
    Color? backgroundColor,
    Color? iconColor,
    double borderRadius = 8.0,
    bool forceLetterFallback = false,
  }) {
    final normalizedName = _normalizeName(name);
    final bgColor = backgroundColor ?? _getBrandColor(normalizedName);
    final icColor = iconColor ?? Colors.white;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: getBrandIcon(
          name: name,
          category: category,
          size: size * 0.6,
          color: icColor,
          forceLetterFallback: forceLetterFallback,
        ),
      ),
    );
  }

  /// Normalize name for matching (lowercase, remove special chars)
  static String _normalizeName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Find partial match for brand names
  static IconData? _findPartialMatch(String normalizedName) {
    for (final entry in _brandIcons.entries) {
      if (normalizedName.contains(entry.key) || entry.key.contains(normalizedName)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Build letter fallback widget
  static Widget _buildLetterFallback(String name, double size, Color? color) {
    final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Text(
      firstLetter,
      style: TextStyle(
        fontSize: size * 0.6,
        fontWeight: FontWeight.bold,
        color: color ?? Colors.white,
      ),
    );
  }

  /// Get brand-specific color
  static Color _getBrandColor(String normalizedName) {
    // Brand-specific colors
    if (normalizedName.contains('netflix')) return const Color(0xFFE50914);
    if (normalizedName.contains('spotify')) return const Color(0xFF1DB954);
    if (normalizedName.contains('youtube')) return const Color(0xFFFF0000);
    if (normalizedName.contains('disney')) return const Color(0xFF113CCF);
    if (normalizedName.contains('amazon')) return const Color(0xFFFF9900);
    if (normalizedName.contains('apple')) return const Color(0xFF000000);
    if (normalizedName.contains('google')) return const Color(0xFF4285F4);
    if (normalizedName.contains('microsoft')) return const Color(0xFF00BCF2);
    if (normalizedName.contains('adobe')) return const Color(0xFFFF0000);
    if (normalizedName.contains('steam')) return const Color(0xFF171a21);
    if (normalizedName.contains('uber')) return const Color(0xFF000000);
    if (normalizedName.contains('lyft')) return const Color(0xFFFF00BF);
    if (normalizedName.contains('paypal')) return const Color(0xFF0070BA);
    if (normalizedName.contains('discord')) return const Color(0xFF5865F2);
    if (normalizedName.contains('tinder')) return const Color(0xFFFF4454);
    if (normalizedName.contains('coursera')) return const Color(0xFF0056D3);
    if (normalizedName.contains('icloud')) return const Color(0xFF007AFF);
    
    // Category-based colors
    if (normalizedName.contains('entertainment') || normalizedName.contains('streaming')) {
      return const Color(0xFF9C27B0);
    }
    if (normalizedName.contains('music')) return const Color(0xFF4CAF50);
    if (normalizedName.contains('gaming')) return const Color(0xFF3F51B5);
    if (normalizedName.contains('software') || normalizedName.contains('productivity')) {
      return const Color(0xFF2196F3);
    }
    if (normalizedName.contains('fitness') || normalizedName.contains('health')) {
      return const Color(0xFF4CAF50);
    }
    if (normalizedName.contains('food') || normalizedName.contains('restaurant')) {
      return const Color(0xFFFF9800);
    }
    if (normalizedName.contains('transportation') || normalizedName.contains('travel')) {
      return const Color(0xFF607D8B);
    }
    if (normalizedName.contains('shopping')) return const Color(0xFFE91E63);
    if (normalizedName.contains('news') || normalizedName.contains('education')) {
      return const Color(0xFF795548);
    }
    if (normalizedName.contains('finance')) return const Color(0xFF4CAF50);
    if (normalizedName.contains('communication') || normalizedName.contains('social')) {
      return const Color(0xFF00BCD4);
    }
    
    // Default gradient colors based on first letter
    return _getDefaultColor(normalizedName);
  }

  /// Get default color based on first letter
  static Color _getDefaultColor(String name) {
    if (name.isEmpty) return const Color(0xFF9E9E9E);
    
    final firstLetter = name[0].toUpperCase();
    final colors = [
      const Color(0xFFE91E63), // A-F
      const Color(0xFF9C27B0), // G-L
      const Color(0xFF3F51B5), // M-R
      const Color(0xFF4CAF50), // S-Z
    ];
    
    final index = (firstLetter.codeUnitAt(0) - 65) ~/ 6;
    return colors[index.clamp(0, colors.length - 1)];
  }

  /// Check if a brand is recognized
  static bool isBrandRecognized(String name) {
    final normalizedName = _normalizeName(name);
    return _brandIcons.containsKey(normalizedName) || _findPartialMatch(normalizedName) != null;
  }

  /// Get all supported brands
  static List<String> getSupportedBrands() {
    return _brandIcons.keys.toList()..sort();
  }
}
