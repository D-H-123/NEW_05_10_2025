import 'package:flutter/material.dart';
import '../services/edge_validation_service.dart';

/// Widget that provides real-time feedback on edge detection quality
class EdgeValidationFeedback extends StatefulWidget {
  final List<Offset> corners;
  final VoidCallback? onRetry;
  final VoidCallback? onContinue;

  const EdgeValidationFeedback({
    super.key,
    required this.corners,
    this.onRetry,
    this.onContinue,
  });

  @override
  State<EdgeValidationFeedback> createState() => _EdgeValidationFeedbackState();
}

class _EdgeValidationFeedbackState extends State<EdgeValidationFeedback>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  EdgeValidationResult? _lastValidation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EdgeValidationFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.corners != widget.corners) {
      _validateCorners();
    }
  }

  void _validateCorners() {
    final result = EdgeValidationService.validateCorners(widget.corners);
    if (mounted) {
      setState(() {
        _lastValidation = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lastValidation == null) {
      _validateCorners();
      return const SizedBox.shrink();
    }

    final result = _lastValidation!;
    final color = EdgeValidationService.getValidationColor(result);
    final message = EdgeValidationService.getValidationMessage(result);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: result.isValid ? 1.0 : _pulseAnimation.value,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      result.isValid ? Icons.check_circle : Icons.warning,
                      color: color,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!result.isValid) ...[
                  const SizedBox(height: 12),
                  if (result.issues.isNotEmpty) ...[
                    Text(
                      'Issues found:',
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...result.issues.map((issue) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: color,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              issue,
                              style: TextStyle(
                                color: color,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                  if (result.suggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Suggestions:',
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...result.suggestions.map((suggestion) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: color,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              suggestion,
                              style: TextStyle(
                                color: color,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (widget.onRetry != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onRetry,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: color,
                              side: BorderSide(color: color),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Try Again'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (widget.onContinue != null)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: widget.onContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Continue Anyway'),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Compact validation indicator for corner handles
class CornerValidationIndicator extends StatelessWidget {
  final List<Offset> corners;
  final int cornerIndex;

  const CornerValidationIndicator({
    super.key,
    required this.corners,
    required this.cornerIndex,
  });

  @override
  Widget build(BuildContext context) {
    final result = EdgeValidationService.validateCorners(corners);
    final color = EdgeValidationService.getValidationColor(result);
    
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
      ),
    );
  }
}

/// Validation overlay that shows over the edge detection preview
class EdgeValidationOverlay extends StatelessWidget {
  final List<Offset> corners;
  final VoidCallback? onRetry;
  final VoidCallback? onContinue;

  const EdgeValidationOverlay({
    super.key,
    required this.corners,
    this.onRetry,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: EdgeValidationFeedback(
        corners: corners,
        onRetry: onRetry,
        onContinue: onContinue,
      ),
    );
  }
}
