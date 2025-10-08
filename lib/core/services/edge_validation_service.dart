import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Service to validate edge detection quality and provide user feedback
class EdgeValidationService {
  /// Validates if the detected corners form a reasonable document shape
  static EdgeValidationResult validateCorners(List<Offset> corners) {
    if (corners.length != 4) {
      return const EdgeValidationResult(
        isValid: false,
        confidence: 0.0,
        issues: ['Invalid number of corners detected'],
        suggestions: ['Please try scanning again or adjust corners manually'],
      );
    }

    final issues = <String>[];
    final suggestions = <String>[];
    double confidence = 1.0;

    // Check if corners are too close together
    const minDistance = 50.0;
    for (int i = 0; i < 4; i++) {
      for (int j = i + 1; j < 4; j++) {
        final distance = (corners[i] - corners[j]).distance;
        if (distance < minDistance) {
          issues.add('Corners are too close together');
          suggestions.add('Drag corners further apart to form a proper rectangle');
          confidence -= 0.3;
        }
      }
    }

    // Check if the shape is too small
    final area = _calculateQuadrilateralArea(corners);
    if (area < 10000) { // Minimum area threshold
      issues.add('Document area is too small');
      suggestions.add('Make sure the entire document is visible and adjust corners');
      confidence -= 0.2;
    }

    // Check if the shape is too skewed (not rectangular enough)
    final skewness = _calculateSkewness(corners);
    if (skewness > 0.3) {
      issues.add('Document shape is too skewed');
      suggestions.add('Try to align corners to form a proper rectangle');
      confidence -= 0.2;
    }

    // Check if corners are in reasonable order (clockwise or counter-clockwise)
    final isClockwise = _isClockwise(corners);
    if (!isClockwise && !_isCounterClockwise(corners)) {
      issues.add('Corners are not in proper order');
      suggestions.add('Drag corners to form a proper rectangle shape');
      confidence -= 0.1;
    }

    // Check if the aspect ratio is reasonable (not too wide or too tall)
    final aspectRatio = _calculateAspectRatio(corners);
    if (aspectRatio > 3.0 || aspectRatio < 0.33) {
      issues.add('Document proportions seem unusual');
      suggestions.add('Check if all corners are correctly positioned');
      confidence -= 0.1;
    }

    confidence = math.max(0.0, confidence);

    return EdgeValidationResult(
      isValid: issues.isEmpty,
      confidence: confidence,
      issues: issues,
      suggestions: suggestions,
    );
  }

  /// Calculates the area of a quadrilateral
  static double _calculateQuadrilateralArea(List<Offset> corners) {
    if (corners.length != 4) return 0.0;
    
    // Using the shoelace formula
    double area = 0.0;
    for (int i = 0; i < 4; i++) {
      final j = (i + 1) % 4;
      area += corners[i].dx * corners[j].dy;
      area -= corners[j].dx * corners[i].dy;
    }
    return area.abs() / 2.0;
  }

  /// Calculates how skewed the quadrilateral is (0 = perfect rectangle, 1 = very skewed)
  static double _calculateSkewness(List<Offset> corners) {
    if (corners.length != 4) return 1.0;
    
    // Calculate angles between adjacent sides
    final angles = <double>[];
    for (int i = 0; i < 4; i++) {
      final prev = corners[(i - 1 + 4) % 4];
      final curr = corners[i];
      final next = corners[(i + 1) % 4];
      
      final v1 = curr - prev;
      final v2 = next - curr;
      
      final dot = v1.dx * v2.dx + v1.dy * v2.dy;
      final mag1 = math.sqrt(v1.dx * v1.dx + v1.dy * v1.dy);
      final mag2 = math.sqrt(v2.dx * v2.dx + v2.dy * v2.dy);
      
      if (mag1 > 0 && mag2 > 0) {
        final cosAngle = dot / (mag1 * mag2);
        final angle = math.acos(math.max(-1.0, math.min(1.0, cosAngle)));
        angles.add(angle);
      }
    }
    
    if (angles.isEmpty) return 1.0;
    
    // Calculate deviation from 90 degrees
    const expectedAngle = math.pi / 2; // 90 degrees
    double totalDeviation = 0.0;
    for (final angle in angles) {
      totalDeviation += (angle - expectedAngle).abs();
    }
    
    return totalDeviation / (angles.length * expectedAngle);
  }

  /// Checks if corners are in clockwise order
  static bool _isClockwise(List<Offset> corners) {
    if (corners.length != 4) return false;
    
    double sum = 0.0;
    for (int i = 0; i < 4; i++) {
      final curr = corners[i];
      final next = corners[(i + 1) % 4];
      sum += (next.dx - curr.dx) * (next.dy + curr.dy);
    }
    return sum > 0;
  }

  /// Checks if corners are in counter-clockwise order
  static bool _isCounterClockwise(List<Offset> corners) {
    if (corners.length != 4) return false;
    
    double sum = 0.0;
    for (int i = 0; i < 4; i++) {
      final curr = corners[i];
      final next = corners[(i + 1) % 4];
      sum += (next.dx - curr.dx) * (next.dy + curr.dy);
    }
    return sum < 0;
  }

  /// Calculates the aspect ratio of the quadrilateral
  static double _calculateAspectRatio(List<Offset> corners) {
    if (corners.length != 4) return 1.0;
    
    // Find bounding box
    double minX = corners[0].dx;
    double maxX = corners[0].dx;
    double minY = corners[0].dy;
    double maxY = corners[0].dy;
    
    for (final corner in corners) {
      minX = math.min(minX, corner.dx);
      maxX = math.max(maxX, corner.dx);
      minY = math.min(minY, corner.dy);
      maxY = math.max(maxY, corner.dy);
    }
    
    final width = maxX - minX;
    final height = maxY - minY;
    
    if (height == 0) return 1.0;
    return width / height;
  }

  /// Gets user-friendly validation message
  static String getValidationMessage(EdgeValidationResult result) {
    if (result.isValid) {
      return 'Great! The document edges look good.';
    }
    
    if (result.confidence > 0.7) {
      return 'The edges look mostly good, but you might want to adjust them slightly.';
    } else if (result.confidence > 0.4) {
      return 'The edges need some adjustment. Please drag the corners to better match your document.';
    } else {
      return 'The edges don\'t look right. Please try scanning again or adjust the corners manually.';
    }
  }

  /// Gets validation color based on confidence
  static Color getValidationColor(EdgeValidationResult result) {
    if (result.isValid) return Colors.green;
    if (result.confidence > 0.7) return Colors.orange;
    if (result.confidence > 0.4) return Colors.amber;
    return Colors.red;
  }
}

/// Result of edge validation
class EdgeValidationResult {
  final bool isValid;
  final double confidence; // 0.0 to 1.0
  final List<String> issues;
  final List<String> suggestions;

  const EdgeValidationResult({
    required this.isValid,
    required this.confidence,
    required this.issues,
    required this.suggestions,
  });
}
