import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image/image.dart' as img;

class MLKitDocumentService {
  DocumentScanner? _documentScanner;
  
  /// Initialize the document scanner
  Future<void> initialize() async {
    try {
      // Configure the scanner with basic options
      final options = DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.full, // Full mode with UI
        isGalleryImport: true,   // Allow gallery import
        pageLimit: 1,           // Single page scanning
      );
      
      _documentScanner = DocumentScanner(options: options);
      print('✅ ML Kit Document Scanner initialized');
      
    } catch (e) {
      print('❌ Failed to initialize ML Kit Document Scanner: $e');
      // If ML Kit is not available, we'll continue without it
      _documentScanner = null;
    }
  }
  
  /// Scan document using ML Kit's built-in UI
  Future<dynamic> scanDocumentWithUI() async {
    try {
      if (_documentScanner == null) {
        await initialize();
      }
      
      if (_documentScanner == null) {
        print('❌ Document scanner not available');
        return null;
      }
      
      final result = await _documentScanner!.scanDocument();
      return result;
      
    } catch (e) {
      print('❌ Document scanning failed: $e');
      return null;
    }
  }
  
  /// Extract corners from existing image using ML Kit
  Future<List<Offset>?> detectDocumentCorners(File imageFile) async {
    try {
      // Note: ML Kit doesn't directly provide corner detection for existing images
      // This is a limitation of the current API
      // We'll implement a workaround using basic edge detection
      
      return await _extractCornersFromImage(imageFile);
      
    } catch (e) {
      print('❌ Corner detection failed: $e');
      return null;
    }
  }
  
  /// Workaround method to extract corners from image
  Future<List<Offset>?> _extractCornersFromImage(File imageFile) async {
    try {
      // Read image to get dimensions
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return null;
      
      // Use a simple edge detection algorithm as fallback
      // since ML Kit's corner detection isn't directly available for existing images
      return await _detectEdgesBasic(image);
      
    } catch (e) {
      print('❌ Basic edge detection failed: $e');
      return null;
    }
  }
  
  /// Basic edge detection as fallback
  Future<List<Offset>?> _detectEdgesBasic(img.Image image) async {
    try {
      // Convert to grayscale
      final grayscale = img.grayscale(image);
      
      // Apply Sobel edge detection
      final edges = img.sobel(grayscale);
      
      // Find document boundaries using simple algorithm
      final corners = _findDocumentCorners(edges);
      
      if (corners.length == 4) {
        return corners;
      }
      
      return null;
      
    } catch (e) {
      print('❌ Basic edge detection failed: $e');
      return null;
    }
  }
  
  /// Find document corners from edge-detected image
  List<Offset> _findDocumentCorners(img.Image edges) {
    final width = edges.width;
    final height = edges.height;
    
    // Simple corner detection algorithm
    List<Offset> corners = [];
    
    // Look for corners in each quadrant
    final quadrants = [
      {'startX': 0, 'endX': width ~/ 2, 'startY': 0, 'endY': height ~/ 2}, // Top-left
      {'startX': width ~/ 2, 'endX': width, 'startY': 0, 'endY': height ~/ 2}, // Top-right
      {'startX': width ~/ 2, 'endX': width, 'startY': height ~/ 2, 'endY': height}, // Bottom-right
      {'startX': 0, 'endX': width ~/ 2, 'startY': height ~/ 2, 'endY': height}, // Bottom-left
    ];
    
    for (final quadrant in quadrants) {
      final corner = _findCornerInQuadrant(
        edges,
        quadrant['startX']!,
        quadrant['endX']!,
        quadrant['startY']!,
        quadrant['endY']!,
      );
      if (corner != null) {
        corners.add(corner);
      }
    }
    
    // If we don't have 4 corners, create default ones
    if (corners.length != 4) {
      corners = [
        Offset(width * 0.1, height * 0.1),     // Top-left
        Offset(width * 0.9, height * 0.1),     // Top-right
        Offset(width * 0.9, height * 0.9),     // Bottom-right
        Offset(width * 0.1, height * 0.9),     // Bottom-left
      ];
    }
    
    return corners;
  }
  
  /// Find corner in specific quadrant
  Offset? _findCornerInQuadrant(img.Image edges, int startX, int endX, int startY, int endY) {
    int maxIntensity = 0;
    Offset? bestCorner;
    
    for (int y = startY; y < endY; y += 5) { // Step by 5 for performance
      for (int x = startX; x < endX; x += 5) {
        final pixel = edges.getPixel(x, y);
        final intensity = (pixel.r + pixel.g + pixel.b).toInt();
        
        if (intensity > maxIntensity) {
          maxIntensity = intensity;
          bestCorner = Offset(x.toDouble(), y.toDouble());
        }
      }
    }
    
    return bestCorner;
  }
  
  /// Dispose of resources
  void dispose() {
    _documentScanner?.close();
    _documentScanner = null;
  }
}