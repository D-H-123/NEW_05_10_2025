import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'interactive_crop_widget.dart';

/// Simple crop dialog with manual crop only (no auto-detect)
/// Users have full control over crop area
class SimpleCropDialog extends StatefulWidget {
  final File imageFile;
  final Function(File) onCropped;
  
  const SimpleCropDialog({
    super.key,
    required this.imageFile,
    required this.onCropped,
  });
  
  @override
  State<SimpleCropDialog> createState() => _SimpleCropDialogState();
}

class _SimpleCropDialogState extends State<SimpleCropDialog> {
  Rect? _currentCrop;
  bool _isProcessing = false;
  String _processingMessage = '';
  double _processingProgress = 0.0;
  
  @override
  void initState() {
    super.initState();
    _initializeCrop();
  }
  
  /// Initialize crop with default area
  Future<void> _initializeCrop() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        final width = image.width.toDouble();
        final height = image.height.toDouble();
        
        // Default crop: 80% of image with 10% margin
        final marginX = width * 0.1;
        final marginY = height * 0.1;
        
        _currentCrop = Rect.fromLTRB(
          marginX,
          marginY,
          width - marginX,
          height - marginY,
        );
      }
    } catch (e) {
      print('❌ CROP: Failed to initialize: $e');
    }
  }
  
  /// Apply crop to image with maximum efficiency
  Future<void> _applyCrop() async {
    if (_currentCrop == null) return;
    
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Processing crop...';
      _processingProgress = 0.0;
    });
    
    try {
      // Update progress
      setState(() {
        _processingMessage = 'Loading image...';
        _processingProgress = 0.2;
      });
      
      // Load image
      final bytes = await widget.imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Failed to load image');
      }
      
      setState(() {
        _processingMessage = 'Applying crop...';
        _processingProgress = 0.5;
      });
      
      // Apply crop with high precision
      final croppedImage = _applyCropToImage(image, _currentCrop!);
      
      setState(() {
        _processingMessage = 'Optimizing image...';
        _processingProgress = 0.8;
      });
      
      // Optimize image for OCR
      final optimizedImage = _optimizeForOCR(croppedImage);
      
      setState(() {
        _processingMessage = 'Saving result...';
        _processingProgress = 0.9;
      });
      
      // Save cropped image
      final croppedFile = await _saveCroppedImage(optimizedImage);
      
      setState(() {
        _processingMessage = 'Complete!';
        _processingProgress = 1.0;
      });
      
      // Close dialog and return result
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCropped(croppedFile);
      }
      
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _processingMessage = 'Error: ${e.toString()}';
        _processingProgress = 0.0;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Crop failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Apply crop to image with maximum precision
  img.Image _applyCropToImage(img.Image image, Rect crop) {
    // The crop rectangle is already in image coordinates from InteractiveCropWidget
    // Just ensure it's within image bounds
    final clampedCrop = Rect.fromLTRB(
      math.max(0, crop.left),
      math.max(0, crop.top),
      math.min(image.width.toDouble(), crop.right),
      math.min(image.height.toDouble(), crop.bottom),
    );
    
    // Convert to integer coordinates
    final x = clampedCrop.left.round();
    final y = clampedCrop.top.round();
    final width = (clampedCrop.right - clampedCrop.left).round();
    final height = (clampedCrop.bottom - clampedCrop.top).round();
    
    print('🔍 CROP DEBUG: Applying crop to image');
    print('  Image size: ${image.width}x${image.height}');
    print('  Crop rect: ${clampedCrop}');
    print('  Crop coordinates: x=$x, y=$y, w=$width, h=$height');
    
    // Apply crop
    return img.copyCrop(
      image,
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }
  
  /// Optimize image for OCR processing
  img.Image _optimizeForOCR(img.Image image) {
    // Resize if too large (max 1200px width/height for OCR efficiency)
    const maxSize = 1200;
    if (image.width > maxSize || image.height > maxSize) {
      final aspectRatio = image.width / image.height;
      int newWidth, newHeight;
      
      if (aspectRatio > 1) {
        newWidth = maxSize;
        newHeight = (maxSize / aspectRatio).round();
      } else {
        newHeight = maxSize;
        newWidth = (maxSize * aspectRatio).round();
      }
      
      image = img.copyResize(image, width: newWidth, height: newHeight);
    }
    
    // Convert to grayscale for better OCR
    final grayscale = img.grayscale(image);
    
    // Apply light contrast enhancement
    final enhanced = img.adjustColor(
      grayscale,
      contrast: 1.1,
      brightness: 1.05,
    );
    
    return enhanced;
  }
  
  /// Save cropped image to temporary file
  Future<File> _saveCroppedImage(img.Image image) async {
    final tempDir = Directory.systemTemp;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/cropped_receipt_$timestamp.jpg');
    
    // Encode with high quality
    final bytes = img.encodeJpg(image, quality: 95);
    await file.writeAsBytes(bytes);
    
    return file;
  }
  
  /// Cancel crop operation
  void _cancelCrop() {
    Navigator.of(context).pop();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.crop,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Crop Receipt',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _cancelCrop,
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Drag the corner handles to select your receipt area. Focus on the receipt content only.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Crop widget
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: InteractiveCropWidget(
                  imageFile: widget.imageFile,
                  initialCrop: _currentCrop,
                  onCropChanged: (crop) {
                    setState(() {
                      _currentCrop = crop;
                    });
                  },
                  showGrid: true,
                ),
              ),
            ),
            
            // Processing overlay
            if (_isProcessing)
              Container(
                color: Colors.black.withOpacity(0.8),
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
            
            // Controls
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Cancel button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : _cancelCrop,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Apply crop button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _applyCrop,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Apply Crop'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
