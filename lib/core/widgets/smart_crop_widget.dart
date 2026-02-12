import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../theme/app_colors.dart';

/// High-performance manual crop widget with smart features
/// Provides maximum efficiency and accuracy for gallery imports
class SmartCropWidget extends StatefulWidget {
  final File imageFile;
  final Rect? suggestedCrop;
  final Function(Rect) onCropChanged;
  final bool showGrid;
  final bool enableSmartSuggestions;
  
  const SmartCropWidget({
    super.key,
    required this.imageFile,
    this.suggestedCrop,
    required this.onCropChanged,
    this.showGrid = true,
    this.enableSmartSuggestions = true,
  });
  
  @override
  State<SmartCropWidget> createState() => _SmartCropWidgetState();
}

class _SmartCropWidgetState extends State<SmartCropWidget> with TickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  
  Rect? _currentCrop;
  Size? _imageSize;
  Size? _widgetSize;
  bool _isDragging = false;
  
  // Smart crop suggestions
  List<Rect> _smartSuggestions = [];
  int _currentSuggestionIndex = -1;
  
  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _initializeCrop();
  }
  
  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeCrop() async {
    try {
      // Get image dimensions
      final bytes = await widget.imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
        
        // Generate smart suggestions if enabled
        if (widget.enableSmartSuggestions) {
          _smartSuggestions = await _generateSmartSuggestions(image);
        }
        
        // Set initial crop
        _currentCrop = widget.suggestedCrop ?? _getDefaultCrop();
        _updateCrop();
      }
    } catch (e) {
      print('❌ CROP: Failed to initialize: $e');
    }
  }
  
  /// Generate smart crop suggestions based on image analysis
  Future<List<Rect>> _generateSmartSuggestions(img.Image image) async {
    final suggestions = <Rect>[];
    final width = image.width.toDouble();
    final height = image.height.toDouble();
    
    // Suggestion 1: Center crop (most common for receipts)
    final centerCrop = Rect.fromCenter(
      center: Offset(width / 2, height / 2),
      width: math.min(width * 0.8, height * 0.8),
      height: math.min(width * 0.8, height * 0.8),
    );
    suggestions.add(centerCrop);
    
    // Suggestion 2: Full width, centered height (for tall receipts)
    final fullWidthCrop = Rect.fromCenter(
      center: Offset(width / 2, height / 2),
      width: width * 0.95,
      height: height * 0.7,
    );
    suggestions.add(fullWidthCrop);
    
    // Suggestion 3: Golden ratio crop (aesthetic)
    const goldenRatio = 1.618;
    final cropHeight = width / goldenRatio;
    final goldenCrop = Rect.fromCenter(
      center: Offset(width / 2, height / 2),
      width: width * 0.9,
      height: cropHeight,
    );
    suggestions.add(goldenCrop);
    
    // Suggestion 4: Square crop (for square receipts)
    final squareSize = math.min(width, height) * 0.8;
    final squareCrop = Rect.fromCenter(
      center: Offset(width / 2, height / 2),
      width: squareSize,
      height: squareSize,
    );
    suggestions.add(squareCrop);
    
    return suggestions;
  }
  
  /// Get default crop based on image dimensions
  Rect _getDefaultCrop() {
    if (_imageSize == null) {
      return const Rect.fromLTWH(0, 0, 400, 600);
    }
    
    final width = _imageSize!.width;
    final height = _imageSize!.height;
    
    // Default to 80% of image with 10% margin
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
    if (_currentCrop != null && _imageSize != null && _widgetSize != null) {
      // Convert crop to widget coordinates
      final scaleX = _widgetSize!.width / _imageSize!.width;
      final scaleY = _widgetSize!.height / _imageSize!.height;
      final scale = math.min(scaleX, scaleY);
      
      final scaledCrop = Rect.fromLTRB(
        _currentCrop!.left * scale,
        _currentCrop!.top * scale,
        _currentCrop!.right * scale,
        _currentCrop!.bottom * scale,
      );
      
      widget.onCropChanged(scaledCrop);
    }
  }
  
  /// Apply smart suggestion
  void _applySuggestion(int index) {
    if (index >= 0 && index < _smartSuggestions.length) {
      setState(() {
        _currentCrop = _smartSuggestions[index];
        _currentSuggestionIndex = index;
      });
      _updateCrop();
      _animateToCrop();
    }
  }
  
  /// Animate to current crop
  void _animateToCrop() {
    if (_currentCrop == null || _imageSize == null || _widgetSize == null) return;
    
    final scaleX = _widgetSize!.width / _imageSize!.width;
    final scaleY = _widgetSize!.height / _imageSize!.height;
    final scale = math.min(scaleX, scaleY);
    
    final centerX = (_currentCrop!.left + _currentCrop!.right) / 2;
    final centerY = (_currentCrop!.top + _currentCrop!.bottom) / 2;
    
    final targetMatrix = Matrix4.identity()
      ..translate(
        _widgetSize!.width / 2 - centerX * scale,
        _widgetSize!.height / 2 - centerY * scale,
      )
      ..scale(scale);
    
    _transformationController.value = targetMatrix;
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
          // Header with smart suggestions
          if (widget.enableSmartSuggestions && _smartSuggestions.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Smart Crop Suggestions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _smartSuggestions.length,
                      itemBuilder: (context, index) {
                        final isSelected = _currentSuggestionIndex == index;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ElevatedButton(
                            onPressed: () => _applySuggestion(index),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected ? Colors.blue : Colors.grey[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: Text('Suggestion ${index + 1}'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          
          // Image with crop overlay
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _widgetSize = constraints.biggest;
                return InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 3.0,
                  onInteractionStart: (details) {
                    setState(() {
                      _isDragging = true;
                    });
                  },
                  onInteractionEnd: (details) {
                    setState(() {
                      _isDragging = false;
                    });
                    _updateCropFromTransform();
                  },
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
                      if (_currentCrop != null && _imageSize != null)
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
          
          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Reset button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetCrop,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Auto-fit button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _autoFitCrop,
                    icon: const Icon(Icons.fit_screen),
                    label: const Text('Auto Fit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build crop overlay with corner handles
  Widget _buildCropOverlay() {
    if (_currentCrop == null || _imageSize == null || _widgetSize == null) {
      return const SizedBox.shrink();
    }
    
    final scaleX = _widgetSize!.width / _imageSize!.width;
    final scaleY = _widgetSize!.height / _imageSize!.height;
    final scale = math.min(scaleX, scaleY);
    
    final scaledCrop = Rect.fromLTRB(
      _currentCrop!.left * scale,
      _currentCrop!.top * scale,
      _currentCrop!.right * scale,
      _currentCrop!.bottom * scale,
    );
    
    return Positioned.fill(
      child: CustomPaint(
        painter: CropOverlayPainter(
          cropRect: scaledCrop,
          imageSize: _imageSize!,
          widgetSize: _widgetSize!,
        ),
      ),
    );
  }
  
  /// Build grid overlay
  Widget _buildGridOverlay() {
    if (_currentCrop == null || _imageSize == null || _widgetSize == null) {
      return const SizedBox.shrink();
    }
    
    final scaleX = _widgetSize!.width / _imageSize!.width;
    final scaleY = _widgetSize!.height / _imageSize!.height;
    final scale = math.min(scaleX, scaleY);
    
    final scaledCrop = Rect.fromLTRB(
      _currentCrop!.left * scale,
      _currentCrop!.top * scale,
      _currentCrop!.right * scale,
      _currentCrop!.bottom * scale,
    );
    
    return Positioned.fill(
      child: CustomPaint(
        painter: GridOverlayPainter(
          cropRect: scaledCrop,
          showGrid: widget.showGrid,
        ),
      ),
    );
  }
  
  /// Update crop from transformation matrix
  void _updateCropFromTransform() {
    // This would calculate the current crop based on the transformation
    // For now, we'll keep the current crop
    _updateCrop();
  }
  
  /// Reset crop to default
  void _resetCrop() {
    setState(() {
      _currentCrop = _getDefaultCrop();
      _currentSuggestionIndex = -1;
    });
    _updateCrop();
    _animateToCrop();
  }
  
  /// Auto-fit crop to image
  void _autoFitCrop() {
    if (_imageSize == null) return;
    
    setState(() {
      _currentCrop = Rect.fromLTWH(
        0,
        0,
        _imageSize!.width,
        _imageSize!.height,
      );
      _currentSuggestionIndex = -1;
    });
    _updateCrop();
    _animateToCrop();
  }
}

/// Custom painter for crop overlay
class CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final Size imageSize;
  final Size widgetSize;
  
  CropOverlayPainter({
    required this.cropRect,
    required this.imageSize,
    required this.widgetSize,
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
    
    // Draw overlay outside crop area
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;
    
    canvas.drawPath(overlayPath, paint);
    
    // Draw crop rectangle
    canvas.drawRect(cropRect, cropPaint);
    
    // Draw corner handles
    const handleSize = 12.0;
    final handles = [
      Offset(cropRect.left, cropRect.top), // Top-left
      Offset(cropRect.right, cropRect.top), // Top-right
      Offset(cropRect.right, cropRect.bottom), // Bottom-right
      Offset(cropRect.left, cropRect.bottom), // Bottom-left
    ];
    
    for (final handle in handles) {
      canvas.drawCircle(handle, handleSize / 2, handlePaint);
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is CropOverlayPainter && oldDelegate.cropRect != cropRect;
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
