import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../theme/app_colors.dart';

/// Interactive crop widget with draggable corner handles
/// Users can manually adjust crop area by dragging corner handles
class InteractiveCropWidget extends StatefulWidget {
  final File imageFile;
  final Rect? initialCrop;
  final Function(Rect) onCropChanged;
  final bool showGrid;
  
  const InteractiveCropWidget({
    super.key,
    required this.imageFile,
    this.initialCrop,
    required this.onCropChanged,
    this.showGrid = true,
  });
  
  @override
  State<InteractiveCropWidget> createState() => _InteractiveCropWidgetState();
}

class _InteractiveCropWidgetState extends State<InteractiveCropWidget> {
  late TransformationController _transformationController;
  
  // Image and widget dimensions
  Size? _imageSize;
  Size? _widgetSize;
  
  // Crop area in image coordinates
  Rect? _cropRect;
  
  // Dragging state
  bool _isDragging = false;
  int? _draggingHandle; // 0=top-left, 1=top-right, 2=bottom-right, 3=bottom-left
  Offset? _dragStart;
  
  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _initializeCrop();
  }
  
  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeCrop() async {
    try {
      // Get image dimensions
      final bytes = await widget.imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
        
        // Set initial crop
        _cropRect = widget.initialCrop ?? _getDefaultCrop();
        _updateCrop();
      }
    } catch (e) {
      print('❌ CROP: Failed to initialize: $e');
    }
  }
  
  /// Get default crop (80% of image with 10% margin)
  Rect _getDefaultCrop() {
    if (_imageSize == null) {
      return const Rect.fromLTWH(0, 0, 400, 600);
    }
    
    final width = _imageSize!.width;
    final height = _imageSize!.height;
    final marginX = width * 0.1;
    final marginY = height * 0.1;
    
    return Rect.fromLTRB(
      marginX,
      marginY,
      width - marginX,
      height - marginY,
    );
  }
  
  /// Update crop and notify parent
  void _updateCrop() {
    if (_cropRect != null && _imageSize != null && _widgetSize != null) {
      // Pass the crop rectangle in image coordinates directly
      // The parent dialog will handle the actual cropping
      widget.onCropChanged(_cropRect!);
    }
  }
  
  /// Get crop rectangle in widget coordinates
  Rect? get _cropRectInWidget {
    if (_cropRect == null || _imageSize == null || _widgetSize == null) {
      return null;
    }
    
    final scaleX = _widgetSize!.width / _imageSize!.width;
    final scaleY = _widgetSize!.height / _imageSize!.height;
    final scale = math.min(scaleX, scaleY);
    
    // Calculate the actual image display area in widget coordinates
    final imageDisplayWidth = _imageSize!.width * scale;
    final imageDisplayHeight = _imageSize!.height * scale;
    
    // Calculate offset to center the image
    final offsetX = (_widgetSize!.width - imageDisplayWidth) / 2;
    final offsetY = (_widgetSize!.height - imageDisplayHeight) / 2;
    
    return Rect.fromLTRB(
      offsetX + (_cropRect!.left * scale),
      offsetY + (_cropRect!.top * scale),
      offsetX + (_cropRect!.right * scale),
      offsetY + (_cropRect!.bottom * scale),
    );
  }
  
  /// Get corner positions in widget coordinates
  List<Offset> get _cornerPositions {
    final rect = _cropRectInWidget;
    if (rect == null) return [];
    
    return [
      Offset(rect.left, rect.top),      // Top-left
      Offset(rect.right, rect.top),     // Top-right
      Offset(rect.right, rect.bottom),  // Bottom-right
      Offset(rect.left, rect.bottom),   // Bottom-left
    ];
  }
  
  /// Handle pan start
  void _onPanStart(DragStartDetails details) {
    final corners = _cornerPositions;
    if (corners.isEmpty) return;
    
    final touchPoint = details.localPosition;
    const handleRadius = 20.0;
    
    // Check which handle is being touched
    for (int i = 0; i < corners.length; i++) {
      final distance = (touchPoint - corners[i]).distance;
      if (distance <= handleRadius) {
        setState(() {
          _isDragging = true;
          _draggingHandle = i;
          _dragStart = touchPoint;
        });
        return;
      }
    }
  }
  
  /// Handle pan update
  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || _draggingHandle == null || _cropRect == null || _imageSize == null || _widgetSize == null) {
      return;
    }
    
    final delta = details.localPosition - (_dragStart ?? details.localPosition);
    
    // Calculate the scale factor from widget to image coordinates
    final scaleX = _widgetSize!.width / _imageSize!.width;
    final scaleY = _widgetSize!.height / _imageSize!.height;
    final scale = math.min(scaleX, scaleY);
    
    // Convert delta from widget coordinates to image coordinates
    final scaledDelta = Offset(delta.dx / scale, delta.dy / scale);
    
    setState(() {
      switch (_draggingHandle!) {
        case 0: // Top-left
          _cropRect = Rect.fromLTRB(
            math.max(0, _cropRect!.left + scaledDelta.dx),
            math.max(0, _cropRect!.top + scaledDelta.dy),
            _cropRect!.right,
            _cropRect!.bottom,
          );
          break;
        case 1: // Top-right
          _cropRect = Rect.fromLTRB(
            _cropRect!.left,
            math.max(0, _cropRect!.top + scaledDelta.dy),
            math.min(_imageSize!.width, _cropRect!.right + scaledDelta.dx),
            _cropRect!.bottom,
          );
          break;
        case 2: // Bottom-right
          _cropRect = Rect.fromLTRB(
            _cropRect!.left,
            _cropRect!.top,
            math.min(_imageSize!.width, _cropRect!.right + scaledDelta.dx),
            math.min(_imageSize!.height, _cropRect!.bottom + scaledDelta.dy),
          );
          break;
        case 3: // Bottom-left
          _cropRect = Rect.fromLTRB(
            math.max(0, _cropRect!.left + scaledDelta.dx),
            _cropRect!.top,
            _cropRect!.right,
            math.min(_imageSize!.height, _cropRect!.bottom + scaledDelta.dy),
          );
          break;
      }
      
      // Ensure minimum size
      if (_cropRect!.width < 50 || _cropRect!.height < 50) {
        // Reset to minimum size
        final center = _cropRect!.center;
        _cropRect = Rect.fromCenter(
          center: center,
          width: math.max(50, _cropRect!.width),
          height: math.max(50, _cropRect!.height),
        );
      }
      
      _dragStart = details.localPosition;
    });
    
    _updateCrop();
  }
  
  /// Handle pan end
  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _draggingHandle = null;
      _dragStart = null;
    });
  }
  
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(12),
            child: const Text(
              'Drag the corner handles to select your receipt area',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Image with crop overlay
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _widgetSize = constraints.biggest;
                return GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Stack(
                    children: [
                      // Image
                      Center(
                        child: Image.file(
                          widget.imageFile,
                          fit: BoxFit.contain,
                        ),
                      ),
                      
                      // Crop overlay
                      if (_cropRectInWidget != null)
                        _buildCropOverlay(),
                      
                      // Grid overlay
                      if (widget.showGrid && !_isDragging)
                        _buildGridOverlay(),
                    ],
                  ),
                );
              },
            ),
          ),
          
        ],
      ),
    );
  }
  
  /// Build crop overlay with draggable corner handles
  Widget _buildCropOverlay() {
    final rect = _cropRectInWidget;
    if (rect == null) return const SizedBox.shrink();
    
    return Positioned.fill(
      child: CustomPaint(
        painter: InteractiveCropOverlayPainter(
          cropRect: rect,
          isDragging: _isDragging,
          draggingHandle: _draggingHandle,
        ),
      ),
    );
  }
  
  /// Build grid overlay
  Widget _buildGridOverlay() {
    final rect = _cropRectInWidget;
    if (rect == null) return const SizedBox.shrink();
    
    return Positioned.fill(
      child: CustomPaint(
        painter: GridOverlayPainter(
          cropRect: rect,
          showGrid: widget.showGrid,
        ),
      ),
    );
  }
}

