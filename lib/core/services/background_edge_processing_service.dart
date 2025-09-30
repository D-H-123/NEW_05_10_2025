import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'optimized_edge_detection_service.dart';

/// Background processing service for edge detection
/// Provides non-blocking UI processing with progress tracking
class BackgroundEdgeProcessingService {
  
  /// Process image in background with progress tracking
  static Future<List<Offset>> processWithProgress(
    File imageFile, 
    Function(EdgeProcessingProgress) onProgress,
  ) async {
    try {
      print('🔄 BACKGROUND: Starting background processing...');
      
      // Update progress
      onProgress(EdgeProcessingProgress(
        step: 0,
        message: 'Analyzing image...',
        progress: 0.1,
        isCompleted: false,
      ));
      
      // Check cache first
      final cachedResult = await OptimizedEdgeDetectionService.getCachedResult(imageFile);
      if (cachedResult != null) {
        onProgress(EdgeProcessingProgress(
          step: 1,
          message: 'Using cached result...',
          progress: 1.0,
          isCompleted: true,
        ));
        return cachedResult.corners;
      }
      
      // Update progress
      onProgress(EdgeProcessingProgress(
        step: 1,
        message: 'Detecting edges...',
        progress: 0.3,
        isCompleted: false,
      ));
      
      // Process in isolate
      final corners = await compute(_processImageInIsolate, imageFile);
      
      // Update progress
      onProgress(EdgeProcessingProgress(
        step: 2,
        message: 'Optimizing results...',
        progress: 0.8,
        isCompleted: false,
      ));
      
      // Final progress
      onProgress(EdgeProcessingProgress(
        step: 3,
        message: 'Complete!',
        progress: 1.0,
        isCompleted: true,
      ));
      
      return corners;
      
    } catch (e) {
      print('❌ BACKGROUND: Processing failed: $e');
      
      // Update progress with error
      onProgress(EdgeProcessingProgress(
        step: -1,
        message: 'Processing failed: ${e.toString()}',
        progress: 0.0,
        isCompleted: false,
        hasError: true,
      ));
      
      // Return default corners
      return await OptimizedEdgeDetectionService.generateSmartDefaultCorners(imageFile);
    }
  }
  
  /// Process image in isolate (for background processing)
  static Future<List<Offset>> _processImageInIsolate(File imageFile) async {
    try {
      print('🔄 ISOLATE: Processing image in isolate...');
      
      // Use optimized edge detection service
      return await OptimizedEdgeDetectionService.detectDocumentEdges(imageFile);
      
    } catch (e) {
      print('❌ ISOLATE: Processing failed: $e');
      rethrow;
    }
  }
  
  /// Process multiple images in background
  static Future<Map<String, List<Offset>>> processMultipleImages(
    List<File> imageFiles,
    Function(String, EdgeProcessingProgress) onProgress,
  ) async {
    final results = <String, List<Offset>>{};
    
    for (int i = 0; i < imageFiles.length; i++) {
      final imageFile = imageFiles[i];
      final fileName = imageFile.path.split('/').last;
      
      try {
        onProgress(fileName, EdgeProcessingProgress(
          step: 0,
          message: 'Processing $fileName...',
          progress: i / imageFiles.length,
          isCompleted: false,
        ));
        
        final corners = await processWithProgress(imageFile, (progress) {
          onProgress(fileName, progress);
        });
        
        results[fileName] = corners;
        
      } catch (e) {
        print('❌ BACKGROUND: Failed to process $fileName: $e');
        results[fileName] = await OptimizedEdgeDetectionService.generateSmartDefaultCorners(imageFile);
      }
    }
    
    return results;
  }
  
  /// Cancel processing (placeholder for future implementation)
  static void cancelProcessing() {
    print('⏹️ BACKGROUND: Processing cancelled');
    // TODO: Implement cancellation logic
  }
}

/// Progress tracking for edge processing
class EdgeProcessingProgress {
  final int step;
  final String message;
  final double progress; // 0.0 to 1.0
  final bool isCompleted;
  final bool hasError;
  
  EdgeProcessingProgress({
    required this.step,
    required this.message,
    required this.progress,
    required this.isCompleted,
    this.hasError = false,
  });
  
  @override
  String toString() {
    return 'EdgeProcessingProgress(step: $step, message: $message, progress: ${(progress * 100).toInt()}%, completed: $isCompleted, error: $hasError)';
  }
}
