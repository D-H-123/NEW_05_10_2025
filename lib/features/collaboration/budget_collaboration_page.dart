import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/shared_budget.dart';
import '../../core/services/budget_collaboration_service.dart';
import '../../core/services/premium_service.dart';
import '../../core/services/category_service.dart';
import '../../core/widgets/subscription_paywall.dart';
import 'settlement_tracker_page.dart';

class BudgetCollaborationPage extends StatefulWidget {
  const BudgetCollaborationPage({super.key});

  @override
  State<BudgetCollaborationPage> createState() => _BudgetCollaborationPageState();
}

class _BudgetCollaborationPageState extends State<BudgetCollaborationPage> {
  @override
  Widget build(BuildContext context) {
    // Check premium access
    if (!PremiumService.isPremium) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Budget Collaboration'),
          backgroundColor: const Color(0xFF16213e),
          foregroundColor: Colors.white,
        ),
        body: const SubscriptionPaywall(
          title: 'Budget Collaboration',
          subtitle: 'Share budgets with family members and track spending together in real-time.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Row(
          children: [
            const Text(
              'Family Budgets',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (PremiumService.isPremium && !PremiumService.isTrialActive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DEBUG',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close',
          ),
        ],
      ),
      body: StreamBuilder<List<SharedBudget>>(
        stream: BudgetCollaborationService.getUserSharedBudgets(),
        builder: (context, snapshot) {
          print('🔄 StreamBuilder state: ${snapshot.connectionState}');
          print('📊 Has data: ${snapshot.hasData}');
          print('❌ Has error: ${snapshot.hasError}');
          if (snapshot.hasData) {
            print('📦 Data length: ${snapshot.data?.length}');
          }

          // Show loading spinner while waiting
          if (snapshot.connectionState == ConnectionState.waiting) {
            print('⏳ Showing loading...');
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16213e)),
                  ),
                  SizedBox(height: 16),
                  Text('Loading budgets...'),
                ],
              ),
            );
          }

          // Show error if there's an issue
          if (snapshot.hasError) {
            print('❌ Error: ${snapshot.error}');
            print('❌ Stack: ${snapshot.stackTrace}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Failed to load budgets'),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16213e),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Get budgets list
          final budgets = snapshot.data ?? [];
          print('✅ Rendering ${budgets.length} budgets');

          // Show empty state if no budgets
          if (budgets.isEmpty) {
            print('📭 Showing empty state');
            return _buildEmptyState();
          }

          // Show budget list
          print('📋 Building budget list...');
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: budgets.length,
            itemBuilder: (context, index) {
              print('🎨 Building card for: ${budgets[index].name}');
              return _buildBudgetCard(budgets[index]);
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: () => _showJoinBudgetDialog(),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF16213e),
            icon: const Icon(Icons.group_add),
            label: const Text('Join'),
            heroTag: 'join',
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: () => _showCreateBudgetDialog(),
            backgroundColor: const Color(0xFF16213e),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Create'),
            heroTag: 'create',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF16213e).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people,
                size: 64,
                color: Color(0xFF16213e),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Shared Budgets',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create a budget to share with family or join an existing one with an invite code.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showJoinBudgetDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF16213e),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF16213e)),
                    ),
                  ),
                  icon: const Icon(Icons.group_add),
                  label: const Text('Join Budget'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showCreateBudgetDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16213e),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Budget'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetCard(SharedBudget budget) {
    // Check if current user is owner
    final isOwner = budget.ownerId == FirebaseAuth.instance.currentUser?.uid;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToBudgetDetails(budget),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                // Header Row
                Row(
                  children: [
                    // Icon with gradient background
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF16213e), Color(0xFF1a2947)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF16213e).withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Budget Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  budget.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16213e),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isOwner) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Text(
                                    'Owner',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.monetization_on,
                                size: 16,
                                color: Color(0xFF16213e),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '\$${budget.amount.toStringAsFixed(0)}/month',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF16213e),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Arrow
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Color(0xFF16213e),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Divider
                Container(
                  height: 1,
                  color: Colors.grey.withOpacity(0.1),
                ),
                
                const SizedBox(height: 14),
                
                // Bottom Row - Members Info
                Row(
                  children: [
                    _buildMemberAvatars(budget.members),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        budget.members.length == 1
                            ? '1 member'
                            : '${budget.members.length} members',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Tap to View badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16213e).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Details',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF16213e),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.visibility,
                            size: 14,
                            color: Color(0xFF16213e),
                          ),
                        ],
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

  Widget _buildMemberAvatars(List<BudgetMember> members) {
    final displayMembers = members.take(3).toList();
    
    if (displayMembers.isEmpty) {
      return const SizedBox(width: 32, height: 32);
    }
    
    // Calculate width: first avatar (32px) + overlapping avatars (24px each)
    final width = 32.0 + (displayMembers.length - 1) * 24.0;
    
    return SizedBox(
      width: width,
      height: 32,
      child: Stack(
        children: List.generate(displayMembers.length, (index) {
          final member = displayMembers[index];
          return Positioned(
            left: index * 24.0,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                color: _getAvatarColor(member.name),
              ),
              child: Center(
                child: Text(
                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.green,
      Colors.red,
      Colors.teal,
    ];
    return colors[name.hashCode % colors.length];
  }

  void _showCreateBudgetDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Create Shared Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Budget Name',
                hintText: 'e.g., Family Budget',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Monthly Amount',
                hintText: '3000',
                prefixText: '\$ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final amount = double.tryParse(amountController.text);

              if (name.isEmpty || amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid details')),
                );
                return;
              }

              Navigator.pop(context);

              print('🚀 Creating budget: "$name" with amount: \$${amount}');
              
              final budget = await BudgetCollaborationService.createSharedBudget(
                name: name,
                amount: amount,
              );

              if (budget != null) {
                print('✅ Budget created successfully!');
                print('   📝 Budget ID: ${budget.id}');
                print('   💰 Budget Name: ${budget.name}');
                print('   💵 Amount: \$${budget.amount}');
                print('   🔑 Invite Code: ${budget.inviteCode}');
                print('   👥 Members: ${budget.members.length}');
                print('   🖼️ Mounted: $mounted');
                
                if (mounted) {
                  print('🎬 Attempting to show dialog...');
                  _showInviteCodeDialog(budget);
                } else {
                  print('⚠️ Widget not mounted, cannot show dialog');
                }
              } else {
                print('❌ Failed to create budget');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to create budget. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16213e),
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinBudgetDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Join Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the 6-character invite code shared by the budget owner.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Invite Code',
                hintText: 'ABC123',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim().toUpperCase();

              if (code.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid 6-character code')),
                );
                return;
              }

              Navigator.pop(context);

              final result = await BudgetCollaborationService.joinSharedBudget(code);

              if (mounted) {
                String message;
                Color backgroundColor;
                
                switch (result) {
                  case 'success':
                    message = '✅ Successfully joined budget!';
                    backgroundColor = Colors.green;
                    break;
                  case 'already_member':
                    message = 'ℹ️ You are already a member of this budget';
                    backgroundColor = Colors.blue;
                    break;
                  case 'invalid_code':
                    message = '❌ Invalid invite code. Please check and try again.';
                    backgroundColor = Colors.red;
                    break;
                  default:
                    message = '❌ Failed to join budget. Please try again.';
                    backgroundColor = Colors.red;
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: backgroundColor,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16213e),
              foregroundColor: Colors.white,
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _showInviteCodeDialog(SharedBudget budget) {
    print('🎉 Showing invite code dialog with code: ${budget.inviteCode}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.orange),
            SizedBox(width: 8),
            Text('Budget Created!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this code with family members to invite them:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF16213e).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF16213e),
                  width: 2,
                ),
              ),
              child: Text(
                budget.inviteCode ?? '',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: Color(0xFF16213e),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: budget.inviteCode ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied!')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
                TextButton.icon(
                  onPressed: () {
                    Share.share(
                      'Join our family budget on SmartReceipt! Use code: ${budget.inviteCode}',
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16213e),
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _navigateToBudgetDetails(SharedBudget budget) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SharedBudgetDetailsPage(budget: budget),
      ),
    );
  }
}

// Shared Budget Details Page
class SharedBudgetDetailsPage extends StatelessWidget {
  final SharedBudget budget;

  const SharedBudgetDetailsPage({super.key, required this.budget});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          budget.name,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          StreamBuilder<List<MemberExpense>>(
            stream: BudgetCollaborationService.getSharedBudgetExpenses(budget.id),
            builder: (context, snapshot) {
              final expenses = snapshot.data ?? [];
              final pendingCount = _getPendingSettlementsCount(expenses);
              
              return Stack(
                children: [
          IconButton(
                    icon: const Icon(Icons.account_balance_wallet, color: Colors.black87),
                    onPressed: () => _navigateToSettlementTracker(context, expenses),
                    tooltip: 'Settlements',
                  ),
                  if (pendingCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            '$pendingCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black87),
            onPressed: () => _showBudgetSettings(context),
          ),
        ],
      ),
      body: StreamBuilder<List<MemberExpense>>(
        stream: BudgetCollaborationService.getSharedBudgetExpenses(budget.id),
        builder: (context, snapshot) {
          final expenses = snapshot.data ?? [];
          final totalSpending = budget.calculateTotalSpending(expenses);
          final remaining = budget.amount - totalSpending;
          final percentage = (totalSpending / budget.amount * 100).clamp(0, 100);

          return SingleChildScrollView(
            child: Column(
              children: [
                // Budget Overview
                Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF16213e), Color(0xFF1a2947)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        '\$${totalSpending.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'of \$${budget.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          minHeight: 12,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            percentage < 70
                                ? Colors.green
                                : percentage < 100
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        remaining >= 0
                            ? '\$${remaining.toStringAsFixed(2)} remaining'
                            : '\$${remaining.abs().toStringAsFixed(2)} over budget',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Share Code Button (Top Right)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Material(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () => _showSimpleInviteCode(context),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              child: const Icon(
                                Icons.share,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),


                // Members Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.people, color: Color(0xFF16213e)),
                          SizedBox(width: 8),
                          Text(
                            'Members',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...budget.members.map((member) {
                        final memberSpending = budget.getSpendingByMember(member.userId, expenses);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: _getAvatarColor(member.name),
                                child: Text(
                                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '\$${memberSpending.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (member.role == 'owner')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Owner',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Expenses List
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.receipt_long, color: Color(0xFF16213e)),
                          SizedBox(width: 8),
                          Text(
                            'Recent Expenses',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (expenses.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'No expenses yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ...expenses.take(10).map((expense) {
                          final hasNote = expense.description != null && expense.description!.isNotEmpty;
                          final categoryInfo = CategoryService.getCategoryInfo(expense.category);
                          final isSplit = expense.isSplit && expense.splitWith.isNotEmpty;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showExpenseDetailsDialog(context, expense),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSplit 
                                        ? const Color(0xFF4facfe).withOpacity(0.02)
                                        : Colors.grey.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSplit
                                          ? const Color(0xFF4facfe).withOpacity(0.15)
                                          : Colors.grey.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                            child: Row(
                              children: [
                                Container(
                                        padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                          color: (categoryInfo?.color ?? Colors.grey).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                  ),
                                        child: Icon(
                                          categoryInfo?.icon ?? Icons.shopping_bag,
                                    size: 20,
                                          color: categoryInfo?.color ?? const Color(0xFF16213e),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                        expense.title ?? expense.category,
                                        style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (hasNote) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ],
                                                if (isSplit) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF4facfe).withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(
                                                        color: const Color(0xFF4facfe).withOpacity(0.3),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.people_alt,
                                                          size: 11,
                                                          color: Color(0xFF4facfe),
                                                        ),
                                                        SizedBox(width: 2),
                                                        Text(
                                                          'Split',
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFF4facfe),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                      Text(
                                        '${expense.userName} • ${_formatDate(expense.date)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                Text(
                                  '\$${expense.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                              color: Color(0xFF16213e),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isSplit) ...[
                                                _buildSplitAvatars(expense),
                                                const SizedBox(width: 6),
                                              ],
                                              Icon(
                                                Icons.chevron_right,
                                                size: 16,
                                                color: Colors.grey[400],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(context),
        backgroundColor: const Color(0xFF16213e),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.green,
      Colors.red,
      Colors.teal,
    ];
    return colors[name.hashCode % colors.length];
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildSplitAvatars(MemberExpense expense) {
    if (!expense.isSplit || expense.splitWith.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get members involved in the split
    final splitMembers = budget.members.where((m) => expense.splitWith.contains(m.userId)).toList();
    final displayMembers = splitMembers.take(3).toList();
    
    if (displayMembers.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate width: each avatar is 20px, overlapping by 8px
    final width = 20.0 + (displayMembers.length - 1) * 12.0;

    return SizedBox(
      width: width,
      height: 20,
      child: Stack(
        children: [
          ...List.generate(displayMembers.length, (index) {
            final member = displayMembers[index];
            return Positioned(
              left: index * 12.0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  color: _getAvatarColor(member.name),
                ),
                child: Center(
                  child: Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }),
          if (splitMembers.length > 3)
            Positioned(
              left: 3 * 12.0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  color: const Color(0xFF4facfe),
                ),
                child: Center(
                  child: Text(
                    '+${splitMembers.length - 3}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, {MemberExpense? expenseToEdit}) {
    final isEditing = expenseToEdit != null;
    
    final amountController = TextEditingController(
      text: isEditing ? expenseToEdit.amount.toStringAsFixed(2) : ''
    );
    final titleController = TextEditingController(
      text: isEditing ? (expenseToEdit.title ?? '') : ''
    );
    final descriptionController = TextEditingController(
      text: isEditing ? (expenseToEdit.description ?? '') : ''
    );
    String? selectedCategory = isEditing ? expenseToEdit.category : null;
    
    // Split expense state - pre-populate if editing
    bool isSplitEnabled = isEditing ? expenseToEdit.isSplit : false;
    Set<String> selectedMembers = isEditing ? expenseToEdit.splitWith.toSet() : {};
    
    // Track if split settings have been modified (for warning when editing)
    bool splitModified = false;
    final originalIsSplit = isEditing ? expenseToEdit.isSplit : false;
    final originalMembers = isEditing ? expenseToEdit.splitWith.toSet() : <String>{};

    // Use centralized category service for all categories (manual + custom)
    // Filter out specific categories not relevant for family budgets
    final excludedCategories = ['Healthcare', 'Utilities', 'Home & Garden', 'Education', 'Travel'];
    final categories = CategoryService.manualExpenseCategories
        .where((category) => !excludedCategories.contains(category))
        .toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
           insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
           contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          title: Text(isEditing ? 'Edit Expense' : 'Add Expense'),
           content: SizedBox(
             width: MediaQuery.of(context).size.width - 72, // Screen width minus padding and margins
             child: ConstrainedBox(
               constraints: BoxConstraints(
                 maxHeight: MediaQuery.of(context).size.height * 0.6,
               ),
               child: SingleChildScrollView(
                 child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Expense Title',
                  hintText: 'e.g., Dinner at Restaurant',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Simple category selector for dialogs
              InkWell(
                onTap: () async {
                  final selected = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Select Category'),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            final categoryInfo = CategoryService.getCategoryInfo(category);
                            final isSelected = selectedCategory == category;
                            
                            return ListTile(
                              leading: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: (categoryInfo?.color ?? Colors.grey).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  categoryInfo?.icon ?? Icons.category,
                                  color: categoryInfo?.color ?? Colors.grey,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                category,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? Colors.blue.shade700 : Colors.grey.shade800,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle, color: Colors.blue.shade600)
                                  : null,
                              selected: isSelected,
                              onTap: () => Navigator.of(context).pop(category),
                            );
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  );
                  if (selected != null) {
                    setState(() => selectedCategory = selected);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.category, color: Colors.grey.shade600, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Category',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selectedCategory ?? 'Select a category',
                              style: TextStyle(
                                fontSize: 16,
                                color: selectedCategory != null
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade500,
                                fontWeight: selectedCategory != null
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
              ),
              
              // SPLIT EXPENSE SECTION
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
                
                // Split Toggle with beautiful design
                Container(
                  decoration: BoxDecoration(
                    color: isSplitEnabled ? const Color(0xFF4facfe).withOpacity(0.08) : Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSplitEnabled ? const Color(0xFF4facfe).withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: SwitchListTile(
                    title: Row(
                      children: [
                        Icon(
                          Icons.people_alt,
                          color: isSplitEnabled ? const Color(0xFF4facfe) : Colors.grey[600],
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Split Expense',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isSplitEnabled ? const Color(0xFF4facfe) : Colors.black87,
                              ),
                            ),
                            Text(
                              isSplitEnabled ? 'Equally among selected members' : 'Tap to enable',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    value: isSplitEnabled,
                    activeColor: const Color(0xFF4facfe),
                    onChanged: (value) async {
                      if (value) {
                        // Check if this is a modification during editing
                        final isModifyingSplit = isEditing && !originalIsSplit;
                        
                        // Show appropriate warning
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isModifyingSplit ? 'Expense Will Be Recreated' : 'Important',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isModifyingSplit) ...[
                                  const Text(
                                    'Changing split settings will:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildWarningItem('Delete the current expense'),
                                  _buildWarningItem('Create a new expense with split enabled'),
                                  _buildWarningItem('Reset all settlement tracking'),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'This prevents data corruption. All members will be notified of the change.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  const Text(
                                    'Once you enable split expense, you cannot change split settings later.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'You can still edit amount, title, category, and description.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isModifyingSplit ? Colors.orange : const Color(0xFF4facfe),
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(isModifyingSplit ? 'Continue' : 'I Understand'),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirmed == true) {
                          setState(() {
                            isSplitEnabled = true;
                            // Auto-select all members when enabling split
                            selectedMembers = budget.members.map((m) => m.userId).toSet();
                            if (isModifyingSplit) splitModified = true;
                          });
                        }
                      } else {
                        // Disabling split - check if we're modifying existing split
                        if (isEditing && originalIsSplit) {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Expense Will Be Recreated',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              content: const Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Disabling split will delete the current expense and create a new one without split.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'All settlement tracking will be lost.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Continue'),
                                ),
                              ],
                            ),
                          );
                          
                          if (confirmed == true) {
                            setState(() {
                              isSplitEnabled = false;
                              selectedMembers.clear();
                              splitModified = true;
                            });
                          }
                        } else {
                          setState(() {
                            isSplitEnabled = false;
                            selectedMembers.clear();
                          });
                        }
                      }
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              
              // Member Selection (shown when split is enabled)
              if (isSplitEnabled) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4facfe).withOpacity(0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF4facfe).withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Split with:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (selectedMembers.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4facfe).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${selectedMembers.length}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4facfe),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.18,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: budget.members.map((member) {
                        final isSelected = selectedMembers.contains(member.userId);
                        final amount = double.tryParse(amountController.text) ?? 0.0;
                        final shareAmount = selectedMembers.isNotEmpty ? amount / selectedMembers.length : 0.0;
                        
                        return InkWell(
                          onTap: () async {
                            // Check if modifying members during editing
                            if (isEditing && originalIsSplit && selectedMembers != originalMembers) {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Changing Members?',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: const Text(
                                    'Changing who is in the split will delete the current expense and create a new one. All settlement tracking will be reset.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Continue'),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (confirmed == true) {
                                setState(() {
                                  if (isSelected) {
                                    selectedMembers.remove(member.userId);
                                  } else {
                                    selectedMembers.add(member.userId);
                                  }
                                  splitModified = true;
                                });
                              }
                            } else {
                              setState(() {
                                if (isSelected) {
                                  selectedMembers.remove(member.userId);
                                } else {
                                  selectedMembers.add(member.userId);
                                }
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF4facfe).withOpacity(0.08) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF4facfe).withOpacity(0.3) : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Checkbox
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: Checkbox(
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          selectedMembers.add(member.userId);
                                        } else {
                                          selectedMembers.remove(member.userId);
                                        }
                                      });
                                    },
                                    activeColor: const Color(0xFF4facfe),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Avatar - smaller
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getAvatarColor(member.name),
                                  ),
                                  child: Center(
                                    child: Text(
                                      member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Name and share - single line
                                Expanded(
                                  child: Text(
                                    member.name + (isSelected && shareAmount > 0 ? ' • \$${shareAmount.toStringAsFixed(2)}' : ''),
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      fontSize: 12,
                                      color: isSelected ? const Color(0xFF4facfe) : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
          ),
          ),
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);

                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                  return;
                }

                if (selectedCategory == null || selectedCategory!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a category')),
                  );
                  return;
                }

                // Validate split (if enabled)
                if (isSplitEnabled && selectedMembers.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select at least one member to split with')),
                  );
                  return;
                }

                Navigator.pop(context);

                final bool success;
                if (isEditing && splitModified) {
                  // Split was modified - delete old and create new
                  // First delete the old expense
                  final deleteSuccess = await BudgetCollaborationService.deleteExpense(
                    budgetId: budget.id,
                    expenseId: expenseToEdit.id,
                  );
                  
                  if (deleteSuccess) {
                    // Create new expense with updated split settings
                    success = await BudgetCollaborationService.addExpense(
                      budgetId: budget.id,
                      amount: amount,
                      category: selectedCategory!,
                      title: titleController.text.trim().isNotEmpty ? titleController.text.trim() : null,
                      description: descriptionController.text.trim().isNotEmpty ? descriptionController.text.trim() : null,
                      isSplit: isSplitEnabled,
                      splitWith: isSplitEnabled ? selectedMembers.toList() : null,
                    );
                  } else {
                    success = false;
                  }
                } else if (isEditing) {
                  // Normal update (split not modified)
                  success = await BudgetCollaborationService.updateExpense(
                    budgetId: budget.id,
                    expenseId: expenseToEdit.id,
                    amount: amount,
                    category: selectedCategory!,
                    title: titleController.text.trim().isNotEmpty ? titleController.text.trim() : null,
                    description: descriptionController.text.trim().isNotEmpty ? descriptionController.text.trim() : null,
                  );
                } else {
                  // Add new expense
                  success = await BudgetCollaborationService.addExpense(
                    budgetId: budget.id,
                    amount: amount,
                    category: selectedCategory!,
                    title: titleController.text.trim().isNotEmpty ? titleController.text.trim() : null,
                    description: descriptionController.text.trim().isNotEmpty ? descriptionController.text.trim() : null,
                    isSplit: isSplitEnabled,
                    splitWith: isSplitEnabled ? selectedMembers.toList() : null,
                  );
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(
                            success ? Icons.check_circle : Icons.error,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              success 
                                ? (isEditing 
                                    ? (splitModified ? 'Expense recreated with new split!' : 'Expense updated!') 
                                    : (isSplitEnabled ? 'Expense added and split!' : 'Expense added!'))
                                : (isEditing 
                                    ? (splitModified ? 'Failed to recreate expense' : 'Failed to update expense') 
                                    : 'Failed to add expense'),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16213e),
                foregroundColor: Colors.white,
              ),
              child: Text(isEditing ? 'Save Changes' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExpenseDetailsDialog(BuildContext context, MemberExpense expense) {
    final isOwner = budget.ownerId == FirebaseAuth.instance.currentUser?.uid;
    final isExpenseOwner = expense.userId == FirebaseAuth.instance.currentUser?.uid;
    final categoryInfo = CategoryService.getCategoryInfo(expense.category);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (categoryInfo?.color ?? Colors.grey).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                categoryInfo?.icon ?? Icons.shopping_bag,
                color: categoryInfo?.color ?? const Color(0xFF4A90E2),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Expense Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title (if exists)
              if (expense.title != null && expense.title!.isNotEmpty) ...[
                _buildDetailRow(
                  icon: Icons.title,
                  label: 'Title',
                  value: expense.title!,
                  color: const Color(0xFF4A90E2),
                ),
                const SizedBox(height: 12),
              ],
              
              // Category
              _buildDetailRow(
                icon: Icons.category,
                label: 'Category',
                value: expense.category,
                color: categoryInfo?.color ?? Colors.grey,
              ),
              const SizedBox(height: 12),
              
              // Amount
              _buildDetailRow(
                icon: Icons.attach_money,
                label: 'Amount',
                value: '\$${expense.amount.toStringAsFixed(2)}',
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              
              // Added by
              _buildDetailRow(
                icon: Icons.person,
                label: 'Added by',
                value: expense.userName,
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              
              // Date
              _buildDetailRow(
                icon: Icons.calendar_today,
                label: 'Date',
                value: _formatDate(expense.date),
                color: Colors.orange,
              ),
              
              // Description/Note
              if (expense.description != null && expense.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.note,
                      size: 18,
                      color: Colors.amber[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Note',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    expense.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              
              // Split Information
              if (expense.isSplit && expense.splitWith.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.people_alt,
                      size: 18,
                      color: Color(0xFF4facfe),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Split Between ${expense.splitCount} Members',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4facfe).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4facfe).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...expense.splitWith.map((userId) {
                        final member = budget.members.firstWhere(
                          (m) => m.userId == userId,
                          orElse: () => BudgetMember(
                            userId: userId,
                            name: 'Unknown',
                            role: 'member',
                            joinedAt: DateTime.now(),
                          ),
                        );
                        final share = expense.getShareForUser(userId);
                        final isSettled = expense.hasUserSettled(userId);
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _getAvatarColor(member.name),
                                ),
                                child: Center(
                                  child: Text(
                                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '\$${share.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSettled 
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSettled ? Icons.check_circle : Icons.pending,
                                      size: 12,
                                      color: isSettled ? Colors.green : Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isSettled ? 'Paid' : 'Pending',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSettled ? Colors.green : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (isExpenseOwner)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showAddExpenseDialog(context, expenseToEdit: expense);
              },
              icon: const Icon(Icons.edit, color: Color(0xFF4A90E2)),
              label: const Text(
                'Edit',
                style: TextStyle(color: Color(0xFF4A90E2)),
              ),
            ),
          if (isExpenseOwner || isOwner)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _confirmDeleteExpense(context, expense);
              },
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              Icons.close,
              size: 16,
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmDeleteExpense(BuildContext context, MemberExpense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Delete Expense?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this expense? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final success = await BudgetCollaborationService.deleteExpense(
                budgetId: budget.id,
                expenseId: expense.id,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          success ? Icons.check_circle : Icons.error,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(success ? 'Expense deleted!' : 'Failed to delete expense'),
                      ],
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showBudgetSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.code, color: Color(0xFF16213e)),
              title: const Text('View Invite Code'),
              onTap: () {
                Navigator.pop(context);
                _showInviteCode(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF16213e)),
              title: const Text('Edit Budget Amount'),
              onTap: () {
                Navigator.pop(context);
                _showEditBudgetDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.orange),
              title: const Text('Leave Budget'),
              onTap: () {
                Navigator.pop(context);
                _confirmLeave(context);
              },
            ),
            if (budget.ownerId == FirebaseAuth.instance.currentUser?.uid)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Budget'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showInviteCode(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_2, color: Color(0xFF4A90E2), size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Invite Code',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share this code to invite family members:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4A90E2).withOpacity(0.15),
                    const Color(0xFF4A90E2).withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF4A90E2).withOpacity(0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A90E2).withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
              ),
                ],
              ),
              child: Center(
              child: Text(
                budget.inviteCode ?? 'N/A',
                style: const TextStyle(
                    fontSize: 38,
                  fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: Color(0xFF4A90E2),
                ),
              ),
            ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: budget.inviteCode ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Code copied to clipboard!'),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.copy, size: 20),
                    label: const Text('Copy Code'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                  onPressed: () {
                    Share.share(
                        'Join our "${budget.name}" budget on SmartReceipt! 💰\n\n'
                        'Use invite code: ${budget.inviteCode}\n\n'
                        'Download the app and go to Profile > Family Budgets > Join Budget',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4A90E2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: const Color(0xFF4A90E2).withOpacity(0.4), width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.share, size: 20),
                  label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[100],
                foregroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSimpleInviteCode(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.qr_code_2,
                      color: Color(0xFF4A90E2),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Invite Code',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Code Display
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4A90E2).withOpacity(0.1),
                      const Color(0xFF4A90E2).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4A90E2).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    budget.inviteCode ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: Color(0xFF4A90E2),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Copy Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: budget.inviteCode ?? ''));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Code copied!'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
            ),
                  ),
                  icon: const Icon(Icons.copy, size: 20),
                  label: const Text('Copy Code', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
          ),
        ],
          ),
        ),
      ),
    );
  }

  void _showEditBudgetDialog(BuildContext context) {
    final controller = TextEditingController(text: budget.amount.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Budget Amount'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Monthly Amount',
            prefixText: '\$ ',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context);
                final success = await BudgetCollaborationService.updateBudgetAmount(
                  budgetId: budget.id,
                  newAmount: amount,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Budget updated!' : 'Failed to update'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16213e),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmLeave(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Budget?'),
        content: const Text('Are you sure you want to leave this shared budget?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to list
              await BudgetCollaborationService.leaveSharedBudget(budget.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Budget?'),
        content: const Text(
          'This will permanently delete the budget and all expenses for all members.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to list
              await BudgetCollaborationService.deleteSharedBudget(budget.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _navigateToSettlementTracker(BuildContext context, List<MemberExpense> expenses) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettlementTrackerPage(
          budget: budget,
          expenses: expenses,
        ),
      ),
    );
  }

  int _getPendingSettlementsCount(List<MemberExpense> expenses) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return 0;

    int count = 0;
    for (final expense in expenses) {
      if (!expense.isSplit || expense.splitWith.isEmpty) continue;

      // Count if current user owes money (is in split but not the payer and not settled)
      if (expense.userId != currentUserId && 
          expense.splitWith.contains(currentUserId) &&
          !expense.hasUserSettled(currentUserId)) {
        count++;
      }
    }
    return count;
  }
}

