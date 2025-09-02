import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum FormType {
  manualExpense,
  subscription,
  sepaTransfer,
}

class DynamicExpenseModal extends StatefulWidget {
  final FormType formType;
  final String selectedCurrency;
  final Function(Map<String, dynamic>) onSubmit;

  const DynamicExpenseModal({
    super.key,
    required this.formType,
    required this.selectedCurrency,
    required this.onSubmit,
  });

  @override
  State<DynamicExpenseModal> createState() => _DynamicExpenseModalState();
}

class _DynamicExpenseModalState extends State<DynamicExpenseModal> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for all possible fields
  final _dateController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _notesController = TextEditingController();
  final _subscriptionNameController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _bankNameController = TextEditingController();
  
  // Form state
  String? _selectedCategory;
  String? _selectedFrequency;
  String? _selectedTransferType;
  DateTime? _selectedDate;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _isEndDateEnabled = false;

  // Predefined options
  final List<String> _categories = [
    'Food & Dining',
    'Transportation',
    'Shopping',
    'Entertainment',
    'Healthcare',
    'Utilities',
    'Home & Garden',
    'Education',
    'Travel',
    'Other',
  ];

  final List<String> _frequencies = [
    'Weekly',
    'Monthly',
    'Quarterly',
    'Yearly',
  ];

  final List<String> _transferTypes = [
    'One-time',
    'Recurring',
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    final now = DateTime.now();
    _selectedDate = now;
    _selectedStartDate = now;
    
    // Set default values based on form type
    switch (widget.formType) {
      case FormType.manualExpense:
        _dateController.text = _formatDate(now);
        _selectedCategory = 'Food & Dining';
        break;
      case FormType.subscription:
        _startDateController.text = _formatDate(now);
        _selectedFrequency = 'Monthly';
        break;
      case FormType.sepaTransfer:
        _selectedTransferType = 'One-time';
        break;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  IconData _getCurrencyIcon(String currency) {
    switch (currency) {
      case 'USD':
        return Icons.attach_money;
      case 'EUR':
        return Icons.euro;
      case 'GBP':
        return Icons.currency_pound;
      case 'JPY':
        return Icons.currency_yen;
      case 'CAD':
        return Icons.attach_money;
      case 'AUD':
        return Icons.attach_money;
      case 'CHF':
        return Icons.attach_money;
      case 'CNY':
        return Icons.currency_yen;
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
      case 'JPY':
        return Colors.orange;
      case 'CAD':
        return Colors.red;
      case 'AUD':
        return Colors.green;
      case 'CHF':
        return Colors.red;
      case 'CNY':
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
    _dateController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    _subscriptionNameController.dispose();
    _frequencyController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  String _getFormTitle() {
    switch (widget.formType) {
      case FormType.manualExpense:
        return 'Add Manual Expense';
      case FormType.subscription:
        return 'Add Subscription';
      case FormType.sepaTransfer:
        return 'Add SEPA Transfer';
    }
  }

  Widget _buildFormFields() {
    switch (widget.formType) {
      case FormType.manualExpense:
        return _buildManualExpenseForm();
      case FormType.subscription:
        return _buildSubscriptionForm();
      case FormType.sepaTransfer:
        return _buildSEPATransferForm();
    }
  }

  Widget _buildManualExpenseForm() {
    return Column(
      children: [
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
          controller: _subscriptionNameController,
          label: 'Subscription Name',
          hint: 'e.g., Netflix, Spotify',
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter subscription name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildAmountField(),
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

  Widget _buildSEPATransferForm() {
    return Column(
      children: [
        _buildTextField(
          controller: _bankNameController,
          label: 'Bank Name',
          hint: 'e.g., Deutsche Bank, Commerzbank',
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter bank name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildAmountField(),
        const SizedBox(height: 16),
        _buildTransferTypeRadio(),
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
              lastDate: DateTime(2030),
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
          lastDate: DateTime(2030),
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
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.category),
      ),
      items: _categories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(category),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategory = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a category';
        }
        return null;
      },
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

  Widget _buildTransferTypeRadio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transfer Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        RadioListTile<String>(
          title: const Text('One-time'),
          value: 'One-time',
          groupValue: _selectedTransferType,
          onChanged: (value) {
            setState(() {
              _selectedTransferType = value;
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<String>(
          title: const Text('Recurring'),
          value: 'Recurring',
          groupValue: _selectedTransferType,
          onChanged: (value) {
            setState(() {
              _selectedTransferType = value;
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    int maxLines = 1,
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

    // Validate transfer type for SEPA form
    if (widget.formType == FormType.sepaTransfer && _selectedTransferType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select transfer type')),
      );
      return;
    }

    // Collect form data
    final formData = <String, dynamic>{
      'formType': widget.formType.toString(),
      'amount': double.parse(_amountController.text),
      'notes': _notesController.text.trim(),
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
          'subscriptionName': _subscriptionNameController.text.trim(),
          'frequency': _selectedFrequency,
          'startDate': _selectedStartDate,
          'endDate': _selectedEndDate,
        });
        break;
      case FormType.sepaTransfer:
        formData.addAll({
          'bankName': _bankNameController.text.trim(),
          'transferType': _selectedTransferType,
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