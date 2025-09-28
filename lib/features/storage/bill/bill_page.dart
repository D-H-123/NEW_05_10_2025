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
  
  // Calendar view state
  String _viewMode = 'list'; // 'list' or 'calendar'
  DateTime _selectedCalendarDate = DateTime.now();
  DateTime _currentCalendarMonth = DateTime.now();
  bool _isCalendarIntegrationEnabled = false;
  bool _isLocationFilterEnabled = false;

  @override
  void initState() {
    super.initState();
    _isCalendarIntegrationEnabled = LocalStorageService.getBoolSetting(LocalStorageService.kCalendarResults);
    _isLocationFilterEnabled = LocalStorageService.getBoolSetting(LocalStorageService.kLocation);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh settings when returning to this page
    _isCalendarIntegrationEnabled = LocalStorageService.getBoolSetting(LocalStorageService.kCalendarResults);
    _isLocationFilterEnabled = LocalStorageService.getBoolSetting(LocalStorageService.kLocation);
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
              bill.vendor ?? 'Receipt Options',
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
                // Navigate to edit page
                context.push('/post-capture', extra: {
                  'imagePath': bill.imagePath,
                  'detectedTitle': bill.vendor,
                  'detectedTotal': bill.total,
                  'detectedCurrency': bill.currency,
                  'isEditing': true,
                  'billId': bill.id,
                  'existingBill': bill,
                });
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
                _showExportOptions(context, bill);
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
          'Are you sure you want to delete "${bill.vendor ?? 'this receipt'}"? This action cannot be undone.',
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
        content: Text('${bill.vendor ?? 'Receipt'} deleted successfully'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _shareBill(dynamic bill) async {
    final String message = '''
Receipt Details:
Vendor: ${bill.vendor ?? 'N/A'}
Date: ${DateFormat('MMM dd, yyyy').format(bill.date ?? DateTime.now())}
Total: ${bill.total ?? 0.0} ${bill.currency ?? ''}
OCR Text: ${bill.ocrText}
Tags: ${bill.tags?.join(', ') ?? 'N/A'}
''';

    await Share.share(message);
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
                _buildPDFRow('Vendor:', bill.vendor ?? 'N/A'),
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
    final subject = 'Receipt: ${bill.vendor ?? 'Unknown Vendor'} - ${bill.total ?? 0.0} ${bill.currency ?? ''}';
    
         final body = '''
 Hello,
 
 Please find the receipt details below:
 
 Vendor: ${bill.vendor ?? 'N/A'}
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
    // Scanned receipts from camera have actual OCR text content (not 'Manual entry')
    if (bill.ocrText == 'Manual entry') {
      return 'manual'; // Created via plus button form
    } else if (bill.ocrText != null && bill.ocrText.isNotEmpty && bill.ocrText != 'Manual entry') {
      return 'scanned'; // Has actual OCR text from camera scanning
    } else {
      return 'manual'; // Fallback for any other cases
    }
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


  // Responsive Filter Layout
  Widget _buildResponsiveFilterLayout(BuildContext context, List<dynamic> filteredBills) {
    // Check if location filter is enabled
    if (_isLocationFilterEnabled) {
      // Use 2x2 grid layout when location is enabled to prevent overflow
      return Column(
        children: [
          // First row: Source and Category
          Row(
            children: [
              Expanded(
                child: _buildFilterButton(
                  label: 'Source',
                  icon: Icons.source,
                  selectedValue: _getSourceDisplayName(_selectedSource),
                  onTap: () => _showSourceDropdown(context, filteredBills),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterButton(
                  label: 'Category',
                  icon: Icons.category,
                  selectedValue: _getCategoryDisplayName(_selectedCategoryFilter),
                  onTap: () => _showCategoryDropdown(context, filteredBills),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Second row: Location (full width)
          _buildFilterButton(
            label: 'Location',
            icon: Icons.location_on,
            selectedValue: _getLocationDisplayName(_selectedLocation),
            onTap: () => _showLocationDropdown(context, filteredBills),
          ),
        ],
      );
    } else {
      // Use single row layout when location is disabled
      return Row(
        children: [
          Expanded(
            child: _buildFilterButton(
              label: 'Source',
              icon: Icons.source,
              selectedValue: _getSourceDisplayName(_selectedSource),
              onTap: () => _showSourceDropdown(context, filteredBills),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterButton(
              label: 'Category',
              icon: Icons.category,
              selectedValue: _getCategoryDisplayName(_selectedCategoryFilter),
              onTap: () => _showCategoryDropdown(context, filteredBills),
            ),
          ),
        ],
      );
    }
  }

  // Compact Filter Button
  Widget _buildFilterButton({
    required String label,
    required IconData icon,
    required String selectedValue,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.blue[600]),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Text(
              label,
              style: TextStyle(
                      fontSize: 10,
                fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedValue,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  // Display name helpers
  String _getSourceDisplayName(String source) {
    switch (source) {
      case 'all': return 'All Sources';
      case 'scanned': return 'Scanned';
      case 'manual': return 'Manual';
      default: return 'All Sources';
    }
  }

  String _getLocationDisplayName(String location) {
    return location == 'all' ? 'All Locations' : location;
  }

  String _getCategoryDisplayName(String category) {
    return category == 'all' ? 'All Categories' : category;
  }

  // Dropdown show methods - using normal dropdowns
  void _showSourceDropdown(BuildContext context, List<dynamic> filteredBills) {
    final RenderBox buttonBox = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        buttonBox.localToGlobal(Offset.zero, ancestor: overlay),
        buttonBox.localToGlobal(buttonBox.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 8,
      items: _buildSourceMenuItems(filteredBills),
    ).then((value) {
      if (value != null) {
        setState(() {
          _selectedSource = value;
        });
      }
    });
  }

  void _showLocationDropdown(BuildContext context, List<dynamic> filteredBills) {
    final RenderBox buttonBox = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        buttonBox.localToGlobal(Offset.zero, ancestor: overlay),
        buttonBox.localToGlobal(buttonBox.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 8,
      items: _buildLocationMenuItems(filteredBills),
    ).then((value) {
      if (value != null) {
        setState(() {
          _selectedLocation = value;
        });
      }
    });
  }

  void _showCategoryDropdown(BuildContext context, List<dynamic> filteredBills) {
    final RenderBox buttonBox = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        buttonBox.localToGlobal(Offset.zero, ancestor: overlay),
        buttonBox.localToGlobal(buttonBox.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 8,
      items: _buildCategoryMenuItems(filteredBills),
    ).then((value) {
      if (value != null) {
        setState(() {
          _selectedCategoryFilter = value;
        });
      }
    });
  }

  // Menu item builders
  List<PopupMenuEntry<String>> _buildSourceMenuItems(List<dynamic> filteredBills) {
    return [
      _buildMenuItem(
        'all',
        'All Sources',
        Icons.all_inclusive,
        _getSourceCount(filteredBills, 'all'),
        _selectedSource == 'all',
      ),
      _buildMenuItem(
        'scanned',
        'Scanned',
        Icons.camera_alt,
        _getSourceCount(filteredBills, 'scanned'),
        _selectedSource == 'scanned',
      ),
      _buildMenuItem(
        'manual',
        'Manual',
        Icons.edit_note,
        _getSourceCount(filteredBills, 'manual'),
        _selectedSource == 'manual',
      ),
    ];
  }

  List<PopupMenuEntry<String>> _buildLocationMenuItems(List<dynamic> filteredBills) {
    return [
      _buildMenuItem(
        'all',
        'All Locations',
        Icons.all_inclusive,
        _getLocationCount(filteredBills, 'all'),
        _selectedLocation == 'all',
      ),
      ..._getUniqueLocations(filteredBills).map((location) => 
        _buildMenuItem(
          location,
          location,
          Icons.place,
          _getLocationCount(filteredBills, location),
          _selectedLocation == location,
        ),
      ),
    ];
  }

  List<PopupMenuEntry<String>> _buildCategoryMenuItems(List<dynamic> filteredBills) {
    return [
      _buildMenuItem(
        'all',
        'All Categories',
        Icons.all_inclusive,
        _getCategoryCount(filteredBills, 'all'),
        _selectedCategoryFilter == 'all',
      ),
      ..._getUniqueCategories(filteredBills).map((category) => 
        _buildMenuItem(
          category,
          category,
          Icons.label,
          _getCategoryCount(filteredBills, category),
          _selectedCategoryFilter == category,
        ),
      ),
    ];
  }

  PopupMenuItem<String> _buildMenuItem(
    String value,
    String label,
    IconData icon,
    int count,
    bool isSelected,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[600], size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.blue[700] : Colors.grey[800],
              ),
            ),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ),
          const SizedBox(width: 8),
          if (isSelected)
            Icon(Icons.check, color: Colors.green[600], size: 18),
        ],
      ),
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
                'Create manual expenses, subscriptions, or SEPA payments\nusing the plus button on the homepage.',
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
      
      // Then filter by category
      if (_selectedCategoryFilter != 'all') {
        final billCategory = bill.categoryId?.toLowerCase() ?? '';
        if (billCategory != _selectedCategoryFilter.toLowerCase()) {
          return false;
        }
      }
      
      // Finally filter by search query
       final query = _searchQuery.toLowerCase();
       return (bill.vendor?.toLowerCase().contains(query) ?? false) ||
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
        filteredBills.sort((a, b) => (a.vendor ?? '').compareTo(b.vendor ?? ''));
        break;
      case 'name_desc':
        filteredBills.sort((a, b) => (b.vendor ?? '').compareTo(a.vendor ?? ''));
        break;
      case 'total_desc':
        filteredBills.sort((a, b) => (b.total ?? 0.0).compareTo(a.total ?? 0.0));
        break;
      case 'total_asc':
        filteredBills.sort((a, b) => (a.total ?? 0.0).compareTo(b.total ?? 0.0));
        break;
    }

    // Group bills by year and month
    final Map<String, Map<String, List<dynamic>>> groupedBills = {};
    for (final bill in filteredBills) {
      final year = DateFormat('yyyy').format(bill.date ?? DateTime.now());
      final month = DateFormat('MMMM yyyy').format(bill.date ?? DateTime.now());
      
      if (!groupedBills.containsKey(year)) {
        groupedBills[year] = {};
      }
      if (!groupedBills[year]!.containsKey(month)) {
        groupedBills[year]![month] = [];
      }
      groupedBills[year]![month]!.add(bill);
    }

    // Sort years and months
    final sortedYears = groupedBills.keys.toList()..sort((a, b) => b.compareTo(a));
    
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
          // View Toggle Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // List View Button
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _viewMode = 'list';
                    });
                  },
                  icon: Icon(
                    Icons.list,
                    size: 18,
                    color: _viewMode == 'list' ? Colors.white : Colors.grey[600],
                  ),
                  label: Text(
                    'List',
                    style: TextStyle(
                      color: _viewMode == 'list' ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _viewMode == 'list' 
                        ? const Color(0xFF4facfe) 
                        : Colors.grey[100],
                    foregroundColor: _viewMode == 'list' 
                        ? Colors.white 
                        : Colors.grey[600],
                    elevation: _viewMode == 'list' ? 2 : 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: _viewMode == 'list' 
                            ? const Color(0xFF4facfe) 
                            : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                  ),
                ),
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
            ],
          ),
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
      body: Column(
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
          
          // View Mode Content
          Expanded(
            child: _viewMode == 'list' 
                ? _buildListView(filteredBills, groupedBills, sortedYears)
                : _buildCalendarView(filteredBills),
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
  Widget _buildListView(List<dynamic> filteredBills, Map<String, Map<String, List<dynamic>>> groupedBills, List<String> sortedYears) {
    return Column(
      children: [
          // Organized Filter Section - Only show in list view
          if (_viewMode == 'list') ...[
           Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
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
                      Icon(Icons.filter_list, size: 20, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Filter Receipts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      // Premium indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.amber[400]!, Colors.amber[600]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Premium',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
               ],
             ),
           ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Responsive Filter Layout
                  _buildResponsiveFilterLayout(context, filteredBills),
                ],
              ),
            ),
          ],
          
                     // Info text
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                     Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                     const SizedBox(width: 8),
                     Text(
                       _selectedCategory == 'manual' 
                           ? 'Manual Entries: Expenses, subscriptions, and SEPA payments created via plus button'
                           : _selectedCategory == 'scanned'
                               ? 'Scanned Receipts: Camera-scanned receipts with OCR text'
                               : 'All entries: Both scanned receipts and manual entries',
                       style: TextStyle(
                         fontSize: 12,
                         color: Colors.grey[600],
                         fontStyle: FontStyle.italic,
                       ),
                     ),
                   ],
                 ),
                 const SizedBox(height: 4),
                 Padding(
                   padding: const EdgeInsets.only(left: 24),
                   child: Text(
                     _selectedCategory == 'manual'
                         ? '💡 These entries are created manually from the homepage plus button'
                         : _selectedCategory == 'scanned'
                             ? '💡 These receipts are scanned using the camera'
                             : '💡 Use tabs above to filter between different entry types',
                     style: TextStyle(
                       fontSize: 11,
                       color: Colors.grey[500],
                       fontStyle: FontStyle.italic,
                     ),
                   ),
                 ),
               ],
             ),
           ),
          
          // Year/Month Filter
          if (groupedBills.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          final monthBills = groupedBills[year]![month]!;
                          
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
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: monthBills.length,
                                itemBuilder: (context, index) {
                                  final bill = monthBills[index];
                                  return GestureDetector(
                                    onTap: () {
                                      _showBillOptions(context, bill);
                                    },
                                    onLongPress: () {
                                      _showBillOptions(context, bill);
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withOpacity(0.2),
                                            spreadRadius: 1,
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          // Receipt Image
                                          Container(
                                            width: 100,
                                            height: 120,
                                            decoration: BoxDecoration(
                                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                                              image: DecorationImage(
                                                image: FileImage(File(bill.imagePath)),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          
                                          // Bill Details
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        bill.vendor ?? 'Unknown Vendor',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                          color: Colors.black87,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        DateFormat('MMM dd, yyyy').format(bill.date ?? DateTime.now()),
                                                        style: TextStyle(
                                                          color: Colors.grey[600],
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        '${(bill.total ?? 0.0).toStringAsFixed(2)} ${bill.currency ?? ''}',
                                                        style: const TextStyle(
                                                          color: Color(0xFF4facfe),
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.all(4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey[100],
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Icon(
                                                          Icons.touch_app,
                                                          color: Colors.grey[600],
                                                          size: 16,
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
                                    ),
                                  );
                                },
                              ),
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
                          child: Card(
                            child: Column(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                      image: DecorationImage(
                                        image: FileImage(File(bill.imagePath)),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    children: [
                                      Text(
                                        bill.vendor ?? 'Unknown',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${(bill.total ?? 0.0).toStringAsFixed(2)} ${bill.currency ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF4facfe),
                                        ),
                                      ),
                                    ],
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
}