import 'package:flutter/material.dart';

// ✅ UI/UX Improvement: Simple shimmer effect without external package
// Using a custom animated container for shimmer effect
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.5 + (_controller.value * 0.5), // Pulse between 0.5 and 1.0
          child: widget.child,
        );
      },
    );
  }
}

/// ✅ UI/UX Improvement: Skeleton loader with shimmer effect
/// Replaces basic loading indicators for better user experience
class SkeletonLoader extends StatelessWidget {
  final double? width;
  final double? height;
  final double? borderRadius;
  final BoxShape shape;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: shape == BoxShape.rectangle
              ? BorderRadius.circular(borderRadius ?? 12)
              : null,
          shape: shape,
        ),
      ),
    );
  }
}

/// Skeleton loader for list items (bills/receipts)
class BillSkeletonLoader extends StatelessWidget {
  const BillSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          // Image placeholder
          SkeletonLoader(
            width: 80,
            height: 80,
            borderRadius: 8,
          ),
          SizedBox(width: 16),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: double.infinity,
                  height: 16,
                  borderRadius: 4,
                ),
                SizedBox(height: 8),
                SkeletonLoader(
                  width: 120,
                  height: 12,
                  borderRadius: 4,
                ),
                SizedBox(height: 8),
                SkeletonLoader(
                  width: 80,
                  height: 14,
                  borderRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for budget card
class BudgetCardSkeletonLoader extends StatelessWidget {
  const BudgetCardSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          SkeletonLoader(
            width: 200,
            height: 24,
            borderRadius: 4,
          ),
          SizedBox(height: 20),
          // Amount
          SkeletonLoader(
            width: 150,
            height: 32,
            borderRadius: 4,
          ),
          SizedBox(height: 8),
          // Subtitle
          SkeletonLoader(
            width: 120,
            height: 14,
            borderRadius: 4,
          ),
          SizedBox(height: 16),
          // Progress bar
          SkeletonLoader(
            width: double.infinity,
            height: 8,
            borderRadius: 4,
          ),
          SizedBox(height: 8),
          // Percentage
          SkeletonLoader(
            width: 80,
            height: 12,
            borderRadius: 4,
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for chart/graph
class ChartSkeletonLoader extends StatelessWidget {
  const ChartSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const SkeletonLoader(
            width: 150,
            height: 20,
            borderRadius: 4,
          ),
          const SizedBox(height: 24),
          // Chart area
          const SkeletonLoader(
            width: double.infinity,
            height: 200,
            borderRadius: 8,
          ),
          const SizedBox(height: 16),
          // Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              5,
              (index) => const SkeletonLoader(
                width: 40,
                height: 12,
                borderRadius: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

