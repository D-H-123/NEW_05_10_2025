import 'dart:io';
import 'package:flutter/material.dart';
import '../services/optimized_edge_detection_service.dart';
import '../services/background_edge_processing_service.dart';

/// Enhanced edge detection widget with real-time preview
class EnhancedEdgeDetectionWidget extends StatefulWidget {
  final File imageFile;
  final List<Offset>? initialCorners;
  final Function(List<Offset>) onCornersChanged;
  final bool showPreview;
  final bool enableBackgroundProcessing;
  
  const EnhancedEdgeDetectionWidget({
    super.key,
    required this.imageFile,
    this.initialCorners,
    required this.onCornersChanged,
    this.showPreview = true,
    this.enableBackgroundProcessing = true,
  });
  
  @override
  State<EnhancedEdgeDetectionWidget> createState() => _EnhancedEdgeDetectionWidgetState();
}

class _EnhancedEdgeDetectionWidgetState extends State<EnhancedEdgeDetectionWidget> {
  List<Offset>? _detectedCorners;
  bool _isProcessing = false;
  String _processingMessage = 'Detecting edges...';
  double _processingProgress = 0.0;
  bool _hasError = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _detectedCorners = widget.initialCorners;
    _detectEdges();
  }
  
  Future<void> _detectEdges() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
      _hasError = false;
      _errorMessage = null;
      _processingMessage = 'Detecting edges...';
      _processingProgress = 0.0;
    });
    
    try {
      List<Offset> corners;
      
      if (widget.enableBackgroundProcessing) {
        // Use background processing with progress tracking
        corners = await BackgroundEdgeProcessingService.processWithProgress(
          widget.imageFile,
          (progress) {
            if (mounted) {
              setState(() {
                _processingMessage = progress.message;
                _processingProgress = progress.progress;
                _hasError = progress.hasError;
              });
            }
          },
        );
      } else {
        // Use direct processing
        corners = await OptimizedEdgeDetectionService.detectDocumentEdges(widget.imageFile);
      }
      
      if (mounted) {
        setState(() {
          _detectedCorners = corners;
          _isProcessing = false;
          _processingMessage = 'Complete!';
          _processingProgress = 1.0;
        });
        
        widget.onCornersChanged(corners);
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _hasError = true;
          _errorMessage = e.toString();
          _processingMessage = 'Detection failed';
          _processingProgress = 0.0;
        });
      }
    }
  }
  
  Future<void> _retryDetection() async {
    await _detectEdges();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Image with edge preview
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  // Image
                  Image.file(
                    widget.imageFile,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  
                  // Edge preview overlay
                  if (widget.showPreview && _detectedCorners != null)
                    CustomPaint(
                      painter: EdgePreviewPainter(_detectedCorners!),
                      size: Size.infinite,
                    ),
                  
                  // Processing overlay
                  if (_isProcessing)
                    Container(
                      color: Colors.black.withOpacity(0.7),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _processingMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_processingProgress > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: LinearProgressIndicator(
                                  value: _processingProgress,
                                  backgroundColor: Colors.white.withOpacity(0.3),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Error overlay
                  if (_hasError)
                    Container(
                      color: Colors.red.withOpacity(0.8),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Detection Failed',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Controls
        Row(
          children: [
            // Retry button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _retryDetection,
                icon: const Icon(Icons.refresh),
                label: Text(_isProcessing ? 'Processing...' : 'Retry Detection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasError ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _hasError 
                    ? Colors.red.withOpacity(0.1)
                    : _isProcessing 
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _hasError 
                      ? Colors.red
                      : _isProcessing 
                          ? Colors.blue
                          : Colors.green,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _hasError 
                        ? Icons.error_outline
                        : _isProcessing 
                            ? Icons.hourglass_empty
                            : Icons.check_circle,
                    size: 16,
                    color: _hasError 
                        ? Colors.red
                        : _isProcessing 
                            ? Colors.blue
                            : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _hasError 
                        ? 'Failed'
                        : _isProcessing 
                            ? 'Processing'
                            : 'Complete',
                    style: TextStyle(
                      color: _hasError 
                          ? Colors.red
                          : _isProcessing 
                              ? Colors.blue
                              : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Custom painter for edge preview
class EdgePreviewPainter extends CustomPainter {
  final List<Offset> corners;
  
  EdgePreviewPainter(this.corners);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;
    
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    final cornerPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    
    // Draw edges
    for (int i = 0; i < corners.length; i++) {
      final start = corners[i];
      final end = corners[(i + 1) % corners.length];
      
      canvas.drawLine(start, end, paint);
    }
    
    // Draw corner points
    for (final corner in corners) {
      canvas.drawCircle(corner, 8, cornerPaint);
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is EdgePreviewPainter && oldDelegate.corners != corners;
  }
}