/// Custom painter for interactive crop overlay
class InteractiveCropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final bool isDragging;
  final int? draggingHandle;
  
  InteractiveCropOverlayPainter({
    required this.cropRect,
    required this.isDragging,
    this.draggingHandle,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5);
    
    final cropPaint = Paint()
      ..color = AppColors.bottomNavBackground
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final handlePaint = Paint()
      ..color = AppColors.bottomNavBackground
      ..style = PaintingStyle.fill;
    
    final draggingHandlePaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;
    
    // Draw overlay outside crop area
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;
    
    canvas.drawPath(overlayPath, paint);
    
    // Draw crop rectangle
    canvas.drawRect(cropRect, cropPaint);
    
    // Draw corner handles
    const handleSize = 16.0;
    final handles = [
      Offset(cropRect.left, cropRect.top),      // Top-left
      Offset(cropRect.right, cropRect.top),     // Top-right
      Offset(cropRect.right, cropRect.bottom),  // Bottom-right
      Offset(cropRect.left, cropRect.bottom),   // Bottom-left
    ];
    
    for (int i = 0; i < handles.length; i++) {
      final handle = handles[i];
      final isDraggingThis = isDragging && draggingHandle == i;
      
      // Draw handle circle
      canvas.drawCircle(
        handle, 
        handleSize / 2, 
        isDraggingThis ? draggingHandlePaint : handlePaint,
      );
      
      // Draw handle border
      canvas.drawCircle(
        handle, 
        handleSize / 2, 
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is InteractiveCropOverlayPainter && 
           (oldDelegate.cropRect != cropRect || 
            oldDelegate.isDragging != isDragging ||
            oldDelegate.draggingHandle != draggingHandle);
  }
}

/// Custom painter for grid overlay
class GridOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final bool showGrid;
  
  GridOverlayPainter({
    required this.cropRect,
    required this.showGrid,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (!showGrid) return;
    
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 0.5;
    
    // Draw rule of thirds grid
    final thirdWidth = cropRect.width / 3;
    final thirdHeight = cropRect.height / 3;
    
    // Vertical lines
    canvas.drawLine(
      Offset(cropRect.left + thirdWidth, cropRect.top),
      Offset(cropRect.left + thirdWidth, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + thirdWidth * 2, cropRect.top),
      Offset(cropRect.left + thirdWidth * 2, cropRect.bottom),
      gridPaint,
    );
    
    // Horizontal lines
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdHeight),
      Offset(cropRect.right, cropRect.top + thirdHeight),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdHeight * 2),
      Offset(cropRect.right, cropRect.top + thirdHeight * 2),
      gridPaint,
    );
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is GridOverlayPainter && oldDelegate.cropRect != cropRect;
  }
}
