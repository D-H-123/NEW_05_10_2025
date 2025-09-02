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
  final bool isEditing;
  final Bill? existingBill;

  const PostCapturePage({
    super.key,
    required this.imagePath,
    this.detectedTitle,
    this.detectedTotal,
    this.detectedCurrency,
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
      
      _titleController.text = widget.detectedTitle ?? '';
      _totalController.text = widget.detectedTotal?.toStringAsFixed(2) ?? '';
      _detectedCurrency = widget.detectedCurrency;
      _selectedDate = DateTime.now();
      
      // FALLBACK: If no data was detected, run OCR analysis again
      if ((widget.detectedTitle == null || widget.detectedTitle!.isEmpty) && 
          (widget.detectedTotal == null)) {
        print('🔍 MAGIC POST-CAPTURE: No data detected, running fallback OCR...');
        // Run fallback OCR after a short delay to ensure UI is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _runFallbackOcr();
          }
        });
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

  /// Fallback OCR analysis when no data is detected from camera
  Future<void> _runFallbackOcr() async {
    print('🔍 MAGIC POST-CAPTURE: Running fallback OCR analysis...');
    
    try {
      setState(() {
        _isOcrProcessing = true;
      });

      final ocrService = MlKitOcrService();
      final file = File(widget.imagePath);
      final result = await ocrService.processImage(file);
      
      if (result != null) {
        print('🔍 MAGIC POST-CAPTURE: Fallback OCR successful!');
        print('  Vendor: "${result.vendor}"');
        print('  Total: ${result.total}');
        print('  Currency: "${result.currency}"');
        
        // Update the fields with detected data
        if (result.vendor != null && result.vendor!.isNotEmpty) {
          _titleController.text = result.vendor!;
        }
        if (result.total != null) {
          _totalController.text = result.total!.toStringAsFixed(2);
        }
        if (result.currency != null) {
          _detectedCurrency = result.currency;
        }
        
        // Force UI update
        if (mounted) {
          setState(() {});
        }
        
        print('🔍 MAGIC POST-CAPTURE: Fields updated after fallback OCR');
        print('  Title controller: "${_titleController.text}"');
        print('  Total controller: "${_totalController.text}"');
        print('  Currency: "$_detectedCurrency"');
      } else {
        print('🔍 MAGIC POST-CAPTURE: Fallback OCR returned null result');
      }
    } catch (e) {
      print('🔍 MAGIC POST-CAPTURE: Fallback OCR failed: $e');
    } finally {
      setState(() {
        _isOcrProcessing = false;
      });
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
      final result = await ocrService.processImage(file);
      
      if (result != null) {
        // Parse the OCR result to extract items
        final items = _parseOcrToItems(result.rawText);
        setState(() {
          _groceryItems = items;
          _showOcrResults = true;
          _detectedCurrency = result.currency;
        });
        
        // Update total if detected
        if (result.total != null) {
          _totalController.text = result.total!.toStringAsFixed(2);
        }
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveReceipt() async {
    if (!_formKey.currentState!.validate()) return;

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
          currency: _detectedCurrency,
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
          currency: _detectedCurrency,
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
              
              // Currency Display
              if (_detectedCurrency != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.currency_exchange, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Detected Currency: $_detectedCurrency',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              
              if (_detectedCurrency != null) const SizedBox(height: 16),
              
              // Date
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
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


