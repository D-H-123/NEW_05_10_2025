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

  Widget _buildCategoryTab(String category, String label, IconData icon) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4facfe) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
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
    
    // Filter bills based on search query and category
    final filteredBills = bills.where((bill) {
      // First filter by category
      if (_selectedCategory != 'all') {
        final billCategory = _getBillCategory(bill);
        if (billCategory != _selectedCategory) {
          return false;
        }
      }
      
             // Then filter by search query
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
          
          
          
                     // Category Tabs
           Container(
             height: 50,
             padding: const EdgeInsets.symmetric(horizontal: 16),
             child: ListView(
               scrollDirection: Axis.horizontal,
               children: [
                 _buildCategoryTab('all', 'All (${bills.length})', Icons.all_inclusive),
                 _buildCategoryTab('scanned', 'Scanned (${bills.where((b) => _getBillCategory(b) == 'scanned').length})', Icons.camera_alt),
                 _buildCategoryTab('manual', 'Manual (${bills.where((b) => _getBillCategory(b) == 'manual').length})', Icons.edit_note),
               ],
             ),
           ),
          
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
          
          // Bills Grid
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
                                      // Show bill options instead of going directly to edit
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
      ),
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
                // Already on storage/bills page
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
}