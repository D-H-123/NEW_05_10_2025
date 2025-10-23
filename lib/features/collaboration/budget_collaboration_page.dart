import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/shared_budget.dart';
import '../../core/services/budget_collaboration_service.dart';
import '../../core/services/premium_service.dart';
import '../../core/services/category_service.dart';
import '../../core/widgets/subscription_paywall.dart';

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
    final isOwner = budget.ownerId == FirebaseAuth.instance.currentUser?.uid;
    
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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF16213e), Color(0xFF1a2947)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
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

                // Invite Code Button (for owners and easy sharing)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: ElevatedButton.icon(
                    onPressed: () => _showInviteCode(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4A90E2),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: const Color(0xFF4A90E2).withOpacity(0.3), width: 2),
                      ),
                      shadowColor: const Color(0xFF4A90E2).withOpacity(0.2),
                    ),
                    icon: const Icon(Icons.qr_code_2, size: 24),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isOwner ? 'Share Invite Code' : 'View Invite Code',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Invite family members to join',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90E2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.arrow_forward, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

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
                                    color: Colors.grey.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.withOpacity(0.1),
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
                                                    expense.category,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (hasNote) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(
                                                        color: Colors.amber.withOpacity(0.3),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.note,
                                                          size: 11,
                                                          color: Colors.amber[700],
                                                        ),
                                                        const SizedBox(width: 2),
                                                        Text(
                                                          'Note',
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.amber[700],
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
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Color(0xFF16213e),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Icon(
                                            Icons.chevron_right,
                                            size: 16,
                                            color: Colors.grey[400],
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

  void _showAddExpenseDialog(BuildContext context) {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedCategory;

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
          title: const Text('Add Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
            ],
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

                Navigator.pop(context);

                final success = await BudgetCollaborationService.addExpense(
                  budgetId: budget.id,
                  amount: amount,
                  category: selectedCategory!,
                  description: descriptionController.text.trim(),
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? 'Expense added!' : 'Failed to add expense',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16213e),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
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
            ],
          ),
        ),
        actions: [
          if (isExpenseOwner)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showEditExpenseDialog(context, expense);
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

  void _showEditExpenseDialog(BuildContext context, MemberExpense expense) {
    final amountController = TextEditingController(text: expense.amount.toStringAsFixed(2));
    final descriptionController = TextEditingController(text: expense.description ?? '');
    String selectedCategory = expense.category;

    // Filter out specific categories not relevant for family budgets
    final excludedCategories = ['Healthcare', 'Utilities', 'Home & Garden', 'Education', 'Travel'];
    final categories = CategoryService.manualExpenseCategories
        .where((category) => !excludedCategories.contains(category))
        .toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: Color(0xFF4A90E2), size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Edit Expense',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Amount field
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Category selector
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
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              CategoryService.getCategoryInfo(selectedCategory)?.icon ?? Icons.category,
                              color: CategoryService.getCategoryInfo(selectedCategory)?.color ?? Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              selectedCategory,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Description field
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
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

                Navigator.pop(context);

                final success = await BudgetCollaborationService.updateExpense(
                  budgetId: budget.id,
                  expenseId: expense.id,
                  amount: amount,
                  category: selectedCategory,
                  description: descriptionController.text.trim().isEmpty 
                      ? null 
                      : descriptionController.text.trim(),
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
                          Text(success ? 'Expense updated!' : 'Failed to update expense'),
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
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
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
}

