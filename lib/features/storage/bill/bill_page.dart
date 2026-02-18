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
import '../../../core/widgets/subscription_badge.dart';
import '../../../core/widgets/cached_bill_image_provider.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../home/dynamic_expense_modal.dart';
import '../models/bill_model.dart';
import '../../../core/theme/app_colors.dart';

class BillsPage extends ConsumerStatefulWidget {
  const BillsPage({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  ConsumerState<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends ConsumerState<BillsPage> with AutomaticKeepAliveClientMixin {
  String _searchQuery = '';
  String _sortBy = 'date_desc'; // date_desc, date_asc, name_asc, name_desc, total_desc, total_asc
  String? _selectedYear;
  String? _selectedMonth;
  int _selectedIndex = 3; // Storage tab is selected
  final String _selectedCategory = 'all'; // all, manual, subscription, sepa, scanned
  String _selectedSource = 'all'; // all, scanned, manual, subscription
  String _selectedCategoryFilter = 'all'; // all, or specific category
  List<String> _selectedCategories = []; // For multi-select categories
  
  // Calendar view state
  String _viewMode = 'list'; // 'list' or 'calendar'
  DateTime _selectedCalendarDate = DateTime.now();
  DateTime _currentCalendarMonth = DateTime.now();
  bool _isCalendarIntegrationEnabled = false;
  
  // ✅ Optimized: Pagination state
  static const int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  
  // ✅ Performance: Cache filtered bills to avoid recalculating on every build
  List<dynamic>? _cachedFilteredBills;
  String? _cachedSearchQuery;
  String? _cachedSource;
  String? _cachedCategoryFilter;
  List<String>? _cachedSelectedCategories;
  int? _cachedBillsLength; // Track if bills list changed

  @override
  void initState() {
    super.initState();
    _isCalendarIntegrationEnabled = LocalStorageService.getBoolSetting(LocalStorageService.kCalendarResults);
    if (widget.initialCategoryId != null && widget.initialCategoryId!.isNotEmpty) {
      _selectedCategoryFilter = widget.initialCategoryId!;
      _selectedCategories = [widget.initialCategoryId!];
    }
    // ✅ Optimized: Setup pagination scroll listener
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  // ✅ Optimized: Reset pagination when filters change
  void _resetPagination() {
    setState(() {
      _currentPage = 0;
      _hasMore = true;
      // ✅ Performance: Clear cache when filters change
      _cachedFilteredBills = null;
    });
  }

  /// Clear all filters: Source → All, Year/Month → none, Categories → none.
  void _clearAllFilters() {
    setState(() {
      _selectedSource = 'all';
      _selectedYear = null;
      _selectedMonth = null;
      _selectedCategories = [];
      _selectedCategoryFilter = 'all';
      _currentPage = 0;
      _hasMore = true;
      _cachedFilteredBills = null;
    });
  }

  // ✅ Optimized: Handle scroll for pagination
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreBills();
    }
  }
  
  // ✅ Optimized: Load more bills for pagination
  void _loadMoreBills() {
    if (!_hasMore) return;
    
    setState(() {
      _currentPage++;
      final allFilteredBills = _getAllFilteredBills();
      final totalItems = allFilteredBills.length;
      final displayedItems = (_currentPage + 1) * _pageSize;
      
      if (displayedItems >= totalItems) {
        _hasMore = false;
      }
    });
  }
  
  // ✅ Optimized: Get paginated bills
  List<dynamic> _getPaginatedBills(List<dynamic> filteredBills) {
    final endIndex = ((_currentPage + 1) * _pageSize).clamp(0, filteredBills.length);
    return filteredBills.sublist(0, endIndex);
  }
  
  // ✅ Optimized: Get all filtered bills (without pagination for grouping)
  List<dynamic> _getAllFilteredBills() {
    final bills = ref.read(billProvider);
    
    // ✅ Performance: Return cached result if filters and bills list haven't changed
    if (_cachedFilteredBills != null &&
        _cachedBillsLength == bills.length &&
        _cachedSearchQuery == _searchQuery &&
        _cachedSource == _selectedSource &&
        _cachedCategoryFilter == _selectedCategoryFilter &&
        _listEquals(_cachedSelectedCategories, _selectedCategories)) {
      return _cachedFilteredBills!;
    }
    final filtered = bills.where((bill) {
      if (_selectedSource != 'all') {
        final billSource = _getBillCategory(bill);
        if (billSource != _selectedSource) return false;
      }
      
      if (_selectedCategoryFilter != 'all') {
        final billCategory = bill.categoryId?.toLowerCase() ?? '';
        if (_selectedCategories.isNotEmpty) {
          if (!_selectedCategories.any((cat) => cat.toLowerCase() == billCategory)) return false;
        } else {
          if (billCategory != _selectedCategoryFilter.toLowerCase()) return false;
        }
      }
      
      final query = _searchQuery.toLowerCase();
      return ((bill.title ?? bill.vendor)?.toLowerCase().contains(query) ?? false) ||
              (bill.tags?.any((tag) => tag.toLowerCase().contains(query)) ?? false);
    }).toList();
    
    // ✅ Performance: Cache the result
    _cachedFilteredBills = filtered;
    _cachedBillsLength = bills.length;
    _cachedSearchQuery = _searchQuery;
    _cachedSource = _selectedSource;
    _cachedCategoryFilter = _selectedCategoryFilter;
    _cachedSelectedCategories = List<String>.from(_selectedCategories);
    
    return filtered;
  }
  
  // ✅ Performance: Helper to compare lists
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ✅ Performance: Remove expensive operations from didChangeDependencies
  // Settings are already loaded in initState and don't need to be refreshed on every navigation

  @override
  bool get wantKeepAlive => true; // ✅ Performance: Preserve page state during navigation

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
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blue,
                    borderRadius: pw.BorderRadius.only(
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
                    style: const pw.TextStyle(
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
    // Subscription = recurring (subscriptionType set or ocrText 'Subscription entry')
    // Manual = one-off manual entries only (ocrText 'Manual entry', not subscription)
    // Scanned = from camera with OCR text
    if (bill.subscriptionType != null || bill.ocrText == 'Subscription entry') {
      return 'subscription';
    }
    if (bill.ocrText == 'Manual entry') {
      return 'manual';
    }
    if (bill.ocrText != null && bill.ocrText.isNotEmpty &&
        bill.ocrText != 'Manual entry' && bill.ocrText != 'Subscription entry') {
      return 'scanned';
    }
    return 'manual'; // Fallback
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

  /// Check if we should show brand icon instead of image (manual/subscription = no receipt image)
  bool _shouldShowBrandIcon(dynamic bill) {
    return bill.ocrText == 'Manual entry' || bill.ocrText == 'Subscription entry';
  }

  /// Get the display name for brand icon
  String _getBrandDisplayName(dynamic bill) {
    return (bill.title?.isNotEmpty == true ? bill.title! : bill.vendor) ?? 'Unknown';
  }

  /// Category for thumbnail/display (categoryId or first tag, else 'Other')
  String _getBillCategoryForDisplay(dynamic bill) {
    if (bill.categoryId != null && bill.categoryId!.isNotEmpty) return bill.categoryId!;
    if (bill.tags != null && bill.tags!.isNotEmpty) return bill.tags!.first;
    return 'Other';
  }

  /// Search bar widget (used inside scroll content so it scrolls with list).
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _resetPagination();
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
    );
  }

  /// Small "SUB" label box for subscription receipts (category color, top-right).
  Widget _buildSubLabelBox(dynamic bill) {
    final category = _getBillCategoryForDisplay(bill);
    final color = _getCategoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'SUB',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Thumbnail for manual/subscription receipts: category icon with category color (no first letter).
  Widget _buildCategoryThumbnail(dynamic bill, {double size = 50}) {
    final category = _getBillCategoryForDisplay(bill);
    final color = _getCategoryColor(category);
    final iconData = _getCategoryIcon(category);
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(iconData, size: size * 0.5, color: color),
      ),
    );
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

  // App primary dark blue for filter selection (matches app theme)
  static Color get _filterPillSelectedBg => AppColors.bottomNavBackground;
  static const Color _filterPillUnselectedBg = Color(0xFFE5E7EB); // grey[200]
  static const Color _filterPillUnselectedText = Color(0xFF374151); // grey[800]
  static const Color _filterSectionLabel = Color(0xFF374151);

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? _filterPillSelectedBg : _filterPillUnselectedBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : _filterPillUnselectedText,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: _filterSectionLabel,
          fontSize: 14,
        ),
      ),
    );
  }

  /// Horizontal scrollable row of pills (touch scroll, no buttons).
  Widget _buildHorizontalPillRow(List<Widget> pills) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: pills,
      ),
    );
  }

  /// Single container filter UI: Source, Year, Month, Categories as pill rows (Figma-style).
  Widget _buildFilterCardContent(
    BuildContext context,
    List<dynamic> allBills,
    Map<String, Map<String, Map<String, List<dynamic>>>> groupedBills,
    List<String> sortedYears,
  ) {
    final uniqueCategories = _getUniqueCategories(allBills);
    List<String> monthsForSelectedYear = <String>[];
    if (_selectedYear != null && groupedBills.containsKey(_selectedYear)) {
      monthsForSelectedYear = groupedBills[_selectedYear]!.keys.toList();
      monthsForSelectedYear.sort((a, b) {
        final da = DateFormat('MMMM yyyy').parse(a);
        final db = DateFormat('MMMM yyyy').parse(b);
        return db.compareTo(da); // descending: newest month first
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Source
        _buildFilterSectionLabel('Source'),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildFilterPill(
              label: 'All',
              isSelected: _selectedSource == 'all',
              onTap: () => setState(() => _selectedSource = 'all'),
            ),
            _buildFilterPill(
              label: 'Scanned',
              isSelected: _selectedSource == 'scanned',
              onTap: () => setState(() => _selectedSource = 'scanned'),
            ),
            _buildFilterPill(
              label: 'Manual',
              isSelected: _selectedSource == 'manual',
              onTap: () => setState(() => _selectedSource = 'manual'),
            ),
            _buildFilterPill(
              label: 'Subscription',
              isSelected: _selectedSource == 'subscription',
              onTap: () => setState(() => _selectedSource = 'subscription'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Year — horizontal scroll
        _buildFilterSectionLabel('Year'),
        _buildHorizontalPillRow([
          _buildFilterPill(
            label: 'All Years',
            isSelected: _selectedYear == null,
            onTap: () => setState(() {
              _selectedYear = null;
              _selectedMonth = null;
            }),
          ),
          ...sortedYears.map((year) => _buildFilterPill(
                label: year,
                isSelected: _selectedYear == year,
                onTap: () => setState(() {
                  _selectedYear = year;
                  _selectedMonth = null;
                }),
              )),
        ]),
        // Month — only when a specific year is selected
        if (_selectedYear != null) ...[
          const SizedBox(height: 16),
          _buildFilterSectionLabel('Month'),
          _buildHorizontalPillRow([
            _buildFilterPill(
              label: 'All Months',
              isSelected: _selectedMonth == null,
              onTap: () => setState(() => _selectedMonth = null),
            ),
            ...monthsForSelectedYear.map((month) {
              final monthShort = DateFormat('MMM').format(DateFormat('MMMM yyyy').parse(month));
              return _buildFilterPill(
                label: monthShort,
                isSelected: _selectedMonth == month,
                onTap: () => setState(() {
                  _selectedMonth = _selectedMonth == month ? null : month;
                }),
              );
            }),
          ]),
        ],
        const SizedBox(height: 16),
        // Categories — horizontal scroll
        _buildFilterSectionLabel('Categories'),
        _buildHorizontalPillRow(
          uniqueCategories.map((category) {
            final isSelected = _selectedCategories.contains(category);
            return _buildFilterPill(
              label: category,
              isSelected: isSelected,
              onTap: () => setState(() {
                if (isSelected) {
                  _selectedCategories = _selectedCategories.where((c) => c != category).toList();
                } else {
                  _selectedCategories = [..._selectedCategories, category];
                }
                if (_selectedCategories.isEmpty) {
                  _selectedCategoryFilter = 'all';
                } else if (_selectedCategories.length == 1) {
                  _selectedCategoryFilter = _selectedCategories.first;
                } else {
                  _selectedCategoryFilter = 'multiple';
                }
              }),
            );
          }).toList(),
        ),
      ],
    );
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
              // ✅ UI/UX Improvement: Use improved empty state widget
            NoBillsEmptyState(
              onScanPressed: () => context.go('/scan'),
              onManualEntryPressed: () => context.go('/home'),
            ),
            ],
          ),
        ),
      );
    }
  }

  /// Empty state when filters are applied but no receipts match.
  Widget _buildNoMatchingFiltersEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.filter_list_off,
                size: 40,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No receipts found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'No receipts match your current filters.\nTry changing or clearing your filters.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.clear_all, size: 20, color: Colors.white),
              label: const Text(
                'Clear filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bottomNavBackground,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Performance: Required for AutomaticKeepAliveClientMixin
    final bills = ref.watch(billProvider);
    
    // ✅ Optimized: Filter bills based on search query, source, and category
    final filteredBills = bills.where((bill) {
      // First filter by source (scanned/manual)
      if (_selectedSource != 'all') {
        final billSource = _getBillCategory(bill);
        if (billSource != _selectedSource) {
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 10, color: Colors.white),
                  SizedBox(width: 2),
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

  /// Filter Receipts container widget (scrolls with list, not fixed).
  Widget _buildFilterReceiptsContainer(
    BuildContext context,
    List<dynamic> allBills,
    Map<String, Map<String, Map<String, List<dynamic>>>> groupedBills,
    List<String> sortedYears,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.04,
        vertical: 6,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Filter Receipts',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _clearAllFilters,
                child: const Text(
                  'Clear all',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.bottomNavBackground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFilterCardContent(context, allBills, groupedBills, sortedYears),
        ],
      ),
    );
  }

  // Build List View: search + filter scroll with receipts (not fixed)
  Widget _buildListView(List<dynamic> allBills, List<dynamic> filteredBills, Map<String, Map<String, Map<String, List<dynamic>>>> groupedBills, List<String> sortedYears) {
    if (groupedBills.isEmpty) {
      // No receipts at all: search bar + empty state
      if (allBills.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchBar(),
            Expanded(child: _buildEmptyState()),
          ],
        );
      }
      // Filters applied but no match: search + filter container + "No receipts found" message
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchBar(),
          _buildFilterReceiptsContainer(context, allBills, groupedBills, sortedYears),
          Expanded(child: _buildNoMatchingFiltersEmptyState()),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        _resetPagination();
        if (mounted) setState(() {});
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Search bar as first sliver — scrolls away with content
          if (_viewMode == 'list')
            SliverToBoxAdapter(child: _buildSearchBar()),
          // Filter container
          if (_viewMode == 'list')
            SliverToBoxAdapter(
              child: _buildFilterReceiptsContainer(context, allBills, groupedBills, sortedYears),
            ),
          // Receipt list
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, yearIndex) {
                      final year = sortedYears[yearIndex];
                      final months = groupedBills[year]!.keys.toList()
                        ..sort((a, b) {
                          final da = DateFormat('MMMM yyyy').parse(a);
                          final db = DateFormat('MMMM yyyy').parse(b);
                          return db.compareTo(da); // descending: newest month first
                        });
                      
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
                                              child: Padding(
                                                padding: const EdgeInsets.only(left: 12),
                                                child: Row(
                                              children: [
                                                // Receipt thumbnail (left): fixed square for uniform padding, larger thumbnail
                                                Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    Container(
                                                      width: 88,
                                                      height: 88,
                                                      decoration: BoxDecoration(
                                                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                                                        color: _shouldShowBrandIcon(bill) ? Colors.white : null,
                                                        image: _shouldShowBrandIcon(bill) ? null : DecorationImage(
                                                          image: CachedBillImageProvider(
                                                            imagePath: bill.imagePath,
                                                            cacheWidth: 200,
                                                            cacheHeight: 200,
                                                          ).resized,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                      child: _shouldShowBrandIcon(bill)
                                                          ? _buildCategoryThumbnail(bill, size: 64)
                                                          : null,
                                                    ),
                                                    if (bill.subscriptionType != null)
                                                      Positioned(
                                                        top: 4,
                                                        right: 4,
                                                        child: _buildSubLabelBox(bill),
                                                      ),
                                                  ],
                                                ),
                                                // Bill Details: title + amount top row, date, then category below
                                                Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        // Top row: Merchant name (left) + Total cost (right, primary dark blue)
                                                        Row(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                (bill.title?.isNotEmpty == true ? bill.title! : bill.vendor) ?? 'Unknown',
                                                                style: const TextStyle(
                                                                  fontWeight: FontWeight.w600,
                                                                  fontSize: 18,
                                                                  color: Color(0xFF1A1A1A),
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Text(
                                                              '${(bill.total ?? 0.0).toStringAsFixed(2)} ${bill.currency ?? ''}',
                                                              style: const TextStyle(
                                                                color: AppColors.bottomNavBackground,
                                                                fontSize: 16,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 4),
                                                        // Date
                                                        Text(
                                                          _formatDate(bill.date),
                                                          style: const TextStyle(
                                                            color: Color(0xFF6B7280),
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w400,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        // Category label(s) below date (text only, reduced height)
                                                        Wrap(
                                                          spacing: 6,
                                                          runSpacing: 4,
                                                          children: [
                                                            if (bill.tags != null && bill.tags!.isNotEmpty)
                                                              ...bill.tags!.take(2).map<Widget>((tag) => Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                                decoration: BoxDecoration(
                                                                  color: const Color(0xFFF8FAFC),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                  border: Border.all(color: const Color(0xFFE1E5E9), width: 1),
                                                                ),
                                                                child: Text(
                                                                  tag,
                                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              )),
                                                            if ((bill.tags == null || bill.tags!.isEmpty) && bill.subscriptionType == null)
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                                decoration: BoxDecoration(
                                                                  color: const Color(0xFFF8FAFC),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                  border: Border.all(color: const Color(0xFFE1E5E9), width: 1),
                                                                ),
                                                                child: const Text('Other', style: TextStyle(fontSize: 11, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500)),
                                                              ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            ),
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
                              }),
                            ],
                          );
                        }).toList(),
                      );
                    },
                childCount: sortedYears.length + (_hasMore && filteredBills.length > (_currentPage + 1) * _pageSize ? 1 : 0),
              ),
            ),
          ),
        ],
      ),
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
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                          color: _shouldShowBrandIcon(bill) ? Colors.white : null,
                                          image: _shouldShowBrandIcon(bill) ? null : DecorationImage(
                                            image: FileImage(File(bill.imagePath)),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        child: _shouldShowBrandIcon(bill)
                                            ? _buildCategoryThumbnail(bill, size: 40)
                                            : null,
                                      ),
                                      if (bill.subscriptionType != null)
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: _buildSubLabelBox(bill),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top row: Title (left) + Amount (right, primary dark blue)
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              (bill.title?.isNotEmpty == true ? bill.title! : bill.vendor) ?? 'Unknown',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1A1A1A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            '${(bill.total ?? 0.0).toStringAsFixed(2)} ${bill.currency ?? ''}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.bottomNavBackground,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      // Date
                                      Text(
                                        DateFormat('MMM dd').format(bill.date ?? DateTime.now()),
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: Color(0xFF6B7280),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Category labels below date (text only, reduced height)
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 2,
                                        children: [
                                          if (bill.tags != null && bill.tags!.isNotEmpty)
                                            ...bill.tags!.take(2).map<Widget>((tag) => Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFFE1E5E9), width: 0.8),
                                              ),
                                              child: Text(
                                                tag,
                                                style: const TextStyle(fontSize: 8, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
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