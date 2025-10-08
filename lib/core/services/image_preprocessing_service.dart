import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

/// Fixed and optimized OCR preprocessing service
class ImagePreprocessingService {
  
  /// OPTIMIZED: Single-run preprocessing pipeline for ML Kit OCR
  /// FIXED: Disabled geometric corrections to prevent text line splitting
  Future<File> preprocessForMaximumOCRAccuracy(File originalImage) async {
    print('🚀 OPTIMIZED OCR: Starting 4-step preprocessing pipeline (geometric corrections disabled)...');
    
    try {
      final bytes = await originalImage.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }
      img.Image image = decodedImage;
      
      print('📊 OPTIMIZED OCR: Original image: ${image.width}x${image.height}');
      
      // STEP 1: Smart size optimization (combines Phase 1 & 3)
      image = _optimizedSizeAndBasicCorrections(image);
      print('✅ STEP 1: Size optimization and basic corrections completed');
      
      // STEP 2: Geometric corrections (DISABLED - causes text line splitting)
      // DISABLED: Skew correction was causing "Receipt Total" and "$154.06" to be split across lines
      // try {
      //   image = _applyGeometricCorrections(image);
      //   print('✅ STEP 2: Geometric corrections completed (TESTING)');
      // } catch (e) {
      //   print('⚠️ STEP 2: Geometric corrections failed, continuing: $e');
      // }
      print('⏭️ STEP 2: Geometric corrections skipped (disabled to prevent text line splitting)');
      
      // STEP 2: Fast contrast enhancement (simplified Phase 4)
      image = _fastContrastEnhancement(image);
      print('✅ STEP 2: Fast contrast enhancement completed');
      
      // STEP 3: Lightweight noise reduction (simplified Phase 5)
      image = _lightweightNoiseReduction(image);
      print('✅ STEP 3: Lightweight noise reduction completed');
      
      // STEP 4: Essential text enhancement (simplified Phase 6)
      image = _essentialTextEnhancement(image);
      print('✅ STEP 4: Essential text enhancement completed');
      
      // Save the optimized image
      final directory = await getTemporaryDirectory();
      final enhancedPath = "${directory.path}/optimized_ocr_phase2_test_${DateTime.now().millisecondsSinceEpoch}.jpg";
      
      final optimizedBytes = img.encodeJpg(image, quality: 90);
      final enhancedFile = File(enhancedPath);
      await enhancedFile.writeAsBytes(optimizedBytes);
      
      print('✅ OPTIMIZED OCR: 4-step pipeline completed (geometric corrections disabled): $enhancedPath');
      return enhancedFile;
      
    } catch (e) {
      print('❌ OPTIMIZED OCR: Processing failed: $e');
      return await _fallbackPreprocessing(originalImage);
    }
  }

  /// SAFE LEGACY: 5-phase preprocessing pipeline (skips problematic phase 6)
  /// This provides better quality than optimized pipeline but avoids crashes
  Future<File> preprocessForMaximumOCRAccuracyLegacySafe(File originalImage) async {
    print('🔍 SAFE LEGACY OCR: Starting 5-phase preprocessing pipeline (skipping phase 6)...');
    
    try {
      final bytes = await originalImage.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }
      img.Image image = decodedImage;
      
      print('📊 SAFE LEGACY OCR: Original image: ${image.width}x${image.height}');
      
      // Check if image is too large and needs downscaling first
      const maxInitialDimension = 3000;
      if (image.width > maxInitialDimension || image.height > maxInitialDimension) {
        print('⚠️ SAFE LEGACY OCR: Image too large, downscaling first...');
        final aspectRatio = image.width / image.height;
        int newWidth, newHeight;
        
        if (image.width > image.height) {
          newWidth = maxInitialDimension;
          newHeight = (maxInitialDimension / aspectRatio).round();
        } else {
          newHeight = maxInitialDimension;
          newWidth = (maxInitialDimension * aspectRatio).round();
        }
        
        image = img.copyResize(image, width: newWidth, height: newHeight);
        print('📊 SAFE LEGACY OCR: Downscaled to: ${image.width}x${image.height}');
      }
      
      // PHASE 1: Input Validation and Basic Corrections
      try {
        image = _validateAndFixBasicIssues(image);
        print('✅ PHASE 1: Input validation completed');
      } catch (e) {
        print('⚠️ PHASE 1: Input validation failed, continuing: $e');
      }
      
      // PHASE 2: Geometric Corrections
      try {
        image = _applyGeometricCorrections(image);
        print('✅ PHASE 2: Geometric corrections completed');
      } catch (e) {
        print('⚠️ PHASE 2: Geometric corrections failed, continuing: $e');
      }
      
      // PHASE 3: Resolution Enhancement (with memory protection)
      try {
        image = _enhanceResolutionForOCR(image);
        print('✅ PHASE 3: Resolution enhancement completed');
      } catch (e) {
        print('⚠️ PHASE 3: Resolution enhancement failed, continuing: $e');
      }
      
      // PHASE 4: Lighting and Contrast Normalization  
      try {
        image = _normalizeLightingAndContrast(image);
        print('✅ PHASE 4: Lighting normalization completed');
      } catch (e) {
        print('⚠️ PHASE 4: Lighting normalization failed, continuing: $e');
      }
      
      // PHASE 5: Advanced Noise Reduction
      try {
        image = _applyAdvancedNoiseReduction(image);
        print('✅ PHASE 5: Noise reduction completed');
      } catch (e) {
        print('⚠️ PHASE 5: Noise reduction failed, continuing: $e');
      }
      
      // SKIPPED PHASE 6: Text Enhancement (was causing crashes)
      print('⏭️ PHASE 6: Text enhancement SKIPPED (crash prevention)');
      
      // PHASE 7: Final Optimizations
      try {
        image = _applyFinalOptimizations(image);
        print('✅ PHASE 7: Final optimizations completed');
      } catch (e) {
        print('⚠️ PHASE 7: Final optimizations failed, continuing: $e');
      }
      
      // Save the enhanced image with memory-efficient encoding
      final directory = await getTemporaryDirectory();
      final enhancedPath = "${directory.path}/safe_legacy_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg";
      
      try {
        // Use lower quality to reduce memory usage
        final optimizedBytes = img.encodeJpg(image, quality: 85);
      final enhancedFile = File(enhancedPath);
        await enhancedFile.writeAsBytes(optimizedBytes);
      
        print('✅ SAFE LEGACY OCR: 5-phase preprocessing completed: $enhancedPath');
      return enhancedFile;
    } catch (e) {
        print('❌ SAFE LEGACY OCR: Failed to save enhanced image: $e');
        // Try with even lower quality
        final optimizedBytes = img.encodeJpg(image, quality: 70);
        final enhancedFile = File(enhancedPath);
        await enhancedFile.writeAsBytes(optimizedBytes);
        return enhancedFile;
      }
      
    } catch (e) {
      print('❌ SAFE LEGACY OCR: Enhanced preprocessing failed: $e');
      return await _fallbackPreprocessing(originalImage);
    }
  }

  /// LEGACY: Original 7-phase preprocessing pipeline (kept for comparison)
  Future<File> preprocessForMaximumOCRAccuracyLegacy(File originalImage) async {
    print('🔍 LEGACY OCR: Starting 7-phase preprocessing pipeline...');
    
    try {
      final bytes = await originalImage.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }
      img.Image image = decodedImage;
      
      print('📊 LEGACY OCR: Original image: ${image.width}x${image.height}');
      
      // Check if image is too large and needs downscaling first
      const maxInitialDimension = 3000;
      if (image.width > maxInitialDimension || image.height > maxInitialDimension) {
        print('⚠️ LEGACY OCR: Image too large, downscaling first...');
        final aspectRatio = image.width / image.height;
        int newWidth, newHeight;
        
        if (image.width > image.height) {
          newWidth = maxInitialDimension;
          newHeight = (maxInitialDimension / aspectRatio).round();
        } else {
          newHeight = maxInitialDimension;
          newWidth = (maxInitialDimension * aspectRatio).round();
        }
        
        image = img.copyResize(image, width: newWidth, height: newHeight);
        print('📊 LEGACY OCR: Downscaled to: ${image.width}x${image.height}');
      }
      
      // PHASE 1: Input Validation and Basic Corrections
      try {
        image = _validateAndFixBasicIssues(image);
        print('✅ PHASE 1: Input validation completed');
      } catch (e) {
        print('⚠️ PHASE 1: Input validation failed, continuing: $e');
      }
      
      // PHASE 2: Geometric Corrections
      try {
        image = _applyGeometricCorrections(image);
        print('✅ PHASE 2: Geometric corrections completed');
      } catch (e) {
        print('⚠️ PHASE 2: Geometric corrections failed, continuing: $e');
      }
      
      // PHASE 3: Resolution Enhancement (with memory protection)
      try {
        image = _enhanceResolutionForOCR(image);
        print('✅ PHASE 3: Resolution enhancement completed');
      } catch (e) {
        print('⚠️ PHASE 3: Resolution enhancement failed, continuing: $e');
      }
      
      // PHASE 4: Lighting and Contrast Normalization  
      try {
        image = _normalizeLightingAndContrast(image);
        print('✅ PHASE 4: Lighting normalization completed');
      } catch (e) {
        print('⚠️ PHASE 4: Lighting normalization failed, continuing: $e');
      }
      
      // PHASE 5: Advanced Noise Reduction
      try {
        image = _applyAdvancedNoiseReduction(image);
        print('✅ PHASE 5: Noise reduction completed');
      } catch (e) {
        print('⚠️ PHASE 5: Noise reduction failed, continuing: $e');
      }
      
      // PHASE 6: Text Enhancement
      try {
        image = _enhanceTextForOCR(image);
        print('✅ PHASE 6: Text enhancement completed');
      } catch (e) {
        print('⚠️ PHASE 6: Text enhancement failed, continuing: $e');
      }
      
      // PHASE 7: Final Optimizations
      try {
        image = _applyFinalOptimizations(image);
        print('✅ PHASE 7: Final optimizations completed');
      } catch (e) {
        print('⚠️ PHASE 7: Final optimizations failed, continuing: $e');
      }
      
      // Save the enhanced image with memory-efficient encoding
      final directory = await getTemporaryDirectory();
      final enhancedPath = "${directory.path}/enhanced_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg";
      
      try {
        // Use lower quality to reduce memory usage
        final optimizedBytes = img.encodeJpg(image, quality: 85);
      final enhancedFile = File(enhancedPath);
      await enhancedFile.writeAsBytes(optimizedBytes);
      
        print('✅ LEGACY OCR: Maximum accuracy preprocessing completed: $enhancedPath');
      return enhancedFile;
      } catch (e) {
        print('❌ LEGACY OCR: Failed to save enhanced image: $e');
        // Try with even lower quality
        final optimizedBytes = img.encodeJpg(image, quality: 70);
        final enhancedFile = File(enhancedPath);
        await enhancedFile.writeAsBytes(optimizedBytes);
        return enhancedFile;
      }
      
    } catch (e) {
      print('❌ LEGACY OCR: Enhanced preprocessing failed: $e');
      return await _fallbackPreprocessing(originalImage);
    }
  }
  
  /// Smart preprocessing that chooses between optimized and legacy based on image quality
  /// FIXED: Always use 4-step optimized pipeline for best quality
  Future<File> preprocessForMaximumOCRAccuracySmart(File originalImage) async {
    print('🧠 SMART OCR: Analyzing image to choose optimal preprocessing...');
    
    try {
      final bytes = await originalImage.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }
      
      // Quick quality assessment
      final quality = _quickQualityAssessment(decodedImage);
      print('📊 SMART OCR: Image quality assessed as: $quality');
      
      // FIXED: Always use 4-step optimized pipeline for best quality
      // The 4-step pipeline provides the best results, so use it for all images
      print('🚀 SMART OCR: Using 4-step optimized pipeline for best quality (all images)');
      return await preprocessForMaximumOCRAccuracy(originalImage);
      
    } catch (e) {
      print('❌ SMART OCR: Quality assessment failed, using optimized pipeline: $e');
      return await preprocessForMaximumOCRAccuracy(originalImage);
    }
  }
  
  /// Quick quality assessment for smart preprocessing selection
  /// SIMPLIFIED: Since we always use 4-step pipeline, just return good quality
  ImageQuality _quickQualityAssessment(img.Image image) {
    // Since we always use the 4-step optimized pipeline for best quality,
    // we can simplify this to just return good quality for logging purposes
    return ImageQuality.good;
  }
  
  /// Specialized preprocessing for different document types
  Future<File> preprocessForDocumentType(File originalImage, DocumentType type) async {
    switch (type) {
      case DocumentType.receipt:
        return await _preprocessReceipt(originalImage);
      case DocumentType.businessCard:
        return await _preprocessBusinessCard(originalImage);
      case DocumentType.handwritten:
        return await _preprocessHandwritten(originalImage);
      case DocumentType.book:
        return await _preprocessBook(originalImage);
      case DocumentType.whiteboard:
        return await _preprocessWhiteboard(originalImage);
      default:
        return await preprocessForMaximumOCRAccuracy(originalImage);
    }
  }
  
  // ===== OPTIMIZED METHODS FOR SINGLE-RUN PIPELINE =====
  
  /// STEP 1: Smart size optimization (combines Phase 1 & 3)
  /// Optimized version that handles size and basic corrections in one pass
  img.Image _optimizedSizeAndBasicCorrections(img.Image image) {
    print('🚀 OPTIMIZED STEP 1: Smart size optimization and basic corrections...');
    
    // Smart size optimization
    const targetDPI = 300.0;
    const assumedOriginalDPI = 72.0;
    const maxDimension = 2000;
    const minDimension = 300;
    
    // Calculate optimal size
    const scaleFactor = targetDPI / assumedOriginalDPI;
    int newWidth = (image.width * scaleFactor).round();
    int newHeight = (image.height * scaleFactor).round();
    
    // Apply size constraints
    if (newWidth > maxDimension || newHeight > maxDimension) {
      final aspectRatio = image.width / image.height;
      if (newWidth > newHeight) {
        newWidth = maxDimension;
        newHeight = (maxDimension / aspectRatio).round();
      } else {
        newHeight = maxDimension;
        newWidth = (maxDimension * aspectRatio).round();
      }
    }
    
    if (newWidth < minDimension || newHeight < minDimension) {
      final aspectRatio = image.width / image.height;
      if (newWidth < newHeight) {
        newWidth = minDimension;
        newHeight = (minDimension / aspectRatio).round();
      } else {
        newHeight = minDimension;
        newWidth = (minDimension * aspectRatio).round();
      }
    }
    
    // Resize if needed
    if (newWidth != image.width || newHeight != image.height) {
      image = img.copyResize(image, width: newWidth, height: newHeight, interpolation: img.Interpolation.linear);
    }
    
    // Convert to grayscale (fast operation)
    if (!_isGrayscaleFast(image)) {
      image = img.grayscale(image);
    }
    
    // Fast exposure correction (simplified)
    image = _fastExposureCorrection(image);
    
    return image;
  }
  
  /// STEP 2: Fast contrast enhancement (simplified Phase 4)
  /// Replaces expensive CLAHE with fast histogram equalization
  img.Image _fastContrastEnhancement(img.Image image) {
    print('🚀 OPTIMIZED STEP 2: Fast contrast enhancement...');
    
    // Use simple contrast stretching instead of CLAHE
    return _applyContrastStretching(image);
  }
  
  /// Simple contrast stretching for fast enhancement
  img.Image _applyContrastStretching(img.Image image) {
    // Find min and max pixel values
    int minVal = 255, maxVal = 0;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = img.getLuminance(image.getPixel(x, y)).round();
        minVal = math.min(minVal, pixel);
        maxVal = math.max(maxVal, pixel);
      }
    }
    
    if (maxVal <= minVal) return image;
    
    // Apply contrast stretching
    final result = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = img.getLuminance(image.getPixel(x, y));
        final stretched = ((pixel - minVal) * 255 / (maxVal - minVal)).clamp(0, 255).round();
        result.setPixel(x, y, img.ColorRgb8(stretched, stretched, stretched));
      }
    }
    
    return result;
  }
  
  // REMOVED: Combined processing method that was causing crashes
  
  /// STEP 3: Lightweight noise reduction (simplified Phase 5)
  /// Replaces expensive bilateral filter with fast Gaussian blur
  img.Image _lightweightNoiseReduction(img.Image image) {
    print('🚀 OPTIMIZED STEP 3: Lightweight noise reduction...');
    
    // Use fast Gaussian blur instead of bilateral filter
    return img.gaussianBlur(image, radius: 1);
  }
  
  /// STEP 4: Essential text enhancement (simplified Phase 6)
  /// Replaces complex morphological operations with simple sharpening
  img.Image _essentialTextEnhancement(img.Image image) {
    print('🚀 OPTIMIZED STEP 4: Essential text enhancement...');
    
    // Simple unsharp mask for text sharpening
    final blurred = img.gaussianBlur(image, radius: 1);
    final result = img.Image(width: image.width, height: image.height);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final original = img.getLuminance(image.getPixel(x, y));
        final blur = img.getLuminance(blurred.getPixel(x, y));
        
        // Simple sharpening formula
        final sharpened = (original + (original - blur) * 1.5).clamp(0, 255).round();
        result.setPixel(x, y, img.ColorRgb8(sharpened, sharpened, sharpened));
      }
    }
    
    return result;
  }
  
  /// Fast grayscale check (optimized version)
  bool _isGrayscaleFast(img.Image image) {
    // Sample fewer pixels for faster check
    final sampleSize = math.min(50, image.width * image.height);
    final step = (image.width * image.height / sampleSize).round();
    
    for (int i = 0; i < image.width * image.height; i += step) {
      final x = i % image.width;
      final y = i ~/ image.width;
      final pixel = image.getPixel(x, y);
      
      if (pixel.r != pixel.g || pixel.g != pixel.b) {
        return false;
      }
    }
    return true;
  }
  
  /// Fast exposure correction (simplified version)
  img.Image _fastExposureCorrection(img.Image image) {
    // Sample pixels for histogram instead of full image
    final sampleSize = math.min(10000, image.width * image.height);
    final step = (image.width * image.height / sampleSize).round();
    
    int darkCount = 0, brightCount = 0;
    
    for (int i = 0; i < image.width * image.height; i += step) {
      final x = i % image.width;
      final y = i ~/ image.width;
      final pixel = img.getLuminance(image.getPixel(x, y)).round();
      
      if (pixel < 30) darkCount++;
      if (pixel > 225) brightCount++;
    }
    
    final darkRatio = darkCount / sampleSize;
    final brightRatio = brightCount / sampleSize;
    
    // Only apply correction if extreme exposure detected
    if (darkRatio > 0.4 || brightRatio > 0.4) {
      final gamma = darkRatio > brightRatio ? 0.8 : 1.2;
      return _applyGammaCorrection(image, gamma);
    }
    
    return image;
  }

  // ===== LEGACY PHASE 1: Input Validation and Basic Corrections =====
  
  img.Image _validateAndFixBasicIssues(img.Image image) {
    print('🔍 PHASE 1: Validating input and fixing basic issues...');
    
    // Check minimum resolution requirements
    const minWidth = 300;
    const minHeight = 300;
    
    if (image.width < minWidth || image.height < minHeight) {
      print('⚠️ PHASE 1: Image too small, upscaling...');
      final scale = math.max(minWidth / image.width, minHeight / image.height);
      image = img.copyResize(image, 
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
        interpolation: img.Interpolation.linear // OPTIMIZED: Use linear instead of cubic
      );
    }
    
    // OPTIMIZED: Use faster grayscale check and conversion
    if (!_isGrayscaleFast(image)) {
      print('🔍 PHASE 1: Converting to grayscale...');
      image = img.grayscale(image);
    }
    
    // OPTIMIZED: Use faster exposure correction
    image = _fastExposureCorrection(image);
    
    print('✅ PHASE 1: Basic corrections completed');
    return image;
  }
  
  bool _isGrayscale(img.Image image) {
    // Sample a few pixels to check if image is already grayscale
    for (int i = 0; i < math.min(100, image.width * image.height); i++) {
      final x = i % image.width;
      final y = i ~/ image.width;
      final pixel = image.getPixel(x, y);
      
      if (pixel.r != pixel.g || pixel.g != pixel.b) {
        return false;
      }
    }
    return true;
  }
  
  img.Image _fixExtremeExposure(img.Image image) {
    // Calculate histogram to detect extreme exposure
    final histogram = List<int>.filled(256, 0);
    final totalPixels = image.width * image.height;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = img.getLuminance(image.getPixel(x, y)).round();
        histogram[pixel]++;
      }
    }
    
    // Check for extreme exposure (too many pixels at 0 or 255)
    final darkPixels = histogram[0] / totalPixels;
    final brightPixels = histogram[255] / totalPixels;
    
    if (darkPixels > 0.3 || brightPixels > 0.3) {
      print('⚠️ PHASE 1: Extreme exposure detected, applying gamma correction');
      return _applyGammaCorrection(image, darkPixels > brightPixels ? 0.7 : 1.4);
    }
    
    return image;
  }
  
  img.Image _applyGammaCorrection(img.Image image, double gamma) {
    final gammaTable = List<int>.generate(256, (i) => 
      (255 * math.pow(i / 255.0, gamma)).round().clamp(0, 255)
    );
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final corrected = gammaTable[img.getLuminance(pixel).round()];
        image.setPixel(x, y, img.ColorRgb8(corrected, corrected, corrected));
      }
    }
    
    return image;
  }
  
  // ===== PHASE 2: Geometric Corrections =====
  
  img.Image _applyGeometricCorrections(img.Image image) {
    print('🔍 PHASE 2: Applying geometric corrections...');
    
    // OPTIMIZED: Use faster skew detection
    final skewAngle = _detectSkewAngleFast(image);
    if (skewAngle.abs() > 0.5) {
      print('🔍 PHASE 2: Correcting skew angle: ${skewAngle.toStringAsFixed(2)}°');
      image = _correctSkew(image, skewAngle);
    }
    
    // OPTIMIZED: Skip perspective correction in legacy pipeline (handled by edge detection)
    // This reduces computational load significantly
    
    print('✅ PHASE 2: Geometric corrections completed');
    return image;
  }
  
  /// OPTIMIZED: Fast skew detection with reduced computational complexity
  double _detectSkewAngleFast(img.Image image) {
    print('🚀 OPTIMIZED SKEW: Using fast skew detection...');
    
    // Use fewer test angles and sample fewer pixels for speed
    final angles = <double>[];
    
    // Test fewer angles from -10 to +10 degrees with larger steps
    for (double angle = -10; angle <= 10; angle += 2.0) {
      final variance = _calculateProjectionVarianceAtAngleFast(image, angle);
      if (variance > 0) {
        angles.add(angle);
      }
    }
    
    if (angles.isEmpty) return 0.0;
    
    // Find angle with maximum text line alignment
    double bestAngle = 0.0;
    double maxVariance = 0.0;
    
    for (final angle in angles) {
      final variance = _calculateProjectionVarianceAtAngleFast(image, angle);
      if (variance > maxVariance) {
        maxVariance = variance;
        bestAngle = angle;
      }
    }
    
    print('🚀 OPTIMIZED SKEW: Detected angle: ${bestAngle.toStringAsFixed(2)}°');
    return bestAngle;
  }
  
  /// Fast projection variance calculation with reduced sampling
  double _calculateProjectionVarianceAtAngleFast(img.Image image, double angle) {
    final radians = angle * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    
    // Sample fewer rows for speed
    final step = math.max(1, image.height ~/ 50); // Sample every 50th row instead of every row
    final projection = <int>[];
    
    for (int y = 0; y < image.height; y += step) {
      int sum = 0;
      int count = 0;
      
      // Sample fewer columns for speed
      final colStep = math.max(1, image.width ~/ 100); // Sample every 100th column
      for (int x = 0; x < image.width; x += colStep) {
        final newX = (x * cos - y * sin).round();
        final newY = (x * sin + y * cos).round();
        
        if (newX >= 0 && newX < image.width && newY >= 0 && newY < image.height) {
          final pixel = img.getLuminance(image.getPixel(newX, newY)).round();
          sum += pixel;
          count++;
        }
      }
      
      if (count > 0) {
        projection.add(sum ~/ count);
      }
    }
    
    if (projection.length < 3) return 0.0;
    
    // Calculate variance
    final mean = projection.reduce((a, b) => a + b) / projection.length;
    final variance = projection.map((p) => math.pow(p - mean, 2)).reduce((a, b) => a + b) / projection.length;
    
    return variance;
  }
  
  double _detectSkewAngle(img.Image image) {
    print('🔍 SKEW: Detecting skew angle...');
    
    // Improved skew detection using projection profiles
    _calculateHorizontalProjection(image);
    final angles = <double>[];
    
    // Test angles from -15 to +15 degrees
    for (double angle = -15; angle <= 15; angle += 1.0) {
      final variance = _calculateProjectionVarianceAtAngle(image, angle);
      if (variance > 0) {
        angles.add(angle);
      }
    }
    
    if (angles.isEmpty) return 0.0;
    
    // Find angle with maximum text line alignment
    double bestAngle = 0.0;
    double maxVariance = 0.0;
    
    for (final angle in angles) {
      final variance = _calculateProjectionVarianceAtAngle(image, angle);
      if (variance > maxVariance) {
        maxVariance = variance;
        bestAngle = angle;
      }
    }
    
    print('✅ SKEW: Detected skew angle: ${bestAngle.toStringAsFixed(2)}°');
    return bestAngle;
  }
  
  List<int> _calculateHorizontalProjection(img.Image image) {
    final profile = List<int>.filled(image.height, 0);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = img.getLuminance(image.getPixel(x, y));
        if (pixel < 128) { // Count dark pixels (text)
          profile[y]++;
        }
      }
    }
    
    return profile;
  }
  
  double _calculateProjectionVarianceAtAngle(img.Image image, double angle) {
    // This is a simplified implementation
    // In practice, you'd rotate the image and calculate projection variance
    // Calculate approximate variance without actual rotation for performance
    final profile = _calculateHorizontalProjection(image);
    return _calculateVariance(profile);
  }
  
  double _calculateVariance(List<int> values) {
    if (values.isEmpty) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
        .map((v) => math.pow(v - mean, 2))
        .reduce((a, b) => a + b) / values.length;
    
    return variance.toDouble();
  }
  
  img.Image _correctSkew(img.Image image, double angle) {
    final radians = angle * math.pi / 180;
    return _rotateImage(image, radians);
  }
  
  img.Image _rotateImage(img.Image image, double radians) {
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    
    final newWidth = (image.width * cos.abs() + image.height * sin.abs()).ceil();
    final newHeight = (image.height * cos.abs() + image.width * sin.abs()).ceil();
    
    final result = img.Image(width: newWidth, height: newHeight);
    img.fill(result, color: img.ColorRgb8(255, 255, 255)); // White background
    
    final centerX = image.width / 2.0;
    final centerY = image.height / 2.0;
    final newCenterX = newWidth / 2.0;
    final newCenterY = newHeight / 2.0;
    
    for (int y = 0; y < newHeight; y++) {
      for (int x = 0; x < newWidth; x++) {
        final dx = x - newCenterX;
        final dy = y - newCenterY;
        
        final srcX = (dx * cos + dy * sin + centerX).round();
        final srcY = (-dx * sin + dy * cos + centerY).round();
        
        if (srcX >= 0 && srcX < image.width && srcY >= 0 && srcY < image.height) {
          result.setPixel(x, y, image.getPixel(srcX, srcY));
        }
      }
    }
    
    return result;
  }
  
  List<Offset>? _detectDocumentCorners(img.Image image) {
    // Simplified corner detection
    final edges = _applyEdgeDetection(image);
    return _findQuadrilateralCorners(edges);
  }
  
  img.Image _applyEdgeDetection(img.Image image) {
    final blurred = img.gaussianBlur(image, radius: 1);
    return _applySobelOperator(blurred);
  }
  
  img.Image _applySobelOperator(img.Image image) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);
    
    // Sobel kernels
    const sobelX = [
      [-1.0, 0.0, 1.0],
      [-2.0, 0.0, 2.0],
      [-1.0, 0.0, 1.0]
    ];
    
    const sobelY = [
      [-1.0, -2.0, -1.0],
      [0.0, 0.0, 0.0],
      [1.0, 2.0, 1.0]
    ];
    
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        double gx = 0, gy = 0;
        
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = img.getLuminance(image.getPixel(x + kx, y + ky));
            gx += pixel * sobelX[ky + 1][kx + 1];
            gy += pixel * sobelY[ky + 1][kx + 1];
          }
        }
        
        final magnitude = math.sqrt(gx * gx + gy * gy);
        final edge = magnitude > 50 ? 255 : 0;
        
        result.setPixel(x, y, img.ColorRgb8(edge, edge, edge));
      }
    }
    
    return result;
  }
  
  List<Offset>? _findQuadrilateralCorners(img.Image edges) {
    final width = edges.width.toDouble();
    final height = edges.height.toDouble();
    
    // Return reasonable default corners
    return [
      Offset(width * 0.1, height * 0.1),
      Offset(width * 0.9, height * 0.1),
      Offset(width * 0.9, height * 0.9),
      Offset(width * 0.1, height * 0.9),
    ];
  }
  
  img.Image _correctPerspective(img.Image image, List<Offset> corners) {
    // Simplified perspective correction - return original for now
    // In a full implementation, you'd apply perspective transformation
    return image;
  }
  
  /// Apply perspective correction to an image using detected corners
  Future<File> applyPerspectiveCorrection(File imageFile, List<Offset> corners) async {
    try {
      final bytes = await imageFile.readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }
      
      // Apply perspective correction
      image = _correctPerspective(image, corners);
      
      // Save the corrected image
      final directory = await getTemporaryDirectory();
      final correctedPath = "${directory.path}/perspective_corrected_${DateTime.now().millisecondsSinceEpoch}.jpg";
      
      final correctedBytes = img.encodeJpg(image, quality: 100);
      final correctedFile = File(correctedPath);
      await correctedFile.writeAsBytes(correctedBytes);
      
      return correctedFile;
    } catch (e) {
      print('❌ Perspective correction failed: $e');
      rethrow;
    }
  }
  
  // ===== PHASE 3: Resolution Enhancement =====
  
  img.Image _enhanceResolutionForOCR(img.Image image) {
    print('🔍 PHASE 3: Enhancing resolution for OCR...');
    
    const targetDPI = 300.0;
    const assumedOriginalDPI = 72.0;
    const maxDimension = 2000; // Maximum dimension to prevent memory issues
    
    const scaleFactor = targetDPI / assumedOriginalDPI;
    
    // Calculate new dimensions
    int newWidth = (image.width * scaleFactor).round();
    int newHeight = (image.height * scaleFactor).round();
    
    // Limit dimensions to prevent memory issues
    if (newWidth > maxDimension || newHeight > maxDimension) {
      final aspectRatio = image.width / image.height;
      if (newWidth > newHeight) {
        newWidth = maxDimension;
        newHeight = (maxDimension / aspectRatio).round();
      } else {
        newHeight = maxDimension;
        newWidth = (maxDimension * aspectRatio).round();
      }
      print('⚠️ PHASE 3: Limiting dimensions to prevent memory issues: ${newWidth}x$newHeight');
    }
    
    if (scaleFactor > 1.1 && (newWidth > image.width || newHeight > image.height)) {
      print('🔍 PHASE 3: Upscaling by factor: ${(newWidth / image.width).toStringAsFixed(2)}x${(newHeight / image.height).toStringAsFixed(2)}');
      
      try {
      image = img.copyResize(
        image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear, // Use linear instead of cubic to save memory
        );
      } catch (e) {
        print('❌ PHASE 3: Upscaling failed, using original size: $e');
        // If upscaling fails, continue with original image
      }
    }
    
    // Only apply super resolution if image is still small and we have enough memory
    if (image.width < 1000 && image.height < 1000 && image.width * image.height < 1000000) {
      try {
      image = _applySuperResolutionEnhancement(image);
      } catch (e) {
        print('❌ PHASE 3: Super resolution failed, skipping: $e');
        // Continue without super resolution
      }
    }
    
    print('✅ PHASE 3: Resolution enhancement completed');
    return image;
  }
  
  img.Image _applySuperResolutionEnhancement(img.Image image) {
    return _applyEdgeDirectedInterpolation(image);
  }
  
  img.Image _applyEdgeDirectedInterpolation(img.Image image) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);
    
    // Copy original image first to avoid issues
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        result.setPixel(x, y, image.getPixel(x, y));
      }
    }
    
    // Only process inner pixels to avoid boundary issues
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        try {
          final gradX = img.getLuminance(image.getPixel(x + 1, y)) - 
                       img.getLuminance(image.getPixel(x - 1, y));
          final gradY = img.getLuminance(image.getPixel(x, y + 1)) - 
                       img.getLuminance(image.getPixel(x, y - 1));
          
          final enhanced = _enhanceAlongEdge(image, x, y, gradX.toDouble(), gradY.toDouble());
          result.setPixel(x, y, img.ColorRgb8(enhanced, enhanced, enhanced));
        } catch (e) {
          // If enhancement fails, keep original pixel
          result.setPixel(x, y, image.getPixel(x, y));
        }
      }
    }
    
    return result;
  }
  
  int _enhanceAlongEdge(img.Image image, int x, int y, double gradX, double gradY) {
    try {
      final center = img.getLuminance(image.getPixel(x, y));
      
      if (gradX.abs() > gradY.abs()) {
        final above = img.getLuminance(image.getPixel(x, y - 1));
        final below = img.getLuminance(image.getPixel(x, y + 1));
        return ((center * 2 + above + below) / 4).round().clamp(0, 255).toInt();
            } else {
        final left = img.getLuminance(image.getPixel(x - 1, y));
        final right = img.getLuminance(image.getPixel(x + 1, y));
        return ((center * 2 + left + right) / 4).round().clamp(0, 255).toInt();
      }
    } catch (e) {
      // If enhancement fails, return original pixel value
      return img.getLuminance(image.getPixel(x, y)).toInt();
    }
  }
  
  // ===== PHASE 4: Lighting and Contrast Normalization =====
  
  img.Image _normalizeLightingAndContrast(img.Image image) {
    print('🔍 PHASE 4: Normalizing lighting and contrast...');
    
    // OPTIMIZED: Use faster contrast enhancement instead of expensive CLAHE
    image = _applyFastCLAHE(image);
    image = _correctIllumination(image);
    image = _normalizeGlobalContrast(image);
    
    print('✅ PHASE 4: Lighting and contrast normalization completed');
    return image;
  }
  
  /// OPTIMIZED: Fast CLAHE implementation with reduced computational complexity
  img.Image _applyFastCLAHE(img.Image image) {
    print('🚀 OPTIMIZED CLAHE: Using fast contrast enhancement...');
    
    // Use larger tiles and simpler processing for speed
    const int tileSize = 128; // Larger tiles = fewer computations
    const double clipLimit = 2.0; // Reduced clip limit for speed
    
    final tilesX = (image.width / tileSize).ceil();
    final tilesY = (image.height / tileSize).ceil();
    
    final result = img.Image(width: image.width, height: image.height);
    
    // Process fewer tiles with simpler algorithm
    for (int ty = 0; ty < tilesY; ty++) {
      for (int tx = 0; tx < tilesX; tx++) {
        final startX = tx * tileSize;
        final startY = ty * tileSize;
        final endX = math.min(startX + tileSize, image.width);
        final endY = math.min(startY + tileSize, image.height);
        
        _applyFastCLAHEToTile(image, result, startX, startY, endX, endY, clipLimit);
      }
    }
    
    return result;
  }
  
  /// Fast CLAHE tile processing with simplified histogram
  void _applyFastCLAHEToTile(img.Image source, img.Image result, 
                            int startX, int startY, int endX, int endY, double clipLimit) {
    // Simplified histogram with fewer bins for speed
    final histogram = List<int>.filled(64, 0); // 64 bins instead of 256
    final tilePixels = (endX - startX) * (endY - startY);
    
    // Build histogram with reduced precision
    for (int y = startY; y < endY; y++) {
      for (int x = startX; x < endX; x++) {
        final pixel = img.getLuminance(source.getPixel(x, y)).round();
        final bin = (pixel ~/ 4).clamp(0, 63); // Map 256 values to 64 bins
        histogram[bin]++;
      }
    }
    
    // Simplified clipping
    final clipThreshold = (tilePixels * clipLimit / 64).round();
    int clippedPixels = 0;
    
    for (int i = 0; i < 64; i++) {
      if (histogram[i] > clipThreshold) {
        clippedPixels += histogram[i] - clipThreshold;
        histogram[i] = clipThreshold;
      }
    }
    
    // Redistribute clipped pixels
    final redistributedPixels = clippedPixels ~/ 64;
    for (int i = 0; i < 64; i++) {
      histogram[i] += redistributedPixels;
    }
    
    // Build cumulative histogram
    final cumulativeHist = List<int>.filled(64, 0);
    cumulativeHist[0] = histogram[0];
    for (int i = 1; i < 64; i++) {
      cumulativeHist[i] = cumulativeHist[i - 1] + histogram[i];
    }
    
    // Apply transformation with reduced precision
    for (int y = startY; y < endY; y++) {
      for (int x = startX; x < endX; x++) {
        final pixel = img.getLuminance(source.getPixel(x, y)).round();
        final bin = (pixel ~/ 4).clamp(0, 63);
        final newValue = (cumulativeHist[bin] * 255 / tilePixels).round().clamp(0, 255);
        result.setPixel(x, y, img.ColorRgb8(newValue, newValue, newValue));
      }
    }
  }
  
  img.Image _applyCLAHE(img.Image image) {
    const int tileSize = 64;
    const double clipLimit = 3.0;
    
    final tilesX = (image.width / tileSize).ceil();
    final tilesY = (image.height / tileSize).ceil();
    
    final result = img.Image(width: image.width, height: image.height);
    
    for (int ty = 0; ty < tilesY; ty++) {
      for (int tx = 0; tx < tilesX; tx++) {
        final startX = tx * tileSize;
        final startY = ty * tileSize;
        final endX = math.min(startX + tileSize, image.width);
        final endY = math.min(startY + tileSize, image.height);
        
        _applyCLAHEToTile(image, result, startX, startY, endX, endY, clipLimit);
      }
    }
    
    return result;
  }

  void _applyCLAHEToTile(img.Image source, img.Image result, 
                        int startX, int startY, int endX, int endY, double clipLimit) {
    final histogram = List<int>.filled(256, 0);
    final tilePixels = (endX - startX) * (endY - startY);
    
    for (int y = startY; y < endY; y++) {
      for (int x = startX; x < endX; x++) {
        final pixel = img.getLuminance(source.getPixel(x, y)).round().clamp(0, 255);
        histogram[pixel]++;
      }
    }
    
    final clipThreshold = (tilePixels * clipLimit / 256).round();
    int clippedPixels = 0;
    
    for (int i = 0; i < 256; i++) {
      if (histogram[i] > clipThreshold) {
        clippedPixels += histogram[i] - clipThreshold;
        histogram[i] = clipThreshold;
      }
    }
    
    final redistribution = clippedPixels ~/ 256;
    for (int i = 0; i < 256; i++) {
      histogram[i] += redistribution;
    }
    
    final lookupTable = List<int>.filled(256, 0);
    int cdf = 0;
    
    for (int i = 0; i < 256; i++) {
      cdf += histogram[i];
      lookupTable[i] = (cdf * 255 ~/ tilePixels).clamp(0, 255);
    }
    
    for (int y = startY; y < endY; y++) {
      for (int x = startX; x < endX; x++) {
        final pixel = img.getLuminance(source.getPixel(x, y)).round().clamp(0, 255);
        final enhanced = lookupTable[pixel];
        result.setPixel(x, y, img.ColorRgb8(enhanced, enhanced, enhanced));
      }
    }
  }
  
  img.Image _correctIllumination(img.Image image) {
    final background = _estimateBackground(image);
    return _subtractBackground(image, background);
  }
  
  img.Image _estimateBackground(img.Image image) {
    return img.gaussianBlur(image, radius: 20);
  }
  
  img.Image _subtractBackground(img.Image image, img.Image background) {
    final result = img.Image(width: image.width, height: image.height);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final original = img.getLuminance(image.getPixel(x, y));
        final bg = img.getLuminance(background.getPixel(x, y));
        
        final corrected = bg > 0 ? ((original / bg) * 128).clamp(0, 255).round() : original.round();
        result.setPixel(x, y, img.ColorRgb8(corrected, corrected, corrected));
      }
    }
    
    return result;
  }
  
  img.Image _normalizeGlobalContrast(img.Image image) {
    double sum = 0, sumSquares = 0;
    final totalPixels = image.width * image.height;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = img.getLuminance(image.getPixel(x, y));
        sum += pixel;
        sumSquares += pixel * pixel;
      }
    }
    
    final mean = sum / totalPixels;
    final variance = sumSquares / totalPixels - mean * mean;
    final stdDev = math.sqrt(variance);
    
    const targetMean = 128.0;
    const targetStdDev = 50.0;
    
    final result = img.Image(width: image.width, height: image.height);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = img.getLuminance(image.getPixel(x, y));
        
        final normalized = stdDev > 0 ? 
            targetMean + (pixel - mean) * (targetStdDev / stdDev) : 
            pixel.toDouble();
        final clamped = normalized.clamp(0, 255).round();
        
        result.setPixel(x, y, img.ColorRgb8(clamped, clamped, clamped));
      }
    }
    
    return result;
  }
  
  // ===== PHASE 5: Advanced Noise Reduction =====
  
  img.Image _applyAdvancedNoiseReduction(img.Image image) {
    print('🔍 PHASE 5: Applying advanced noise reduction...');
    
    // OPTIMIZED: Use faster noise reduction instead of expensive bilateral filter
    image = _applyFastBilateralFilter(image);
    image = _applyCustomMedianFilter(image); // Custom implementation
    
    print('✅ PHASE 5: Advanced noise reduction completed');
    return image;
  }
  
  /// OPTIMIZED: Fast bilateral filter with reduced computational complexity
  img.Image _applyFastBilateralFilter(img.Image image) {
    print('🚀 OPTIMIZED BILATERAL: Using fast noise reduction...');
    
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);

    // Use smaller kernel and simplified calculations for speed
    const int kernelSize = 3; // Smaller kernel (3x3 instead of 5x5)
    const double sigmaColor = 50.0; // Increased for faster convergence
    const double sigmaSpace = 50.0; // Increased for faster convergence
    
    // Pre-calculate spatial weights for speed
    final spatialWeights = List<List<double>>.generate(kernelSize, (i) => 
      List<double>.generate(kernelSize, (j) {
        final dx = i - kernelSize ~/ 2;
        final dy = j - kernelSize ~/ 2;
        final spatialDist = math.sqrt(dx * dx + dy * dy);
        return math.exp(-(spatialDist * spatialDist) / (2 * sigmaSpace * sigmaSpace));
      })
    );
    
    for (int y = kernelSize ~/ 2; y < height - kernelSize ~/ 2; y++) {
      for (int x = kernelSize ~/ 2; x < width - kernelSize ~/ 2; x++) {
        double weightSum = 0.0;
        double valueSum = 0.0;
        
        final centerPixel = img.getLuminance(image.getPixel(x, y));
        
        for (int ky = 0; ky < kernelSize; ky++) {
          for (int kx = 0; kx < kernelSize; kx++) {
            final neighborPixel = img.getLuminance(image.getPixel(x + kx - kernelSize ~/ 2, y + ky - kernelSize ~/ 2));
            
            final colorDist = (centerPixel - neighborPixel).abs();
            final colorWeight = math.exp(-(colorDist * colorDist) / (2 * sigmaColor * sigmaColor));
            final spatialWeight = spatialWeights[ky][kx];
            
            final weight = spatialWeight * colorWeight;
            weightSum += weight;
            valueSum += neighborPixel * weight;
          }
        }
        
        final filtered = (valueSum / weightSum).round().clamp(0, 255);
        result.setPixel(x, y, img.ColorRgb8(filtered, filtered, filtered));
      }
    }

    // Copy border pixels
    for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
        if (x < kernelSize ~/ 2 || x >= width - kernelSize ~/ 2 || 
            y < kernelSize ~/ 2 || y >= height - kernelSize ~/ 2) {
          final pixel = img.getLuminance(image.getPixel(x, y)).round();
          result.setPixel(x, y, img.ColorRgb8(pixel, pixel, pixel));
        }
      }
    }

    return result;
  }

  img.Image _applyBilateralFilter(img.Image image) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);
    
    const int kernelSize = 5;
    const double sigmaColor = 30.0;
    const double sigmaSpace = 30.0;
    
    for (int y = kernelSize ~/ 2; y < height - kernelSize ~/ 2; y++) {
      for (int x = kernelSize ~/ 2; x < width - kernelSize ~/ 2; x++) {
        double weightSum = 0.0;
        double valueSum = 0.0;
        
        final centerPixel = img.getLuminance(image.getPixel(x, y));
        
        for (int ky = -kernelSize ~/ 2; ky <= kernelSize ~/ 2; ky++) {
          for (int kx = -kernelSize ~/ 2; kx <= kernelSize ~/ 2; kx++) {
            final neighborPixel = img.getLuminance(image.getPixel(x + kx, y + ky));
            
            final spatialDist = math.sqrt(kx * kx + ky * ky);
            final colorDist = (centerPixel - neighborPixel).abs();
            
            final spatialWeight = math.exp(-(spatialDist * spatialDist) / (2 * sigmaSpace * sigmaSpace));
            final colorWeight = math.exp(-(colorDist * colorDist) / (2 * sigmaColor * sigmaColor));
            
            final weight = spatialWeight * colorWeight;
            weightSum += weight;
            valueSum += neighborPixel * weight;
          }
        }
        
        final filtered = (valueSum / weightSum).round().clamp(0, 255);
        result.setPixel(x, y, img.ColorRgb8(filtered, filtered, filtered));
      }
    }
    
    // Copy border pixels
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (x < kernelSize ~/ 2 || x >= width - kernelSize ~/ 2 || 
            y < kernelSize ~/ 2 || y >= height - kernelSize ~/ 2) {
          result.setPixel(x, y, image.getPixel(x, y));
        }
      }
    }
    
    return result;
  }
  
  // Custom median filter implementation since img.medianFilter doesn't exist
  img.Image _applyCustomMedianFilter(img.Image image, {int size = 3}) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);
    final halfSize = size ~/ 2;
    
    for (int y = halfSize; y < height - halfSize; y++) {
      for (int x = halfSize; x < width - halfSize; x++) {
        final values = <int>[];
        
        for (int dy = -halfSize; dy <= halfSize; dy++) {
          for (int dx = -halfSize; dx <= halfSize; dx++) {
            final pixel = img.getLuminance(image.getPixel(x + dx, y + dy));
            values.add(pixel.round());
          }
        }
        
        values.sort();
        final median = values[values.length ~/ 2];
        
        result.setPixel(x, y, img.ColorRgb8(median, median, median));
      }
    }
    
    // Copy border pixels
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (x < halfSize || x >= width - halfSize || 
            y < halfSize || y >= height - halfSize) {
          result.setPixel(x, y, image.getPixel(x, y));
        }
      }
    }
    
    return result;
  }
  
  // ===== PHASE 6: Text Enhancement =====
  
  img.Image _enhanceTextForOCR(img.Image image) {
    print('🔍 PHASE 6: Enhancing text for OCR...');
    
    // OPTIMIZED: Use faster text enhancement methods
    image = _applyTextSharpening(image);
    image = _enhanceStrokeConsistencyFast(image);
    image = _applyAdaptiveBinarization(image);
    
    print('✅ PHASE 6: Text enhancement completed');
    return image;
  }
  
  img.Image _applyTextSharpening(img.Image image) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);
    
    final blurred = img.gaussianBlur(image, radius: 1);
    
    const double amount = 2.0;
    const double threshold = 5.0;
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final original = img.getLuminance(image.getPixel(x, y));
        final blur = img.getLuminance(blurred.getPixel(x, y));
        
        final difference = original - blur;
        
        double enhanced;
        if (difference.abs() > threshold) {
          enhanced = original + amount * difference;
          } else {
          enhanced = original.toDouble();
        }
        
        final sharpened = enhanced.clamp(0, 255).round();
        result.setPixel(x, y, img.ColorRgb8(sharpened, sharpened, sharpened));
      }
    }
    
    return result;
  }
  
  /// OPTIMIZED: Fast stroke consistency enhancement with simplified operations
  img.Image _enhanceStrokeConsistencyFast(img.Image image) {
    print('🚀 OPTIMIZED STROKE: Using fast morphological operations...');
    
    // Use smaller kernel and simplified operations for speed
    var result = _applyOpeningFast(image, 1);
    result = _applyClosingFast(result, 1);
    return result;
  }
  
  img.Image _enhanceStrokeConsistency(img.Image image) {
    var result = _applyOpening(image, 1);
    result = _applyClosing(result, 1);
    return result;
  }
  
  /// OPTIMIZED: Fast opening operation with reduced computational complexity
  img.Image _applyOpeningFast(img.Image image, int kernelSize) {
    // Use simplified erosion and dilation for speed
    return _applyDilationFast(_applyErosionFast(image, kernelSize), kernelSize);
  }
  
  /// OPTIMIZED: Fast closing operation with reduced computational complexity
  img.Image _applyClosingFast(img.Image image, int kernelSize) {
    // Use simplified erosion and dilation for speed
    return _applyErosionFast(_applyDilationFast(image, kernelSize), kernelSize);
  }
  
  img.Image _applyOpening(img.Image image, int kernelSize) {
    return _applyDilation(_applyErosion(image, kernelSize), kernelSize);
  }
  
  img.Image _applyClosing(img.Image image, int kernelSize) {
    return _applyErosion(_applyDilation(image, kernelSize), kernelSize);
  }
  
  /// OPTIMIZED: Fast erosion with reduced computational complexity
  img.Image _applyErosionFast(img.Image image, int kernelSize) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);
    
    // Use cross-shaped kernel instead of square for speed
    for (int y = kernelSize; y < height - kernelSize; y++) {
      for (int x = kernelSize; x < width - kernelSize; x++) {
        int minVal = 255;
        
        // Check only cross pattern (4 neighbors + center) instead of full square
        final neighbors = [
          [0, 0], [-1, 0], [1, 0], [0, -1], [0, 1] // Center + 4 directions
        ];
        
        for (final offset in neighbors) {
          final pixel = img.getLuminance(image.getPixel(x + offset[0], y + offset[1])).round();
          minVal = math.min(minVal, pixel);
        }
        
        result.setPixel(x, y, img.ColorRgb8(minVal, minVal, minVal));
      }
    }
    
    // Copy border pixels
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (x < kernelSize || x >= width - kernelSize || 
            y < kernelSize || y >= height - kernelSize) {
          result.setPixel(x, y, image.getPixel(x, y));
        }
      }
    }
    
    return result;
  }
  
  img.Image _applyErosion(img.Image image, int kernelSize) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);
    
    for (int y = kernelSize; y < height - kernelSize; y++) {
      for (int x = kernelSize; x < width - kernelSize; x++) {
        int minVal = 255;
        
        for (int ky = -kernelSize; ky <= kernelSize; ky++) {
          for (int kx = -kernelSize; kx <= kernelSize; kx++) {
            final pixel = img.getLuminance(image.getPixel(x + kx, y + ky)).round();
            minVal = math.min(minVal, pixel);
          }
        }
        
        result.setPixel(x, y, img.ColorRgb8(minVal, minVal, minVal));
      }
    }
    
    // Copy border pixels
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (x < kernelSize || x >= width - kernelSize || 
            y < kernelSize || y >= height - kernelSize) {
          result.setPixel(x, y, image.getPixel(x, y));
        }
      }
    }
    
    return result;
  }
  
  /// OPTIMIZED: Fast dilation with reduced computational complexity
  img.Image _applyDilationFast(img.Image image, int kernelSize) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);
    
    // Use cross-shaped kernel instead of square for speed
    for (int y = kernelSize; y < height - kernelSize; y++) {
      for (int x = kernelSize; x < width - kernelSize; x++) {
        int maxVal = 0;
        
        // Check only cross pattern (4 neighbors + center) instead of full square
        final neighbors = [
          [0, 0], [-1, 0], [1, 0], [0, -1], [0, 1] // Center + 4 directions
        ];
        
        for (final offset in neighbors) {
          final pixel = img.getLuminance(image.getPixel(x + offset[0], y + offset[1])).round();
          maxVal = math.max(maxVal, pixel);
        }
        
        result.setPixel(x, y, img.ColorRgb8(maxVal, maxVal, maxVal));
      }
    }
    
    // Copy border pixels
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (x < kernelSize || x >= width - kernelSize || 
            y < kernelSize || y >= height - kernelSize) {
          result.setPixel(x, y, image.getPixel(x, y));
        }
      }
    }
    
    return result;
  }
  
  img.Image _applyDilation(img.Image image, int kernelSize) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);
    
    for (int y = kernelSize; y < height - kernelSize; y++) {
      for (int x = kernelSize; x < width - kernelSize; x++) {
        int maxVal = 0;
        
        for (int ky = -kernelSize; ky <= kernelSize; ky++) {
          for (int kx = -kernelSize; kx <= kernelSize; kx++) {
            final pixel = img.getLuminance(image.getPixel(x + kx, y + ky)).round();
            maxVal = math.max(maxVal, pixel);
          }
        }
        
        result.setPixel(x, y, img.ColorRgb8(maxVal, maxVal, maxVal));
      }
    }
    
    // Copy border pixels
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (x < kernelSize || x >= width - kernelSize || 
            y < kernelSize || y >= height - kernelSize) {
          result.setPixel(x, y, image.getPixel(x, y));
        }
      }
    }
    
    return result;
  }
  
  img.Image _applyAdaptiveBinarization(img.Image image) {
    final globalThreshold = _calculateOtsuThreshold(image);
    return _applyHybridThresholding(image, globalThreshold);
  }
  
  int _calculateOtsuThreshold(img.Image image) {
    final histogram = List<int>.filled(256, 0);
    final totalPixels = image.width * image.height;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = img.getLuminance(image.getPixel(x, y)).round();
        histogram[pixel]++;
      }
    }
    
    double maxVariance = 0;
    int optimalThreshold = 0;
    
    for (int t = 1; t < 255; t++) {
      int w0 = 0, w1 = 0;
      int sum0 = 0, sum1 = 0;
      
      for (int i = 0; i < t; i++) {
        w0 += histogram[i];
        sum0 += i * histogram[i];
      }
      
      for (int i = t; i < 256; i++) {
        w1 += histogram[i];
        sum1 += i * histogram[i];
      }
      
      if (w0 == 0 || w1 == 0) continue;
      
      final mean0 = sum0.toDouble() / w0;
      final mean1 = sum1.toDouble() / w1;
      
      final variance = (w0.toDouble() / totalPixels) * 
                      (w1.toDouble() / totalPixels) * 
                      (mean0 - mean1) * (mean0 - mean1);
      
      if (variance > maxVariance) {
        maxVariance = variance;
        optimalThreshold = t;
      }
    }
    
    return optimalThreshold;
  }
  
  img.Image _applyHybridThresholding(img.Image image, int globalThreshold) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);
    
    const int blockSize = 25;
    const double k = 0.2;
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double sum = 0, sumSquares = 0;
        int count = 0;
        
        for (int dy = -blockSize ~/ 2; dy <= blockSize ~/ 2; dy++) {
          for (int dx = -blockSize ~/ 2; dx <= blockSize ~/ 2; dx++) {
            final nx = x + dx;
            final ny = y + dy;
            
            if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
              final pixel = img.getLuminance(image.getPixel(nx, ny));
              sum += pixel;
              sumSquares += pixel * pixel;
              count++;
            }
          }
        }
        
        final mean = sum / count;
        final variance = sumSquares / count - mean * mean;
        final stdDev = math.sqrt(variance);
        
        final localThreshold = mean + k * stdDev;
        final threshold = (globalThreshold + localThreshold) / 2;
        
        final pixel = img.getLuminance(image.getPixel(x, y));
        final binary = pixel > threshold ? 255 : 0;
        
        result.setPixel(x, y, img.ColorRgb8(binary, binary, binary));
      }
    }
    
    return result;
  }
  
  // ===== PHASE 7: Final Optimizations =====
  
  img.Image _applyFinalOptimizations(img.Image image) {
    print('🔍 PHASE 7: Applying final optimizations...');
    
    // OPTIMIZED: Use faster final optimizations
    image = _removeSmallNoiseFast(image);
    image = _addCleanBorders(image);
    
    print('✅ PHASE 7: Final optimizations completed');
    return image;
  }
  
  /// OPTIMIZED: Fast small noise removal with reduced computational complexity
  img.Image _removeSmallNoiseFast(img.Image image) {
    print('🚀 OPTIMIZED NOISE: Using fast noise removal...');
    
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);
    
    // Use larger step size to process fewer pixels for speed
    const int step = 2; // Process every 2nd pixel instead of every pixel
    
    for (int y = 0; y < height; y += step) {
      for (int x = 0; x < width; x += step) {
        final pixel = img.getLuminance(image.getPixel(x, y)).round();
        
        // Simple threshold-based noise removal
        if (pixel < 30 || pixel > 225) {
          // Check if it's isolated noise (surrounded by different values)
          int differentNeighbors = 0;
          final neighbors = [
            [x-1, y], [x+1, y], [x, y-1], [x, y+1]
          ];
          
          for (final neighbor in neighbors) {
            if (neighbor[0] >= 0 && neighbor[0] < width && 
                neighbor[1] >= 0 && neighbor[1] < height) {
              final neighborPixel = img.getLuminance(image.getPixel(neighbor[0], neighbor[1])).round();
              if ((pixel - neighborPixel).abs() > 50) {
                differentNeighbors++;
              }
            }
          }
          
          // If more than 2 neighbors are very different, it's likely noise
          if (differentNeighbors > 2) {
            // Replace with average of neighbors
            int sum = 0;
            int count = 0;
            for (final neighbor in neighbors) {
              if (neighbor[0] >= 0 && neighbor[0] < width && 
                  neighbor[1] >= 0 && neighbor[1] < height) {
                sum += img.getLuminance(image.getPixel(neighbor[0], neighbor[1])).round();
                count++;
              }
            }
            if (count > 0) {
              final avgValue = (sum / count).round().clamp(0, 255);
              result.setPixel(x, y, img.ColorRgb8(avgValue, avgValue, avgValue));
            } else {
              result.setPixel(x, y, img.ColorRgb8(pixel, pixel, pixel));
            }
          } else {
            result.setPixel(x, y, img.ColorRgb8(pixel, pixel, pixel));
          }
        } else {
          result.setPixel(x, y, img.ColorRgb8(pixel, pixel, pixel));
        }
      }
    }
    
    // Fill in skipped pixels with original values
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (y % step != 0 || x % step != 0) {
          final pixel = img.getLuminance(image.getPixel(x, y)).round();
          result.setPixel(x, y, img.ColorRgb8(pixel, pixel, pixel));
        }
      }
    }
    
    return result;
  }
  
  img.Image _removeSmallNoise(img.Image image) {
    final width = image.width;
    final height = image.height;
    final visited = List.generate(height, (y) => List.filled(width, false));
    final result = _copyImage(image); // Fixed: use custom copy function
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (!visited[y][x] && img.getLuminance(image.getPixel(x, y)) < 128) {
          final componentSize = _floodFillAndCount(image, visited, x, y);
          
          if (componentSize < 20) {
            _floodFillWithColor(result, x, y, img.ColorRgb8(255, 255, 255));
          }
        }
      }
    }
    
    return result;
  }
  
  // Custom image copy function since img.copyFrom doesn't exist
  img.Image _copyImage(img.Image source) {
    final result = img.Image(width: source.width, height: source.height);
    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        result.setPixel(x, y, source.getPixel(x, y));
      }
    }
    return result;
  }
  
  int _floodFillAndCount(img.Image image, List<List<bool>> visited, int startX, int startY) {
    final stack = <Point<int>>[Point(startX, startY)];
    int count = 0;
    
    while (stack.isNotEmpty) {
      final point = stack.removeLast();
      final x = point.x;
      final y = point.y;
      
      if (x < 0 || x >= image.width || y < 0 || y >= image.height || visited[y][x]) {
        continue;
      }
      
      if (img.getLuminance(image.getPixel(x, y)) >= 128) continue;
      
      visited[y][x] = true;
      count++;
      
      stack.addAll([
        Point(x + 1, y),
        Point(x - 1, y),
        Point(x, y + 1),
        Point(x, y - 1),
      ]);
    }
    
    return count;
  }
  
  void _floodFillWithColor(img.Image image, int startX, int startY, img.Color color) {
    final stack = <Point<int>>[Point(startX, startY)];
    final visited = <Point<int>>{};
    
    while (stack.isNotEmpty) {
      final point = stack.removeLast();
      final x = point.x;
      final y = point.y;
      
      if (x < 0 || x >= image.width || y < 0 || y >= image.height || visited.contains(point)) {
        continue;
      }
      
      if (img.getLuminance(image.getPixel(x, y)) >= 128) continue;
      
      visited.add(point);
      image.setPixel(x, y, color);
      
      stack.addAll([
        Point(x + 1, y),
        Point(x - 1, y),
        Point(x, y + 1),
        Point(x, y - 1),
      ]);
    }
  }
  
  img.Image _addCleanBorders(img.Image image) {
    const int borderSize = 5;
    final width = image.width + 2 * borderSize;
    final height = image.height + 2 * borderSize;
    
    final result = img.Image(width: width, height: height);
    img.fill(result, color: img.ColorRgb8(255, 255, 255));
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        result.setPixel(x + borderSize, y + borderSize, image.getPixel(x, y));
      }
    }
    
    return result;
  }
  
  // ===== Document Type Specific Preprocessing =====
  
  Future<File> _preprocessReceipt(File originalImage) async {
    print('🔍 RECEIPT: Applying receipt-specific preprocessing...');
    
    final bytes = await originalImage.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');
    
    image = img.grayscale(image);
    image = _enhanceReceiptContrast(image);
    image = _applyBilateralFilter(image);
    image = _enhanceReceiptText(image);
    
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.jpg";
    await File(path).writeAsBytes(img.encodeJpg(image, quality: 95));
    
    return File(path);
  }
  
  img.Image _enhanceReceiptContrast(img.Image image) {
    return _applyCLAHE(image);
  }
  
  img.Image _enhanceReceiptText(img.Image image) {
    return _applyTextSharpening(image);
  }
  
  Future<File> _preprocessBusinessCard(File originalImage) async {
    print('🔍 BUSINESS CARD: Applying business card preprocessing...');
    
    final bytes = await originalImage.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');
    
    image = img.grayscale(image);
    image = _enhanceResolutionForOCR(image);
    image = _normalizeLightingAndContrast(image);
    image = _applyTextSharpening(image);
    
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/business_card_${DateTime.now().millisecondsSinceEpoch}.jpg";
    await File(path).writeAsBytes(img.encodeJpg(image, quality: 95));
    
    return File(path);
  }
  
  Future<File> _preprocessHandwritten(File originalImage) async {
    print('🔍 HANDWRITTEN: Applying handwritten text preprocessing...');
    
    final bytes = await originalImage.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');
    
    image = img.grayscale(image);
    image = _normalizeLightingAndContrast(image);
    image = _applyBilateralFilter(image);
    
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/handwritten_${DateTime.now().millisecondsSinceEpoch}.jpg";
    await File(path).writeAsBytes(img.encodeJpg(image, quality: 95));
    
    return File(path);
  }
  
  Future<File> _preprocessBook(File originalImage) async {
    print('🔍 BOOK: Applying book page preprocessing...');
    
    final bytes = await originalImage.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');
    
    image = img.grayscale(image);
    image = _correctIllumination(image);
    image = _applyGeometricCorrections(image);
    image = _applyAdaptiveBinarization(image);
    
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/book_${DateTime.now().millisecondsSinceEpoch}.jpg";
    await File(path).writeAsBytes(img.encodeJpg(image, quality: 95));
    
    return File(path);
  }
  
  Future<File> _preprocessWhiteboard(File originalImage) async {
    print('🔍 WHITEBOARD: Applying whiteboard preprocessing...');
    
    final bytes = await originalImage.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');
    
    image = img.grayscale(image);
    image = _applyGeometricCorrections(image);
    image = _enhanceWhiteboardMarkers(image);
    image = _normalizeWhiteboardBackground(image);
    
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/whiteboard_${DateTime.now().millisecondsSinceEpoch}.jpg";
    await File(path).writeAsBytes(img.encodeJpg(image, quality: 95));
    
    return File(path);
  }
  
  img.Image _enhanceWhiteboardMarkers(img.Image image) {
    return _applyTextSharpening(image);
  }
  
  img.Image _normalizeWhiteboardBackground(img.Image image) {
    final background = _estimateBackground(image);
    return _subtractBackground(image, background);
  }
  
  // ===== Fallback Methods =====
  
  Future<File> _fallbackPreprocessing(File originalImage) async {
    print('🔍 FALLBACK: Using fallback preprocessing...');
    
    try {
      final bytes = await originalImage.readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return originalImage;
      
      image = img.grayscale(image);
      image = _applySimpleContrastEnhancement(image);
      image = _applyBasicNoiseReduction(image);
      
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/fallback_${DateTime.now().millisecondsSinceEpoch}.jpg";
      await File(path).writeAsBytes(img.encodeJpg(image, quality: 95));
      
      return File(path);
    } catch (e) {
      print('❌ FALLBACK: Fallback preprocessing failed: $e');
      return originalImage;
    }
  }
  
  img.Image _applySimpleContrastEnhancement(img.Image image) {
    double minVal = 255, maxVal = 0;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = img.getLuminance(image.getPixel(x, y));
        minVal = math.min(minVal, pixel.toDouble());
        maxVal = math.max(maxVal, pixel.toDouble());
      }
    }
    
    if (maxVal <= minVal) return image;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = img.getLuminance(image.getPixel(x, y));
        final enhanced = ((pixel - minVal) * 255 / (maxVal - minVal)).round().clamp(0, 255);
        image.setPixel(x, y, img.ColorRgb8(enhanced, enhanced, enhanced));
      }
    }
    
    return image;
  }
  
  img.Image _applyBasicNoiseReduction(img.Image image) {
    return _applyCustomMedianFilter(image, size: 3);
  }
  
  // ===== Quality Assessment =====
  
  ImageQuality assessImageQuality(img.Image image) {
    final contrast = _calculateContrast(image);
    final sharpness = _calculateSharpness(image);
    final noise = _estimateNoise(image);
    
    if (contrast > 0.8 && sharpness > 0.7 && noise < 0.3) {
      return ImageQuality.excellent;
    } else if (contrast > 0.6 && sharpness > 0.5 && noise < 0.5) {
      return ImageQuality.good;
    } else if (contrast > 0.4 && sharpness > 0.3 && noise < 0.7) {
      return ImageQuality.poor;
    }
    return ImageQuality.terrible;
  }
  
  double _calculateContrast(img.Image image) {
    double sum = 0, sumSquares = 0;
    final totalPixels = image.width * image.height;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = img.getLuminance(image.getPixel(x, y));
        sum += pixel;
        sumSquares += pixel * pixel;
      }
    }
    
    final mean = sum / totalPixels;
    final variance = sumSquares / totalPixels - mean * mean;
    final stdDev = math.sqrt(variance);
    
    return (stdDev / 128.0).clamp(0.0, 1.0); // Normalized contrast
  }
  
  double _calculateSharpness(img.Image image) {
    double totalVariance = 0;
    int count = 0;
    
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final center = img.getLuminance(image.getPixel(x, y));
        final neighbors = [
          img.getLuminance(image.getPixel(x-1, y)),
          img.getLuminance(image.getPixel(x+1, y)),
          img.getLuminance(image.getPixel(x, y-1)),
          img.getLuminance(image.getPixel(x, y+1)),
        ];
        
        final variance = neighbors
            .map((n) => (n - center) * (n - center))
            .reduce((a, b) => a + b) / neighbors.length;
            
        totalVariance += variance;
        count++;
      }
    }
    
    final avgVariance = totalVariance / count;
    return (avgVariance / 10000.0).clamp(0.0, 1.0); // Normalized sharpness
  }
  
  double _estimateNoise(img.Image image) {
    // Simple noise estimation using high-pass filtering
    double totalNoise = 0;
    int count = 0;
    
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final center = img.getLuminance(image.getPixel(x, y));
        final laplacian = 4 * center - 
          img.getLuminance(image.getPixel(x-1, y)) -
          img.getLuminance(image.getPixel(x+1, y)) -
          img.getLuminance(image.getPixel(x, y-1)) -
          img.getLuminance(image.getPixel(x, y+1));
          
        totalNoise += laplacian.abs();
        count++;
      }
    }
    
    final avgNoise = totalNoise / count;
    return (avgNoise / 500.0).clamp(0.0, 1.0); // Normalized noise
  }
  
  // ===== Adaptive Processing =====
  
  Future<File> preprocessAdaptively(File originalImage) async {
    final bytes = await originalImage.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return originalImage;
    
    final quality = assessImageQuality(image);
    
    switch (quality) {
      case ImageQuality.excellent:
        return await _preprocessMinimal(originalImage);
      case ImageQuality.good:
        return await _preprocessModerate(originalImage);
      case ImageQuality.poor:
        return await preprocessForMaximumOCRAccuracy(originalImage);
      case ImageQuality.terrible:
        return await _preprocessHeavily(originalImage);
    }
  }
  
  Future<File> _preprocessMinimal(File originalImage) async {
    final bytes = await originalImage.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return originalImage;
    
    image = img.grayscale(image);
    image = _applySimpleContrastEnhancement(image);
    
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/minimal_${DateTime.now().millisecondsSinceEpoch}.jpg";
    await File(path).writeAsBytes(img.encodeJpg(image, quality: 95));
    
    return File(path);
  }
  
  Future<File> _preprocessModerate(File originalImage) async {
    final bytes = await originalImage.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return originalImage;
    
    image = img.grayscale(image);
    image = _normalizeLightingAndContrast(image);
    image = _applyTextSharpening(image);
    
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/moderate_${DateTime.now().millisecondsSinceEpoch}.jpg";
    await File(path).writeAsBytes(img.encodeJpg(image, quality: 95));
    
    return File(path);
  }
  
  Future<File> _preprocessHeavily(File originalImage) async {
    final bytes = await originalImage.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return originalImage;
    
    // Apply all preprocessing steps with stronger parameters
    image = _validateAndFixBasicIssues(image);
    image = _applyGeometricCorrections(image);
    image = _enhanceResolutionForOCR(image);
    image = _normalizeLightingAndContrast(image);
    image = _applyAdvancedNoiseReduction(image);
    image = _enhanceTextForOCR(image);
    image = _applyFinalOptimizations(image);
    
    // Additional aggressive processing for terrible quality images
    image = _applyCustomMedianFilter(image, size: 5); // Stronger noise reduction
    image = _applyTextSharpening(image); // Additional sharpening
    
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/heavy_${DateTime.now().millisecondsSinceEpoch}.jpg";
    await File(path).writeAsBytes(img.encodeJpg(image, quality: 100));
    
    return File(path);
  }
}

/// Document types for specialized preprocessing
enum DocumentType {
  receipt,
  businessCard,
  handwritten,
  book,
  whiteboard,
  general
}

/// Image quality assessment levels
enum ImageQuality {
  excellent,
  good,
  poor,
  terrible
}

/// Point class for coordinate storage
class Point<T> {
  final T x;
  final T y;
  
  Point(this.x, this.y);
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point && runtimeType == other.runtimeType && x == other.x && y == other.y;
  
  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}