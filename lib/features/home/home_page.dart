import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';
import './dynamic_expense_modal.dart';
import '../camera/camera_page.dart';
import '../storage/bill/bill_provider.dart';
import '../storage/models/bill_model.dart';

class HomePage extends ConsumerStatefulWidget {
  final double growthPercentage;
  final int achievementsCount;

  const HomePage({super.key, required this.growthPercentage, required this.achievementsCount});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedIndex = 0;
  bool _isMenuOpen = false;
  String? _lastTappedItem;
  String _selectedCurrency = 'USD';
  
  final List<String> _availableCurrencies = [
    'USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'CHF', 'CNY', 'INR', 'BRL'
  ];

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'CAD':
        return 'C\$';
      case 'AUD':
        return 'A\$';
      case 'CHF':
        return 'CHF';
      case 'CNY':
        return '¥';
      case 'INR':
        return '₹';
      case 'BRL':
        return 'R\$';
      default:
        return '\$';
    }
  }

  IconData _getCurrencyIcon(String currency) {
    switch (currency) {
      case 'USD':
        return Icons.attach_money;
      case 'EUR':
        return Icons.euro;
      case 'GBP':
        return Icons.currency_pound;
      case 'JPY':
        return Icons.currency_yen;
      case 'CAD':
        return Icons.attach_money;
      case 'AUD':
        return Icons.attach_money;
      case 'CHF':
        return Icons.attach_money;
      case 'CNY':
        return Icons.currency_yen;
      case 'INR':
        return Icons.currency_rupee;
      case 'BRL':
        return Icons.attach_money;
      default:
        return Icons.attach_money;
    }
  }

  Color _getCurrencyColor(String currency) {
    switch (currency) {
      case 'USD':
        return Colors.green;
      case 'EUR':
        return Colors.blue;
      case 'GBP':
        return Colors.red;
      case 'JPY':
        return Colors.orange;
      case 'CAD':
        return Colors.red;
      case 'AUD':
        return Colors.green;
      case 'CHF':
        return Colors.red;
      case 'CNY':
        return Colors.red;
      case 'INR':
        return Colors.orange;
      case 'BRL':
        return Colors.green;
      default:
        return Colors.green;
    }
  }

  String _getVendorName(Map<String, dynamic> formData) {
    switch (formData['formType']) {
      case 'FormType.manualExpense':
        return 'Manual Expense - ${formData['category'] ?? 'Other'}';
      case 'FormType.subscription':
        return 'Manual Entry - ${formData['subscriptionName'] ?? 'Unknown'}';
      case 'FormType.sepaTransfer':
        return 'Manual Entry - ${formData['bankName'] ?? 'Unknown Bank'}';
      default:
        return 'Manual Entry';
    }
  }

  Future<void> _showExpenseModal(String category) async {
    print('🔍 MAGIC HOME: Opening modal for category: $category');
    print('🔍 MAGIC HOME: Menu state before toggle: $_isMenuOpen');
    
    _toggleMenu();
    
    print('🔍 MAGIC HOME: Menu state after toggle: $_isMenuOpen');
    
    FormType formType;
    switch (category) {
      case 'Manual Expense':
        formType = FormType.manualExpense;
        break;
      case 'Subscription':
        formType = FormType.subscription;
        break;
      case 'SEPA':
        formType = FormType.sepaTransfer;
        break;
      default:
        formType = FormType.manualExpense;
    }
    
    print('🔍 MAGIC HOME: Form type determined: $formType');
    print('🔍 MAGIC HOME: Form type enum value: ${formType.name}');
    print('🔍 MAGIC HOME: Form type index: ${formType.index}');
    print('🔍 MAGIC HOME: About to show modal...');
    
    try {
      print('🔍 MAGIC HOME: Calling showModalBottomSheet...');
      
      
      
             print('🔍 MAGIC HOME: About to create DynamicExpenseModal widget...');
      
             final result = await showModalBottomSheet(
         context: context,
         isScrollControlled: true,
         backgroundColor: Colors.transparent,
         barrierColor: Colors.black54,
         isDismissible: true,
         enableDrag: true,
         builder: (context) => DynamicExpenseModal(
           formType: formType,
           selectedCurrency: _selectedCurrency,
                     onSubmit: (formData) async {
            print('🔍 MAGIC HOME: Form submitted: $formData');
            
            try {
              // Create a unique ID for the bill
              final billId = DateTime.now().millisecondsSinceEpoch.toString();
              
              // Create the bill object for manual entries
              final bill = Bill(
                id: billId,
                imagePath: 'assets/test_receipts/sample1.jpg', // Placeholder image for manual entries
                vendor: _getVendorName(formData),
                date: formData['date'] ?? DateTime.now(),
                total: formData['amount'] ?? 0.0,
                currency: _selectedCurrency,
                ocrText: 'Manual entry', // This identifies it as manual entry
                tags: [formData['category'] ?? 'Other'],
                location: null,
                notes: formData['notes'] ?? '',
              );
              
              // Save the bill to database
              ref.read(billProvider.notifier).addBill(bill);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${category} added successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              print('🔍 MAGIC HOME: Error saving manual entry: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to save ${category}: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
         ),
       );
      
      print('🔍 MAGIC HOME: Modal result: $result');
    } catch (e) {
      print('🔍 MAGIC HOME: ERROR showing modal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening form: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    print('🔍 MAGIC HOME: Modal should now be visible');
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4facfe).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                                 child: const Icon(
                   Icons.receipt_long,
                   color: Colors.white,
                   size: 24,
                 ),
              ),
              const SizedBox(width: 12),
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
              const Text(
                     'Smart Receipt',
                style: TextStyle(
                       fontSize: 20,
                       fontWeight: FontWeight.bold,
                       color: Colors.black87,
                     ),
                   ),
                   Row(
                     children: [
                       const Text(
                         'Track your expenses',
                         style: TextStyle(
                           fontSize: 12,
                           color: Colors.grey,
                         ),
                       ),
                       const SizedBox(width: 8),
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                         decoration: BoxDecoration(
                           color: _getCurrencyColor(_selectedCurrency).withOpacity(0.1),
                           borderRadius: BorderRadius.circular(8),
                           border: Border.all(
                             color: _getCurrencyColor(_selectedCurrency).withOpacity(0.3),
                             width: 1,
                           ),
                         ),
                         child: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Icon(
                               _getCurrencyIcon(_selectedCurrency),
                               color: _getCurrencyColor(_selectedCurrency),
                               size: 10,
                             ),
                             const SizedBox(width: 2),
                             Text(
                               _selectedCurrency,
                               style: TextStyle(
                                 color: _getCurrencyColor(_selectedCurrency),
                                 fontSize: 10,
                                 fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
                       ),
                     ],
                   ),
                 ],
               ),
            ],
          ),
                     Row(
             children: [
               
               // Notifications
          Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: Colors.grey.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: const Icon(
                   Icons.notifications_outlined,
                   color: Colors.grey,
                   size: 24,
                 ),
               ),
             ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'ve saved ${widget.achievementsCount} receipts this month',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
                    'Keep it up! 🎉',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingAnalytics(double growthPercentage) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                 'Monthly Spending (${_selectedCurrency})',
                 style: const TextStyle(
                   fontSize: 18,
                   fontWeight: FontWeight.bold,
                   color: Colors.black87,
                 ),
               ),
          Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                  color: growthPercentage >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      growthPercentage >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: growthPercentage >= 0 ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${growthPercentage.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: growthPercentage >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
                     Row(
             children: [
               Text(
                 '${_getCurrencySymbol(_selectedCurrency)}2,847',
                 style: const TextStyle(
                   fontSize: 32,
                   fontWeight: FontWeight.bold,
                   color: Colors.black87,
                 ),
               ),
               const SizedBox(width: 8),
               Text(
                 'this month',
                 style: const TextStyle(
                   fontSize: 14,
                   color: Colors.grey,
                 ),
               ),
             ],
           ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: 0.7,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4facfe)),
          ),
          const SizedBox(height: 8),
                     Text(
             '70% of monthly budget used (${_getCurrencySymbol(_selectedCurrency)}4,000)',
             style: TextStyle(
               fontSize: 12,
               color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(int achievementsCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CameraPage(),
                  ),
                );
              },
              child: _buildActionCard(
                'Scan Receipt',
                '${achievementsCount} scanned',
                Icons.camera_alt_rounded,
                [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildActionCard(
              'Achievements',
              '${achievementsCount} unlocked',
              Icons.emoji_events_rounded,
              [const Color(0xFFf59e0b), const Color(0xFFd97706)],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () {
                context.go('/bills');
              },
            child: _buildActionCard(
              'Storage',
              '245 receipts',
              Icons.folder_rounded,
              [const Color(0xFF6366f1), const Color(0xFF4f46e5)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCircularMenu() {
    return Container(
      width: 250,
      height: 250,
             decoration: BoxDecoration(
         color: Colors.transparent,
         borderRadius: BorderRadius.circular(100),
       ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Main Plus Button
          AnimatedRotation(
            turns: _isMenuOpen ? 0.125 : 0.0, // 45 degree rotation when open
            duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: () {
                print('🔍 Plus button tapped. Menu state before: $_isMenuOpen');
                _toggleMenu();
                print('🔍 Menu state after: $_isMenuOpen');
          },
                child: Container(
                width: 60,
                height: 60,
                  decoration: BoxDecoration(
                  color: const Color(0xFF4facfe),
                    shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                    boxShadow: [
                      BoxShadow(
                      color: const Color(0xFF4facfe).withOpacity(0.4),
                        blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                child: Icon(
                  _isMenuOpen ? Icons.close : Icons.add,
                    color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          // Menu items - positioned in a circle when open
          ...(_isMenuOpen ? [
            // Manual Expense - Top (0°)
            Positioned(
              top: 10,
              child: _buildMenuItem(
                'Manual\nExpense',
                Icons.account_balance_wallet,
                Colors.green,
                () async {
                  print('🔍 MAGIC HOME: Manual Expense callback executed!');
                  await _showExpenseModal('Manual Expense');
                },
                size: 60,
              ),
            ),
            // Subscription - Top Right (45°)
            Positioned(
              top: 25,
              right: 25,
              child: _buildMenuItem(
                'Subscription',
                Icons.calendar_today,
                Colors.blue,
                () async {
                  print('🔍 MAGIC HOME: Subscription callback executed!');
                  await _showExpenseModal('Subscription');
                },
                size: 60,
              ),
            ),
            // SEPA - Right (90°)
            Positioned(
              right: 10,
              child: _buildMenuItem(
                'SEPA',
                Icons.account_balance,
                Colors.orange,
                () async {
                  print('🔍 MAGIC HOME: SEPA callback executed!');
                  await _showExpenseModal('SEPA');
                },
                size: 60,
              ),
            ),
          ] : <Widget>[]),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String label, IconData icon, Color color, Future<void> Function() onTap, {double size = 70.0}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) {
      print('🔍 MAGIC HOME: Menu item "$label" tap down detected!');
    },
    onTapUp: (_) {
      print('🔍 MAGIC HOME: Menu item "$label" tap up detected!');
    },
    onTap: () {
      print('🔍 MAGIC HOME: Menu item "$label" tapped!');
      setState(() {
        _lastTappedItem = label;
      });
      print('🔍 MAGIC HOME: About to call onTap callback...');
      print('🔍 MAGIC HOME: onTap callback type: ${onTap.runtimeType}');
      
      try {
        print('🔍 MAGIC HOME: Executing onTap callback now...');
        onTap();
        print('🔍 MAGIC HOME: onTap callback completed successfully');
      } catch (e) {
        print('🔍 MAGIC HOME: ERROR in onTap callback: $e');
      }
    },
    child: Container(
      width: size,        // Use the size parameter
      height: size,       // Use the size parameter
         decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: size * 0.34), // Scale icon with button size
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: size * 0.14, // Scale text with button size
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final bottomPadding = MediaQuery.of(context).padding.bottom;

        const baseScreenWidth = 375.0; // iPhone standard width, adjust to your test device
        const baseScreenHeight = 812.0;

        final widthScale = screenWidth / baseScreenWidth;
        final heightScale = screenHeight / baseScreenHeight;

        final leftPosition = -70 * widthScale;
        final bottomPosition = (kBottomNavigationBarHeight + bottomPadding - 140) * heightScale;

    return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              Column(
                children: [
                  _buildCustomAppBar(),
                  Expanded(
                    child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                          const SizedBox(height: 20),
                    _buildWelcomeCard(),
                    _buildSpendingAnalytics(widget.growthPercentage),
                    _buildQuickActions(widget.achievementsCount),
                          const SizedBox(height: 20),
                          const SizedBox(height: 120), // Space for floating button
                  ],
                ),
              ),
                  ),
                ],
              ),
              // Positioned button on left side, 1cm above bottom navigation
              Positioned(
                left: leftPosition, // 24px from left edge
                bottom: bottomPosition, // 1cm above bottom nav
                child: _buildCircularMenu(),
              ),
            ],
          ),
          // Remove floatingActionButton completely
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
              ),
            ],
          ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: const Color(0xFF16213e),
              elevation: 0,
              currentIndex: _selectedIndex,
              selectedItemColor: const Color(0xFF4facfe),
              unselectedItemColor: Colors.grey[600],
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
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
        ),
      ),
    );
  }
//   @override
//   Widget build(BuildContext context) {
//     final auth = ref.watch(authControllerProvider);

//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Column(
//         children: [
//           _buildCustomAppBar(),
//           Expanded(
//             child: SingleChildScrollView(
//               physics: const BouncingScrollPhysics(),
//               child: Column(
//                 children: [
//                   const SizedBox(height: 20),
//                   _buildWelcomeCard(),
//                   _buildSpendingAnalytics(widget.growthPercentage),
//                                  _buildQuickActions(widget.achievementsCount),
               
//                                                 const SizedBox(height: 20),
               
//                const SizedBox(height: 20), // Space for bottom nav
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: _buildCircularMenu(),
//       floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
//       // floatingActionButton: Container(
//       //   margin: const EdgeInsets.only( bottom: 0, right: 330),
//       //   child: _buildCircularMenu(),
//       // ),
//       bottomNavigationBar: Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           boxShadow: [
//             BoxShadow(
//               color: Colors.grey.withOpacity(0.2),
//               blurRadius: 10,
//               offset: const Offset(0, -5),
//             ),
//           ],
//         ),
//         child: BottomNavigationBar(
//           type: BottomNavigationBarType.fixed,
//           backgroundColor: const Color(0xFF16213e),
//           elevation: 0,
//           currentIndex: _selectedIndex,
//           selectedItemColor: const Color(0xFF4facfe),
//           unselectedItemColor: Colors.grey[600],
//           onTap: (index) {
//             setState(() {
//               _selectedIndex = index;
//             });
//             // ignore: unused_local_variable
//             Widget destination = const HomePage(growthPercentage: 25, achievementsCount: 10,) as Widget;
//             switch (index) {
//               case 0:
//               context.go('/home');
            
//                 break;
//               case 1:
//                 context.go('/analysis');
//                 break;
//               case 2:
//                 // Navigator.push(
//                   context.go('/scan');
//                   // MaterialPageRoute(builder: (context) => const CameraPage()),
//                 // );
//                 break;
//               case 3:
//                 context.go('/bills');
//                 break;
//               case 4:
//                 context.go('/settings');
//                 break;
//             }
//           },
//           items: const [
//             BottomNavigationBarItem(
//               icon: Icon(Icons.home),
//               label: 'Home',
//             ),
//             BottomNavigationBarItem(
//               icon: Icon(Icons.analytics),
//               label: 'Analysis',
//             ),
//             BottomNavigationBarItem(
//               icon: Icon(Icons.camera_alt),
//               label: 'Scan',
//             ),
//             BottomNavigationBarItem(
//               icon: Icon(Icons.folder),
//               label: 'Storage',
//             ),
//             BottomNavigationBarItem(
//               icon: Icon(Icons.person),
//               label: 'Profile',
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
}