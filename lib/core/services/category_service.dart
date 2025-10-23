import 'package:flutter/material.dart';
import 'package:smart_receipt/core/services/local_storage_service.dart';
import 'package:smart_receipt/core/models/custom_category.dart';

class CategoryService {
  static const Map<String, CategoryInfo> _categories = {
    'Food & Dining': CategoryInfo(
      color: Colors.orange,
      icon: Icons.restaurant,
      keywords: ['restaurant', 'cafe', 'coffee', 'pizza', 'bar', 'diner', 'mcdonald', 'burger', 'starbucks', 'subway', 'fast food', 'dining', 'food'],
    ),
    'Groceries': CategoryInfo(
      color: Colors.green,
      icon: Icons.shopping_cart,
      keywords: ['grocery', 'supermarket', 'market', 'walmart', 'target', 'costco', 'whole foods', 'kroger', 'safeway', 'grocery store', 'food shopping'],
    ),
    'Transportation': CategoryInfo(
      color: Colors.blue,
      icon: Icons.directions_car,
      keywords: ['transport', 'gas', 'fuel', 'gasoline', 'petrol', 'diesel', 'shell', 'bp', 'exxon', 'chevron', 'taxi', 'uber', 'lyft', 'parking', 'public transport'],
    ),
    'Shopping': CategoryInfo(
      color: Colors.purple,
      icon: Icons.shopping_bag,
      keywords: ['store', 'shop', 'amazon', 'ebay', 'best buy', 'home depot', 'lowes', 'retail', 'clothing', 'fashion', 'electronics', 'online shopping'],
    ),
    'Entertainment': CategoryInfo(
      color: Colors.pink,
      icon: Icons.movie,
      keywords: ['movie', 'cinema', 'theater', 'netflix', 'spotify', 'game', 'gaming', 'music', 'streaming', 'entertainment'],
    ),
    'Healthcare': CategoryInfo(
      color: Colors.red,
      icon: Icons.local_hospital,
      keywords: ['hospital', 'doctor', 'medical', 'dental', 'clinic', 'pharmacy', 'drug', 'cvs', 'walgreens', 'rite aid', 'medicine', 'prescription', 'health', 'healthcare'],
    ),
    'Utilities': CategoryInfo(
      color: Colors.teal,
      icon: Icons.home,
      keywords: ['electric', 'gas company', 'water', 'internet', 'phone', 'cable', 'utility', 'utilities', 'electricity'],
    ),
    'Home & Garden': CategoryInfo(
      color: Colors.brown,
      icon: Icons.home_work,
      keywords: ['furniture', 'home', 'garden', 'home depot', 'lowes', 'home improvement', 'furniture & home'],
    ),
    'Education': CategoryInfo(
      color: Colors.indigo,
      icon: Icons.school,
      keywords: ['books', 'school', 'university', 'course', 'training', 'education', 'office supplies'],
    ),
    'Travel': CategoryInfo(
      color: Colors.amber,
      icon: Icons.flight,
      keywords: ['hotel', 'flight', 'vacation', 'trip', 'accommodation', 'travel'],
    ),
    'Personal Care': CategoryInfo(
      color: Colors.deepPurple,
      icon: Icons.spa,
      keywords: ['beauty', 'cosmetics', 'salon', 'spa', 'personal care', 'fashion & clothing'],
    ),
    'Services': CategoryInfo(
      color: Colors.teal,
      icon: Icons.build,
      keywords: ['service', 'repair', 'maintenance', 'cleaning', 'services'],
    ),
    'Insurance': CategoryInfo(
      color: Colors.cyan,
      icon: Icons.security,
      keywords: ['insurance', 'coverage', 'policy'],
    ),
    'Other': CategoryInfo(
      color: Colors.grey,
      icon: Icons.label,
      keywords: ['other', 'miscellaneous', 'misc'],
    ),
    // Subscription-specific categories
    'Software': CategoryInfo(
      color: Colors.indigo,
      icon: Icons.code,
      keywords: ['software', 'app', 'application', 'program', 'tool'],
    ),
    'Telecom': CategoryInfo(
      color: Colors.blue,
      icon: Icons.phone,
      keywords: ['phone', 'telecom', 'telephone', 'mobile', 'internet', 'broadband'],
    ),
    'Cloud/Storage': CategoryInfo(
      color: Colors.cyan,
      icon: Icons.cloud,
      keywords: ['cloud', 'storage', 'backup', 'aws', 'google cloud', 'azure', 'dropbox'],
    ),
    'Productivity': CategoryInfo(
      color: Colors.purple,
      icon: Icons.work,
      keywords: ['productivity', 'office', 'work', 'business', 'management'],
    ),
  };

  /// Get all available categories (predefined + custom)
  static List<String> get allCategories {
    final predefined = _categories.keys.toList();
    final custom = LocalStorageService.getAllCustomCategories()
        .map((cat) => cat.name)
        .toList();
    return [...predefined, ...custom];
  }

