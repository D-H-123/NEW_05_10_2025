import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/category_service.dart';
import '../../core/widgets/unified_category_dropdown.dart';

enum FormType {
  manualExpense,
  subscription,
}

class DynamicExpenseModal extends StatefulWidget {
  final FormType formType;
  final String selectedCurrency;
  final Function(Map<String, dynamic>) onSubmit;
  final dynamic existingBill; // Optional existing bill for editing

  const DynamicExpenseModal({
    super.key,
    required this.formType,
    required this.selectedCurrency,
    required this.onSubmit,
    this.existingBill,
  });

  @override
  State<DynamicExpenseModal> createState() => _DynamicExpenseModalState();
}

class _DynamicExpenseModalState extends State<DynamicExpenseModal> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for all possible fields
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _notesController = TextEditingController();
  final _subscriptionNameController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  
  // Form state
  String? _selectedCategory;
  String? _selectedFrequency;
  String? _selectedSubscriptionCategory;
  DateTime? _selectedDate;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _isEndDateEnabled = false;

  // Predefined options - using centralized service
  List<String> get _categories => CategoryService.manualExpenseCategories;

  final List<String> _frequencies = [
    'Weekly',
    'Monthly',
    'Yearly',
  ];

  // Categories relevant to subscriptions only - using centralized service
  List<String> get _subscriptionCategories => CategoryService.subscriptionCategories;


  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    final now = DateTime.now();
    _selectedDate = now;
    _selectedStartDate = now;
    
    // If editing existing bill, pre-fill the form
    if (widget.existingBill != null) {
      _prefillFormWithExistingData();
      return;
    }
    
    // Set default values based on form type for new entries
    switch (widget.formType) {
      case FormType.manualExpense:
        _dateController.text = _formatDate(now);
        _selectedCategory = 'Food & Dining';
        break;
      case FormType.subscription:
        _startDateController.text = _formatDate(now);
        _selectedFrequency = 'Monthly';
        _selectedSubscriptionCategory = 'Entertainment';
        break;
    }
  }

  void _prefillFormWithExistingData() {
    final bill = widget.existingBill;
    
    // Common fields
    _titleController.text = bill.title ?? bill.vendor ?? '';
    _amountController.text = bill.total?.toString() ?? '';
    _notesController.text = bill.notes ?? '';
    
    // Set date fields
    if (bill.date != null) {
      _selectedDate = bill.date;
      _dateController.text = _formatDate(bill.date!);
    }
    
    // Set category
    if (bill.tags != null && bill.tags!.isNotEmpty) {
      _selectedCategory = bill.tags!.first;
    }
    
    // Form-specific fields
    switch (widget.formType) {
      case FormType.manualExpense:
        // Manual expense specific fields are already set above
        break;
      case FormType.subscription:
        // Set subscription-specific fields
        _subscriptionNameController.text = bill.title ?? bill.vendor ?? '';
        _selectedSubscriptionCategory = bill.tags?.isNotEmpty == true ? bill.tags!.first : 'Entertainment';
        _selectedFrequency = bill.subscriptionType != null ? _capitalize(bill.subscriptionType!) : 'Monthly';
        _frequencyController.text = _selectedFrequency ?? 'Monthly';
        
        // Set start date
        if (bill.date != null) {
          _selectedStartDate = bill.date;
          _startDateController.text = _formatDate(bill.date!);
        }
        
        // Set end date if available (this would need to be stored in the bill model)
        // For now, we'll leave it empty as it's not currently stored
        break;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  IconData _getCurrencyIcon(String currency) {
    switch (currency) {
      case 'USD':
        return Icons.attach_money;
      case 'EUR':
        return Icons.euro;
      case 'GBP':
        return Icons.currency_pound;
      case 'CAD':
        return Icons.attach_money;
      case 'AUD':
        return Icons.attach_money;
      case 'CHF':
        return Icons.attach_money;
      case 'INR':
        return Icons.currency_rupee;
      case 'BRL':
        return Icons.attach_money;
      default:
        return Icons.attach_money;
    }
  }

  Color _getCurrencyColor(String currency) {
    switch (currency) {
      case 'USD':
        return Colors.green;
      case 'EUR':
        return Colors.blue;
      case 'GBP':
        return Colors.red;
      case 'CAD':
        return Colors.red;
      case 'AUD':
        return Colors.green;
      case 'CHF':
        return Colors.red;
      case 'INR':
        return Colors.orange;
      case 'BRL':
        return Colors.green;
      default:
        return Colors.green;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    _subscriptionNameController.dispose();
    _frequencyController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  String _getFormTitle() {
    switch (widget.formType) {
      case FormType.manualExpense:
        return 'Add Manual Expense';
      case FormType.subscription:
        return 'Add Subscription';
    }
  }

  Widget _buildFormFields() {
    switch (widget.formType) {
      case FormType.manualExpense:
        return _buildManualExpenseForm();
      case FormType.subscription:
        return _buildSubscriptionForm();
    }
  }

  Widget _buildManualExpenseForm() {
    return Column(
      children: [
        _buildTextField(
          controller: _titleController,
          label: 'Title',
          hint: 'e.g., Lunch with team',
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a title';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildDateField(
          controller: _dateController,
          label: 'Date',
          selectedDate: _selectedDate,
          onDateSelected: (date) {
            setState(() {
              _selectedDate = date;
              _dateController.text = _formatDate(date);
            });
          },
          allowFutureDates: false, // Manual expenses should not allow future dates
        ),
        const SizedBox(height: 16),
        _buildAmountField(),
        const SizedBox(height: 16),
        _buildCategoryDropdown(),
        const SizedBox(height: 16),
        _buildNotesField(),
      ],
    );
  }

  Widget _buildSubscriptionForm() {
    return Column(
      children: [
        _buildTextField(
          controller: _titleController,
          label: 'Title',
          hint: 'e.g., Netflix Subscription',
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a title';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildAmountField(),
        const SizedBox(height: 16),
        _buildSubscriptionCategoryDropdown(),
        const SizedBox(height: 16),
        _buildFrequencyDropdown(),
        const SizedBox(height: 16),
        _buildDateField(
          controller: _startDateController,
          label: 'Start Date',
          selectedDate: _selectedStartDate,
          onDateSelected: (date) {
            setState(() {
              _selectedStartDate = date;
              _startDateController.text = _formatDate(date);
            });
          },
          allowFutureDates: false, // Subscription start date should not allow future dates
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          title: const Text('Set End Date'),
          value: _isEndDateEnabled,
          onChanged: (value) {
            setState(() {
              _isEndDateEnabled = value ?? false;
              if (!_isEndDateEnabled) {
                _endDateController.clear();
                _selectedEndDate = null;
              }
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (_isEndDateEnabled) const SizedBox(height: 16),
        if (_isEndDateEnabled)
          _buildDateField(
            controller: _endDateController,
            label: 'End Date',
            selectedDate: _selectedEndDate,
            onDateSelected: (date) {
              setState(() {
                _selectedEndDate = date;
                _endDateController.text = _formatDate(date);
              });
            },
            allowFutureDates: true, // Subscription end date should allow future dates
            validator: (value) {
              if (_isEndDateEnabled && (value == null || value.isEmpty)) {
                return 'Please select end date';
              }
              if (_selectedEndDate != null && _selectedStartDate != null) {
                if (_selectedEndDate!.isBefore(_selectedStartDate!)) {
                  return 'End date must be after start date';
                }
              }
              return null;
            },
          ),
        const SizedBox(height: 16),
        _buildNotesField(),
      ],
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required DateTime? selectedDate,
    required Function(DateTime) onDateSelected,
    String? Function(String?)? validator,
    bool allowFutureDates = false, // New parameter to control future dates
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.calendar_today),
        suffixIcon: IconButton(
          icon: const Icon(Icons.date_range),
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: allowFutureDates ? DateTime(2030) : DateTime.now(), // Restrict future dates unless allowed
            );
            if (date != null) {
              onDateSelected(date);
            }
          },
        ),
      ),
      validator: validator,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: allowFutureDates ? DateTime(2030) : DateTime.now(), // Restrict future dates unless allowed
        );
        if (date != null) {
          onDateSelected(date);
        }
      },
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      decoration: InputDecoration(
        labelText: 'Amount',
        border: const OutlineInputBorder(),
        prefixIcon: Icon(
          _getCurrencyIcon(widget.selectedCurrency),
          color: _getCurrencyColor(widget.selectedCurrency),
        ),
        hintText: '0.00',
        suffixText: widget.selectedCurrency,
        suffixStyle: TextStyle(
          color: _getCurrencyColor(widget.selectedCurrency),
          fontWeight: FontWeight.w600,
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter amount';
        }
        final amount = double.tryParse(value);
        if (amount == null || amount <= 0) {
          return 'Please enter a valid amount';
        }
        return null;
      },
    );
  }

  Widget _buildCategoryDropdown() {
    return UnifiedCategoryFormField(
      selectedCategory: _selectedCategory,
      categories: _categories,
      onChanged: (value) {
        setState(() {
          _selectedCategory = value;
        });
      },
      label: 'Category',
      hint: 'Select a category',
      isRequired: true,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a category';
        }
        return null;
      },
      showIcons: true,
      showColors: true,
    );
  }

  Widget _buildFrequencyDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedFrequency,
      decoration: const InputDecoration(
        labelText: 'Frequency',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.repeat),
      ),
      items: _frequencies.map((frequency) {
        return DropdownMenuItem(
          value: frequency,
          child: Text(frequency),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedFrequency = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select frequency';
        }
        return null;
      },
    );
  }

  Widget _buildSubscriptionCategoryDropdown() {
    return UnifiedCategoryFormField(
      selectedCategory: _selectedSubscriptionCategory,
      categories: _subscriptionCategories,
      onChanged: (value) {
        setState(() {
          _selectedSubscriptionCategory = value;
        });
      },
      label: 'Subscription Category',
      hint: 'Select a category',
      isRequired: true,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a category';
        }
        return null;
      },
      showIcons: true,
      showColors: true,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      decoration: const InputDecoration(
        labelText: 'Notes (Optional)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.note),
        hintText: 'Additional notes...',
      ),
      maxLines: 3,
    );
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Collect form data
    final formData = <String, dynamic>{
      'formType': widget.formType.toString(),
      'amount': double.parse(_amountController.text),
      'notes': _notesController.text.trim(),
      'title': _titleController.text.trim(),
    };

    // Add type-specific data
    switch (widget.formType) {
      case FormType.manualExpense:
        formData.addAll({
          'date': _selectedDate,
          'category': _selectedCategory,
        });
        break;
      case FormType.subscription:
        formData.addAll({
          'subscriptionCategory': _selectedSubscriptionCategory,
          'frequency': _selectedFrequency,
          'startDate': _selectedStartDate,
          'endDate': _selectedEndDate,
        });
        break;
    }

    widget.onSubmit(formData);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getFormTitle(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _buildFormFields(),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Submit',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
}