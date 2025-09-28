import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// Real-time edge detection preview component
/// Shows detected edges with visual feedback for better accuracy
class EdgeDetectionPreview extends StatefulWidget {
  final File imageFile;
  final List<Offset> detectedCorners;
  final Function(List<Offset>) onCornersChanged;
  final bool showGuides;
  final bool showAccuracy;

  const EdgeDetectionPreview({
    super.key,
    required this.imageFile,
    required this.detectedCorners,
    required this.onCornersChanged,
    this.showGuides = true,
    this.showAccuracy = true,
  });

  @override
  State<EdgeDetectionPreview> createState() => _EdgeDetectionPreviewState();
}

class _EdgeDetectionPreviewState extends State<EdgeDetectionPreview>
    with TickerProviderStateMixin {
  late List<Offset> _corners;
  int? _draggingCorner;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize with empty corners - we'll calculate them in build()
    _corners = [];
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate proper corner positions based on actual display size
        _calculateCornerPositions(constraints.maxWidth, constraints.maxHeight);
        
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Image - show full receipt with minimal white space
                Positioned.fill(
                  child: Image.file(
                    widget.imageFile,
                    fit: BoxFit.contain, // Back to contain to show full receipt
                  ),
                ),
                
                // Edge detection overlay
                if (widget.showGuides) _buildEdgeOverlay(),
                
                // Corner handles
                ..._buildCornerHandles(),
                
                // Accuracy indicator
                if (widget.showAccuracy) _buildAccuracyIndicator(),
                
                // Removed validation feedback overlay to eliminate green message
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// Calculate proper corner positions based on display size
  void _calculateCornerPositions(double displayWidth, double displayHeight) {
    if (_corners.isNotEmpty) return; // Already calculated
    
    // Get image dimensions
    widget.imageFile.readAsBytes().then((bytes) {
      final image = img.decodeImage(bytes);
      if (image == null) return;
      
      final imageWidth = image.width.toDouble();
      final imageHeight = image.height.toDouble();
      
      // Calculate scaling factors for BoxFit.contain (show full image)
      final imageAspectRatio = imageWidth / imageHeight;
      final displayAspectRatio = displayWidth / displayHeight;
      
      double scaledWidth, scaledHeight, offsetX, offsetY;
      
      if (imageAspectRatio > displayAspectRatio) {
        // Image is wider than display - scale to fit width
        scaledWidth = displayWidth;
        scaledHeight = displayWidth / imageAspectRatio;
        offsetX = 0;
        offsetY = (displayHeight - scaledHeight) / 2;
      } else {
        // Image is taller than display - scale to fit height
        scaledHeight = displayHeight;
        scaledWidth = displayHeight * imageAspectRatio;
        offsetX = (displayWidth - scaledWidth) / 2;
        offsetY = 0;
      }
      
      // Convert image coordinates to display coordinates
      List<Offset> displayCorners;
      
      if (widget.detectedCorners.length == 4) {
        // Scale detected corners to display coordinates
        displayCorners = widget.detectedCorners.map((corner) {
          final scaleX = scaledWidth / imageWidth;
          final scaleY = scaledHeight / imageHeight;
          
          return Offset(
            (corner.dx * scaleX) + offsetX,
            (corner.dy * scaleY) + offsetY,
          );
        }).toList();
      } else {
        // Generate default corners in display coordinates
        displayCorners = [
          Offset(offsetX + scaledWidth * 0.1, offsetY + scaledHeight * 0.1),      // Top-left
          Offset(offsetX + scaledWidth * 0.9, offsetY + scaledHeight * 0.1),      // Top-right
          Offset(offsetX + scaledWidth * 0.9, offsetY + scaledHeight * 0.9),      // Bottom-right
          Offset(offsetX + scaledWidth * 0.1, offsetY + scaledHeight * 0.9),      // Bottom-left
        ];
      }
      
      if (mounted) {
        setState(() {
          _corners = displayCorners;
        });
        print('🔍 DEBUG: Calculated display corners: $_corners');
      }
    });
  }

  Widget _buildEdgeOverlay() {
    return Positioned.fill(
      child: CustomPaint(
        painter: EdgeDetectionPainter(
          corners: _corners,
          isDragging: _draggingCorner != null,
        ),
      ),
    );
  }

  List<Widget> _buildCornerHandles() {
    // Ensure we always have exactly 4 corners
    if (_corners.length != 4) {
      print('❌ DEBUG: Invalid corner count: ${_corners.length}');
      return [];
    }
    
    return _corners.asMap().entries.map((entry) {
      final index = entry.key;
      final corner = entry.value;
      
      print('🔍 DEBUG: Building corner handle $index at position $corner');
      
      return Positioned(
        left: corner.dx - 15, // Adjusted for smaller size
        top: corner.dy - 15,
        child: GestureDetector(
          onPanStart: (details) {
            print('🔍 DEBUG: Started dragging corner $index');
            setState(() {
              _draggingCorner = index;
            });
            _pulseController.stop();
          },
          onPanUpdate: (details) {
            final newCorner = Offset(
              corner.dx + details.delta.dx,
              corner.dy + details.delta.dy,
            );
            setState(() {
              _corners[index] = newCorner;
            });
            widget.onCornersChanged(_corners);
            print('🔍 DEBUG: Moved corner $index to $newCorner');
          },
          onPanEnd: (details) {
            print('🔍 DEBUG: Finished dragging corner $index');
            setState(() {
              _draggingCorner = null;
            });
            _pulseController.repeat(reverse: true);
          },
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _draggingCorner == index ? 1.3 : _pulseAnimation.value,
                child: Container(
                  width: 30, // Reduced size for better UX
                  height: 30,
                  decoration: BoxDecoration(
                    color: _draggingCorner == index 
                        ? Colors.orange 
                        : Colors.blue, // Changed to blue for better integration
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.drag_indicator,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }).toList();
  }

  Widget _buildAccuracyIndicator() {
    final accuracy = _calculateAccuracy();
    
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getAccuracyColor(accuracy).withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getAccuracyIcon(accuracy),
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '${(accuracy * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateAccuracy() {
    if (_corners.length != 4) return 0.0;
    
    // Calculate how rectangular the shape is
    final rect = _getBoundingRect(_corners);
    final area = rect.width * rect.height;
    
    if (area == 0) return 0.0;
    
    // Calculate the area of the quadrilateral
    final quadArea = _calculateQuadrilateralArea(_corners);
    
    // Accuracy is the ratio of quadrilateral area to bounding rectangle area
    final accuracy = quadArea / area;
    
    return accuracy.clamp(0.0, 1.0);
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy > 0.8) return Colors.green;
    if (accuracy > 0.6) return Colors.orange;
    return Colors.red;
  }

  IconData _getAccuracyIcon(double accuracy) {
    if (accuracy > 0.8) return Icons.check_circle;
    if (accuracy > 0.6) return Icons.warning;
    return Icons.error;
  }

  Rect _getBoundingRect(List<Offset> corners) {
    if (corners.isEmpty) return Rect.zero;
    
    double minX = corners.first.dx;
    double maxX = corners.first.dx;
    double minY = corners.first.dy;
    double maxY = corners.first.dy;
    
    for (final point in corners) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }
    
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  double _calculateQuadrilateralArea(List<Offset> corners) {
    if (corners.length != 4) return 0.0;
    
    // Use shoelace formula for quadrilateral area
    double area = 0;
    for (int i = 0; i < 4; i++) {
      final j = (i + 1) % 4;
      area += corners[i].dx * corners[j].dy;
      area -= corners[j].dx * corners[i].dy;
    }
    
    return area.abs() / 2;
  }

}

/// Custom painter for edge detection overlay
class EdgeDetectionPainter extends CustomPainter {
  final List<Offset> corners;
  final bool isDragging;

  EdgeDetectionPainter({
    required this.corners,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;

    // Light connecting lines (diagonal)
    final lightPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Bold horizontal and vertical lines
    final boldPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw light connecting lines (diagonal)
    for (int i = 0; i < 4; i++) {
      final next = (i + 1) % 4;
      canvas.drawLine(corners[i], corners[next], lightPaint);
    }

    // Draw bold horizontal and vertical lines
    // Top horizontal line
    canvas.drawLine(corners[0], corners[1], boldPaint);
    // Right vertical line
    canvas.drawLine(corners[1], corners[2], boldPaint);
    // Bottom horizontal line
    canvas.drawLine(corners[2], corners[3], boldPaint);
    // Left vertical line
    canvas.drawLine(corners[3], corners[0], boldPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
