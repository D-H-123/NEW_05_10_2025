import 'package:flutter/material.dart';
import '../services/category_service.dart';

class FilterDropdown extends StatefulWidget {
  final String? selectedValue;
  final List<FilterItem> items;
  final ValueChanged<String?> onChanged;
  final String label;
  final IconData icon;
  final double? width;
  final bool showIcons;
  final bool showColors;
  final bool isCategoryFilter;

  const FilterDropdown({
    super.key,
    this.selectedValue,
    required this.items,
    required this.onChanged,
    required this.label,
    required this.icon,
    this.width,
    this.showIcons = true,
    this.showColors = true,
    this.isCategoryFilter = false,
  });

  @override
  State<FilterDropdown> createState() => _FilterDropdownState();
}

class _FilterDropdownState extends State<FilterDropdown>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isOpen = false;
  List<FilterItem> _filteredItems = [];

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
    _filteredItems = widget.items;
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

  void _onItemSelected(String value) {
    widget.onChanged(value);
    _toggleDropdown();
  }


  Widget _buildDropdownButton() {
    final selectedItem = widget.items.firstWhere(
      (item) => item.value == widget.selectedValue,
      orElse: () => FilterItem(
        value: widget.selectedValue ?? '',
        label: widget.selectedValue ?? 'All',
        icon: widget.icon,
        count: 0,
      ),
    );

    return InkWell(
      onTap: _toggleDropdown,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: widget.width,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  const SizedBox(height: 4),
                  Text(
                    selectedItem.label,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (selectedItem.count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${selectedItem.count}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
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
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  final isSelected = widget.selectedValue == item.value;

                  return _buildFilterItem(
                    item: item,
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


  Widget _buildFilterItem({
    required FilterItem item,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _onItemSelected(item.value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
        ),
        child: Row(
          children: [
            // For category filters on bills page, don't show icons
            if (widget.showIcons && !widget.isCategoryFilter) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.showColors && item.color != null
                      ? item.color!.withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  color: widget.showColors && item.color != null
                      ? item.color!
                      : Colors.grey.shade600,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  // For category filters, use category color; otherwise use default colors
                  color: widget.isCategoryFilter && widget.showColors
                      ? CategoryService.getCategoryColor(item.value)
                      : (isSelected ? Colors.blue.shade700 : Colors.grey.shade800),
                ),
              ),
            ),
            if (item.count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade200 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${item.count}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
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
      ],
    );
  }
}

class FilterItem {
  final String value;
  final String label;
  final IconData icon;
  final int count;
  final Color? color;

  const FilterItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.count,
    this.color,
  });
}
