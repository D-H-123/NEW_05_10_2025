import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_receipt/core/services/analytics_repository.dart';
import 'package:smart_receipt/features/storage/models/bill_model.dart';
import 'package:smart_receipt/core/services/local_storage_service.dart';
import 'package:smart_receipt/core/services/category_service.dart';
import 'package:smart_receipt/core/theme/app_colors.dart';
import 'package:smart_receipt/core/widgets/modern_widgets.dart';
import 'package:smart_receipt/core/widgets/skeleton_loader.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  int _selectedTimeFilter = 1; // 0: Week, 1: Month, 2: Year
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late final AnalyticsRepository _analyticsRepository;
  List<Bill> _filteredBills = [];
  bool _isLoading = false;
  
  // Analytics data
  double _totalSpent = 0.0;
  double _previousTotal = 0.0;
  double _percentageChange = 0.0;

  /// Hovered segment index for donut chart (web/desktop); null when not hovering.
  int? _chartHoveredSegmentIndex;

  @override
  void initState() {
    super.initState();
    _analyticsRepository = AnalyticsRepository(localStorage: LocalStorageService());
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    // ✅ Performance: Start loading immediately, don't defer
    _fetchBills();
  }

  void _fetchBills() async {
    setState(() => _isLoading = true);
    final filter = TimeFilter.values[_selectedTimeFilter];
    
    try {
      // ✅ Performance: Fetch all needed data in parallel, avoiding redundant calls
      final results = await Future.wait([
        _analyticsRepository.getBills(filter: filter),
        _analyticsRepository.getPreviousPeriodBills(filter),
      ]);
      
      final bills = results[0];
      final previousBills = results[1];
      
      // ✅ Performance: Calculate totals synchronously (fast)
      final totalSpent = bills.fold<double>(0.0, (sum, bill) => sum + (bill.total ?? 0.0));
      final previousTotal = previousBills.fold<double>(0.0, (sum, bill) => sum + (bill.total ?? 0.0));
      
      // ✅ Performance: Calculate percentage change locally (fast)
      double percentageChange = 0.0;
      if (previousTotal == 0 && totalSpent > 0) {
        percentageChange = 100.0;
      } else if (previousTotal > 0) {
        percentageChange = ((totalSpent - previousTotal) / previousTotal) * 100;
      }
      percentageChange = double.parse(percentageChange.toStringAsFixed(1));
      
      setState(() {
        _filteredBills = bills;
        _totalSpent = totalSpent;
        _previousTotal = previousTotal;
        _percentageChange = percentageChange;
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error fetching analytics data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  bool get wantKeepAlive => true; // ✅ Performance: Preserve page state during navigation

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

  /// Period label for donut center: "This week", "This month", "This year".
  String _getCenterPeriodLabel() {
    switch (_selectedTimeFilter) {
      case 0:
        return 'This week';
      case 1:
        return 'This month';
      case 2:
        return 'This year';
      default:
        return 'This month';
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
    super.build(context); // ✅ Performance: Required for AutomaticKeepAliveClientMixin
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
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isLoading
            ? ListView(
                // ✅ UI/UX Improvement: Show skeleton loaders instead of spinner
                padding: const EdgeInsets.all(16),
                children: const [
                  SizedBox(height: 24),
                  BudgetCardSkeletonLoader(),
                  SizedBox(height: 16),
                  ChartSkeletonLoader(),
                  SizedBox(height: 16),
                  SkeletonLoader(height: 200, borderRadius: 16),
                ],
              )
            : RefreshIndicator(
                // ✅ UI/UX Improvement: Add pull-to-refresh
                onRefresh: () async {
                  _fetchBills();
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth;
                    return SizedBox(
                      width: maxW.isFinite ? maxW : MediaQuery.sizeOf(context).width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
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

                    // Your receipt story (Suggestion 10) — commented out
                    // _buildReceiptStorySection(),
                    // const SizedBox(height: 24),

                    // Categories Section
                    _buildCategoriesSection(),
                    const SizedBox(height: 32),
                        ],
                      ),
                    );
                  },
                ),
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
                      ? AppColors.bottomNavBackground
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
    final periodLabel = _getPeriodLabel();
    final delta = _totalSpent - _previousTotal;
    final isUp = delta >= 0;
    final deltaAbs = delta.abs();
    final trendColor = _getSpendingChangeColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  periodLabel.lastPeriod,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '\$${_previousTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  periodLabel.thisPeriod,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      isUp ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: trendColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isUp ? '+' : ''}\$${deltaAbs.toStringAsFixed(2)} from ${_getPeriodText()}',
                      style: TextStyle(
                        fontSize: 13,
                        color: trendColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Labels for comparison card: "Last month" / "This month" (or week/year).
  ({String lastPeriod, String thisPeriod}) _getPeriodLabel() {
    switch (_selectedTimeFilter) {
      case 0:
        return (lastPeriod: 'Last week', thisPeriod: 'This week');
      case 1:
        return (lastPeriod: 'Last month', thisPeriod: 'This month');
      case 2:
        return (lastPeriod: 'Last year', thisPeriod: 'This year');
      default:
        return (lastPeriod: 'Last month', thisPeriod: 'This month');
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

  /// This period in receipts: receipt count, categories, top merchants (Suggestion 10).
  Widget _buildReceiptStorySection() {
    if (_filteredBills.isEmpty) return const SizedBox.shrink();

    final receiptCount = _filteredBills.length;
    final Set<String> categories = {};
    final Map<String, double> byVendor = {};
    for (var bill in _filteredBills) {
      categories.add(bill.categoryId ?? 'Uncategorized');
      final v = (bill.vendor ?? 'Unknown').trim().isEmpty ? 'Unknown' : (bill.vendor ?? 'Unknown');
      byVendor[v] = (byVendor[v] ?? 0.0) + (bill.total ?? 0.0);
    }
    final topVendors = byVendor.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = topVendors.take(3).map((e) => e.key).toList();
    final periodLabel = _selectedTimeFilter == 0
        ? 'This week'
        : _selectedTimeFilter == 1
            ? 'This month'
            : 'This year';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4facfe).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt, color: const Color(0xFF4facfe), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$periodLabel in receipts',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _storyChip(
                Icons.receipt_long,
                '$receiptCount ${receiptCount == 1 ? 'receipt' : 'receipts'}',
              ),
              _storyChip(
                Icons.category_outlined,
                '${categories.length} ${categories.length == 1 ? 'category' : 'categories'}',
              ),
              if (top3.isNotEmpty)
                _storyChip(
                  Icons.store_outlined,
                  'Top: ${top3.take(2).join(', ')}${top3.length > 2 ? ', ${top3[2]}' : ''}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _storyChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[800], fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingTrendChart() {
    // Group bills by category and sum totals
    final Map<String, double> categoryTotals = {};
    for (var bill in _filteredBills) {
      final category = bill.categoryId ?? 'Uncategorized';
      categoryTotals[category] = (categoryTotals[category] ?? 0.0) + (bill.total ?? 0.0);
    }
    final allCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
          Text(
            _getTimeFilterTitle(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          allCategories.isEmpty
              ? Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
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
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4facfe).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.receipt_long_outlined,
                            size: 40,
                            color: const Color(0xFF4facfe).withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No spending data yet',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Your first chart appears after you scan a receipt.',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => context.go('/scan'),
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('Scan receipt', style: TextStyle(fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4facfe),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildPieChart(allCategories),
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

    const double chartSize = 280;
    const double strokeWidth = 36;
    const double gapDeg = 8; // clear visible gap between segments

    // Build segment data
    final segments = <_DonutSegment>[];
    for (final entry in allCategories) {
      final info = CategoryService.getCategoryInfo(entry.key);
      segments.add(_DonutSegment(
        value: entry.value,
        color: info?.color ?? Colors.grey,
        icon: info?.icon ?? Icons.category,
      ));
    }

    return Center(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onHover: (event) {
          final index = _getTappedSegmentIndex(
            event.localPosition,
            Size(chartSize, chartSize),
            segments,
            totalSpent,
            strokeWidth,
            gapDeg,
          );
          if (_chartHoveredSegmentIndex != index) {
            setState(() => _chartHoveredSegmentIndex = index);
          }
        },
        onExit: (_) {
          if (_chartHoveredSegmentIndex != null) {
            setState(() => _chartHoveredSegmentIndex = null);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final index = _getTappedSegmentIndex(
              details.localPosition,
              Size(chartSize, chartSize),
              segments,
              totalSpent,
              strokeWidth,
              gapDeg,
            );
            if (index != null && index >= 0 && index < allCategories.length) {
              final categoryKey = allCategories[index].key;
              context.go('/bills', extra: categoryKey);
            }
          },
          child: SizedBox(
            width: chartSize,
            height: chartSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
            // Donut ring with rounded ends
            CustomPaint(
              size: Size(chartSize, chartSize),
              painter: _RoundedDonutPainter(
                segments: segments,
                totalValue: totalSpent,
                strokeWidth: strokeWidth,
                gapDegrees: gapDeg,
                hoveredSegmentIndex: _chartHoveredSegmentIndex,
              ),
            ),
            // Category icons positioned on each segment (mid-angle matches rounded slice)
            ...List.generate(segments.length, (i) {
              final seg = segments[i];
              double startAngleDeg = -90;
              for (int j = 0; j < i; j++) {
                startAngleDeg += 360 * (segments[j].value / totalSpent);
              }
              final sweepDeg = 360 * (seg.value / totalSpent);
              final midAngle = startAngleDeg + sweepDeg / 2;
              final midRad = midAngle * math.pi / 180;
              final iconRadius = (chartSize - strokeWidth) / 2; // center of the ring
              final dx = chartSize / 2 + iconRadius * math.cos(midRad);
              final dy = chartSize / 2 + iconRadius * math.sin(midRad);

              return Positioned(
                left: dx - 10,
                top: dy - 10,
                child: Icon(seg.icon, color: Colors.white, size: 20),
              );
            }),
            // Center: total spend + period label
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '\$${totalSpent.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getCenterPeriodLabel(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
          ),
        ),
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
    final themeColor = AppColors.bottomNavBackground;
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
              const Text(
                'Categories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: _filteredBills.isEmpty ? null : _showAllCategoriesSheet,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(left: 12, right: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: themeColor,
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              final width = (maxW.isFinite && maxW > 0)
                  ? maxW
                  : MediaQuery.sizeOf(context).width;
              return SizedBox(
                width: width,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Container(
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
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            category['name'] as String? ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '\$${(category['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${category['percentage']}%',
                      style: TextStyle(
                        color: category['color'] is Color ? category['color'] as Color : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.visible,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (category['percentage'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.0,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(category['color'] is Color ? category['color'] as Color : Colors.grey),
          ),
        ],
      ),
    );
  }

  /// Full category breakdown sheet when "View All" is tapped (Suggestion 5).
  void _showAllCategoriesSheet() {
    final Map<String, double> categoryTotals = {};
    for (var bill in _filteredBills) {
      final cat = bill.categoryId ?? 'Uncategorized';
      categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + (bill.total ?? 0.0);
    }
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalSpent = _filteredBills.fold<double>(0.0, (sum, b) => sum + (b.total ?? 0.0));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          width: MediaQuery.sizeOf(context).width,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Category breakdown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\$${totalSpent.toStringAsFixed(2)} total',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: sorted.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.category_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No categories for this period',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: sorted.length,
                        itemBuilder: (context, index) {
                          final entry = sorted[index];
                          final percent = totalSpent > 0
                              ? (entry.value / totalSpent * 100).round()
                              : 0;
                          final info = CategoryService.getCategoryInfo(entry.key);
                          return _buildCategoryItem({
                            'name': entry.key,
                            'amount': entry.value,
                            'percentage': percent,
                            'color': info?.color ?? Colors.grey,
                            'icon': info?.icon ?? Icons.category,
                          });
                        },
                      ),
              ),
            ],
          ),
        ),
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

// ---------------------------------------------------------------------------
// Custom donut chart with rounded segment ends
// ---------------------------------------------------------------------------

/// Returns the segment index under [position], or null if tap is outside the ring.
int? _getTappedSegmentIndex(
  Offset position,
  Size size,
  List<_DonutSegment> segments,
  double totalValue,
  double strokeWidth,
  double gapDegrees,
) {
  final center = Offset(size.width / 2, size.height / 2);
  final outerR = math.min(size.width, size.height) / 2;
  final innerR = outerR - strokeWidth;
  final dx = position.dx - center.dx;
  final dy = position.dy - center.dy;
  final distance = math.sqrt(dx * dx + dy * dy);
  if (distance < innerR || distance > outerR) return null;

  double angle = math.atan2(dy, dx);
  if (angle < -math.pi / 2) angle += 2 * math.pi;

  final gapRadian = (gapDegrees * math.pi / 180);
  double startAngle = -math.pi / 2;
  for (int i = 0; i < segments.length; i++) {
    final sweep = (segments[i].value / totalValue) * 2 * math.pi;
    final realStart = startAngle + gapRadian / 2;
    final realEnd = startAngle + sweep - gapRadian / 2;
    if (angle >= realStart && angle < realEnd) return i;
    startAngle += sweep;
  }
  return null;
}

class _DonutSegment {
  final double value;
  final Color color;
  final IconData icon;
  _DonutSegment({required this.value, required this.color, required this.icon});
}

class _RoundedDonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final double totalValue;
  final double strokeWidth;
  final double gapDegrees;
  final int? hoveredSegmentIndex;
  static const double _cornerRadius = 6.0;

  _RoundedDonutPainter({
    required this.segments,
    required this.totalValue,
    required this.strokeWidth,
    required this.gapDegrees,
    this.hoveredSegmentIndex,
  });

  /// Rounded donut slice (logic from Stack Overflow CC BY-SA 4.0 - Tuấn Nguyễn Văn / community).
  Path _roundedDonutSlice({
    required Offset center,
    required double rOuter,
    required double rInner,
    required double a0,
    required double a1,
    required double radius,
  }) {
    final path = Path();

    Offset p(double r, double a) {
      return Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
    }

    final o0 = p(rOuter, a0);
    final o1 = p(rOuter, a1);
    final i1 = p(rInner, a1);
    final i0 = p(rInner, a0);

    final r = radius.clamp(0.0, (rOuter - rInner) / 2);

    final o0s = p(rOuter, a0 + r / rOuter);
    path.moveTo(o0s.dx, o0s.dy);

    path.arcTo(
      Rect.fromCircle(center: center, radius: rOuter),
      a0 + r / rOuter,
      (a1 - a0) - 2 * r / rOuter,
      false,
    );

    path.quadraticBezierTo(
      o1.dx,
      o1.dy,
      p(rOuter - r, a1).dx,
      p(rOuter - r, a1).dy,
    );

    path.lineTo(p(rInner + r, a1).dx, p(rInner + r, a1).dy);
    path.quadraticBezierTo(
      i1.dx,
      i1.dy,
      p(rInner, a1 - r / rInner).dx,
      p(rInner, a1 - r / rInner).dy,
    );
    path.arcTo(
      Rect.fromCircle(center: center, radius: rInner),
      a1 - r / rInner,
      -((a1 - a0) - 2 * r / rInner),
      false,
    );
    path.quadraticBezierTo(
      i0.dx,
      i0.dy,
      p(rInner + r, a0).dx,
      p(rInner + r, a0).dy,
    );
    path.lineTo(p(rOuter - r, a0).dx, p(rOuter - r, a0).dy);
    path.quadraticBezierTo(o0.dx, o0.dy, o0s.dx, o0s.dy);

    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = math.min(size.width, size.height) / 2;
    final innerR = outerR - strokeWidth;
    final gapRadian = (gapDegrees * math.pi / 180);
    final total = totalValue;
    double startAngle = -math.pi / 2;

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final sweep = (seg.value / total) * 2 * math.pi;
      final realSweep = sweep - gapRadian;
      if (realSweep > 0) {
        final a0 = startAngle + gapRadian / 2;
        final a1 = a0 + realSweep;
        final path = _roundedDonutSlice(
          center: center,
          rOuter: outerR,
          rInner: innerR,
          a0: a0,
          a1: a1,
          radius: _cornerRadius,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = seg.color.withOpacity(0.75)
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
        if (hoveredSegmentIndex == i) {
          canvas.drawPath(
            path,
            Paint()
              ..color = Colors.white.withOpacity(0.25)
              ..style = PaintingStyle.fill
              ..isAntiAlias = true,
          );
        }
      }
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RoundedDonutPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.totalValue != totalValue ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gapDegrees != gapDegrees ||
        oldDelegate.hoveredSegmentIndex != hoveredSegmentIndex;
  }
}