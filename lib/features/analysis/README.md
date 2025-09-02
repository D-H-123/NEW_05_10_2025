# Analysis Feature

## Overview
The Analysis page provides comprehensive spending analytics and insights for the SmartReceipt app. It features a modern, responsive design with interactive charts, budget tracking, and smart insights.

## Features Implemented

### 1. Premium Banner
- Gradient design with crown icon
- Upgrade button for premium features
- Promotes advanced analytics capabilities

### 2. Time Filter Tabs
- Week, Month, Year toggle buttons
- Smooth animations on selection
- Default selection: Month

### 3. Budget Overview Cards
- Total Spent vs Budget Left comparison
- Percentage change indicators
- Color-coded positive/negative trends

### 4. Spending Trend Chart
- Interactive bar chart using fl_chart
- Daily spending visualization (Mon-Sun)
- Teal-colored bars with proper scaling

### 5. Categories Section
- Top 5 spending categories
- Progress bars with category colors
- Amount and percentage display
- "View All" navigation option

### 6. Smart Insights
- AI-powered spending pattern analysis
- Goal progress tracking
- Actionable recommendations

### 7. Bottom Navigation
- Four-tab navigation system
- Analysis tab highlighted in green

## Backend Integration Suggestions

### Data Structure for Receipt Categories

```dart
// Enhanced Bill Model with Category Support
class Bill {
  final String id;
  final String imagePath;
  final String vendor;
  final DateTime date;
  final double total;
  final String? currency;
  final String? ocrText;
  final String categoryId; // NEW: Category classification
  final double? subtotal;
  final double? tax;
  final String? notes;
  final List<String>? tags;
  final String? location;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // NEW: Category-specific fields
  final List<BillItem>? items; // Individual items from receipt
  final String? categoryName; // Auto-detected category
  final double? categoryConfidence; // ML confidence score
}

// NEW: Bill Item Model for Detailed Analysis
class BillItem {
  final String name;
  final double price;
  final int quantity;
  final String? category;
  final String? subcategory;
}
```

### Category Classification System

```dart
// Predefined Categories with Icons and Colors
enum ReceiptCategory {
  foodDining(
    name: 'Food & Dining',
    icon: Icons.restaurant,
    color: Colors.green,
    keywords: ['restaurant', 'food', 'dining', 'cafe', 'pizza', 'burger']
  ),
  shopping(
    name: 'Shopping',
    icon: Icons.shopping_bag,
    color: Colors.blue,
    keywords: ['store', 'shop', 'retail', 'clothing', 'electronics']
  ),
  transportation(
    name: 'Transportation',
    icon: Icons.directions_car,
    color: Colors.yellow,
    keywords: ['gas', 'fuel', 'uber', 'taxi', 'parking', 'toll']
  ),
  coffee(
    name: 'Coffee',
    icon: Icons.coffee,
    color: Colors.orange,
    keywords: ['coffee', 'starbucks', 'espresso', 'latte']
  ),
  home(
    name: 'Home',
    icon: Icons.home,
    color: Colors.purple,
    keywords: ['home', 'furniture', 'decor', 'maintenance']
  ),
  entertainment(
    name: 'Entertainment',
    icon: Icons.movie,
    color: Colors.pink,
    keywords: ['movie', 'theater', 'concert', 'game']
  ),
  health(
    name: 'Health',
    icon: Icons.local_pharmacy,
    color: Colors.red,
    keywords: ['pharmacy', 'medicine', 'doctor', 'hospital']
  ),
  utilities(
    name: 'Utilities',
    icon: Icons.electric_bolt,
    color: Colors.indigo,
    keywords: ['electricity', 'water', 'gas', 'internet', 'phone']
  );
}
```

### Analysis Service Implementation

