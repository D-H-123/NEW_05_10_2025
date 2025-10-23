import 'package:flutter/material.dart';
import '../services/category_service.dart';

/// A compact, user-friendly multi-select category selector using chips
/// Much faster and more space-efficient than dropdown with checkboxes
class CategoryChipSelector extends StatelessWidget {
  final List<String> availableCategories;
  final List<String> selectedCategories;
  final ValueChanged<List<String>> onChanged;
  final bool showCounts;
  final Map<String, int>? categoryCounts;
  final bool isCompact; // If true, shows in a single scrollable row
  final String label;

  const CategoryChipSelector({
    super.key,
    required this.availableCategories,
    required this.selectedCategories,
    required this.onChanged,
    this.showCounts = false,
    this.categoryCounts,
    this.isCompact = false,
    this.label = 'Categories',
  });

  void _toggleCategory(String category) {
    final List<String> newSelection = List.from(selectedCategories);
    if (newSelection.contains(category)) {
      newSelection.remove(category);
    } else {
      newSelection.add(category);
    }
    onChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    if (availableCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with clear all button
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 4),
            // Helper icon with tooltip
            Tooltip(
              message: 'Tap any chip to select/unselect. You can select multiple categories at once.',
              child: Icon(
                Icons.info_outline,
                size: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 8),
            if (selectedCategories.isNotEmpty)
              TextButton(
                onPressed: () => onChanged([]),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade600,
                  ),
                ),
              ),
            const Spacer(),
            if (selectedCategories.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${selectedCategories.length} selected',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Chips
        if (isCompact)
          _buildCompactChips()
        else
          _buildWrappedChips(),
      ],
    );
  }

  Widget _buildWrappedChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: availableCategories.map((category) {
        final isSelected = selectedCategories.contains(category);
        final categoryColor = CategoryService.getCategoryColor(category);
        final count = categoryCounts?[category] ?? 0;

        return _buildChip(
          category: category,
          isSelected: isSelected,
          color: categoryColor,
          count: count,
        );
      }).toList(),
    );
  }

  Widget _buildCompactChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: availableCategories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final category = availableCategories[index];
          final isSelected = selectedCategories.contains(category);
          final categoryColor = CategoryService.getCategoryColor(category);
          final count = categoryCounts?[category] ?? 0;

          return _buildChip(
            category: category,
            isSelected: isSelected,
            color: categoryColor,
            count: count,
          );
        },
      ),
    );
  }

  Widget _buildChip({
    required String category,
    required bool isSelected,
    required Color color,
    required int count,
  }) {
    final categoryIcon = CategoryService.getCategoryIcon(category);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleCategory(category),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                categoryIcon,
                size: 14,
                color: isSelected ? color : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                category,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? color : Colors.grey.shade700,
                ),
              ),
              if (showCounts && count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Expandable version with show more/less functionality
class ExpandableCategoryChipSelector extends StatefulWidget {
  final List<String> availableCategories;
  final List<String> selectedCategories;
  final ValueChanged<List<String>> onChanged;
  final bool showCounts;
  final Map<String, int>? categoryCounts;
  final int initialDisplayCount; // Number of chips to show initially
  final String label;

  const ExpandableCategoryChipSelector({
    super.key,
    required this.availableCategories,
    required this.selectedCategories,
    required this.onChanged,
    this.showCounts = false,
    this.categoryCounts,
    this.initialDisplayCount = 6,
    this.label = 'Categories',
  });

  @override
  State<ExpandableCategoryChipSelector> createState() =>
      _ExpandableCategoryChipSelectorState();
}

class _ExpandableCategoryChipSelectorState
    extends State<ExpandableCategoryChipSelector> {
  bool _isExpanded = false;

  void _toggleCategory(String category) {
    final List<String> newSelection = List.from(widget.selectedCategories);
    if (newSelection.contains(category)) {
      newSelection.remove(category);
    } else {
      newSelection.add(category);
    }
    widget.onChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.availableCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayCategories = _isExpanded
        ? widget.availableCategories
        : widget.availableCategories.take(widget.initialDisplayCount).toList();

    final hasMore = widget.availableCategories.length > widget.initialDisplayCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with clear all button
        Row(
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 8),
            if (widget.selectedCategories.isNotEmpty)
              TextButton(
                onPressed: () => widget.onChanged([]),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade600,
                  ),
                ),
              ),
            const Spacer(),
            if (widget.selectedCategories.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.selectedCategories.length} selected',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...displayCategories.map((category) {
              final isSelected = widget.selectedCategories.contains(category);
              final categoryColor = CategoryService.getCategoryColor(category);
              final count = widget.categoryCounts?[category] ?? 0;
              final categoryIcon = CategoryService.getCategoryIcon(category);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _toggleCategory(category),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? categoryColor.withOpacity(0.2)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? categoryColor : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          categoryIcon,
                          size: 14,
                          color: isSelected ? categoryColor : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? categoryColor
                                : Colors.grey.shade700,
                          ),
                        ),
                        if (widget.showCounts && count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? categoryColor
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              count.toString(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            // Show more/less button
            if (hasMore)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.blue.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isExpanded
                              ? 'Show Less'
                              : 'Show More (${widget.availableCategories.length - widget.initialDisplayCount})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