  /// Get category info (color and icon/emoji) for a given category name
  static CategoryInfo? getCategoryInfo(String category) {
    // Check custom categories first
    final customCategories = LocalStorageService.getAllCustomCategories();
    for (final customCat in customCategories) {
      if (customCat.name.toLowerCase() == category.toLowerCase()) {
        return CategoryInfo(
          color: customCat.color,
          icon: Icons.label, // Default icon for custom categories
          keywords: customCat.keywords,
          emoji: customCat.emoji, // Custom emoji
        );
      }
    }

    // Direct lookup in predefined categories
    if (_categories.containsKey(category)) {
      return _categories[category];
    }

    // Try case-insensitive lookup in predefined
    final lowerCategory = category.toLowerCase();
    for (final entry in _categories.entries) {
      if (entry.key.toLowerCase() == lowerCategory) {
        return entry.value;
      }
    }

    // Try keyword matching in predefined categories
    for (final entry in _categories.entries) {
      for (final keyword in entry.value.keywords) {
        if (lowerCategory.contains(keyword.toLowerCase())) {
          return entry.value;
        }
      }
    }

    // Try keyword matching in custom categories
    for (final customCat in customCategories) {
      for (final keyword in customCat.keywords) {
        if (lowerCategory.contains(keyword.toLowerCase())) {
          return CategoryInfo(
            color: customCat.color,
            icon: Icons.label,
            keywords: customCat.keywords,
            emoji: customCat.emoji,
          );
        }
      }
    }

    return null;
  }

  /// Get color for a category
  static Color getCategoryColor(String category) {
    return getCategoryInfo(category)?.color ?? Colors.grey;
  }

  /// Get icon for a category
  static IconData getCategoryIcon(String category) {
    return getCategoryInfo(category)?.icon ?? Icons.label;
  }

  /// Get emoji for a category (returns null for predefined categories)
  static String? getCategoryEmoji(String category) {
    return getCategoryInfo(category)?.emoji;
  }

  /// Check if category is custom
  static bool isCustomCategory(String category) {
    final customCategories = LocalStorageService.getAllCustomCategories();
    return customCategories.any((cat) => 
      cat.name.toLowerCase() == category.toLowerCase()
    );
  }

  /// Normalize category name to standard format
  static String normalizeCategory(String category) {
    final lowerCategory = category.toLowerCase();
    
    // Direct mapping for common variations
    final mappings = {
      'transport': 'Transportation',
      'transport & fuel': 'Transportation',
      'pharmacy': 'Healthcare',
      'pharmacy & health': 'Healthcare',
      'retail': 'Shopping',
      'furniture & home': 'Home & Garden',
      'fashion & clothing': 'Personal Care',
      'office supplies': 'Education',
    };

    if (mappings.containsKey(lowerCategory)) {
      return mappings[lowerCategory]!;
    }

    // Try keyword matching
    for (final entry in _categories.entries) {
      for (final keyword in entry.value.keywords) {
        if (lowerCategory.contains(keyword.toLowerCase())) {
          return entry.key;
        }
      }
    }

    // Return original if no match found
    return category;
  }

  /// Get categories for manual expense form (predefined + custom)
  static List<String> get manualExpenseCategories {
    final predefined = [
      'Food & Dining',
      'Groceries',
      'Transportation',
      'Shopping',
      'Entertainment',
      'Healthcare',
      'Utilities',
      'Home & Garden',
      'Education',
      'Travel',
      'Other',
    ];
    
    // Add custom categories that are available for manual expenses
    final custom = LocalStorageService.getCustomCategoriesByType('expense')
        .map((cat) => cat.name)
        .toList();
    
    return [...predefined, ...custom];
  }

  /// Get categories for post-capture (scanned receipts) (predefined + custom)
  static List<String> get postCaptureCategories {
    final predefined = [
      'Services',
      'Groceries',
      'Food & Dining',
      'Transportation',
      'Healthcare',
      'Home & Garden',
      'Shopping',
      'Entertainment',
      'Utilities',
      'Insurance',
      'Education',
      'Travel',
      'Personal Care',
      'Other',
    ];
    
    // Add custom categories that are available for receipts
    final custom = LocalStorageService.getCustomCategoriesByType('receipt')
        .map((cat) => cat.name)
        .toList();
    
    return [...predefined, ...custom];
  }

  /// Get categories for subscription form (predefined + custom)
  static List<String> get subscriptionCategories {
    final predefined = [
      'Entertainment',
      'Software',
      'Utilities',
      'Services',
      'Telecom',
      'Cloud/Storage',
      'Productivity',
      'Other',
    ];
    
    // Add custom categories that are available for subscriptions
    final custom = LocalStorageService.getCustomCategoriesByType('subscription')
        .map((cat) => cat.name)
        .toList();
    
    return [...predefined, ...custom];
  }
}

class CategoryInfo {
  final Color color;
  final IconData icon;
  final List<String> keywords;
  final String? emoji; // Optional emoji for custom categories

  const CategoryInfo({
    required this.color,
    required this.icon,
    required this.keywords,
    this.emoji,
  });
}