```dart
class AnalysisService {
  // Calculate spending by category for a given time period
  Future<Map<String, CategorySpending>> getCategorySpending({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final bills = await _billRepository.getBillsInDateRange(startDate, endDate);
    
    final categorySpending = <String, CategorySpending>{};
    
    for (final bill in bills) {
      final category = bill.categoryName ?? 'Uncategorized';
      if (!categorySpending.containsKey(category)) {
        categorySpending[category] = CategorySpending(
          category: category,
          totalAmount: 0,
          transactionCount: 0,
          averageAmount: 0,
        );
      }
      
      categorySpending[category]!.totalAmount += bill.total;
      categorySpending[category]!.transactionCount++;
    }
    
    // Calculate averages
    for (final spending in categorySpending.values) {
      spending.averageAmount = spending.totalAmount / spending.transactionCount;
    }
    
    return categorySpending;
  }
  
  // Generate spending insights
  Future<List<SpendingInsight>> generateInsights() async {
    final insights = <SpendingInsight>[];
    
    // Weekend spending analysis
    final weekendSpending = await _analyzeWeekendSpending();
    if (weekendSpending.isSignificantlyHigher) {
      insights.add(SpendingInsight(
        type: InsightType.spendingPattern,
        title: 'Weekend Spending Pattern',
        message: 'You spend ${weekendSpending.percentageIncrease}% more on weekends. Consider setting weekend budgets.',
        priority: InsightPriority.medium,
      ));
    }
    
    // Budget goal progress
    final budgetProgress = await _analyzeBudgetProgress();
    if (budgetProgress.isUnderBudget) {
      insights.add(SpendingInsight(
        type: InsightType.goalProgress,
        title: 'Budget Goal Progress',
        message: 'Great job! You\'re ${budgetProgress.percentageUnder}% under your budget this month.',
        priority: InsightPriority.high,
      ));
    }
    
    return insights;
  }
  
  // Get spending trends for charts
  Future<List<DailySpending>> getDailySpendingTrend({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final bills = await _billRepository.getBillsInDateRange(startDate, endDate);
    final dailySpending = <DateTime, double>{};
    
    for (final bill in bills) {
      final date = DateTime(bill.date.year, bill.date.month, bill.date.day);
      dailySpending[date] = (dailySpending[date] ?? 0) + bill.total;
    }
    
    return dailySpending.entries
        .map((entry) => DailySpending(date: entry.key, amount: entry.value))
        .toList();
  }
}
```

### Data Models for Analysis

```dart
class CategorySpending {
  final String category;
  double totalAmount;
  int transactionCount;
  double averageAmount;
  
  CategorySpending({
    required this.category,
    required this.totalAmount,
    required this.transactionCount,
    required this.averageAmount,
  });
}

class SpendingInsight {
  final InsightType type;
  final String title;
  final String message;
  final InsightPriority priority;
  final DateTime createdAt;
  
  SpendingInsight({
    required this.type,
    required this.title,
    required this.message,
    required this.priority,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class DailySpending {
  final DateTime date;
  final double amount;
  
  DailySpending({
    required this.date,
    required this.amount,
  });
}

enum InsightType {
  spendingPattern,
  goalProgress,
  budgetAlert,
  savingOpportunity,
}

enum InsightPriority {
  low,
  medium,
  high,
  critical,
}
```

### Integration with Existing Bill System

1. **Category Auto-Detection**: Use OCR text analysis to automatically categorize receipts
2. **Manual Override**: Allow users to change categories if auto-detection is incorrect
3. **Learning System**: Improve categorization accuracy based on user corrections
4. **Budget Integration**: Connect spending analysis with budget goals
5. **Real-time Updates**: Refresh analysis data when new receipts are added

### Performance Considerations

1. **Caching**: Cache analysis results to avoid recalculating frequently
2. **Pagination**: Load large datasets in chunks for better performance
3. **Background Processing**: Calculate insights in the background
4. **Indexing**: Proper database indexing for date range queries
5. **Aggregation**: Pre-calculate common metrics for faster access

### Future Enhancements

1. **Predictive Analytics**: Forecast future spending based on patterns
2. **Anomaly Detection**: Identify unusual spending patterns
3. **Goal Setting**: Allow users to set spending goals by category
4. **Export Features**: Generate PDF/CSV reports
5. **Social Features**: Compare spending with similar users (anonymously)
6. **AI Recommendations**: Personalized saving suggestions
7. **Integration**: Connect with bank accounts for automatic categorization

## Usage

To use the Analysis page, simply navigate to it from your app's navigation system:

```dart
// Navigate to Analysis page
context.go('/analysis');

// Or use Navigator
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const AnalysisPage()),
);
```

The page is fully responsive and will adapt to different screen sizes automatically.