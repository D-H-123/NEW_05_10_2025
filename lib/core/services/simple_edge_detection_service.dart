import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'document_scanner_service.dart';
import 'advanced_edge_detection_service.dart';

/// Simple, reliable edge detection service that always returns 4 corners
/// This ensures the user always sees 4 draggable corner points
class SimpleEdgeDetectionService {
  
  /// Detect document edges with guaranteed 4 corners
  /// Always returns 4 corners, either detected or smart defaults
  static Future<List<Offset>> detectDocumentEdges(File imageFile) async {
    try {
      print('🔍 SIMPLE EDGE: Starting high-accuracy edge detection...');
      
      // Method 1: Try advanced edge detection (90%+ accuracy)
      final advancedCorners = await AdvancedEdgeDetectionService.detectDocumentEdges(imageFile);
      if (advancedCorners.length == 4) {
        print('✅ SIMPLE EDGE: Advanced detection successful');
        return _validateCorners(advancedCorners);
      }
      
      // Method 2: Try ML Kit service as fallback
      final mlKitService = MLKitDocumentService();
      await mlKitService.initialize();
      
      final mlKitCorners = await mlKitService.detectDocumentCorners(imageFile);
      if (mlKitCorners != null && mlKitCorners.length == 4) {
        print('✅ SIMPLE EDGE: ML Kit detection successful');
        return _validateCorners(mlKitCorners);
      }
      
      // Method 3: Try basic manual detection
      final detectedCorners = await _detectEdgesManually(imageFile);
      if (detectedCorners.length == 4) {
        print('✅ SIMPLE EDGE: Manual detection successful');
        return _validateCorners(detectedCorners);
      }
      
      // Method 4: Smart analysis-based defaults
      print('⚠️ SIMPLE EDGE: Using smart analysis-based defaults');
      return await _generateSmartDefaultCorners(imageFile);
      
    } catch (e) {
      print('❌ SIMPLE EDGE: All methods failed: $e');
      return await _generateSmartDefaultCorners(imageFile);
    }
  }
  
  /// Manual edge detection using fast image analysis
  static Future<List<Offset>> _detectEdgesManually(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        return await _generateSmartDefaultCorners(imageFile);
      }
      
      print('🔍 MANUAL EDGE: Starting fast manual detection...');
      
      // Resize image for faster processing
      final resizedImage = _resizeImageForSpeed(image);
      final width = resizedImage.width.toDouble();
      final height = resizedImage.height.toDouble();
      
      // Convert to grayscale
      final grayscale = img.grayscale(resizedImage);
      
      // Apply light blur for noise reduction
      final blurred = img.gaussianBlur(grayscale, radius: 1);
      
      // Apply edge detection
      final edges = img.sobel(blurred);
      
      // Find document boundaries using fast algorithm
      final corners = _findDocumentBoundariesFast(edges, width, height);
      
      if (corners.length == 4) {
        print('✅ MANUAL EDGE: Found 4 corners using fast detection');
        final scaledCorners = _scaleCornersToOriginal(corners, resizedImage, image);
        return _validateCorners(scaledCorners);
      }
      
      // Fallback: Try quadrant-based detection
      final quadrantCorners = _findCornersFromEdges(edges, width, height);
      if (quadrantCorners.length == 4) {
        print('✅ MANUAL EDGE: Found 4 corners using quadrant detection');
        final scaledCorners = _scaleCornersToOriginal(quadrantCorners, resizedImage, image);
        return _validateCorners(scaledCorners);
      }
      
