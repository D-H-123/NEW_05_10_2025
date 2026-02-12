import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/category_service.dart';
import '../../core/services/local_storage_service.dart';
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
  
  // Settings state
  bool _isNotesEnabled = false;

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
    _loadSettings();
    _initializeForm();
  }
  
  void _loadSettings() {
    _isNotesEnabled = LocalStorageService.getBoolSetting(LocalStorageService.kNotes);
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
        
        // Set end date if available
        if (bill.subscriptionEndDate != null) {
          print('🔍 DEBUG: Loading end date: ${bill.subscriptionEndDate}');
          _selectedEndDate = bill.subscriptionEndDate;
          _endDateController.text = _formatDate(bill.subscriptionEndDate!);
          _isEndDateEnabled = true;
          print('🔍 DEBUG: End date loaded - selected: $_selectedEndDate, controller: ${_endDateController.text}, enabled: $_isEndDateEnabled');
        } else {
          print('🔍 DEBUG: No end date found in bill');
        }
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
            // Check if title contains at least one letter
            if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
              return 'Title must contain at least one letter';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildAmountField(),
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
            // Check if title contains at least one letter
            if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
              return 'Title must contain at least one letter';
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
          label: 'Last Payment Date',
          hint: 'When did you last pay for this subscription?',
          selectedDate: _selectedStartDate,
          onDateSelected: (date) {
            setState(() {
              _selectedStartDate = date;
              _startDateController.text = _formatDate(date);
            });
          },
          allowFutureDates: false, // Last payment date should not allow future dates
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
            hint: 'When will this subscription end? (Optional)',
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
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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
    return _InlineSimpleDropdown(
      value: _selectedFrequency,
      items: _frequencies,
      label: 'Frequency',
      icon: Icons.repeat,
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
    if (!_isNotesEnabled) {
      return const SizedBox.shrink();
    }
    
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Collect form data
    final formData = <String, dynamic>{
      'formType': widget.formType.toString(),
      'amount': double.parse(_amountController.text),
      'notes': _isNotesEnabled ? _notesController.text.trim() : '',
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
        print('🔍 DEBUG: Form submission - endDate: $_selectedEndDate, isEndDateEnabled: $_isEndDateEnabled');
        break;
    }

    await widget.onSubmit(formData);
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.85,
          maxWidth: 600,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getFormTitle(),
                    style: const TextStyle(
                      fontSize: 22,
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
            ),
            
            // Form
            Flexible(
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.disabled,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: _buildFormFields(),
                ),
              ),
            ),
            
            // Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
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
            ),
          ],
        ),
      ),
    );
  }
  
  /// Shows the modal as a dialog (faster, recommended)
  static Future<void> showAsDialog(
    BuildContext context, {
    required FormType formType,
    required String selectedCurrency,
    required Function(Map<String, dynamic>) onSubmit,
    dynamic existingBill,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => DynamicExpenseModal(
        formType: formType,
        selectedCurrency: selectedCurrency,
        onSubmit: onSubmit,
        existingBill: existingBill,
      ),
    );
  }
  
  /// Shows the modal as a bottom sheet (legacy support)
  static Future<void> showAsBottomSheet(
    BuildContext context, {
    required FormType formType,
    required String selectedCurrency,
    required Function(Map<String, dynamic>) onSubmit,
    dynamic existingBill,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: DynamicExpenseModal(
          formType: formType,
          selectedCurrency: selectedCurrency,
          onSubmit: onSubmit,
          existingBill: existingBill,
        ),
      ),
    );
  }
}

/// Custom inline dropdown that stays within dialog boundaries
class _InlineSimpleDropdown extends StatefulWidget {
  final String? value;
  final List<String> items;
  final String label;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const _InlineSimpleDropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.icon,
    required this.onChanged,
    this.validator,
  });

  @override
  State<_InlineSimpleDropdown> createState() => _InlineSimpleDropdownState();
}

class _InlineSimpleDropdownState extends State<_InlineSimpleDropdown> {
  bool _isOpen = false;

  void _toggleDropdown() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  void _selectItem(String item) {
    widget.onChanged(item);
    _toggleDropdown();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown Button
        InkWell(
          onTap: _toggleDropdown,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: _isOpen ? Colors.blue.shade400 : Colors.grey.shade300,
                width: _isOpen ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              boxShadow: _isOpen
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.value ?? 'Select ${widget.label.toLowerCase()}',
                        style: TextStyle(
                          fontSize: 16,
                          color: widget.value != null
                              ? Colors.grey.shade800
                              : Colors.grey.shade500,
                          fontWeight: widget.value != null
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey.shade600,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Dropdown Menu (inline)
        if (_isOpen)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final isSelected = widget.value == item;

                return InkWell(
                  onTap: () => _selectItem(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue.shade50
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 16,
                              color: isSelected
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade800,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // Validation Error
        if (widget.validator != null)
          Builder(
            builder: (context) {
              final error = widget.validator!(widget.value);
              if (error != null && error.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8, left: 12),
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 12,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }
}