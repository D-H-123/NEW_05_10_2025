import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_receipt/features/storage/bill/bill_page.dart';
import 'package:smart_receipt/features/settings/settings_page.dart';
import 'package:smart_receipt/features/home/home_page.dart';

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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Premium Banner
              _buildPremiumBanner(),
              const SizedBox(height: 24),

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
              const SizedBox(height: 24),

              // Smart Insights Section
              _buildSmartInsightsSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildPremiumBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unlock Premium Analytics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Advanced insights & forecasting',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _showPremiumUpgradeDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Upgrade',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
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
              onTap: () => _onTimeFilterChanged(index),
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
    return Row(
      children: [
        Expanded(
          child: _buildBudgetCard(
            icon: Icons.attach_money,
            amount: '\$1,247',
            title: 'Total Spent',
            subtitle: '+12% vs last month',
            isPositive: true,
            color: const Color(0xFF4facfe),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBudgetCard(
            icon: Icons.track_changes,
            amount: '\$753',
            title: 'Budget Left',
            subtitle: '-8% vs target',
            isPositive: false,
            color: const Color(0xFFe74c3c),
          ),
        ),
      ],
    );
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, // Restored to original white background
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isPositive ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingTrendChart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, // Restored to original white background
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
                 'Spending Trend',
                 style: TextStyle(
                   fontSize: 18,
                   fontWeight: FontWeight.bold,
                   color: Colors.black87,
                 ),
               ),
              Icon(
                Icons.show_chart,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 100,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            if (value >= 0 && value < days.length) {
                              return Text(
                                days[value.toInt()],
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
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
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '\$${value.toInt()}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    backgroundColor: const Color(0xFF16213e),
                                         barGroups: [
                       BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 45, color: Color(0xFF4facfe))]),
                       BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 32, color: Color(0xFF4facfe))]),
                       BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 67, color: Color(0xFF4facfe))]),
                       BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 89, color: Color(0xFF4facfe))]),
                       BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 56, color: Color(0xFF4facfe))]),
                       BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 78, color: Color(0xFF4facfe))]),
                       BarChartGroupData(x: 6, barRods: [BarChartRodData(toY: 34, color: Color(0xFF4facfe))]),
                     ],
                  ),
                ),
              ),
              if (!_isPremium)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock,
                            color: Colors.white.withOpacity(0.7),
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Premium Required',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Upgrade to view detailed analytics',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final categories = [
      {'name': 'Food & Dining', 'amount': 487.32, 'percentage': 39, 'color': Colors.green, 'icon': Icons.restaurant},
      {'name': 'Shopping', 'amount': 234.50, 'percentage': 19, 'color': Color(0xFF4facfe), 'icon': Icons.shopping_bag},
      {'name': 'Transportation', 'amount': 156.78, 'percentage': 13, 'color': Colors.yellow, 'icon': Icons.directions_car},
      {'name': 'Coffee', 'amount': 89.45, 'percentage': 7, 'color': Colors.orange, 'icon': Icons.coffee},
      {'name': 'Home', 'amount': 278.95, 'percentage': 22, 'color': Colors.purple, 'icon': Icons.home},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213e), // Dark blue card background
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
                  color: Colors.white,
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
          ...categories.map((category) => _buildCategoryItem(category)),
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
                  color: category['color'].withOpacity(0.1),
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
                        color: Colors.white,
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
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(category['color']),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartInsightsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0f3460), // Darker blue background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4facfe).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Smart Insights',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildInsightCard(
            icon: Icons.lightbulb,
            title: 'Spending Pattern',
            text: 'You spend 40% more on weekends. Consider setting weekend budgets.',
            backgroundColor: const Color(0xFF4facfe).withOpacity(0.1),
            iconColor: const Color(0xFF4facfe),
          ),
          const SizedBox(height: 12),
          _buildInsightCard(
            icon: Icons.check_circle,
            title: 'Goal Progress',
            text: 'Great job! You\'re 15% under your dining budget this month.',
            backgroundColor: Colors.green.withOpacity(0.1),
            iconColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required String text,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
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
            ...['Detailed spending analytics', 'Export functionality', 'Advanced insights', 'Custom reports'].map((feature) => 
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
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: const Color(0xFF16213e),
      selectedItemColor: const Color(0xFF4facfe),
      unselectedItemColor: Colors.grey[600],
      currentIndex: 1, // Analysis is active
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics),
          label: 'Analysis',
        ),
        BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt),
              label: 'Scan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.folder),
          label: 'Storage',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      onTap: (index) {
        Widget destination = const AnalysisPage() as Widget;

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

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
      },
    );
  }
}
