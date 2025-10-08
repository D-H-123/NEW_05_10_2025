import 'package:flutter/material.dart';
import '../services/category_service.dart';

class UnifiedCategoryDropdown extends StatefulWidget {
  final String? selectedCategory;
  final List<String> categories;
  final ValueChanged<String?> onChanged;
  final String? label;
  final String? hint;
  final bool isRequired;
  final String? Function(String?)? validator;
  final double? width;
  final bool showIcons;
  final bool showColors;
  final bool isExpanded;
  final EdgeInsetsGeometry? padding;
  const UnifiedCategoryDropdown({
    super.key,
    this.selectedCategory,
    required this.categories,
    required this.onChanged,
    this.label,
    this.hint,
    this.isRequired = false,
    this.validator,
    this.width,
    this.showIcons = true,
    this.showColors = true,
    this.isExpanded = true,
    this.padding,
  });

  @override
  State<UnifiedCategoryDropdown> createState() => _UnifiedCategoryDropdownState();
}

class _UnifiedCategoryDropdownState extends State<UnifiedCategoryDropdown>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isOpen = false;
  List<String> _filteredCategories = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _filteredCategories = widget.categories;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _onCategorySelected(String category) {
    widget.onChanged(category);
    _toggleDropdown();
  }


  Widget _buildDropdownButton() {
    final selectedCategory = widget.selectedCategory;
    final categoryInfo = selectedCategory != null
        ? CategoryService.getCategoryInfo(selectedCategory)
        : null;

    return InkWell(
      onTap: _toggleDropdown,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: widget.width,
        padding: widget.padding ?? const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
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
            if (widget.showIcons && categoryInfo != null) ...[
              Icon(
                categoryInfo.icon,
                color: widget.showColors ? categoryInfo.color : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.label != null) ...[
                    Text(
                      widget.label!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    selectedCategory ?? widget.hint ?? 'Select category',
                    style: TextStyle(
                      fontSize: 16,
                      color: selectedCategory != null
                          ? Colors.grey.shade800
                          : Colors.grey.shade500,
                      fontWeight: selectedCategory != null
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
    );
  }

  Widget _buildDropdownMenu() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scaleY: _animation.value,
          alignment: Alignment.topCenter,
          child: Opacity(
            opacity: _animation.value,
            child: Container(
              width: widget.width,
              constraints: const BoxConstraints(maxHeight: 300),
              margin: const EdgeInsets.only(top: 8),
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
                itemCount: _filteredCategories.length,
                itemBuilder: (context, index) {
                  final category = _filteredCategories[index];
                  final isSelected = widget.selectedCategory == category;
                  final categoryInfo = CategoryService.getCategoryInfo(category);

                  return _buildCategoryItem(
                    category: category,
                    categoryInfo: categoryInfo,
                    isSelected: isSelected,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildCategoryItem({
    required String category,
    CategoryInfo? categoryInfo,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _onCategorySelected(category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
        ),
        child: Row(
          children: [
            if (widget.showIcons && categoryInfo != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.showColors
                      ? categoryInfo.color.withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  categoryInfo.icon,
                  color: widget.showColors ? categoryInfo.color : Colors.grey.shade600,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.blue.shade700 : Colors.grey.shade800,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.blue.shade600,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropdownButton(),
        if (_isOpen) _buildDropdownMenu(),
        if (widget.validator != null && widget.isRequired)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.validator!(widget.selectedCategory) ?? '',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

// Convenience widget for form fields
class UnifiedCategoryFormField extends StatelessWidget {
  final String? selectedCategory;
  final List<String> categories;
  final ValueChanged<String?> onChanged;
  final String? label;
  final String? hint;
  final bool isRequired;
  final String? Function(String?)? validator;
  final double? width;
  final bool showIcons;
  final bool showColors;

  const UnifiedCategoryFormField({
    super.key,
    this.selectedCategory,
    required this.categories,
    required this.onChanged,
    this.label,
    this.hint,
    this.isRequired = false,
    this.validator,
    this.width,
    this.showIcons = true,
    this.showColors = true,
  });

  @override
  Widget build(BuildContext context) {
    return UnifiedCategoryDropdown(
      selectedCategory: selectedCategory,
      categories: categories,
      onChanged: onChanged,
      label: label,
      hint: hint,
      isRequired: isRequired,
      validator: validator,
      width: width,
      showIcons: showIcons,
      showColors: showColors,
    );
  }
}
