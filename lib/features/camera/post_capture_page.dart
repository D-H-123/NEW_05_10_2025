import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../features/storage/bill/bill_provider.dart';
import '../../features/storage/models/bill_model.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/ocr/i_ocr_service.dart';
import '../../core/theme/app_colors.dart';

class PostCapturePage extends ConsumerStatefulWidget {
  final String imagePath;
  final String? detectedTitle;
  final double? detectedTotal;
  final String? detectedCurrency;
  final DateTime? detectedDate;
  final String? detectedCategory;
  final List<AmountCandidate>? totalCandidates;
  final bool isEditing;
  final Bill? existingBill;

  const PostCapturePage({
    super.key,
    required this.imagePath,
    this.detectedTitle,
    this.detectedTotal,
    this.detectedCurrency,
    this.detectedDate,
    this.detectedCategory,
    this.totalCandidates,
    this.isEditing = false,
    this.existingBill,
  });

  @override
  ConsumerState<PostCapturePage> createState() => _PostCapturePageState();
}

class _PostCapturePageState extends ConsumerState<PostCapturePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _totalController = TextEditingController();
  final _tagController = TextEditingController();
  final _locationController = TextEditingController();
  final _warrantyController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime? _selectedDate;
  final bool _isOcrProcessing = false;
  final List<Map<String, dynamic>> _groceryItems = [];
  final bool _showOcrResults = false;
  bool _isSaving = false;
  String? _detectedCurrency;
  String? _selectedCurrency;
  String? _detectedCategory;
  String? _selectedCategory;
  List<AmountCandidate> _totalCandidates = const [];
  
  // Settings state
  bool _isNotesEnabled = false;
  bool _isLocationEnabled = false;

  /// Step 3: Low-confidence hints – show "Review suggested" when OCR result is missing or ambiguous.
  bool get _vendorNeedsReview =>
      !widget.isEditing &&
      (widget.detectedTitle == null ||
          widget.detectedTitle!.isEmpty ||
          widget.detectedTitle!.trim().length < 3);
  bool get _totalNeedsReview =>
      !widget.isEditing &&
      (widget.detectedTotal == null ||
          (widget.totalCandidates != null && widget.totalCandidates!.length > 1));
  bool get _dateNeedsReview =>
      !widget.isEditing && widget.detectedDate == null;
  
  // Common currencies for manual selection
  final List<String> _commonCurrencies = [
    'USD', 'EUR', 'GBP', 'CAD', 'AUD', 'CHF', 'INR', 'BRL'
  ];

  // Available categories for user selection
  final List<String> _availableCategoriesList = [
    'Services',
    'Groceries',
    'Food & Dining',
    'Transport & Fuel',
    'Pharmacy & Health',
    'Furniture & Home',
    'Electronics',
    'Fashion & Clothing',
    'Entertainment',
    'Utilities',
    'Insurance',
    'Education',
    'Travel',
    'Personal Care',
    'Office Supplies',
    'Other'
  ];

  /// Step 9: Map OCR-detected category (parser output) to a list item so the chip is pre-selected.
  String? _mapDetectedCategoryToList(String? detected) {
    if (detected == null || detected.isEmpty) return null;
    final d = detected.trim();
    if (_availableCategoriesList.any((c) => c == d)) return d;
    final lower = d.toLowerCase();
    if (lower.contains('transport')) return 'Transport & Fuel';
    if (lower.contains('health') || lower.contains('pharmacy')) return 'Pharmacy & Health';
    if (lower.contains('home') || lower.contains('garden') || lower.contains('furniture')) return 'Furniture & Home';
    if (lower.contains('shopping') || lower.contains('retail')) return 'Other';
    final firstWord = lower.split(' ').first;
    if (firstWord.isEmpty) return null;
    for (final c in _availableCategoriesList) {
      if (c.toLowerCase().contains(firstWord)) return c;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initializeFields();
  }

  void _loadSettings() {
    _isNotesEnabled = LocalStorageService.getBoolSetting(LocalStorageService.kNotes);
    _isLocationEnabled = LocalStorageService.getBoolSetting(LocalStorageService.kLocation);
  }

  void _initializeFields() {
    print('🔍 MAGIC POST-CAPTURE: Initializing fields');
    print('🔍 MAGIC POST-CAPTURE: Is editing: ${widget.isEditing}');
    
    if (widget.isEditing == true && widget.existingBill != null) {
      // Editing existing bill
      final bill = widget.existingBill!;
      print('🔍 MAGIC POST-CAPTURE: Loading existing bill data');
      
      _titleController.text = bill.vendor ?? '';
      _totalController.text = bill.total?.toStringAsFixed(2) ?? '';
      _detectedCurrency = bill.currency;
      _selectedCurrency = bill.currency; // Set selected currency for existing bills
      _selectedDate = bill.date ?? DateTime.now();
      _tagController.text = bill.tags?.join(', ') ?? '';
      _selectedCategory = bill.categoryId;
      if (_isLocationEnabled) {
        _locationController.text = bill.location ?? '';
      }
      if (_isNotesEnabled) {
        _notesController.text = bill.notes ?? '';
      }
      
      print('🔍 MAGIC POST-CAPTURE: Loaded existing bill:');
      print('  Vendor: "${bill.vendor}"');
      print('  Total: ${bill.total}');
      print('  Currency: "${bill.currency}"');
      print('  Date: ${bill.date}');
      print('  Tags: ${bill.tags}');
      print('  Location: ${bill.location}');
      print('  Notes: ${bill.notes}');
    } else {
      // New bill from camera
      print('🔍 MAGIC POST-CAPTURE: Loading new bill data');
      print('🔍 MAGIC POST-CAPTURE: Detected title: "${widget.detectedTitle}"');
      print('🔍 MAGIC POST-CAPTURE: Detected total: ${widget.detectedTotal}');
      print('🔍 MAGIC POST-CAPTURE: Detected currency: "${widget.detectedCurrency}"');
      print('🔍 MAGIC POST-CAPTURE: Detected date: ${widget.detectedDate}');
      print('🔍 MAGIC POST-CAPTURE: Detected category: "${widget.detectedCategory}"');
      
      _titleController.text = widget.detectedTitle ?? '';
      _totalController.text = widget.detectedTotal?.toStringAsFixed(2) ?? '';
      _detectedCurrency = widget.detectedCurrency;
      _selectedCurrency = widget.detectedCurrency ?? ref.read(currencyProvider).currencyCode;
      _selectedDate = widget.detectedDate ?? DateTime.now();
      
      // Step 9: Pre-select OCR category (map to list item so a chip is selected)
      if (widget.detectedCategory != null && widget.detectedCategory!.isNotEmpty) {
        _detectedCategory = widget.detectedCategory;
        final listCategory = _mapDetectedCategoryToList(widget.detectedCategory);
        _selectedCategory = listCategory ?? widget.detectedCategory;
        _tagController.text = _selectedCategory ?? widget.detectedCategory!;
        print('🔍 MAGIC POST-CAPTURE: Auto-selected category: "${_selectedCategory}" (from "${widget.detectedCategory}")');
      }















      
      
      print('🔍 MAGIC POST-CAPTURE: Final selected date: $_selectedDate');
      print('🔍 MAGIC POST-CAPTURE: Using detected date: ${widget.detectedDate != null}');
      
      // OCR data should already be available from camera page
      // No need for fallback OCR - data was extracted when user clicked "Extract Text"
      if ((widget.detectedTitle == null || widget.detectedTitle!.isEmpty) && 
          (widget.detectedTotal == null)) {
        print('🔍 MAGIC POST-CAPTURE: No OCR data received from camera page');
        print('🔍 MAGIC POST-CAPTURE: This should not happen - OCR was already performed');
      }
    }
    
    print('🔍 MAGIC POST-CAPTURE: Title controller text: "${_titleController.text}"');
    print('🔍 MAGIC POST-CAPTURE: Total controller text: "${_totalController.text}"');
    print('🔍 MAGIC POST-CAPTURE: Detected currency set to: "$_detectedCurrency"');
    if (_selectedCurrency == null || _selectedCurrency!.isEmpty) {
      _selectedCurrency = ref.read(currencyProvider).currencyCode;
    }

    _totalCandidates = widget.totalCandidates ?? const [];
    
    // Force UI update
    if (mounted) {
      setState(() {});
    }
  }


  /// Parse amount string handling both US and European formats
  double? _parseAmount(String amountStr) {
    if (amountStr.isEmpty) return null;
    
    // Remove any currency symbols and spaces
    String cleaned = amountStr.replaceAll(RegExp(r'[\$€£¥₹\s]'), '');
    
    // Handle different decimal separators
    if (cleaned.contains(',') && cleaned.contains('.')) {
      final lastComma = cleaned.lastIndexOf(',');
      final lastDot = cleaned.lastIndexOf('.');
      
      if (lastComma > lastDot) {
        // European style: 1.234,56
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // US style: 1,234.56
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains(',')) {
      // Could be thousands separator or decimal
      final commaIndex = cleaned.lastIndexOf(',');
      final digitsAfterComma = cleaned.substring(commaIndex + 1).length;
      final digitsBefore = cleaned.substring(0, commaIndex);
      
      if (digitsAfterComma == 2 && !digitsBefore.contains(',') && 
          !digitsBefore.contains('.') && digitsBefore.length <= 6) {
        // Likely decimal: 12,34
        cleaned = cleaned.replaceAll(',', '.');
      } else {
        // Likely thousands: 1,234 or 12,345
        cleaned = cleaned.replaceAll(',', '');
      }
    }
    
    return double.tryParse(cleaned);
  }

  String _formatCandidateAmount(AmountCandidate candidate) {
    final amount = candidate.amount.toStringAsFixed(2);
    if (candidate.currency == null || candidate.currency!.isEmpty) {
      return amount;
    }
    return '$amount ${candidate.currency}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalController.dispose();
    _tagController.dispose();
    _locationController.dispose();
    _warrantyController.dispose();
    _notesController.dispose();
    super.dispose();
  }



  String _getCurrencySymbol() {
    switch (_selectedCurrency) {
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
      case 'INR':
        return '₹';
      case 'BRL':
        return 'R\$';
      case 'MXN':
        return 'MX\$';
      case 'KRW':
        return '₩';
      case 'SGD':
        return 'S\$';
      case 'HKD':
        return 'HK\$';
      case 'NZD':
        return 'NZ\$';
      case 'SEK':
        return 'kr';
      case 'NOK':
        return 'kr';
      case 'DKK':
        return 'kr';
      case 'PLN':
        return 'zł';
      case 'CZK':
        return 'Kč';
      case 'HUF':
        return 'Ft';
      case 'RUB':
        return '₽';
      case 'TRY':
        return '₺';
      case 'ZAR':
        return 'R';
      case 'ILS':
        return '₪';
      case 'AED':
        return 'د.إ';
      case 'SAR':
        return 'ر.س';
      case 'THB':
        return '฿';
      case 'MYR':
        return 'RM';
      case 'IDR':
        return 'Rp';
      case 'PHP':
        return '₱';
      case 'VND':
        return '₫';
      default:
        return '\$'; // Default to USD symbol
    }
  }

  Future<void> _selectDate() async {
    print('🔍 DATE PICKER: Current selected date: $_selectedDate');
    print('🔍 DATE PICKER: Detected date from widget: ${widget.detectedDate}');
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900), // Allow older dates for receipts
      lastDate: DateTime.now(), // Restrict future dates - only current/past dates allowed
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _selectCurrency() async {
    final String? selected = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Currency'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: _commonCurrencies.length,
              itemBuilder: (context, index) {
                final currency = _commonCurrencies[index];
                final isSelected = currency == _selectedCurrency;
                return ListTile(
                  title: Text(currency),
                  trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                  selected: isSelected,
                  onTap: () {
                    Navigator.of(context).pop(currency);
                  },
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
        );
      },
    );
    
    if (selected != null) {
      setState(() {
        _selectedCurrency = selected;
      });
    }
  }


  Future<void> _saveReceipt() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check if currency is selected
    if (_selectedCurrency == null || _selectedCurrency!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a currency before saving'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check if tag is provided
    if (_tagController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category/tag before saving'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Parse total amount (handle both US and European formats)
      final total = _parseAmount(_totalController.text) ?? 0.0;
      
      // Prepare tags and location
      final tags = _tagController.text.trim();
      final tagList = tags.isNotEmpty 
        ? tags.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList()
        : null;
      
      final location = _isLocationEnabled ? _locationController.text.trim() : '';
      final locationValue = _isLocationEnabled && location.isNotEmpty ? location : null;

      if (widget.isEditing && widget.existingBill != null) {
        // Update existing bill
        final existingBill = widget.existingBill!;
        print('🔍 MAGIC POST-CAPTURE: Updating existing bill: ${existingBill.id}');
        
        final updatedBill = Bill(
          id: existingBill.id,
          imagePath: widget.imagePath,
          vendor: _titleController.text.trim(),
          date: _selectedDate ?? DateTime.now(),
          total: total,
          currency: _selectedCurrency,
          ocrText: existingBill.ocrText,
          categoryId: _selectedCategory,
          subtotal: existingBill.subtotal,
          tax: existingBill.tax,
          notes: _isNotesEnabled ? _notesController.text.trim() : '',
          tags: tagList,
          location: locationValue,
          subscriptionType: existingBill.subscriptionType, // Preserve existing subscription type
          subscriptionEndDate: existingBill.subscriptionEndDate, // Preserve existing end date
          createdAt: existingBill.createdAt,
          updatedAt: DateTime.now(),
        );

        // Update the bill in database
        ref.read(billProvider.notifier).updateBill(updatedBill);

        print('🔍 DEBUG: Scanned receipt updated successfully - ID: ${updatedBill.id}, Title: ${updatedBill.vendor}, Total: ${updatedBill.total}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt updated successfully!')),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          context.go('/bills');
        }
      } else {
        // Create new bill
        print('🔍 MAGIC POST-CAPTURE: Creating new bill');
        
        // Create a unique ID for the bill
        final billId = DateTime.now().millisecondsSinceEpoch.toString();

        // Create the bill object
        final bill = Bill(
          id: billId,
          imagePath: widget.imagePath,
          vendor: _titleController.text.trim(),
          date: _selectedDate ?? DateTime.now(),
          total: total,
          currency: _selectedCurrency,
          ocrText: _groceryItems.isNotEmpty 
            ? _groceryItems.map((item) => '${item['name']}: ${_detectedCurrency ?? '\$'}${item['price']}').join('\n')
            : 'Scanned receipt', // This identifies it as scanned, not manual
          categoryId: _selectedCategory,
          tags: tagList,
          location: locationValue,
          notes: _isNotesEnabled ? _notesController.text.trim() : '',
        );

        // Save the bill to database
        ref.read(billProvider.notifier).addBill(bill);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt saved successfully!')),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          context.go('/bills');
        }
      }
    } catch (e) {
      print('🔍 MAGIC POST-CAPTURE: Error saving receipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save receipt: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔍 MAGIC POST-CAPTURE: Building widget');
    print('🔍 MAGIC POST-CAPTURE: Title controller text: "${_titleController.text}"');
    print('🔍 MAGIC POST-CAPTURE: Total controller text: "${_totalController.text}"');
    print('🔍 MAGIC POST-CAPTURE: Detected currency: "$_detectedCurrency"');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Details'),
        actions: [
          // Reset button to go back to camera
          IconButton(
            onPressed: _isSaving ? null : () {
              print('🔄 POST-CAPTURE: Reset button pressed, going back to camera');
              context.go('/scan');
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset & Try Again',
          ),
          // Save button
          IconButton(
            onPressed: _isSaving ? null : _saveReceipt,
            icon: _isSaving 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
            tooltip: 'Save Receipt',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Receipt Image Preview (Step 10: theme colors)
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.bottomNavBackground, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.bottomNavBackground.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain, // Changed from cover to contain to show full image
                    alignment: Alignment.center,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Fallback OCR Loading Indicator (theme colors)
              if (_isOcrProcessing && 
                  (widget.detectedTitle == null || widget.detectedTitle!.isEmpty) &&
                  (widget.detectedTotal == null))
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bottomNavBackground.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.bottomNavBackground.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.bottomNavBackground.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Analyzing receipt...',
                          style: TextStyle(
                            color: AppColors.bottomNavBackground,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              
              // Basic Information (theme color)
              Text(
                'Receipt Information',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: AppColors.bottomNavBackground,
                ),
              ),
              const SizedBox(height: 16),
              
              // Title/Company Name
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Store/Company Name *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.store),
                  helperText: _vendorNeedsReview ? 'Review suggested' : null,
                  helperStyle: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter store name';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Currency and Amount (Responsive Horizontal Layout)
              LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive breakpoints
                  final screenWidth = constraints.maxWidth;
                  final isSmallScreen = screenWidth < 360;
                  final isVerySmallScreen = screenWidth < 320;
                  
                  // Adjust flex ratios based on screen size - give more space to currency
                  final currencyFlex = isVerySmallScreen ? 3 : (isSmallScreen ? 4 : 4);
                  final amountFlex = isVerySmallScreen ? 5 : (isSmallScreen ? 6 : 6);
                  
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Currency Field (Responsive width)
                      Expanded(
                        flex: currencyFlex,
                        child: InkWell(
                          onTap: _selectCurrency,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Currency *',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: _selectedCurrency == null ? Colors.red : Colors.grey,
                                  width: _selectedCurrency == null ? 2 : 1,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.currency_exchange,
                                color: _selectedCurrency == null ? Colors.red : Colors.grey,
                                size: isVerySmallScreen ? 18 : 20,
                              ),
                              suffixIcon: Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.grey.shade600,
                                size: isVerySmallScreen ? 18 : 20,
                              ),
                              errorText: _selectedCurrency == null ? 'Required' : null,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isVerySmallScreen ? 8 : 12,
                                vertical: isVerySmallScreen ? 12 : 16,
                              ),
                            ),
                            child: Text(
                              _selectedCurrency ?? 'Select Currency',
                              style: TextStyle(
                                color: _selectedCurrency == null ? Colors.red : Colors.black,
                                fontWeight: _selectedCurrency == null ? FontWeight.w600 : FontWeight.normal,
                                fontSize: isVerySmallScreen ? 13 : 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(width: isVerySmallScreen ? 8 : 12),
                      
                      // Amount Field (Responsive width)
                      Expanded(
                        flex: amountFlex,
                        child: TextFormField(
                          controller: _totalController,
                          decoration: InputDecoration(
                            labelText: 'Total Amount *',
                            border: const OutlineInputBorder(),
                            prefixText: _getCurrencySymbol(),
                            prefixStyle: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                              fontSize: isVerySmallScreen ? 14 : 16,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isVerySmallScreen ? 8 : 12,
                              vertical: isVerySmallScreen ? 12 : 16,
                            ),
                            helperText: _totalNeedsReview ? 'Review suggested' : null,
                            helperStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter total amount';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid amount';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              if (_totalCandidates.isNotEmpty) ...[
                Text(
                  'Suggested Totals',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _totalCandidates.map((candidate) {
                    return ActionChip(
                      label: Text(
                        _formatCandidateAmount(candidate),
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          _totalController.text = candidate.amount.toStringAsFixed(2);
                          if (candidate.currency != null && candidate.currency!.isNotEmpty) {
                            _selectedCurrency = candidate.currency;
                          }
                        });
                      },
                      backgroundColor: Colors.blue.shade50,
                      labelStyle: TextStyle(color: Colors.blue.shade800),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
              
              // Date
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.calendar_today),
                    helperText: _dateNeedsReview ? 'Review suggested' : null,
                    helperStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  child: Text(
                    _selectedDate != null
                        ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                        : 'Select Date',
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Tag/Category (Now compulsory)
              TextFormField(
                controller: _tagController,
                decoration: InputDecoration(
                  labelText: 'Category *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.category),
                  errorText: _tagController.text.trim().isEmpty ? 'Category is required' : null,
                ),
                readOnly: true,
                onTap: () {
                  // Focus on the field to show keyboard if needed
                },
              ),
              
              const SizedBox(height: 16),
              
              // Step 9: Hint when category was detected – confirm or change
              if (!widget.isEditing && _detectedCategory != null && _detectedCategory!.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Detected: $_detectedCategory. Confirm or change below.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              
              // Category selection chips (Responsive)
              LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  final isVerySmallScreen = screenWidth < 320;
                  
                  return SizedBox(
                    height: isVerySmallScreen ? 50 : 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _availableCategoriesList.length,
                      itemBuilder: (context, index) {
                        final category = _availableCategoriesList[index];
                        final isSelected = _selectedCategory == category;
                        final isDetected = _detectedCategory == category;
                        
                        return Padding(
                          padding: EdgeInsets.only(right: isVerySmallScreen ? 8.0 : 12.0),
                          child: FilterChip(
                            label: Text(
                              category,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey.shade700,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                fontSize: isVerySmallScreen ? 12 : 14,
                              ),
                            ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = category;
                            _tagController.text = category;
                          });
                        },
                        backgroundColor: isDetected 
                            ? Colors.blue.shade50 
                            : Colors.grey.shade50,
                        selectedColor: Colors.blue.shade600,
                        checkmarkColor: Colors.white,
                        side: BorderSide(
                          color: isDetected 
                              ? Colors.blue.shade300 
                              : Colors.grey.shade300,
                          width: 1.5,
                        ),
                        avatar: isDetected 
                            ? Icon(
                                Icons.auto_awesome, 
                                size: 18, 
                                color: Colors.blue.shade600,
                              )
                            : null,
                        elevation: isSelected ? 2 : 0,
                        shadowColor: Colors.blue.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  },
                ),
              );
                },
              ),
              
              const SizedBox(height: 16),
              
              // Location (only if enabled in settings)
              if (_isLocationEnabled) ...[
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                    hintText: 'e.g., Walmart, Downtown',
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              const SizedBox(height: 16),
              
              // Warranty Reminder
              TextFormField(
                controller: _warrantyController,
                decoration: const InputDecoration(
                  labelText: 'Warranty Reminder (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.warning),
                  hintText: 'e.g., 90 days warranty',
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Notes (only if enabled in settings)
              if (_isNotesEnabled) ...[
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                    hintText: 'Additional notes...',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
              ],
              
              // OCR Results (if available)
              if (_showOcrResults && _groceryItems.isNotEmpty) ...[
                Text(
                  'Detected Items',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _groceryItems.length,
                    itemBuilder: (context, index) {
                      final item = _groceryItems[index];
                      return ListTile(
                        title: Text(item['name']),
                        subtitle: Text('Quantity: ${item['quantity']}'),
                        trailing: Text(
                          '\$${item['price'].toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        leading: const Icon(Icons.shopping_cart),
                      );
                    },
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}


