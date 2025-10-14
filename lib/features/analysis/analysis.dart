import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_receipt/core/services/analytics_repository.dart';
import 'package:smart_receipt/features/storage/models/bill_model.dart';
import 'package:smart_receipt/core/services/local_storage_service.dart';
import 'package:smart_receipt/core/services/category_service.dart';
import 'package:smart_receipt/core/widgets/modern_widgets.dart';

class CategorySegment {
  final String categoryName;
  final double amount;
  final double percentage; // Percentage of total spending
  final Color color;
  
  CategorySegment({
    required this.categoryName,
    required this.amount,
    required this.percentage,
    required this.color,
  });
}

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> with TickerProviderStateMixin {
  int _selectedTimeFilter = 1; // 0: Week, 1: Month, 2: Year
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isPremium = false; // TODO: Connect to premium service
  String _selectedChartType = 'Bar Chart'; // Track selected chart type

  late final AnalyticsRepository _analyticsRepository;
  List<Bill> _filteredBills = [];
  bool _isLoading = false;
  
  // Analytics data
  double _totalSpent = 0.0;
  double _percentageChange = 0.0;

  @override
  void initState() {
    super.initState();
    _analyticsRepository = AnalyticsRepository(localStorage: LocalStorageService());
    _fetchBills();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  void _fetchBills() async {
    setState(() => _isLoading = true);
    final filter = TimeFilter.values[_selectedTimeFilter];
    
    try {
      // Fetch bills and analytics data in parallel
      final results = await Future.wait([
        _analyticsRepository.getBills(filter: filter),
        _analyticsRepository.getTotalSpent(filter: filter),
        _analyticsRepository.getPercentageChange(filter: filter),
      ]);
      
      setState(() {
        _filteredBills = results[0] as List<Bill>;
        _totalSpent = results[1] as double;
        _percentageChange = results[2] as double;
        _isLoading = false;
      });

      // Debug: Print detailed information
      final debugInfo = await _analyticsRepository.getPercentageChangeDetails(filter: filter);
      print('=== DEBUG INFO ===');
      print('Filter: ${debugInfo['filter']}');
      print('Current Total: \$${debugInfo['currentTotal']}');
      print('Previous Total: \$${debugInfo['previousTotal']}');
      print('Percentage Change: ${debugInfo['percentageChange']}%');
      print('Current Bills Count: ${debugInfo['currentBillsCount']}');
      print('Previous Bills Count: ${debugInfo['previousBillsCount']}');
      print('==================');
      
    } catch (e) {
      print('Error fetching analytics data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTimeFilterChanged(int index) {
    setState(() {
      _selectedTimeFilter = index;
    });
    _animationController.reset();
    _animationController.forward();
    _fetchBills();
  }

  String _getTimeFilterTitle() {
    final now = DateTime.now();
    switch (_selectedTimeFilter) {
      case 0: // Week
        final weekNumber = _getWeekNumber(now);
        return 'Week $weekNumber';
      case 1: // Month
        final monthNames = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        return '${monthNames[now.month - 1]} ${now.year}';
      case 2: // Year
        return '${now.year}';
      default:
        return 'Spending by Category';
    }
  }

  int _getWeekNumber(DateTime date) {
    // Proper ISO 8601 week number calculation
    // ISO week: Week 1 is the first week with at least 4 days in the new year
    
    // Get the Thursday of the current week (ISO week starts on Monday)
    final thursday = date.add(Duration(days: 4 - date.weekday));
    
    // Get January 4th of the Thursday's year (guaranteed to be in week 1)
    final jan4 = DateTime(thursday.year, 1, 4);
    
    // Get the Monday of week 1 in that year
    final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
    
    // Calculate week number
    final daysSinceWeek1 = thursday.difference(week1Monday).inDays;
    final weekNumber = (daysSinceWeek1 / 7).floor() + 1;
    
    return weekNumber;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Restored to original white background
      appBar: AppBar(
        title: const Text(
          'Analysis',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white, // Restored to original white app bar
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.black87),
            onPressed: () {
              if (_isPremium) {
                // TODO: Implement download functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Downloading analytics data...')),
                );
              } else {
                _showPremiumUpgradeDialog();
              }
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time Filter Tabs
                    _buildTimeFilterTabs(),
                    const SizedBox(height: 24),

                    // Budget Overview Cards
                    _buildBudgetOverviewCards(),
                    const SizedBox(height: 24),

                    // Spending Trend Chart
                    _buildSpendingTrendChart(),
                    const SizedBox(height: 24),

                    // Categories Section
                    _buildCategoriesSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildTimeFilterTabs() {
    final filters = ['Week', 'Month', 'Year'];
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200], // Restored to original grey background
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(
          filters.length,
          (index) => Expanded(
            child: GestureDetector(
              onTap: _isLoading ? null : () => _onTimeFilterChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTimeFilter == index
                      ? Colors.green // Restored to original green
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  filters[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedTimeFilter == index
                        ? Colors.white
                        : Colors.grey[600],
                    fontWeight: _selectedTimeFilter == index
                        ? FontWeight.bold
                        : FontWeight.normal,
                    // Disable text color if loading
                    decoration: _isLoading ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetOverviewCards() {
    String periodText = _getPeriodText();
    
    // Enhanced logic: consider spending change context
    bool isSpendingGood = _getSpendingChangeContext();
    
    return _buildBudgetCard(
      icon: Icons.attach_money,
      amount: '\$${_totalSpent.toStringAsFixed(2)}',
      title: 'Total Spent',
      subtitle: _percentageChange >= 0 ? '+${_percentageChange.toStringAsFixed(1)}% vs $periodText' : '${_percentageChange.toStringAsFixed(1)}% vs $periodText',
      isPositive: isSpendingGood,
      color: const Color(0xFF4facfe),
    );
  }

  /// Determines if spending change is positive (good) or negative (bad)
  bool _getSpendingChangeContext() {
    // Threshold-based logic for more nuanced feedback
    const double significantIncreaseThreshold = 10.0; // 10% increase is significant
    const double significantDecreaseThreshold = -5.0; // 5% decrease is good
    
    if (_percentageChange <= significantDecreaseThreshold) {
      return true; // Significant decrease = Very Good (Green)
    } else if (_percentageChange <= 0) {
      return true; // Small decrease = Good (Green)
    } else if (_percentageChange <= significantIncreaseThreshold) {
      return false; // Small increase = Bad (Red)
    } else {
      return false; // Significant increase = Very Bad (Red)
    }
  }

  /// Returns appropriate color based on spending change magnitude
  Color _getSpendingChangeColor() {
    const double significantIncreaseThreshold = 10.0;
    const double significantDecreaseThreshold = -5.0;
    
    if (_percentageChange <= significantDecreaseThreshold) {
      return Colors.lightGreen[600]!; // Very good - lighter green
    } else if (_percentageChange <= 0) {
      return Colors.green[600]!; // Good - standard green
    } else if (_percentageChange <= significantIncreaseThreshold) {
      return Colors.orange[600]!; // Warning - orange for small increases
    } else {
      return Colors.red[600]!; // Bad - red for significant increases
    }
  }

  String _getPeriodText() {
    switch (_selectedTimeFilter) {
      case 0: // Week
        return 'last week';
      case 1: // Month
        return 'last month';
      case 2: // Year
        return 'last year';
      default:
        return 'last month';
    }
  }

  Widget _buildBudgetCard({
    required IconData icon,
    required String amount,
    required String title,
    required String subtitle,
    required bool isPositive,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left section - Centered content
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        amount,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Center divider line - positioned in middle of entire card
          Container(
            height: 30,
            width: 1,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(0.5),
            ),
          ),
          // Right section - Centered content
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive ? Icons.trending_down : Icons.trending_up,
                    size: 24,
                    color: _getSpendingChangeColor(),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _percentageChange >= 0 ? '+${_percentageChange.toStringAsFixed(1)}%' : '${_percentageChange.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 20,
                          color: _getSpendingChangeColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'vs ${_getPeriodText()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingTrendChart() {
    // Group bills by category and sum totals
    Map<String, double> categoryTotals = {};
    for (var bill in _filteredBills) {
      String category = bill.categoryId ?? 'Uncategorized';
      categoryTotals[category] = (categoryTotals[category] ?? 0.0) + (bill.total ?? 0.0);
    }
    
    // Sort categories by total spent
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // For bar chart: take top 5, for pie chart: use all categories
    final topCategories = sortedCategories.take(5).toList();
    final allCategories = sortedCategories; // All categories for pie chart
    
    // Calculate maxY with proper rounding to multiples of 10, 50, 100, or 1000
    double maxY = topCategories.isNotEmpty 
        ? topCategories.first.value 
        : 0.0;
    
    // Round to appropriate multiple based on value
    if (maxY <= 0) {
      maxY = 40; // Default minimum (4 lines * 10)
    } else {
      maxY = maxY * 1.2; // Add 20% padding
      if (maxY <= 100) {
        maxY = (maxY / 10).ceil() * 10; // Round to nearest 10
      } else if (maxY <= 500) {
        maxY = (maxY / 50).ceil() * 50; // Round to nearest 50
      } else if (maxY <= 5000) {
        maxY = (maxY / 100).ceil() * 100; // Round to nearest 100
      } else {
        maxY = (maxY / 1000).ceil() * 1000; // Round to nearest 1000
      }
    }
    
    // Ensure maxY is divisible by 4 for clean grid lines
    // This ensures grid lines at 0, maxY/4, maxY/2, 3*maxY/4, maxY are nice numbers
    if (maxY <= 100) {
      maxY = ((maxY / 4).ceil() * 4).toDouble(); // Round to nearest multiple of 4
    } else if (maxY <= 500) {
      maxY = ((maxY / 20).ceil() * 20).toDouble(); // Round to nearest multiple of 20
    } else if (maxY <= 5000) {
      maxY = ((maxY / 40).ceil() * 40).toDouble(); // Round to nearest multiple of 40
    } else {
      maxY = ((maxY / 400).ceil() * 400).toDouble(); // Round to nearest multiple of 400
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                _getTimeFilterTitle(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (String value) {
                  setState(() {
                    _selectedChartType = value;
                  });
                },
                offset: const Offset(0, 40), // Position dropdown below button
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Chart',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.grey[600],
                        size: 16,
                      ),
                    ],
                  ),
                ),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'Bar Chart',
                    child: Row(
                      children: [
                        Icon(
                          _selectedChartType == 'Bar Chart' 
                              ? Icons.radio_button_checked 
                              : Icons.radio_button_unchecked,
                          color: _selectedChartType == 'Bar Chart' 
                              ? const Color(0xFF4facfe) 
                              : Colors.grey[400],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Bar Chart',
                          style: TextStyle(
                            color: _selectedChartType == 'Bar Chart' 
                                ? Colors.black87 
                                : Colors.grey[600],
                            fontWeight: _selectedChartType == 'Bar Chart' 
                                ? FontWeight.w600 
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'Pie Chart',
                    child: Row(
                      children: [
                        Icon(
                          _selectedChartType == 'Pie Chart' 
                              ? Icons.radio_button_checked 
                              : Icons.radio_button_unchecked,
                          color: _selectedChartType == 'Pie Chart' 
                              ? const Color(0xFF4facfe) 
                              : Colors.grey[400],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pie Chart',
                          style: TextStyle(
                            color: _selectedChartType == 'Pie Chart' 
                                ? Colors.black87 
                                : Colors.grey[600],
                            fontWeight: _selectedChartType == 'Pie Chart' 
                                ? FontWeight.w600 
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'Progress Chart',
                    child: Row(
                      children: [
                        Icon(
                          _selectedChartType == 'Progress Chart' 
                              ? Icons.radio_button_checked 
                              : Icons.radio_button_unchecked,
                          color: _selectedChartType == 'Progress Chart' 
                              ? const Color(0xFF4facfe) 
                              : Colors.grey[400],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Progress Chart',
                          style: TextStyle(
                            color: _selectedChartType == 'Progress Chart' 
                                ? Colors.black87 
                                : Colors.grey[600],
                            fontWeight: _selectedChartType == 'Progress Chart' 
                                ? FontWeight.w600 
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          topCategories.isEmpty
              ? Container(
                  height: 220, // Increased height to prevent overflow
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12), // Reduced padding
                          decoration: BoxDecoration(
                            color: Colors.grey[50], // Lighter background
                            borderRadius: BorderRadius.circular(40), // Smaller circle
                          ),
                          child: Icon(
                            Icons.receipt_long_outlined,
                            size: 36, // Smaller icon
                            color: Colors.grey[500], // Slightly darker
                          ),
                        ),
                        const SizedBox(height: 12), // Reduced spacing
                        Text(
                          'No spending data for this period',
                          style: TextStyle(
                            color: Colors.grey[700], // Darker text
                            fontSize: 15, // Slightly smaller
                            fontWeight: FontWeight.w600, // Bolder
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6), // Reduced spacing
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Add receipts to see your spending by category',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13, // Smaller text
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16), // Reduced spacing
                        ElevatedButton.icon(
                          onPressed: () {
                            context.go('/scan'); // Navigate to camera/scan page
                          },
                          icon: const Icon(Icons.camera_alt, size: 16), // Smaller icon
                          label: const Text('Add Receipt', style: TextStyle(fontSize: 13)), // Smaller text
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4facfe),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced padding
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6), // Smaller radius
                            ),
                            elevation: 2, // Added shadow
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SizedBox(
                  height: _selectedChartType == 'Pie Chart' ? 280 : 
                          _selectedChartType == 'Progress Chart' ? 120 : 200, // Reduced height for progress chart
                  child: _selectedChartType == 'Pie Chart' 
                      ? _buildPieChart(allCategories)
                      : _selectedChartType == 'Progress Chart'
                          ? _buildProgressChart(allCategories)
                          : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value >= 0 && value < topCategories.length) {
                                final category = topCategories[value.toInt()].key;
                                // Truncate long category names
                                final displayName = category.length > 8 
                                    ? '${category.substring(0, 8)}...' 
                                    : category;
                                return Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: maxY / 4, // Match grid line interval
                            getTitlesWidget: (value, meta) {
                              // Show labels only for grid lines (0, maxY/4, maxY/2, 3*maxY/4, maxY)
                              // But hide the first (0) and last (maxY) values
                              if (value == 0 || value == maxY) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                '\$${value.toInt()}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600, // Bolder font weight
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false, // Remove vertical grid lines
                        drawHorizontalLine: true, // Keep horizontal grid lines
                        horizontalInterval: maxY / 4, // 4 horizontal lines
                        getDrawingHorizontalLine: (value) {
                          // All grid lines should be dotted (X-axis is handled by border)
                          return FlLine(
                            color: Colors.grey[350]!,
                            strokeWidth: 1,
                            dashArray: [5, 5], // Dotted line
                          );
                        },
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[350]!,
                            width: 1.5,
                          ),
                        ),
                      ),
                      backgroundColor: Colors.transparent,
                      barGroups: List.generate(topCategories.length, (i) {
                        // Use CategoryService colors to match category colors
                        final categoryInfo = CategoryService.getCategoryInfo(topCategories[i].key);
                        final categoryColor = categoryInfo?.color ?? Colors.grey;
                        
                        return BarChartGroupData(
                          x: i, 
                          barRods: [BarChartRodData(
                            toY: topCategories[i].value, 
                            color: categoryColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                              bottomLeft: Radius.zero,
                              bottomRight: Radius.zero,
                            ),
                          )],
                        );
                      }),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildPieChart(List<MapEntry<String, double>> allCategories) {
    final totalSpent = allCategories.fold(0.0, (sum, entry) => sum + entry.value);
    
    if (allCategories.isEmpty || totalSpent == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No spending data for this period',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }
    
    return Container(
      height: 280, // Match the container height
      width: double.infinity,
      padding: const EdgeInsets.all(20), // Add padding to prevent overflow
      child: Center(
        child: PieChart(
          PieChartData(
            pieTouchData: PieTouchData(
              enabled: true,
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                // Add hover/click interactions here
              },
            ),
            sectionsSpace: 2,
            centerSpaceRadius: 40, // Reduced from 40 to 25 for smaller center hole
            sections: List.generate(allCategories.length, (i) {
              final entry = allCategories[i];
              final categoryInfo = CategoryService.getCategoryInfo(entry.key);
              final percentage = (entry.value / totalSpent * 100).round();
              
              return PieChartSectionData(
                color: categoryInfo?.color ?? Colors.grey,
                value: entry.value,
                title: '${percentage}%',
                radius: 80, // Increased from 50 to 80 for larger pie chart
                titleStyle: const TextStyle(
                  fontSize: 12, // Slightly larger font for better readability
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                titlePositionPercentageOffset: 0.6,
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressChart(List<MapEntry<String, double>> allCategories) {
    if (allCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No spending data for this period',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    final totalSpent = allCategories.fold(0.0, (sum, entry) => sum + entry.value);
    final segments = allCategories.map((entry) {
      final categoryInfo = CategoryService.getCategoryInfo(entry.key);
      final percentage = (entry.value / totalSpent * 100);
      
      return CategorySegment(
        categoryName: entry.key,
        amount: entry.value,
        percentage: percentage,
        color: categoryInfo?.color ?? Colors.grey,
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top categories',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          
          // Individual segments with spacing and rounded corners
          Row(
            children: segments.asMap().entries.map((entry) {
              final index = entry.key;
              final segment = entry.value;
              
              return Expanded(
                flex: (segment.percentage * 100).round(),
                child: Container(
                  height: 16, // Reduced from 24 to 16 for thinner bars
                  margin: EdgeInsets.only(
                    right: index < segments.length - 1 ? 4 : 0, // Add spacing between segments
                  ),
                  decoration: BoxDecoration(
                    color: segment.color,
                    borderRadius: BorderRadius.circular(8), // Reduced radius for thinner bars
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 12),
          
          // Percentage labels below each segment
          Row(
            children: segments.asMap().entries.map((entry) {
              final index = entry.key;
              final segment = entry.value;
              
              return Expanded(
                flex: (segment.percentage * 100).round(),
                child: Container(
                  margin: EdgeInsets.only(
                    right: index < segments.length - 1 ? 4 : 0, // Match segment spacing
                  ),
                  child: Text(
                    '${segment.percentage.toStringAsFixed(1)}%',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    // Group bills by category and sum totals
    Map<String, double> categoryTotals = {};
    for (var bill in _filteredBills) {
      String category = bill.categoryId ?? 'Uncategorized';
      categoryTotals[category] = (categoryTotals[category] ?? 0.0) + (bill.total ?? 0.0);
    }
    // Sort categories by total spent, take top 5
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sortedCategories.take(5).toList();
    final totalSpent = _filteredBills.fold(0.0, (sum, bill) => sum + (bill.total ?? 0.0));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4facfe).withOpacity(0.1),
            const Color(0xFF4facfe).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4facfe).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4facfe).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                'Categories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to detailed categories view
                },
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: const Color(0xFF4facfe),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (topCategories.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.category_outlined, size: 48, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text(
                    'No spending categories for this period',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            )
          else
            ...topCategories.map((entry) {
              final percent = totalSpent > 0 ? (entry.value / totalSpent * 100).round() : 0;
              final categoryInfo = CategoryService.getCategoryInfo(entry.key);
              return _buildCategoryItem({
                'name': entry.key,
                'amount': entry.value,
                'percentage': percent,
                'color': categoryInfo?.color ?? Colors.grey,
                'icon': categoryInfo?.icon ?? Icons.category,
              });
            }),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> category) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
               Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: category['color'].withOpacity(0.05),
                   borderRadius: BorderRadius.circular(8),
                 ),
                child: Icon(
                  category['icon'],
                  color: category['color'],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '\$${category['amount'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${category['percentage']}%',
                style: TextStyle(
                  color: category['color'],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: category['percentage'] / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(category['color']),
          ),
        ],
      ),
    );
  }


  void _showPremiumUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213e),
        title: const Text(
          '🔒 Premium Feature',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Advanced analytics require premium access.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'Premium features include:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...['Detailed spending analytics', 'Export functionality', 'Advanced analytics', 'Custom reports'].map((feature) => 
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(feature, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isPremium = true; // TODO: Connect to actual premium service
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Premium features unlocked!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4facfe),
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return ModernBottomNavigationBar(
      currentIndex: 1, // Analysis is active
      onTap: (index) {
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
    );
  }
}