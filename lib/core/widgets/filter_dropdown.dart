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
  final bool allowMultiSelect;
  final List<String>? selectedValues; // For multi-select
  final ValueChanged<List<String>?>? onMultiChanged; // For multi-select

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
    this.allowMultiSelect = false,
    this.selectedValues,
    this.onMultiChanged,
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
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _buttonKey = GlobalKey();
  List<String> _selectedValues = []; // For multi-select

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
    
    // Initialize selected values for multi-select
    if (widget.allowMultiSelect && widget.selectedValues != null) {
      _selectedValues = List.from(widget.selectedValues!);
    } else if (widget.selectedValue != null) {
      _selectedValues = [widget.selectedValue!];
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
        _showOverlay();
      } else {
        _animationController.reverse();
        _removeOverlay();
      }
    });
  }

  void _onItemSelected(String value) {
    if (widget.allowMultiSelect) {
      // Handle multi-select
      setState(() {
        if (_selectedValues.contains(value)) {
          _selectedValues.remove(value);
        } else {
          _selectedValues.add(value);
        }
      });
      
      // Notify parent of multi-select change
      if (widget.onMultiChanged != null) {
        widget.onMultiChanged!(_selectedValues);
      }
      
      // Don't auto-close for multi-select - let user click outside
    } else {
      // Handle single select
      widget.onChanged(value);
      _toggleDropdown(); // Auto-close after selection
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => _buildOverlayContent(),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildOverlayContent() {
    final RenderBox? renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    return GestureDetector(
      onTap: () {
        // Close dropdown when clicking outside
        _toggleDropdown();
      },
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Invisible overlay to catch outside clicks
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _toggleDropdown();
                },
                child: Container(color: Colors.transparent),
              ),
            ),
            // Dropdown content
            Positioned(
              left: position.dx,
              top: position.dy + size.height + 4, // Position below the button
              width: size.width,
              child: GestureDetector(
                onTap: () {
                  // Prevent closing when clicking on dropdown content
                },
                child: CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  child: Material(
                    elevation: 20,
                    borderRadius: BorderRadius.circular(10),
                    child: _buildDropdownMenu(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDropdownButton() {
    String displayLabel;
    int selectedCount = 0;
    
    if (widget.allowMultiSelect) {
      if (_selectedValues.isEmpty) {
        displayLabel = 'All';
      } else if (_selectedValues.length == 1) {
        final item = widget.items.firstWhere(
          (item) => item.value == _selectedValues.first,
          orElse: () => FilterItem(
            value: _selectedValues.first,
            label: _selectedValues.first,
            icon: widget.icon,
            count: 0,
          ),
        );
        displayLabel = item.label;
      } else {
        displayLabel = '${_selectedValues.length} selected';
      }
      selectedCount = _selectedValues.length;
    } else {
      final selectedItem = widget.items.firstWhere(
        (item) => item.value == widget.selectedValue,
        orElse: () => FilterItem(
          value: widget.selectedValue ?? '',
          label: widget.selectedValue ?? 'All',
          icon: widget.icon,
          count: 0,
        ),
      );
      displayLabel = selectedItem.label;
      selectedCount = selectedItem.count;
    }

    return InkWell(
      onTap: _toggleDropdown,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        key: _buttonKey,
        width: widget.width,
        constraints: const BoxConstraints(
          minHeight: 56,
          maxHeight: 64,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: _isOpen ? Colors.blue.shade400 : Colors.grey.shade300,
            width: _isOpen ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
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
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayLabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            if (selectedCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$selectedCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: _isOpen ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.grey.shade600,
                size: 20,
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
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  final isSelected = widget.allowMultiSelect 
                      ? _selectedValues.contains(item.value)
                      : widget.selectedValue == item.value;

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
        ),
        child: Row(
          children: [
            // Show checkbox for multi-select, icon for single select
            if (widget.allowMultiSelect) ...[
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade600 : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? Colors.blue.shade600 : Colors.grey.shade400,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
            ] else if (widget.showIcons && !widget.isCategoryFilter) ...[
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: widget.showColors && item.color != null
                      ? item.color!.withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  item.icon,
                  color: widget.showColors && item.color != null
                      ? item.color!
                      : Colors.grey.shade600,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade200 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.count}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            if (isSelected && !widget.allowMultiSelect)
              Icon(
                Icons.check_circle,
                color: Colors.blue.shade600,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: _buildDropdownButton(),
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
