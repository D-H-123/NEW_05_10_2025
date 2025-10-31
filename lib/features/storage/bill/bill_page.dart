import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'bill_provider.dart';
import '../../../core/widgets/modern_widgets.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/category_service.dart';
import '../../../core/services/premium_service.dart';
import '../../../core/widgets/subscription_paywall.dart';
import '../../../core/services/subscription_utils.dart';
import '../../../core/services/personal_subscription_reminder_service.dart';
import '../../../core/widgets/filter_dropdown.dart';
import '../../../core/widgets/subscription_badge.dart';
import '../../../core/widgets/brand_icon_widget.dart';
import '../../../core/widgets/category_chip_selector.dart';
import '../../home/dynamic_expense_modal.dart';
import '../models/bill_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/budget_collaboration_service.dart';

class BillsPage extends ConsumerStatefulWidget {
  const BillsPage({super.key});

  @override
  ConsumerState<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends ConsumerState<BillsPage> {
  String _searchQuery = '';
  String _sortBy = 'date_desc'; // date_desc, date_asc, name_asc, name_desc, total_desc, total_asc
  String? _selectedYear;
  String? _selectedMonth;
  int _selectedIndex = 3; // Storage tab is selected
  String _selectedCategory = 'all'; // all, manual, subscription, sepa, scanned
  String _selectedLocation = 'all'; // all, or specific location
  String _selectedSource = 'all'; // all, scanned, manual
  String _selectedCategoryFilter = 'all'; // all, or specific category
  List<String> _selectedCategories = []; // For multi-select categories
  
  // Calendar view state
  String _viewMode = 'list'; // 'list' or 'calendar'
  DateTime _selectedCalendarDate = DateTime.now();
  DateTime _currentCalendarMonth = DateTime.now();
  bool _isCalendarIntegrationEnabled = false;
  bool _isLocationFilterEnabled = false;
  bool _showSharedExpenses = false;

  @override
  void initState() {
    super.initState();
    _isCalendarIntegrationEnabled = LocalStorageService.getBoolSetting(LocalStorageService.kCalendarResults);
    _isLocationFilterEnabled = LocalStorageService.getBoolSetting(LocalStorageService.kLocation);
    _showSharedExpenses = LocalStorageService.getBoolSetting(LocalStorageService.kShowSharedExpenses, defaultValue: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh settings when returning to this page
    _isCalendarIntegrationEnabled = LocalStorageService.getBoolSetting(LocalStorageService.kCalendarResults);
    _isLocationFilterEnabled = LocalStorageService.getBoolSetting(LocalStorageService.kLocation);
    _showSharedExpenses = LocalStorageService.getBoolSetting(LocalStorageService.kShowSharedExpenses, defaultValue: false);
  }

  void _showBillOptions(BuildContext context, dynamic bill) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              bill.title?.isNotEmpty == true ? bill.title! : (bill.vendor ?? 'Receipt Options'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            
            // Edit Option
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF4facfe).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit,
                  color: Color(0xFF4facfe),
                ),
              ),
              title: const Text(
                'Edit Receipt',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Modify receipt details'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to appropriate edit page based on bill source
                _navigateToEditPage(bill);
              },
            ),
            
            // Delete Option
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
              ),
              title: const Text(
                'Delete Receipt',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Remove from storage'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, bill);
              },
            ),
            
            // Share Option
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.share,
                  color: Colors.blue,
                ),
              ),
              title: const Text(
                'Export & Share',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Export as PDF or share via email'),
              onTap: () {
                Navigator.pop(context);
                if (PremiumService.isExportAvailable) {
                  _showExportOptions(context, bill);
                } else {
                  _showUpgradePrompt();
                }
              },
            ),
            
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, dynamic bill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Receipt',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${(bill.title?.isNotEmpty == true ? bill.title! : bill.vendor) ?? 'this receipt'}"? This action cannot be undone.',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteBill(bill);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteBill(dynamic bill) {
    // Remove the bill from your provider/database
    ref.read(billProvider.notifier).deleteBill(bill.id);
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${(bill.title?.isNotEmpty == true ? bill.title! : bill.vendor) ?? 'Receipt'} deleted successfully'
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _updateSubscriptionFrequency(dynamic bill, String newFrequency) async {
    // Update the subscription frequency in your provider/database
    ref.read(billProvider.notifier).updateBillSubscriptionFrequency(bill.id, newFrequency);
    
    // Update the bill object with new frequency
    final updatedBill = Bill(
      id: bill.id,
      imagePath: bill.imagePath,
      vendor: bill.vendor,
      date: bill.date,
      total: bill.total,
      ocrText: bill.ocrText,
      categoryId: bill.categoryId,
      currency: bill.currency,
      subtotal: bill.subtotal,
      tax: bill.tax,
      notes: bill.notes,
      tags: bill.tags,
      location: bill.location,
      title: bill.title,
      subscriptionType: newFrequency,
      subscriptionEndDate: bill.subscriptionEndDate, // Preserve existing end date
      subscriptionStartDate: bill.subscriptionStartDate, // Preserve existing start date
      createdAt: bill.createdAt,
      updatedAt: DateTime.now(),
    );
    
    // Update subscription reminders with new frequency
    try {
      await PersonalSubscriptionReminderService.updateSubscriptionReminders(updatedBill);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Subscription frequency changed to $newFrequency and reminders updated'
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      // Handle permission errors gracefully
      if (e.toString().contains('exact_alarms_not_permitted')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Subscription frequency changed to $newFrequency! Note: Exact alarm permission is required for precise reminders.'
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Subscription frequency changed to $newFrequency! Warning: Could not update reminders - ${e.toString()}'
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _shareBill(dynamic bill) async {
    final String message = '''
Receipt Details:
Title: ${(bill.title?.isNotEmpty == true ? bill.title! : bill.vendor) ?? 'N/A'}
Date: ${DateFormat('MMM dd, yyyy').format(bill.date ?? DateTime.now())}
Total: ${bill.total ?? 0.0} ${bill.currency ?? ''}
OCR Text: ${bill.ocrText}
Tags: ${bill.tags?.join(', ') ?? 'N/A'}
''';

    await Share.share(message);
  }

  void _showUpgradePrompt() {
    showDialog(
      context: context,
      builder: (context) => SubscriptionPaywall(
        title: 'Export Feature',
        subtitle: 'Export receipts as PDF and share via email with Premium!',
        onDismiss: () => Navigator.of(context).pop(),
        showTrialOption: !PremiumService.isTrialActive,
      ),
    );
  }

  void _showExportOptions(BuildContext context, dynamic bill) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Export & Share Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // PDF Export Option
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.picture_as_pdf,
                  color: Colors.red,
                ),
              ),
              title: const Text(
                'Export as PDF',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Generate and save PDF receipt'),
              onTap: () {
                Navigator.pop(context);
                _exportAsPDF(bill);
              },
            ),
            
            // Email Share Option
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.email,
                  color: Colors.blue,
                ),
              ),
              title: const Text(
                'Share via Email',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Open email app with receipt details'),
              onTap: () {
                Navigator.pop(context);
                _shareViaEmail(bill);
              },
            ),
            
            // Simple Share Option
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.share,
                  color: Colors.green,
                ),
              ),
              title: const Text(
                'Share Text',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Share receipt details as text'),
              onTap: () {
                Navigator.pop(context);
                _shareBill(bill);
              },
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAsPDF(dynamic bill) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Create PDF document
      final pdf = pw.Document();
      
      // Add receipt page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue,
                    borderRadius: const pw.BorderRadius.only(
                      bottomLeft: pw.Radius.circular(10),
                      bottomRight: pw.Radius.circular(10),
                    ),
                  ),
                  child: pw.Text(
                    'SmartReceipt',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                
                pw.SizedBox(height: 20),
                
                // Receipt Title
                pw.Center(
                  child: pw.Text(
                    'Receipt Details',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                ),
                
                pw.SizedBox(height: 30),
                
                // Receipt Information
                _buildPDFRow('Title:', (bill.title?.isNotEmpty == true ? bill.title! : bill.vendor) ?? 'N/A'),
                _buildPDFRow('Date:', DateFormat('MMM dd, yyyy').format(bill.date ?? DateTime.now())),
                _buildPDFRow('Total:', '${bill.total ?? 0.0} ${bill.currency ?? ''}'),
                _buildPDFRow('Tags:', bill.tags?.join(', ') ?? 'N/A'),
                if (bill.location?.isNotEmpty == true) _buildPDFRow('Location:', bill.location!),
                if (bill.notes?.isNotEmpty == true) _buildPDFRow('Notes:', bill.notes!),
                
                pw.SizedBox(height: 20),
                
                // OCR Text Section
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'OCR Text:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                                             pw.Text(
                         bill.ocrText ?? 'No OCR text available',
                         style: const pw.TextStyle(
                           fontSize: 12,
                           color: PdfColors.black,
                         ),
                       ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 30),
                
                // Footer
                pw.Center(
                  child: pw.Text(
                    'Generated on ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Save PDF to temporary directory
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/receipt_${bill.id}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Close loading dialog
      Navigator.pop(context);

      // Show success message and share PDF
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF generated successfully!'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Share',
            textColor: Colors.white,
            onPressed: () {
              Share.shareFiles([file.path], text: 'Receipt PDF from SmartReceipt');
            },
          ),
        ),
      );

    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  pw.Widget _buildPDFRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.Expanded(
                         child: pw.Text(
               value,
               style: const pw.TextStyle(
                 fontSize: 14,
                 color: PdfColors.black,
               ),
             ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareViaEmail(dynamic bill) async {
    final subject = 'Receipt: ${(bill.title?.isNotEmpty == true ? bill.title! : bill.vendor) ?? 'Untitled'} - ${bill.total ?? 0.0} ${bill.currency ?? ''}';
    
         final body = '''
 Hello,
 
 Please find the receipt details below:
 
 Title: ${(bill.title?.isNotEmpty == true ? bill.title! : bill.vendor) ?? 'N/A'}
 Date: ${DateFormat('MMM dd, yyyy').format(bill.date ?? DateTime.now())}
 Total: ${bill.total ?? 0.0} ${bill.currency ?? ''}
 Tags: ${bill.tags?.join(', ') ?? 'N/A'}
 Location: ${bill.location ?? 'N/A'}
 Notes: ${bill.notes ?? 'N/A'}
 
 OCR Text:
 ${bill.ocrText ?? 'No OCR text available'}
 
 ---
 Sent from SmartReceipt App
 ''';

    final emailUrl = Uri.parse(
      'mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}'
    );

    try {
      if (await canLaunchUrl(emailUrl)) {
        await launchUrl(emailUrl);
      } else {
        // Fallback to simple share if email app not available
        await Share.share(body, subject: subject);
      }
    } catch (e) {
      // Fallback to simple share if email app not available
      await Share.share(body, subject: subject);
    }
  }



  String _getBillCategory(dynamic bill) {
    // Manual entries from plus button have ocrText = 'Manual entry'
    // Subscription entries have ocrText = 'Subscription entry'
    // Scanned receipts from camera have actual OCR text content (not 'Manual entry' or 'Subscription entry')
    if (bill.ocrText == 'Manual entry' || bill.ocrText == 'Subscription entry') {
      return 'manual'; // Created via plus button form or subscription
    } else if (bill.ocrText != null && bill.ocrText.isNotEmpty && 
               bill.ocrText != 'Manual entry' && bill.ocrText != 'Subscription entry') {
      return 'scanned'; // Has actual OCR text from camera scanning
    } else {
      return 'manual'; // Fallback for any other cases
    }
  }

  /// Format date to show "Today", "Yesterday", or relative time
  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('MMM dd, yyyy').format(date);
  }

  /// Check if we should show brand icon instead of image
  bool _shouldShowBrandIcon(dynamic bill) {
    return bill.ocrText == 'Manual entry' || bill.ocrText == 'Subscription entry';
  }

  /// Get the display name for brand icon
  String _getBrandDisplayName(dynamic bill) {
    return (bill.title?.isNotEmpty == true ? bill.title! : bill.vendor) ?? 'Unknown';
  }

  List<String> _getUniqueLocations(List<dynamic> bills) {
    final locations = <String>{};
    for (final bill in bills) {
      if (bill.location != null && bill.location!.isNotEmpty) {
        locations.add(bill.location!);
      }
    }
    return locations.toList()..sort();
  }

  int _getLocationCount(List<dynamic> bills, String location) {
    if (location == 'all') return bills.length;
    return bills.where((bill) => 
      bill.location?.toLowerCase() == location.toLowerCase()
    ).length;
  }

  List<String> _getUniqueCategories(List<dynamic> bills) {
    final categories = <String>{};
    for (final bill in bills) {
      if (bill.categoryId != null && bill.categoryId!.isNotEmpty) {
        categories.add(bill.categoryId!);
      }
    }
    return categories.toList()..sort();
  }

  int _getCategoryCount(List<dynamic> bills, String category) {
    if (category == 'all') return bills.length;
    return bills.where((bill) => 
      bill.categoryId?.toLowerCase() == category.toLowerCase()
    ).length;
  }

  int _getSourceCount(List<dynamic> bills, String source) {
    if (source == 'all') return bills.length;
    return bills.where((bill) => _getBillCategory(bill) == source).length;
  }

  // Helper methods for category display - now using centralized service
  Color _getCategoryColor(String category) {
    return CategoryService.getCategoryColor(category);
  }

  IconData _getCategoryIcon(String category) {
    return CategoryService.getCategoryIcon(category);
  }

  // Filter item builders for new dropdown
  List<FilterItem> _buildSourceFilterItems(List<dynamic> filteredBills) {
    return [
      FilterItem(
        value: 'all',
        label: 'All Sources',
        icon: Icons.all_inclusive,
        count: _getSourceCount(filteredBills, 'all'),
      ),
      FilterItem(
        value: 'scanned',
        label: 'Scanned',
        icon: Icons.camera_alt,
        count: _getSourceCount(filteredBills, 'scanned'),
      ),
      FilterItem(
        value: 'manual',
        label: 'Manual',
        icon: Icons.edit_note,
        count: _getSourceCount(filteredBills, 'manual'),
      ),
    ];
  }

  List<FilterItem> _buildLocationFilterItems(List<dynamic> filteredBills) {
    final items = <FilterItem>[
      FilterItem(
        value: 'all',
        label: 'All Locations',
        icon: Icons.all_inclusive,
        count: _getLocationCount(filteredBills, 'all'),
      ),
    ];

    // Add unique locations
    for (final location in _getUniqueLocations(filteredBills)) {
      items.add(FilterItem(
        value: location,
        label: location,
        icon: Icons.location_on,
        count: _getLocationCount(filteredBills, location),
      ));
    }

    return items;
  }


  // Responsive Filter Layout
  Widget _buildResponsiveFilterLayout(BuildContext context, List<dynamic> allBills, List<dynamic> filteredBills) {
    final screenWidth = MediaQuery.of(context).size.width;
    final spacing = screenWidth < 360 ? 8.0 : 12.0;
    
    // Get ALL available categories from all bills (not just filtered ones)
    // This ensures all categories remain visible even after selecting some
    final uniqueCategories = _getUniqueCategories(allBills);
    
    // But get counts from filtered bills for accurate counts
    final categoryCounts = <String, int>{};
    for (final category in uniqueCategories) {
      categoryCounts[category] = _getCategoryCount(allBills, category);
    }
    
    // Check if location filter is enabled
    if (_isLocationFilterEnabled) {
      // Use column layout when location is enabled
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First row: Source and Location dropdowns
          Row(
            children: [
              Expanded(
                child: FilterDropdown(
                  selectedValue: _selectedSource,
                  items: _buildSourceFilterItems(allBills),
                  onChanged: (value) {
                    setState(() {
                      _selectedSource = value ?? 'all';
                    });
                  },
                  label: 'Source',
                  icon: Icons.source,
                  showIcons: true,
                  showColors: false,
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: FilterDropdown(
                  selectedValue: _selectedLocation,
                  items: _buildLocationFilterItems(allBills),
                  onChanged: (value) {
                    setState(() {
                      _selectedLocation = value ?? 'all';
                    });
                  },
                  label: 'Location',
                  icon: Icons.location_on,
                  showIcons: true,
                  showColors: false,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing),
          // Category chips (compact horizontal scroll for small screens)
          if (uniqueCategories.isNotEmpty)
            screenWidth < 600
                ? CategoryChipSelector(
                    availableCategories: uniqueCategories,
                    selectedCategories: _selectedCategories,
                    onChanged: (values) {
                      setState(() {
                        _selectedCategories = values;
                        // Update single select for backward compatibility
                        if (_selectedCategories.isEmpty) {
                          _selectedCategoryFilter = 'all';
                        } else if (_selectedCategories.length == 1) {
                          _selectedCategoryFilter = _selectedCategories.first;
                        } else {
                          _selectedCategoryFilter = 'multiple';
                        }
                      });
                    },
                    showCounts: true,
                    categoryCounts: categoryCounts,
                    isCompact: true,
                    label: 'Filter by Category',
                  )
                : ExpandableCategoryChipSelector(
                    availableCategories: uniqueCategories,
                    selectedCategories: _selectedCategories,
                    onChanged: (values) {
                      setState(() {
                        _selectedCategories = values;
                        // Update single select for backward compatibility
                        if (_selectedCategories.isEmpty) {
                          _selectedCategoryFilter = 'all';
                        } else if (_selectedCategories.length == 1) {
                          _selectedCategoryFilter = _selectedCategories.first;
                        } else {
                          _selectedCategoryFilter = 'multiple';
                        }
                      });
                    },
                    showCounts: true,
                    categoryCounts: categoryCounts,
                    initialDisplayCount: 8,
                    label: 'Filter by Category',
                  ),
        ],
      );
    } else {
      // Use layout without location when location is disabled
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source dropdown
          FilterDropdown(
            selectedValue: _selectedSource,
            items: _buildSourceFilterItems(allBills),
            onChanged: (value) {
              setState(() {
                _selectedSource = value ?? 'all';
              });
            },
            label: 'Source',
            icon: Icons.source,
            showIcons: true,
            showColors: false,
          ),
          SizedBox(height: spacing),
          // Category chips (compact horizontal scroll for small screens)
          if (uniqueCategories.isNotEmpty)
            screenWidth < 600
                ? CategoryChipSelector(
                    availableCategories: uniqueCategories,
                    selectedCategories: _selectedCategories,
                    onChanged: (values) {
                      setState(() {
                        _selectedCategories = values;
                        // Update single select for backward compatibility
                        if (_selectedCategories.isEmpty) {
                          _selectedCategoryFilter = 'all';
                        } else if (_selectedCategories.length == 1) {
                          _selectedCategoryFilter = _selectedCategories.first;
                        } else {
                          _selectedCategoryFilter = 'multiple';
                        }
                      });
                    },
                    showCounts: true,
                    categoryCounts: categoryCounts,
                    isCompact: true,
                    label: 'Filter by Category',
                  )
                : ExpandableCategoryChipSelector(
                    availableCategories: uniqueCategories,
                    selectedCategories: _selectedCategories,
                    onChanged: (values) {
                      setState(() {
                        _selectedCategories = values;
                        // Update single select for backward compatibility
                        if (_selectedCategories.isEmpty) {
                          _selectedCategoryFilter = 'all';
                        } else if (_selectedCategories.length == 1) {
                          _selectedCategoryFilter = _selectedCategories.first;
                        } else {
                          _selectedCategoryFilter = 'multiple';
                        }
                      });
                    },
                    showCounts: true,
                    categoryCounts: categoryCounts,
                    initialDisplayCount: 8,
                    label: 'Filter by Category',
                  ),
        ],
      );
    }
  }



  Widget _buildEmptyState() {
    // Show different empty state based on selected category
    if (_selectedCategory == 'manual') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Empty manual entries icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit_note,
                  size: 60,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              
              // Main message
              const Text(
                'No manual entries yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Subtitle message
              Text(
                'Create manual expenses or subscriptions\nusing the plus button on the homepage.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Call to action button - go to home to use plus button
              ElevatedButton.icon(
                onPressed: () {
                  context.go('/home'); // Navigate to home to use plus button
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Create Manual Entry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4facfe),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_selectedCategory == 'scanned') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Empty scanned receipts icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: 60,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              
              // Main message
              const Text(
                'No scanned receipts yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Subtitle message
              Text(
                'Start scanning receipts to see them here.\nAll your scanned receipts will be organized by date.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Call to action button - scan receipts
              ElevatedButton.icon(
                onPressed: () {
                  context.go('/scan'); // Navigate to camera/scan page
                },
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: const Text(
                  'Scan Your First Receipt',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4facfe),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Default empty state for "All" tab
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Empty folder icon with circular background
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.folder_open_rounded,
                  size: 60,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              
              // Main message
              const Text(
                'No receipts saved yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Subtitle message
              Text(
                'Start scanning receipts or create manual entries\nto see them organized here.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Call to action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      context.go('/scan'); // Navigate to camera/scan page
                    },
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text(
                      'Scan Receipt',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4facfe),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.go('/home'); // Navigate to home to use plus button
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Manual Entry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bills = ref.watch(billProvider);
    
    // Filter bills based on search query, source, location, and category
    final filteredBills = bills.where((bill) {
      // First filter by source (scanned/manual)
      if (_selectedSource != 'all') {
        final billSource = _getBillCategory(bill);
        if (billSource != _selectedSource) {
          return false;
        }
      }
      
      // Then filter by location (if location filtering is enabled)
      if (_isLocationFilterEnabled && _selectedLocation != 'all') {
        final billLocation = bill.location?.toLowerCase() ?? '';
        if (billLocation != _selectedLocation.toLowerCase()) {
          return false;
        }
      }
      
      // Then filter by category (support both single and multi-select)
      if (_selectedCategoryFilter != 'all') {
        final billCategory = bill.categoryId?.toLowerCase() ?? '';
        
        // Handle multi-select categories
        if (_selectedCategories.isNotEmpty) {
          if (!_selectedCategories.any((cat) => cat.toLowerCase() == billCategory)) {
            return false;
          }
        } else {
          // Handle single select
          if (billCategory != _selectedCategoryFilter.toLowerCase()) {
            return false;
          }
        }
      }
      
      // Finally filter by search query
       final query = _searchQuery.toLowerCase();
      return ((bill.title ?? bill.vendor)?.toLowerCase().contains(query) ?? false) ||
              (bill.tags?.any((tag) => tag.toLowerCase().contains(query)) ?? false);
    }).toList();

    // Sort bills
    switch (_sortBy) {
      case 'date_desc':
        filteredBills.sort((a, b) => (b.date ?? DateTime.now()).compareTo(a.date ?? DateTime.now()));
        break;
      case 'date_asc':
        filteredBills.sort((a, b) => (a.date ?? DateTime.now()).compareTo(b.date ?? DateTime.now()));
        break;
      case 'name_asc':
        filteredBills.sort((a, b) => ((a.title ?? a.vendor) ?? '').compareTo((b.title ?? b.vendor) ?? ''));
        break;
      case 'name_desc':
        filteredBills.sort((a, b) => ((b.title ?? b.vendor) ?? '').compareTo((a.title ?? a.vendor) ?? ''));
        break;
      case 'total_desc':
        filteredBills.sort((a, b) => (b.total ?? 0.0).compareTo(a.total ?? 0.0));
        break;
      case 'total_asc':
        filteredBills.sort((a, b) => (a.total ?? 0.0).compareTo(b.total ?? 0.0));
        break;
    }

    // Group bills by year and month, then by category
    final Map<String, Map<String, Map<String, List<dynamic>>>> groupedBills = {};
    for (final bill in filteredBills) {
      final year = DateFormat('yyyy').format(bill.date ?? DateTime.now());
      final month = DateFormat('MMMM yyyy').format(bill.date ?? DateTime.now());
      final category = bill.tags?.isNotEmpty == true ? bill.tags!.first : 'Other';
      
      if (!groupedBills.containsKey(year)) {
        groupedBills[year] = {};
      }
      if (!groupedBills[year]!.containsKey(month)) {
        groupedBills[year]![month] = {};
      }
      if (!groupedBills[year]![month]!.containsKey(category)) {
        groupedBills[year]![month]![category] = [];
      }
      groupedBills[year]![month]![category]!.add(bill);
    }

    // Sort years and months
    final sortedYears = groupedBills.keys.toList()..sort((a, b) => b.compareTo(a));
    
    // Compute subscription remaining days label
    final DateTime? subStart = PremiumService.subscriptionStartDate;
    final String subType = PremiumService.subscriptionType;
    final int totalCycleDays = SubscriptionUtils.getCycleDays(subType);
    final int remainingDays = (subStart != null && totalCycleDays > 0)
        ? SubscriptionUtils.getRemainingDays(subStart, subType)
        : 0;
    final bool showRemainingLabel = subStart != null && totalCycleDays > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'My Bills',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          // Shared Expenses Toggle
          IconButton(
            icon: Icon(
              _showSharedExpenses ? Icons.people_alt : Icons.people_outline,
              color: _showSharedExpenses ? const Color(0xFF4facfe) : Colors.grey[600],
            ),
            tooltip: _showSharedExpenses ? 'Hide Shared Expenses' : 'Show Shared Expenses',
            onPressed: () {
              setState(() {
                _showSharedExpenses = !_showSharedExpenses;
                LocalStorageService.setBoolSetting(LocalStorageService.kShowSharedExpenses, _showSharedExpenses);
              });
            },
          ),
          // Calendar View Button (only if calendar integration is enabled)
          if (_isCalendarIntegrationEnabled) ...[
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _viewMode = 'calendar';
                  });
                },
                icon: Icon(
                  Icons.calendar_month,
                  size: 18,
                  color: _viewMode == 'calendar' ? Colors.white : Colors.blue[600],
                ),
                label: Text(
                  'Calendar',
                  style: TextStyle(
                    color: _viewMode == 'calendar' ? Colors.white : Colors.blue[600],
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _viewMode == 'calendar' 
                      ? const Color(0xFF4facfe) 
                      : Colors.blue[50],
                  foregroundColor: _viewMode == 'calendar' 
                      ? Colors.white 
                      : Colors.blue[600],
                  elevation: _viewMode == 'calendar' ? 2 : 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: _viewMode == 'calendar' 
                          ? const Color(0xFF4facfe) 
                          : Colors.blue[200]!,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            // Premium indicator for calendar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber[400]!, Colors.amber[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 10, color: Colors.white),
                  const SizedBox(width: 2),
                  Text(
                    'Premium',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Colors.black87),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'date_desc', child: Text('Newest First')),
              const PopupMenuItem(value: 'date_asc', child: Text('Oldest First')),
              const PopupMenuItem(value: 'name_asc', child: Text('Name A-Z')),
              const PopupMenuItem(value: 'name_desc', child: Text('Name Z-A')),
              const PopupMenuItem(value: 'total_desc', child: Text('Total: High to Low')),
              const PopupMenuItem(value: 'total_asc', child: Text('Total: Low to High')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search receipts...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          
          // Shared Expenses Section (if enabled)
          if (_showSharedExpenses)
            StreamBuilder<List<UnpaidSharedExpense>>(
              stream: BudgetCollaborationService.getUnpaidSharedExpenses(),
              builder: (context, snapshot) {
                // Show minimal loading indicator (only if no data yet)
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return Container(
                    height: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF4facfe),
                        ),
                      ),
                    ),
                  );
                }
                
                // Show error if any
                if (snapshot.hasError) {
                  return Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Error loading shared expenses',
                            style: TextStyle(color: Colors.red[700], fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                final unpaidExpenses = snapshot.data ?? [];
                
                if (unpaidExpenses.isEmpty) {
                  return const SizedBox.shrink();
                }
                
                final totalOwed = unpaidExpenses.fold<double>(0.0, (sum, e) => sum + e.remainingAmount);
                
                return Column(
                  children: [
                    // Summary Widget
                    _buildSharedExpensesSummary(context, totalOwed, unpaidExpenses.length),
                    // Shared Expenses List
                    _buildSharedExpensesList(context, unpaidExpenses),
                  ],
                );
              },
            ),
          
          // View Mode Content
          Expanded(
            child: _viewMode == 'list' 
                ? _buildListView(bills, filteredBills, groupedBills, sortedYears)
                : _buildCalendarView(filteredBills),
          ),
        ],
      ),
          // Bottom-right subtle remaining days label
          if (showRemainingLabel)
            Positioned(
              right: 10,
              bottom: 12 + kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom,
              child: Opacity(
                opacity: 0.85,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tiny progress indicator
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: totalCycleDays > 0
                              ? remainingDays / totalCycleDays
                              : null,
                          backgroundColor: Colors.red.withOpacity(0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        remainingDays == 1
                            ? '1 day left until renewal'
                            : '$remainingDays days remaining to renew',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: ModernBottomNavigationBar(
          currentIndex: _selectedIndex,
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
                // Already on storage/bills page
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
      ),
    );
  }

  // Build List View (existing functionality)
  Widget _buildListView(List<dynamic> allBills, List<dynamic> filteredBills, Map<String, Map<String, Map<String, List<dynamic>>>> groupedBills, List<String> sortedYears) {
    return Column(
      children: [
          // Organized Filter Section - Only show in list view
          if (_viewMode == 'list') ...[
           Container(
              margin: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.04,
                vertical: 6,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  // Filter Header
                  Row(
                    children: [
                      Icon(Icons.filter_list, size: 18, color: Colors.blue[600]),
                      const SizedBox(width: 6),
                      Text(
                        'Filter Receipts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      // Premium indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.amber[400]!, Colors.amber[600]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 10, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              'Premium',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
               ],
             ),
           ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Responsive Filter Layout
                  _buildResponsiveFilterLayout(context, allBills, filteredBills),
                ],
              ),
            ),
          ],
          
          
          // Year/Month Filter
          if (groupedBills.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: Colors.transparent,
                child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: sortedYears.length,
                itemBuilder: (context, yearIndex) {
                  final year = sortedYears[yearIndex];
                  final months = groupedBills[year]!.keys.toList()..sort((a, b) => b.compareTo(a));
                  
                  return Row(
                    children: [
                      // Year filter
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_selectedYear == year) {
                              _selectedYear = null;
                              _selectedMonth = null;
                            } else {
                              _selectedYear = year;
                              _selectedMonth = null;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: _selectedYear == year ? const Color(0xFF4facfe) : Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            year,
                            style: TextStyle(
                              color: _selectedYear == year ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      
                      // Month filters
                      if (_selectedYear == year)
                        ...months.map((month) => GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_selectedMonth == month) {
                                _selectedMonth = null;
                              } else {
                                _selectedMonth = month;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: _selectedMonth == month ? const Color(0xFF4facfe) : Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              DateFormat('MMM').format(DateFormat('MMMM yyyy').parse(month)),
                              style: TextStyle(
                                color: _selectedMonth == month ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )).toList(),
                    ],
                  );
                },
              ),
            ),
            ),
          ],
          
        // Bills List
          Expanded(
            child: groupedBills.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedYears.length,
                    itemBuilder: (context, yearIndex) {
                      final year = sortedYears[yearIndex];
                      final months = groupedBills[year]!.keys.toList()..sort((a, b) => b.compareTo(a));
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: months.map((month) {
                          final monthCategories = groupedBills[year]![month]!;
                          
                          // Apply year/month filter
                          if (_selectedYear != null && _selectedYear != year) return const SizedBox.shrink();
                          if (_selectedMonth != null && _selectedMonth != month) return const SizedBox.shrink();
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  month,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              // Group by category within each month
                              ...monthCategories.entries.map((categoryEntry) {
                                final categoryBills = categoryEntry.value;
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Bills in this category
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: categoryBills.length,
                                      itemBuilder: (context, index) {
                                        final bill = categoryBills[index];
                                        return GestureDetector(
                                          onTap: () {
                                            _showBillOptions(context, bill);
                                          },
                                          onLongPress: () {
                                            _showBillOptions(context, bill);
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.only(bottom: 12),
                                            child: SubscriptionCardDecoration(
                                              isSubscription: bill.subscriptionType != null,
                                              subscriptionType: bill.subscriptionType,
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(12),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withOpacity(0.08),
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 2),
                                                          spreadRadius: 0,
                                                        ),
                                                        BoxShadow(
                                                          color: Colors.black.withOpacity(0.04),
                                                          blurRadius: 4,
                                                          offset: const Offset(0, 1),
                                                          spreadRadius: 0,
                                                        ),
                                                      ],
                                                    ),
                                                    child: IntrinsicHeight(
                                              child: Row(
                                              children: [
                                                // Receipt Image or Brand Icon (LEFT SIDE)
                                                Container(
                                                  width: 80,
                                                  decoration: BoxDecoration(
                                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                                                    color: _shouldShowBrandIcon(bill) ? const Color(0xFFF1F3F4) : null,
                                                    image: _shouldShowBrandIcon(bill) ? null : DecorationImage(
                                                      image: FileImage(File(bill.imagePath)),
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                  child: _shouldShowBrandIcon(bill)
                                                      ? Center(
                                                          child: ReceiptBrandIcon(
                                                            name: _getBrandDisplayName(bill),
                                                            category: null,
                                                            size: 50,
                                                            isSubscription: bill.subscriptionType != null,
                                                            forceLetterFallback: true, // Always show first letter for manual/subscription
                                                          ),
                                                        )
                                                      : null,
                                                ),
                                                
                                                // Bill Details
                                                Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(12),
                                                    child: Row(
                                                      children: [
                                                        // Left side: Title, Date, Amount
                                                        Expanded(
                                                          flex: 3,
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              // Title (bold and bigger - primary focus)
                                                              Text(
                                                                (bill.title?.isNotEmpty == true ? bill.title! : bill.vendor) ?? 'Unknown',
                                                                style: const TextStyle(
                                                                  fontWeight: FontWeight.w600,
                                                                  fontSize: 16,
                                                                  color: Color(0xFF1A1A1A),
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                              const SizedBox(height: 4),
                                                              // Date (small)
                                                              Text(
                                                                _formatDate(bill.date),
                                                                style: const TextStyle(
                                                                  color: Color(0xFF6B7280),
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.w400,
                                                                ),
                                                              ),
                                                              const SizedBox(height: 4),
                                                              // Amount (highlighted with primary color)
                                                              Text(
                                                                '${(bill.total ?? 0.0).toStringAsFixed(2)} ${bill.currency ?? ''}',
                                                                style: const TextStyle(
                                                                  color: Color(0xFF4facfe),
                                                                  fontSize: 14,
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        
                                                        // Right side: Categories as unified neutral labels (TOP-RIGHT)
                                                        Expanded(
                                                          flex: 2,
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.end,
                                                            mainAxisAlignment: MainAxisAlignment.start,
                                                            children: [
                                                              Wrap(
                                                                alignment: WrapAlignment.end,
                                                                spacing: 6,
                                                                runSpacing: 6,
                                                                children: [
                                                                  // Category tags - show first to maintain consistent position
                                                                  if (bill.tags != null && bill.tags!.isNotEmpty)
                                                                    ...bill.tags!.take(2).map<Widget>((tag) => Container(
                                                                    constraints: const BoxConstraints(
                                                                      minWidth: 80,
                                                                    ),
                                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                                    decoration: BoxDecoration(
                                                                      color: const Color(0xFFF8FAFC),
                                                                      borderRadius: BorderRadius.circular(8),
                                                                      border: Border.all(
                                                                        color: const Color(0xFFE1E5E9),
                                                                        width: 1,
                                                                      ),
                                                                    ),
                                                                    child: Row(
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                                      children: [
                                                                        Icon(
                                                                          _getCategoryIcon(tag),
                                                                          size: 12,
                                                                          color: const Color(0xFF6B7280),
                                                                        ),
                                                                        const SizedBox(width: 5),
                                                                        Flexible(
                                                                          child: Text(
                                                                            tag,
                                                                            style: const TextStyle(
                                                                              fontSize: 11,
                                                                              color: Color(0xFF1A1A1A),
                                                                              fontWeight: FontWeight.w500,
                                                                            ),
                                                                            maxLines: 1,
                                                                            overflow: TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  )),
                                                                  // Show "Other" tag only if no categories and no subscription
                                                                  if ((bill.tags == null || bill.tags!.isEmpty) && bill.subscriptionType == null)
                                                                    Container(
                                                                      constraints: const BoxConstraints(
                                                                        minWidth: 80,
                                                                      ),
                                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                                      decoration: BoxDecoration(
                                                                        color: const Color(0xFFF8FAFC),
                                                                        borderRadius: BorderRadius.circular(8),
                                                                        border: Border.all(
                                                                          color: const Color(0xFFE1E5E9),
                                                                          width: 1,
                                                                        ),
                                                                      ),
                                                                      child: Row(
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                                        children: [
                                                                          const Icon(
                                                                            Icons.label_outline,
                                                                            size: 12,
                                                                            color: Color(0xFF6B7280),
                                                                          ),
                                                                          const SizedBox(width: 5),
                                                                          const Text(
                                                                            'Other',
                                                                            style: TextStyle(
                                                                              fontSize: 11,
                                                                              color: Color(0xFF1A1A1A),
                                                                              fontWeight: FontWeight.w500,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                ],
                                                              ),
                                                              // Spacer to push categories to top
                                                              const Spacer(),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            ),
                                                  ),
                                                  // Subscription frequency indicator - positioned to overlap card edge
                                                  if (bill.subscriptionType != null)
                                                    Positioned(
                                                      top: -8,
                                                      right: -8,
                                                      child: SubscriptionIndicator(
                                                        subscriptionType: bill.subscriptionType,
                                                        size: 22,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                    },
                                  ),
                                  ]);
                              }).toList(),
                            ],
                          );
                        }).toList(),
                      );
                    },
                  ),
          ),
        ],
    );
  }

  // Build Calendar View (new functionality)
  Widget _buildCalendarView(List<dynamic> filteredBills) {
    // Get receipts for the selected date
    final selectedDateReceipts = filteredBills.where((bill) {
      final billDate = bill.date ?? DateTime.now();
      return billDate.year == _selectedCalendarDate.year &&
             billDate.month == _selectedCalendarDate.month &&
             billDate.day == _selectedCalendarDate.day;
    }).toList();

    return Column(
      children: [
        // Calendar Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _currentCalendarMonth = DateTime(
                      _currentCalendarMonth.year,
                      _currentCalendarMonth.month - 1,
                    );
                  });
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_currentCalendarMonth),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () {
            setState(() {
                    _currentCalendarMonth = DateTime(
                      _currentCalendarMonth.year,
                      _currentCalendarMonth.month + 1,
                    );
                  });
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        
        // Calendar Grid
        Expanded(
          child: _buildCalendarGrid(filteredBills),
        ),
        
        // Selected Date Receipts
        if (selectedDateReceipts.isNotEmpty) ...[
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receipts for ${DateFormat('MMM dd, yyyy').format(_selectedCalendarDate)} (${selectedDateReceipts.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedDateReceipts.length,
                    itemBuilder: (context, index) {
                      final bill = selectedDateReceipts[index];
                      return Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _showBillOptions(context, bill),
                          child: SubscriptionCardDecoration(
                            isSubscription: bill.subscriptionType != null,
                            subscriptionType: bill.subscriptionType,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                          spreadRadius: 0,
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                      color: _shouldShowBrandIcon(bill) ? const Color(0xFFF1F3F4) : null,
                                      image: _shouldShowBrandIcon(bill) ? null : DecorationImage(
                                        image: FileImage(File(bill.imagePath)),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    child: _shouldShowBrandIcon(bill)
                                        ? Center(
                                            child: ReceiptBrandIcon(
                                              name: _getBrandDisplayName(bill),
                                              category: null,
                                              size: 40,
                                              isSubscription: bill.subscriptionType != null,
                                              forceLetterFallback: true, // Always show first letter for manual/subscription
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Title (bold)
                                      Text(
                                        (bill.title?.isNotEmpty == true ? bill.title! : bill.vendor) ?? 'Unknown',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      // Date (small)
                                      Text(
                                        DateFormat('MMM dd').format(bill.date ?? DateTime.now()),
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: Color(0xFF6B7280),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      // Amount (highlighted)
                                      Text(
                                        '${(bill.total ?? 0.0).toStringAsFixed(2)} ${bill.currency ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF4facfe),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Categories and subscription indicator as unified neutral labels
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: [
                                          // Category tags - show first to maintain consistent position
                                          if (bill.tags != null && bill.tags!.isNotEmpty)
                                            ...bill.tags!.take(2).map<Widget>((tag) => Container(
                                            constraints: const BoxConstraints(
                                              minWidth: 60,
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFFE1E5E9),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  _getCategoryIcon(tag),
                                                  size: 8,
                                                  color: const Color(0xFF6B7280),
                                                ),
                                                const SizedBox(width: 3),
                                                Flexible(
                                                  child: Text(
                                                    tag,
                                                    style: const TextStyle(
                                                      fontSize: 8,
                                                      color: Color(0xFF1A1A1A),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                                  ),
                                ),
                                // Subscription frequency indicator - positioned to overlap card edge
                                if (bill.subscriptionType != null)
                                  Positioned(
                                    top: -6,
                                    right: -6,
                                    child: SubscriptionIndicator(
                                      subscriptionType: bill.subscriptionType,
                                      size: 18,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Build Calendar Grid
  Widget _buildCalendarGrid(List<dynamic> filteredBills) {
    final firstDayOfMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month + 1, 0);
    final firstDayWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;
    
    // Get receipts count for each day
    final Map<int, int> receiptsPerDay = {};
    for (final bill in filteredBills) {
      final billDate = bill.date ?? DateTime.now();
      if (billDate.year == _currentCalendarMonth.year && 
          billDate.month == _currentCalendarMonth.month) {
        final day = billDate.day;
        receiptsPerDay[day] = (receiptsPerDay[day] ?? 0) + 1;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          
          // Calendar days
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: 42, // 6 weeks * 7 days
              itemBuilder: (context, index) {
                final dayNumber = index - firstDayWeekday + 1;
                final isCurrentMonth = dayNumber > 0 && dayNumber <= daysInMonth;
                final isSelected = isCurrentMonth && 
                    dayNumber == _selectedCalendarDate.day &&
                    _currentCalendarMonth.month == _selectedCalendarDate.month &&
                    _currentCalendarMonth.year == _selectedCalendarDate.year;
                final hasReceipts = isCurrentMonth && receiptsPerDay.containsKey(dayNumber);
                // final receiptCount = receiptsPerDay[dayNumber] ?? 0; // For future use

                return GestureDetector(
                  onTap: isCurrentMonth ? () {
                    setState(() {
                      _selectedCalendarDate = DateTime(
                        _currentCalendarMonth.year,
                        _currentCalendarMonth.month,
                        dayNumber,
                      );
                    });
                  } : null,
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? const Color(0xFF4facfe)
                          : hasReceipts 
                              ? Colors.blue[50]
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected 
                          ? Border.all(color: const Color(0xFF4facfe), width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isCurrentMonth ? dayNumber.toString() : '',
                          style: TextStyle(
                            color: isSelected 
                                ? Colors.white
                                : hasReceipts 
                                    ? const Color(0xFF4facfe)
                                    : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (hasReceipts && !isSelected) ...[
                          const SizedBox(height: 2),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4facfe),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Navigate to appropriate edit page based on bill source
  void _navigateToEditPage(dynamic bill) {
    // Determine bill source based on ocrText
    final isManualEntry = bill.ocrText == 'Manual entry';
    final isSubscriptionEntry = bill.ocrText == 'Subscription entry';
    
    if (isSubscriptionEntry) {
      // Navigate to subscription form for editing
      _showSubscriptionEditModal(bill);
    } else if (isManualEntry) {
      // Navigate to manual expense form for editing
      _showManualExpenseEditModal(bill);
    } else {
      // Navigate to post-capture page for scanned receipts
      context.push('/post-capture', extra: {
        'imagePath': bill.imagePath,
        'detectedTitle': bill.title ?? bill.vendor,
        'detectedTotal': bill.total,
        'detectedCurrency': bill.currency,
        'isEditing': true,
        'billId': bill.id,
        'existingBill': bill,
      });
    }
  }

  // Show subscription edit modal
  void _showSubscriptionEditModal(dynamic bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => DynamicExpenseModal(
        formType: FormType.subscription,
        selectedCurrency: bill.currency ?? 'USD',
        existingBill: bill,
        onSubmit: (formData) async {
          try {
            // Update the existing bill with new data
            final updatedBill = Bill(
              id: bill.id,
              imagePath: bill.imagePath,
              vendor: _getVendorName(formData),
              title: (formData['title'] as String?)?.isNotEmpty == true
                  ? formData['title'] as String
                  : null,
              date: formData['startDate'] ?? DateTime.now(), // This is the last payment date
              total: formData['amount'] ?? 0.0,
              currency: bill.currency ?? 'USD',
              ocrText: 'Subscription entry',
              categoryId: formData['subscriptionCategory'] ?? 'Other',
              tags: [formData['subscriptionCategory'] ?? 'Other'],
              location: bill.location,
              notes: formData['notes'] ?? '',
              subscriptionType: formData['frequency']?.toString().toLowerCase(),
              subscriptionEndDate: formData['endDate'], // Include the end date from form data
              subscriptionStartDate: formData['startDate'] ?? bill.subscriptionStartDate ?? bill.date, // Set start date
              createdAt: bill.createdAt,
              updatedAt: DateTime.now(),
            );
            
            // Update the bill in database
            ref.read(billProvider.notifier).updateBill(updatedBill);
            
            print('🔍 DEBUG: Subscription updated successfully - ID: ${updatedBill.id}, Title: ${updatedBill.title}, EndDate: ${updatedBill.subscriptionEndDate}');
            
            // Update subscription reminders with new data
            try {
              await PersonalSubscriptionReminderService.updateSubscriptionReminders(updatedBill);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Subscription updated successfully and reminders updated!'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              // Handle permission errors gracefully
              if (e.toString().contains('exact_alarms_not_permitted')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Subscription updated! Note: Exact alarm permission is required for precise reminders.'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 4),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Subscription updated! Warning: Could not update reminders - ${e.toString()}'),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update subscription: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  // Show manual expense edit modal
  void _showManualExpenseEditModal(dynamic bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => DynamicExpenseModal(
        formType: FormType.manualExpense,
        selectedCurrency: bill.currency ?? 'USD',
        existingBill: bill,
        onSubmit: (formData) async {
          try {
            // Update the existing bill with new data
            final updatedBill = Bill(
              id: bill.id,
              imagePath: bill.imagePath,
              vendor: _getVendorName(formData),
              title: (formData['title'] as String?)?.isNotEmpty == true
                  ? formData['title'] as String
                  : null,
              date: formData['date'] ?? DateTime.now(),
              total: formData['amount'] ?? 0.0,
              currency: bill.currency ?? 'USD',
              ocrText: 'Manual entry',
              categoryId: formData['category'] ?? 'Other',
              subtotal: bill.subtotal, // Preserve existing subtotal
              tax: bill.tax, // Preserve existing tax
              tags: [formData['category'] ?? 'Other'],
              location: bill.location,
              notes: formData['notes'] ?? '',
              subscriptionType: bill.subscriptionType, // Preserve existing subscription type
              subscriptionEndDate: bill.subscriptionEndDate, // Preserve existing end date
              createdAt: bill.createdAt,
              updatedAt: DateTime.now(),
            );
            
            // Update the bill in database
            ref.read(billProvider.notifier).updateBill(updatedBill);
            
            print('🔍 DEBUG: Manual expense updated successfully - ID: ${updatedBill.id}, Title: ${updatedBill.title}, Total: ${updatedBill.total}');
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Manual expense updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update manual expense: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  // ==================== Shared Expenses UI ====================
  
  /// Build summary widget showing total owed
  Widget _buildSharedExpensesSummary(BuildContext context, double totalOwed, int count) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4facfe).withOpacity(0.1),
            const Color(0xFF4facfe).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4facfe).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4facfe).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.people_alt,
              color: Color(0xFF4facfe),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You Owe from Shared Expenses',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${totalOwed.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4facfe),
                  ),
                ),
                if (count > 0)
                  Text(
                    '$count ${count == 1 ? 'expense' : 'expenses'} pending',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build list of unpaid shared expenses
  Widget _buildSharedExpensesList(BuildContext context, List<UnpaidSharedExpense> expenses) {
    return Container(
      height: 130,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: expenses.length,
        itemBuilder: (context, index) {
          final unpaid = expenses[index];
          return _buildSharedExpenseCard(context, unpaid);
        },
      ),
    );
  }

  /// Build individual shared expense card
  Widget _buildSharedExpenseCard(BuildContext context, UnpaidSharedExpense unpaid) {
    final expense = unpaid.expense;
    final budget = unpaid.budget;
    final categoryInfo = CategoryService.getCategoryInfo(expense.category);
    final isPartiallyPaid = unpaid.paidAmount > 0;
    
    return GestureDetector(
      onTap: () => _showSharedExpenseDetails(context, unpaid),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF4facfe).withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4facfe).withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header with budget name and category
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (categoryInfo?.color ?? Colors.grey).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    categoryInfo?.icon ?? Icons.category,
                    size: 16,
                    color: categoryInfo?.color ?? Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        expense.title ?? expense.category,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Shared badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4facfe).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.people_alt,
                    size: 12,
                    color: Color(0xFF4facfe),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Amount and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You Owe:',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '\$${unpaid.remainingAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isPartiallyPaid ? Colors.orange[700] : const Color(0xFF4facfe),
                      ),
                    ),
                  ],
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPartiallyPaid 
                        ? Colors.orange.withOpacity(0.15)
                        : Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPartiallyPaid ? 'Partial' : 'Unpaid',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isPartiallyPaid ? Colors.orange[700] : Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Show inline details dialog for shared expense
  Future<void> _showSharedExpenseDetails(BuildContext context, UnpaidSharedExpense unpaid) async {
    final expense = unpaid.expense;
    final budget = unpaid.budget;
    final categoryInfo = CategoryService.getCategoryInfo(expense.category);
    final payer = budget.members.firstWhere(
      (m) => m.userId == expense.userId,
      orElse: () => budget.members.first,
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (categoryInfo?.color ?? Colors.grey).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                categoryInfo?.icon ?? Icons.category,
                color: categoryInfo?.color ?? Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title ?? expense.category,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    budget.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4facfe).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Total Expense', '\$${expense.amount.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    _buildDetailRow('Your Share', '\$${unpaid.totalOwed.toStringAsFixed(2)}'),
                    if (unpaid.paidAmount > 0) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow('Paid', '\$${unpaid.paidAmount.toStringAsFixed(2)}', color: Colors.green[700]),
                    ],
                    const Divider(height: 16),
                    _buildDetailRow(
                      'Remaining',
                      '\$${unpaid.remainingAmount.toStringAsFixed(2)}',
                      isBold: true,
                      color: const Color(0xFF4facfe),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Payer info
              _buildDetailRow('Paid By', payer.name),
              if (expense.description?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  'Description:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  expense.description!,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Date: ${_formatSharedExpenseDate(expense.date)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _markSharedExpenseAsPaid(context, unpaid);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4facfe),
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark as Paid'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  String _formatSharedExpenseDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Mark shared expense as paid
  Future<void> _markSharedExpenseAsPaid(BuildContext context, UnpaidSharedExpense unpaid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final success = await BudgetCollaborationService.markSettlement(
      budgetId: unpaid.budget.id,
      expenseId: unpaid.expense.id,
      userId: currentUser.uid,
      paymentAmount: unpaid.remainingAmount, // Pay full remaining amount
      settled: true,
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
              Expanded(
                child: Text(
                  success 
                      ? 'Marked as paid successfully!'
                      : 'Failed to mark as paid. Please try again.',
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
  }

  // ==================== End Shared Expenses UI ====================

  // Helper method to get vendor name from form data
  String _getVendorName(Map<String, dynamic> formData) {
    final title = formData['title'] as String?;
    if (title != null && title.isNotEmpty) {
      return title;
    }
    
    // For subscriptions, try to get subscription category
    final subscriptionCategory = formData['subscriptionCategory'] as String?;
    if (subscriptionCategory != null && subscriptionCategory.isNotEmpty) {
      return subscriptionCategory;
    }
    
    // For manual expenses, try to get category
    final category = formData['category'] as String?;
    if (category != null && category.isNotEmpty) {
      return category;
    }
    
    return 'Manual Entry';
  }
}