import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/custom_category.dart';
import '../../core/services/local_storage_service.dart';

class CustomCategoriesPage extends StatefulWidget {
  const CustomCategoriesPage({super.key});

  @override
  State<CustomCategoriesPage> createState() => _CustomCategoriesPageState();
}

class _CustomCategoriesPageState extends State<CustomCategoriesPage> {
  List<CustomCategory> _customCategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    setState(() {
      _isLoading = true;
    });
    
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        _customCategories = LocalStorageService.getAllCustomCategories();
        _isLoading = false;
      });
    });
  }

  void _addNewCategory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategoryFormModal(
        onSave: (category) async {
          await LocalStorageService.addCustomCategory(category);
          _loadCategories();
        },
      ),
    );
  }

  void _editCategory(CustomCategory category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategoryFormModal(
        existingCategory: category,
        onSave: (updatedCategory) async {
          await LocalStorageService.updateCustomCategory(updatedCategory);
          _loadCategories();
        },
      ),
    );
  }

  void _deleteCategory(CustomCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${category.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await LocalStorageService.deleteCustomCategory(category.id);
              if (mounted) {
                Navigator.pop(context);
                _loadCategories();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${category.name} deleted'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Categories'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _customCategories.isEmpty
              ? _buildEmptyState()
              : _buildCategoryList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewCategory,
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF16213e),
        foregroundColor: Colors.white,
        label: const Text('Add Category'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Custom Categories',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your own categories to personalize your expense tracking',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addNewCategory,
              icon: const Icon(Icons.add),
              label: const Text('Create First Category'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: const Color(0xFF16213e),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _customCategories.length,
      itemBuilder: (context, index) {
        final category = _customCategories[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: category.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  category.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            title: Text(
              category.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Available in: ${category.availableIn.join(", ")}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (category.keywords.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Keywords: ${category.keywords.take(3).join(", ")}${category.keywords.length > 3 ? "..." : ""}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF16213e),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFF4facfe)),
                onPressed: () => _editCategory(category),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteCategory(category),
              ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CategoryFormModal extends StatefulWidget {
  final CustomCategory? existingCategory;
  final Function(CustomCategory) onSave;

  const CategoryFormModal({
    super.key,
    this.existingCategory,
    required this.onSave,
  });

  @override
  State<CategoryFormModal> createState() => _CategoryFormModalState();
}

class _CategoryFormModalState extends State<CategoryFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _keywordsController = TextEditingController();
  
  String _selectedEmoji = '📦';
  Color _selectedColor = const Color(0xFF16213e);
  Set<String> _selectedTypes = {'receipt', 'expense', 'subscription'};
  
  final List<String> _commonEmojis = [
    '📦', '🎯', '💼', '🎨', '🏠', '🚗', '✈️', '🎮', '📱', '💡',
    '🔧', '🎵', '📚', '⚽', '🏋️', '🍔', '☕', '🎭', '🏥', '📄',
    '💰', '🎁', '🛍️', '🏖️', '🌟', '⚡', '🔥', '💎', '🎪', '🎬',
  ];
  
  final List<Color> _commonColors = [
    const Color(0xFF16213e), // Navy blue (primary)
  
    Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
    Colors.indigo, Colors.blue,  Colors.cyan,
    Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
    Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
    Colors.brown, Colors.grey, Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingCategory != null) {
      final cat = widget.existingCategory!;
      _nameController.text = cat.name;
      _selectedEmoji = cat.emoji;
      _selectedColor = cat.color;
      _selectedTypes = Set<String>.from(cat.availableIn);
      _keywordsController.text = cat.keywords.join(', ');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keywordsController.dispose();
    super.dispose();
  }

  void _saveCategory() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one section'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final keywords = _keywordsController.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    final category = CustomCategory(
      id: widget.existingCategory?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      emoji: _selectedEmoji,
      colorValue: _selectedColor.value,
      keywords: keywords,
      availableIn: _selectedTypes.toList(),
      createdAt: widget.existingCategory?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    widget.onSave(category);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Title
                Text(
                  widget.existingCategory == null ? 'Add Custom Category' : 'Edit Category',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Category Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.label),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4facfe), width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a category name';
                    }
                    
                    // Check if category name already exists
                    if (LocalStorageService.customCategoryExists(
                      value.trim(),
                      excludeId: widget.existingCategory?.id,
                    )) {
                      return 'A category with this name already exists';
                    }
                    
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Emoji Selector
                const Text(
                  'Select Symbol/Emoji',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _commonEmojis.length,
                    itemBuilder: (context, index) {
                      final emoji = _commonEmojis[index];
                      final isSelected = emoji == _selectedEmoji;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedEmoji = emoji),
                        child: Container(
                          width: 50,
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF16213e).withOpacity(0.2)
                                : const Color(0xFF16213e).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF16213e) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                
                // Color Picker
                const Text(
                  'Select Color',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _commonColors.map((color) {
                    final isSelected = color == _selectedColor;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF4facfe) : const Color(0xFF16213e),
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: const Color(0xFF4facfe).withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ] : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                
                // Available In Sections
                const Text(
                  'Available In',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: Text(
                        'Receipt Scanning',
                        style: TextStyle(
                          color: _selectedTypes.contains('receipt')
                              ? const Color(0xFF4facfe)
                              : Colors.grey[600],
                          fontWeight: _selectedTypes.contains('receipt')
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      selected: _selectedTypes.contains('receipt'),
                      selectedColor: const Color(0xFF16213e),
                      backgroundColor: Colors.grey[200],
                      checkmarkColor: const Color(0xFF4facfe),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTypes.add('receipt');
                          } else {
                            _selectedTypes.remove('receipt');
                          }
                        });
                      },
                    ),
                    FilterChip(
                      label: Text(
                        'Manual Expense',
                        style: TextStyle(
                          color: _selectedTypes.contains('expense')
                              ? const Color(0xFF4facfe)
                              : Colors.grey[600],
                          fontWeight: _selectedTypes.contains('expense')
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      selected: _selectedTypes.contains('expense'),
                      selectedColor: const Color(0xFF16213e),
                      backgroundColor: Colors.grey[200],
                      checkmarkColor: const Color(0xFF4facfe),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTypes.add('expense');
                          } else {
                            _selectedTypes.remove('expense');
                          }
                        });
                      },
                    ),
                    FilterChip(
                      label: Text(
                        'Subscription',
                        style: TextStyle(
                          color: _selectedTypes.contains('subscription')
                              ? const Color(0xFF4facfe)
                              : Colors.grey[600],
                          fontWeight: _selectedTypes.contains('subscription')
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      selected: _selectedTypes.contains('subscription'),
                      selectedColor: const Color(0xFF16213e),
                      backgroundColor: Colors.grey[200],
                      checkmarkColor: const Color(0xFF4facfe),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTypes.add('subscription');
                          } else {
                            _selectedTypes.remove('subscription');
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Keywords (Optional)
                TextFormField(
                  controller: _keywordsController,
                  decoration: InputDecoration(
                    labelText: 'Keywords (Optional)',
                    helperText: 'Comma-separated keywords for auto-detection in OCR',
                    helperMaxLines: 2,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4facfe), width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveCategory,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF16213e),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      widget.existingCategory == null ? 'Create Category' : 'Update Category',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

