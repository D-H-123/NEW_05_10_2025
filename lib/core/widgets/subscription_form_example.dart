import 'package:flutter/material.dart';
import 'package:smart_receipt/core/services/premium_service.dart';

/// Example subscription form that matches the UI shown in the image
class SubscriptionFormExample extends StatefulWidget {
  const SubscriptionFormExample({super.key});

  @override
  State<SubscriptionFormExample> createState() => _SubscriptionFormExampleState();
}

class _SubscriptionFormExampleState extends State<SubscriptionFormExample> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedFrequency = 'Monthly';
  bool _setEndDate = false;
  DateTime? _endDate;
  final TextEditingController _notesController = TextEditingController();

  final List<String> _frequencies = [
    'Weekly',
    'Monthly', 
    'Quarterly',
    'Yearly',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Subscription'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subscription Name Field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Subscription Name',
                hintText: 'Enter subscription name',
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Frequency Dropdown
            DropdownButtonFormField<String>(
              value: _selectedFrequency,
              decoration: const InputDecoration(
                labelText: 'Frequency',
                border: OutlineInputBorder(),
              ),
              items: _frequencies.map((String frequency) {
                return DropdownMenuItem<String>(
                  value: frequency,
                  child: Text(frequency),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedFrequency = newValue!;
                });
              },
            ),
            
            const SizedBox(height: 20),
            
            // Set End Date Checkbox
            CheckboxListTile(
              title: const Text('Set End Date'),
              value: _setEndDate,
              onChanged: (bool? value) {
                setState(() {
                  _setEndDate = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            
            // End Date Picker (shown when checkbox is checked)
            if (_setEndDate) ...[
              const SizedBox(height: 10),
              ListTile(
                title: Text(_endDate == null 
                    ? 'Select End Date' 
                    : 'End Date: ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (date != null) {
                    setState(() {
                      _endDate = date;
                    });
                  }
                },
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Notes Field
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Add any additional notes...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Reminder Information Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reminder Schedule',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getReminderInfo(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveSubscription,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Save Subscription'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getReminderInfo() {
    switch (_selectedFrequency.toLowerCase()) {
      case 'weekly':
        return 'You\'ll receive reminders 3 days, 1 day, and 6 hours before renewal.';
      case 'monthly':
        return 'You\'ll receive reminders 7, 3, and 1 day before renewal.';
      case 'quarterly':
        return 'You\'ll receive reminders 14, 7, 3, and 1 day before renewal.';
      case 'yearly':
        return 'You\'ll receive reminders 30, 14, 7, and 3 days before renewal.';
      default:
        return 'Reminder schedule will be set based on your subscription frequency.';
    }
  }

  void _saveSubscription() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a subscription name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Here you would typically save the subscription to your database
    // For now, we'll just show a success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_nameController.text} subscription saved!'),
        backgroundColor: Colors.green,
      ),
    );

    // Navigate back
    Navigator.pop(context);
  }
}

/// Example of how to show subscription frequency options in a grid
class SubscriptionFrequencyGrid extends StatelessWidget {
  final String selectedFrequency;
  final Function(String) onFrequencySelected;

  const SubscriptionFrequencyGrid({
    super.key,
    required this.selectedFrequency,
    required this.onFrequencySelected,
  });

  @override
  Widget build(BuildContext context) {
    final frequencies = [
      {'name': 'Weekly', 'icon': Icons.calendar_view_week, 'color': Colors.blue},
      {'name': 'Monthly', 'icon': Icons.calendar_view_month, 'color': Colors.green},
      {'name': 'Quarterly', 'icon': Icons.calendar_view_day, 'color': Colors.orange},
      {'name': 'Yearly', 'icon': Icons.calendar_today, 'color': Colors.purple},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: frequencies.length,
      itemBuilder: (context, index) {
        final frequency = frequencies[index];
        final isSelected = selectedFrequency == frequency['name'];
        
        return GestureDetector(
          onTap: () => onFrequencySelected(frequency['name'] as String),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected 
                  ? (frequency['color'] as Color).withOpacity(0.1)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? frequency['color'] as Color
                    : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  frequency['icon'] as IconData,
                  color: isSelected 
                      ? frequency['color'] as Color
                      : Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  frequency['name'] as String,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected 
                        ? frequency['color'] as Color
                        : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
