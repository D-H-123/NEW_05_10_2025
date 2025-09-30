import 'package:flutter/material.dart';
import 'package:smart_receipt/core/widgets/subscription_status_card.dart';
import 'package:smart_receipt/core/widgets/subscription_reminder_settings.dart';

/// Example showing how to integrate subscription reminder widgets
/// into your existing home page or other screens
class SubscriptionIntegrationExample extends StatelessWidget {
  const SubscriptionIntegrationExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          // Add notification settings button to app bar
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionReminderSettings(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Add subscription status card at the top
          const SubscriptionStatusCard(),
          
          // Your existing home content goes here
          Expanded(
            child: ListView(
              children: [
                // Example: Add compact status card in a list
                const CompactSubscriptionStatusCard(),
                
                // Your existing content...
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.receipt),
                    title: Text('Recent Receipts'),
                    subtitle: Text('View your scanned receipts'),
                  ),
                ),
                
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.camera_alt),
                    title: Text('Scan Receipt'),
                    subtitle: Text('Capture a new receipt'),
                  ),
                ),
                
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.analytics),
                    title: Text('Analytics'),
                    subtitle: Text('View spending insights'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Example of how to add subscription status to a drawer
class SubscriptionDrawerExample extends StatelessWidget {
  const SubscriptionDrawerExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 48,
                ),
                SizedBox(height: 8),
                Text(
                  'SmartReceipt',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Add compact subscription status in drawer
          const CompactSubscriptionStatusCard(),
          
          const ListTile(
            leading: Icon(Icons.home),
            title: Text('Home'),
          ),
          
          const ListTile(
            leading: Icon(Icons.receipt),
            title: Text('Receipts'),
          ),
          
          const ListTile(
            leading: Icon(Icons.analytics),
            title: Text('Analytics'),
          ),
          
          const ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
          ),
          
          // Add notification settings in drawer
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notification Settings'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionReminderSettings(),
                ),
              );
            },
          ),
          
          const ListTile(
            leading: Icon(Icons.help),
            title: Text('Help & Support'),
          ),
        ],
      ),
    );
  }
}

/// Example of how to show subscription status in a bottom sheet
class SubscriptionBottomSheetExample extends StatelessWidget {
  const SubscriptionBottomSheetExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Info'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => DraggableScrollableSheet(
                initialChildSize: 0.6,
                minChildSize: 0.3,
                maxChildSize: 0.9,
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Handle bar
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        
                        // Subscription status card
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: SubscriptionStatusCard(),
                        ),
                        
                        // Scrollable content
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            children: [
                              const Text(
                                'Subscription Details',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              const Card(
                                child: ListTile(
                                  leading: Icon(Icons.notifications),
                                  title: Text('Notification Settings'),
                                  subtitle: Text('Manage your reminder preferences'),
                                  trailing: Icon(Icons.arrow_forward_ios),
                                ),
                              ),
                              
                              const Card(
                                child: ListTile(
                                  leading: Icon(Icons.payment),
                                  title: Text('Billing'),
                                  subtitle: Text('View billing history and payment methods'),
                                  trailing: Icon(Icons.arrow_forward_ios),
                                ),
                              ),
                              
                              const Card(
                                child: ListTile(
                                  leading: Icon(Icons.help),
                                  title: Text('Support'),
                                  subtitle: Text('Get help with your subscription'),
                                  trailing: Icon(Icons.arrow_forward_ios),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
          child: const Text('Show Subscription Info'),
        ),
      ),
    );
  }
}
