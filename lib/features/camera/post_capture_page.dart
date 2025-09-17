import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/services/premium_service.dart';
import '../../core/services/ocr/mlkit_ocr_service.dart';
import '../../features/storage/bill/bill_provider.dart';
import '../../features/storage/models/bill_model.dart';

class PostCapturePage extends ConsumerStatefulWidget {
  final String imagePath;
  final String? detectedTitle;
  final double? detectedTotal;
  final String? detectedCurrency;
  final DateTime? detectedDate;
  final bool isEditing;
  final Bill? existingBill;

  const PostCapturePage({
    super.key,
    required this.imagePath,
    this.detectedTitle,
    this.detectedTotal,
    this.detectedCurrency,
    this.detectedDate,
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
  bool _isOcrProcessing = false;
  List<Map<String, dynamic>> _groceryItems = [];
  bool _showOcrResults = false;
  bool _isSaving = false;
  String? _detectedCurrency;
  String? _selectedCurrency;
  
  // Common currencies for manual selection
  final List<String> _commonCurrencies = [
    'USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'CHF', 'CNY', 'SEK', 'NOK',
    'DKK', 'PLN', 'CZK', 'HUF', 'RUB', 'BRL', 'MXN', 'INR', 'KRW', 'SGD',
    'HKD', 'NZD', 'ZAR', 'TRY', 'THB', 'MYR', 'PHP', 'IDR', 'VND', 'TWD'
  ];

  @override
  void initState() {
    super.initState();
    _initializeFields();
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
      _locationController.text = bill.location ?? '';
      _notesController.text = bill.notes ?? '';
      
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
      
      _titleController.text = widget.detectedTitle ?? '';
      _totalController.text = widget.detectedTotal?.toStringAsFixed(2) ?? '';
      _detectedCurrency = widget.detectedCurrency;
      _selectedCurrency = widget.detectedCurrency; // Only set if currency was detected
      _selectedDate = widget.detectedDate ?? DateTime.now();















      
      
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
    
    // Force UI update
    if (mounted) {
      setState(() {});
    }
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

  Future<void> _performOcrScan() async {
    if (!PremiumService.isOcrAvailable) {
      _showPremiumUpgradeDialog();
      return;
    }

    setState(() {
      _isOcrProcessing = true;
    });

    try {
      final ocrService = MlKitOcrService();
      final file = File(widget.imagePath);
      
      // Check if this is a preprocessed image (from camera pipeline)
      // If so, use processPreprocessedImage to avoid double preprocessing
      final result = file.path.contains('preprocessed') 
          ? await ocrService.processPreprocessedImage(file)
          : await ocrService.processImage(file);
      
      // Parse the OCR result to extract items
      final items = _parseOcrToItems(result.rawText);
      setState(() {
        _groceryItems = items;
        _showOcrResults = true;
        _detectedCurrency = result.currency;
        _selectedCurrency = result.currency; // Only set if currency was detected
      });
        
      // Update total if detected
      if (result.total != null) {
        _totalController.text = result.total!.toStringAsFixed(2);
      }
      
      // Update vendor if detected
      if (result.vendor != null && result.vendor!.isNotEmpty) {
        _titleController.text = result.vendor!;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR processing failed: $e')),
      );
    } finally {
      setState(() {
        _isOcrProcessing = false;
      });
    }
  }

  List<Map<String, dynamic>> _parseOcrToItems(String ocrText) {
    final lines = ocrText.split('\n');
    final items = <Map<String, dynamic>>[];
    
    for (String line in lines) {
      // Simple regex to find items with prices
      final priceRegex = RegExp(r'(\d+\.\d{2})');
      final match = priceRegex.firstMatch(line);
      
      if (match != null) {
        final price = double.tryParse(match.group(1) ?? '0');
        final itemName = line.replaceAll(priceRegex, '').trim();
        
        if (itemName.isNotEmpty && price != null && price > 0) {
          items.add({
            'name': itemName,
            'price': price,
            'quantity': 1,
            'isEditable': true,
          });
        }
      }
    }
    
    return items;
  }

  void _showPremiumUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔒 Premium Feature'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('OCR Text Extraction is a premium feature.'),
            const SizedBox(height: 16),
            const Text('Premium features include:'),
            const SizedBox(height: 8),
            ...PremiumService.premiumFeatures.map((feature) => 
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(feature),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              PremiumService.showPremiumUpgrade();
            },
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    print('🔍 DATE PICKER: Current selected date: $_selectedDate');
    print('🔍 DATE PICKER: Detected date from widget: ${widget.detectedDate}');
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900), // Allow older dates for receipts
      lastDate: DateTime.now().add(const Duration(days: 365)), // Allow some future dates
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

    setState(() {
      _isSaving = true;
    });

    try {
      // Parse total amount
      final total = double.tryParse(_totalController.text) ?? 0.0;
      
      // Prepare tags and location
      final tags = _tagController.text.trim();
      final tagList = tags.isNotEmpty 
        ? tags.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList()
        : null;
      
      final location = _locationController.text.trim();
      final locationValue = location.isNotEmpty ? location : null;

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
          categoryId: existingBill.categoryId,
          subtotal: existingBill.subtotal,
          tax: existingBill.tax,
          notes: _notesController.text.trim(),
          tags: tagList,
          location: locationValue,
          createdAt: existingBill.createdAt,
          updatedAt: DateTime.now(),
        );

        // Update the bill in database
        ref.read(billProvider.notifier).updateBill(updatedBill);

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
          tags: tagList,
          location: locationValue,
          notes: _notesController.text.trim(),
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
              // Receipt Image Preview
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Fallback OCR Loading Indicator
              if (_isOcrProcessing && 
                  (widget.detectedTitle == null || widget.detectedTitle!.isEmpty) &&
                  (widget.detectedTotal == null))
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Analyzing receipt...',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // OCR Scan Button
              if (!_showOcrResults)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _isOcrProcessing ? null : _performOcrScan,
                    icon: _isOcrProcessing 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.document_scanner),
                    label: Text(_isOcrProcessing ? 'Processing...' : 'Extract Text (Premium)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumService.isOcrAvailable 
                        ? Colors.blue 
                        : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Basic Information
              const Text(
                'Receipt Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Title/Company Name
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Store/Company Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter store name';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Total Amount
              TextFormField(
                controller: _totalController,
                decoration: const InputDecoration(
                  labelText: 'Total Amount',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
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
              
              const SizedBox(height: 16),
              
              // Currency Selection
              InkWell(
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
                    ),
                    helperText: _detectedCurrency != null 
                        ? 'Detected: $_detectedCurrency (tap to change)'
                        : 'Currency not detected - Please select currency',
                    helperStyle: TextStyle(
                      color: _detectedCurrency != null ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: _detectedCurrency == null ? FontWeight.w600 : FontWeight.normal,
                    ),
                    errorText: _selectedCurrency == null ? 'Required' : null,
                  ),
                  child: Text(
                    _selectedCurrency ?? '⚠️ Select Currency (Required)',
                    style: TextStyle(
                      color: _selectedCurrency != null ? Colors.black : Colors.red,
                      fontWeight: _selectedCurrency == null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              
              // Date
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.calendar_today),
                    helperText: widget.detectedDate != null 
                        ? 'Date detected from receipt' 
                        : 'Date not detected - using current date',
                    helperStyle: TextStyle(
                      color: widget.detectedDate != null ? Colors.green : Colors.orange,
                      fontSize: 12,
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
              
              // Tag
              TextFormField(
                controller: _tagController,
                decoration: const InputDecoration(
                  labelText: 'Tag (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                  hintText: 'e.g., Groceries, Work, Personal',
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Location
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
              
              // Notes
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
              
              const SizedBox(height: 24),
              
              // OCR Results (if available)
              if (_showOcrResults && _groceryItems.isNotEmpty) ...[
                const Text(
                  'Detected Items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
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
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}