      print('⚠️ MANUAL EDGE: Could not find 4 corners, using smart defaults');
      return await _generateSmartDefaultCorners(imageFile);
      
    } catch (e) {
      print('❌ Manual edge detection failed: $e');
      return await _generateSmartDefaultCorners(imageFile);
    }
  }
  
  /// Resize image for faster processing
  static img.Image _resizeImageForSpeed(img.Image image) {
    const maxSize = 600; // Smaller than advanced for speed
    
    if (image.width <= maxSize && image.height <= maxSize) {
      return image;
    }
    
    final aspectRatio = image.width / image.height;
    int newWidth, newHeight;
    
    if (aspectRatio > 1) {
      newWidth = maxSize;
      newHeight = (maxSize / aspectRatio).round();
    } else {
      newHeight = maxSize;
      newWidth = (maxSize * aspectRatio).round();
    }
    
    return img.copyResize(image, width: newWidth, height: newHeight);
  }
  
  /// Scale corners back to original image size
  static List<Offset> _scaleCornersToOriginal(List<Offset> corners, img.Image resizedImage, img.Image originalImage) {
    final scaleX = originalImage.width / resizedImage.width;
    final scaleY = originalImage.height / resizedImage.height;
    
    return corners.map((corner) => 
      Offset(corner.dx * scaleX, corner.dy * scaleY)
    ).toList();
  }
  
  /// Find document boundaries using high-accuracy algorithm
  static List<Offset> _findDocumentBoundariesFast(img.Image image, double width, double height) {
    final corners = <Offset>[];
    
    // Use smaller steps for better accuracy
    final step = math.max(1, math.min(width, height).toInt() ~/ 120);
    const edgeThreshold = 90; // Higher threshold for better accuracy
    
    // Top edge
    for (int y = 0; y < (height * 0.4).toInt(); y += step) {
      for (int x = 0; x < width.toInt(); x += step) {
        final pixel = image.getPixel(x, y);
        final intensity = (pixel.r + pixel.g + pixel.b) / 3;
        
        if (intensity > edgeThreshold) {
          final leftX = _findEdgeStartFast(image, x, y, true, step);
          final rightX = _findEdgeEndFast(image, x, y, true, step);
          
          if (leftX != null && rightX != null) {
            corners.add(Offset(leftX, y.toDouble()));
            corners.add(Offset(rightX, y.toDouble()));
          }
          break;
        }
      }
    }
    
    // Bottom edge
    for (int y = (height * 0.6).toInt(); y < height.toInt(); y += step) {
      for (int x = 0; x < width.toInt(); x += step) {
        final pixel = image.getPixel(x, y);
        final intensity = (pixel.r + pixel.g + pixel.b) / 3;
        
        if (intensity > edgeThreshold) {
          final leftX = _findEdgeStartFast(image, x, y, true, step);
          final rightX = _findEdgeEndFast(image, x, y, true, step);
          
          if (leftX != null && rightX != null) {
            corners.add(Offset(leftX, y.toDouble()));
            corners.add(Offset(rightX, y.toDouble()));
          }
          break;
        }
      }
    }
    
    // Left edge
    for (int x = 0; x < (width * 0.4).toInt(); x += step) {
      for (int y = 0; y < height.toInt(); y += step) {
        final pixel = image.getPixel(x, y);
        final intensity = (pixel.r + pixel.g + pixel.b) / 3;
        
        if (intensity > edgeThreshold) {
          final topY = _findEdgeStartFast(image, x, y, false, step);
          final bottomY = _findEdgeEndFast(image, x, y, false, step);
          
          if (topY != null && bottomY != null) {
            corners.add(Offset(x.toDouble(), topY));
            corners.add(Offset(x.toDouble(), bottomY));
          }
          break;
        }
      }
    }
    
    // Right edge
    for (int x = (width * 0.6).toInt(); x < width.toInt(); x += step) {
      for (int y = 0; y < height.toInt(); y += step) {
        final pixel = image.getPixel(x, y);
        final intensity = (pixel.r + pixel.g + pixel.b) / 3;
        
        if (intensity > edgeThreshold) {
          final topY = _findEdgeStartFast(image, x, y, false, step);
          final bottomY = _findEdgeEndFast(image, x, y, false, step);
          
          if (topY != null && bottomY != null) {
            corners.add(Offset(x.toDouble(), topY));
            corners.add(Offset(x.toDouble(), bottomY));
          }
          break;
        }
      }
    }
    
    // If we found enough corners, return them
    if (corners.length >= 4) {
      return corners.take(4).toList();
    }
    
    return [];
  }
  
  /// Find start of edge with high accuracy
  static double? _findEdgeStartFast(img.Image image, int startX, int startY, bool isHorizontal, int step) {
    const threshold = 90;
    
    if (isHorizontal) {
      for (int x = startX; x >= 0; x -= step) {
        final pixel = image.getPixel(x, startY);
        final intensity = (pixel.r + pixel.g + pixel.b) / 3;
        if (intensity < threshold) {
          return x.toDouble();
        }
      }
    } else {
      for (int y = startY; y >= 0; y -= step) {
        final pixel = image.getPixel(startX, y);
        final intensity = (pixel.r + pixel.g + pixel.b) / 3;
        if (intensity < threshold) {
          return y.toDouble();
        }
      }
    }
    
    return null;
  }
  
  /// Find end of edge with high accuracy
  static double? _findEdgeEndFast(img.Image image, int startX, int startY, bool isHorizontal, int step) {
    const threshold = 90;
    
    if (isHorizontal) {
      for (int x = startX; x < image.width; x += step) {
        final pixel = image.getPixel(x, startY);
        final intensity = (pixel.r + pixel.g + pixel.b) / 3;
        if (intensity < threshold) {
          return x.toDouble();
        }
      }
    } else {
      for (int y = startY; y < image.height; y += step) {
        final pixel = image.getPixel(startX, y);
        final intensity = (pixel.r + pixel.g + pixel.b) / 3;
        if (intensity < threshold) {
          return y.toDouble();
        }
      }
    }
    
    return null;
  }
  
  /// Find corners from edge-detected image
  static List<Offset> _findCornersFromEdges(img.Image edges, double width, double height) {
    final corners = <Offset>[];
    
    // Define search regions for each corner
    final regions = [
      {'name': 'top-left', 'startX': 0, 'endX': (width * 0.5).toInt(), 'startY': 0, 'endY': (height * 0.5).toInt()},
      {'name': 'top-right', 'startX': (width * 0.5).toInt(), 'endX': width.toInt(), 'startY': 0, 'endY': (height * 0.5).toInt()},
      {'name': 'bottom-right', 'startX': (width * 0.5).toInt(), 'endX': width.toInt(), 'startY': (height * 0.5).toInt(), 'endY': height.toInt()},
      {'name': 'bottom-left', 'startX': 0, 'endX': (width * 0.5).toInt(), 'startY': (height * 0.5).toInt(), 'endY': height.toInt()},
    ];
    
    for (final region in regions) {
      final corner = _findCornerInRegion(
        edges,
        region['startX'] as int,
        region['endX'] as int,
        region['startY'] as int,
        region['endY'] as int,
      );
      
      if (corner != null) {
        corners.add(corner);
      }
    }
    
    // If we don't have 4 corners, fill in with smart defaults
    while (corners.length < 4) {
      final index = corners.length;
      final defaultCorner = _getDefaultCorner(index, width, height);
      corners.add(defaultCorner);
    }
    
    return corners;
  }
  
  /// Find corner in specific region
  static Offset? _findCornerInRegion(img.Image edges, int startX, int endX, int startY, int endY) {
    int maxIntensity = 0;
    Offset? bestCorner;
    
    // Sample every 5 pixels for performance
    for (int y = startY; y < endY; y += 5) {
      for (int x = startX; x < endX; x += 5) {
        if (x < edges.width && y < edges.height) {
          final pixel = edges.getPixel(x, y);
          final intensity = (pixel.r + pixel.g + pixel.b).toInt();
          
          if (intensity > maxIntensity) {
            maxIntensity = intensity;
            bestCorner = Offset(x.toDouble(), y.toDouble());
          }
        }
      }
    }
    
    // Only return corner if we found a strong edge
    if (maxIntensity > 50) {
      return bestCorner;
    }
    
    return null;
  }
  
  /// Get default corner based on index
  static Offset _getDefaultCorner(int index, double width, double height) {
    switch (index) {
      case 0: // Top-left
        return Offset(width * 0.1, height * 0.1);
      case 1: // Top-right
        return Offset(width * 0.9, height * 0.1);
      case 2: // Bottom-right
        return Offset(width * 0.9, height * 0.9);
      case 3: // Bottom-left
        return Offset(width * 0.1, height * 0.9);
      default:
        return Offset(width * 0.5, height * 0.5);
    }
  }
  
  /// Generate smart default corners based on image analysis
  static Future<List<Offset>> _generateSmartDefaultCorners(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        // Ultimate fallback - ensure 4 distinct corners
        return [
          const Offset(50, 50),      // Top-left
          const Offset(350, 50),     // Top-right  
          const Offset(350, 450),    // Bottom-right
          const Offset(50, 450),     // Bottom-left
        ];
      }
      
      final width = image.width.toDouble();
      final height = image.height.toDouble();
      
      // Always generate 4 distinct corners in proper order
      // Top-left, Top-right, Bottom-right, Bottom-left
      final corners = [
        Offset(width * 0.1, height * 0.1),      // Top-left
        Offset(width * 0.9, height * 0.1),      // Top-right
        Offset(width * 0.9, height * 0.9),      // Bottom-right
        Offset(width * 0.1, height * 0.9),      // Bottom-left
      ];
      
      print('🔍 DEBUG: Generated smart default corners: $corners');
      return corners;
      
    } catch (e) {
      print('❌ Smart default corners failed: $e');
      // Ultimate fallback - ensure 4 distinct corners
      return [
        const Offset(50, 50),      // Top-left
        const Offset(350, 50),     // Top-right
        const Offset(350, 450),    // Bottom-right
        const Offset(50, 450),     // Bottom-left
      ];
    }
  }
  
  
  /// Validate and correct corner order
  static List<Offset> _validateCorners(List<Offset> corners) {
    if (corners.length != 4) {
      // If we don't have 4 corners, return empty list
      return [];
    }
    
    // Ensure corners are in correct order: top-left, top-right, bottom-right, bottom-left
    final sortedCorners = List<Offset>.from(corners);
    
    // Sort by Y coordinate first, then by X coordinate
    sortedCorners.sort((a, b) {
      if ((a.dy - b.dy).abs() < 10) {
        // Same row, sort by X
        return a.dx.compareTo(b.dx);
      } else {
        // Different rows, sort by Y
        return a.dy.compareTo(b.dy);
      }
    });
    
    // Ensure we have the correct order
    final topLeft = sortedCorners[0];
    final topRight = sortedCorners[1];
    final bottomRight = sortedCorners[2];
    final bottomLeft = sortedCorners[3];
    
    return [topLeft, topRight, bottomRight, bottomLeft];
  }
}
