/// Import for Offset class
library;
import 'package:flutter/material.dart';

/// Position-aware text recognition model for enhanced OCR accuracy
/// Based on efficient vendor detection approach from receipt_recognition repository
class RecognizedPosition {
  final String text;
  final double x;
  final double y;
  final double width;
  final double height;
  final double confidence;

  const RecognizedPosition({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
  });

  /// Get the center point of the recognized text
  Offset get center => Offset(x + width / 2, y + height / 2);

  /// Get the bottom-right corner of the recognized text
  Offset get bottomRight => Offset(x + width, y + height);

  /// Get the top-left corner of the recognized text
  Offset get topLeft => Offset(x, y);

  /// Check if this position is in the top region of the image
  bool isInTopRegion(double imageHeight, {double threshold = 0.3}) {
    return y < imageHeight * threshold;
  }

  /// Check if this position is in the bottom region of the image
  bool isInBottomRegion(double imageHeight, {double threshold = 0.7}) {
    return y > imageHeight * threshold;
  }

  /// Check if this position is in the left region of the image
  bool isInLeftRegion(double imageWidth, {double threshold = 0.3}) {
    return x < imageWidth * threshold;
  }

  /// Check if this position is in the right region of the image
  bool isInRightRegion(double imageWidth, {double threshold = 0.7}) {
    return x > imageWidth * threshold;
  }

  /// Check if this position overlaps with another position
  bool overlapsWith(RecognizedPosition other) {
    return !(x + width < other.x || 
             other.x + other.width < x || 
             y + height < other.y || 
             other.y + other.height < y);
  }

  /// Calculate distance to another position
  double distanceTo(RecognizedPosition other) {
    return (center - other.center).distance;
  }

  /// Check if this position is above another position
  bool isAbove(RecognizedPosition other) {
    return y + height < other.y;
  }

  /// Check if this position is below another position
  bool isBelow(RecognizedPosition other) {
    return y > other.y + other.height;
  }

  /// Check if this position is to the left of another position
  bool isLeftOf(RecognizedPosition other) {
    return x + width < other.x;
  }

  /// Check if this position is to the right of another position
  bool isRightOf(RecognizedPosition other) {
    return x > other.x + other.width;
  }

  /// Get the area of the recognized text
  double get area => width * height;

  /// Check if this looks like a vendor name based on position and characteristics
  bool looksLikeVendorName(double imageHeight, double imageWidth) {
    // Vendor names are typically:
    // 1. In the top region of the receipt
    // 2. Not too small or too large
    // 3. Have reasonable confidence
    // 4. Are not mostly numbers or special characters
    
    final isInTop = isInTopRegion(imageHeight, threshold: 0.5); // More lenient: top 50%
    final hasReasonableSize = width > 30 && width < imageWidth * 0.9 && // More lenient size
                             height > 10 && height < 120;
    final hasGoodConfidence = confidence > 0.4; // Lower confidence threshold
    final isNotMostlyNumbers = !_isMostlyNumbers(text);
    final isNotMostlySpecialChars = !_isMostlySpecialChars(text);
    final hasReasonableLength = text.length >= 2 && text.length <= 60; // More lenient length
    
    // Additional checks for business-like text
    final hasBusinessKeywords = _hasBusinessKeywords(text);
    final hasProperCapitalization = _hasProperCapitalization(text);
    
    return isInTop && hasReasonableSize && hasGoodConfidence && 
           isNotMostlyNumbers && isNotMostlySpecialChars && hasReasonableLength &&
           (hasBusinessKeywords || hasProperCapitalization);
  }

  /// Check if text has business-related keywords
  bool _hasBusinessKeywords(String text) {
    final upper = text.toUpperCase();
    final businessKeywords = [
      'STORE', 'SHOP', 'MARKET', 'MART', 'SUPERMARKET',
      'RESTAURANT', 'CAFE', 'PIZZA', 'FOOD', 'HOTEL',
      'GAS', 'FUEL', 'STATION', 'PHARMACY', 'DRUG',
      'MEDICAL', 'CLINIC', 'BANK', 'INSURANCE'
    ];
    
    return businessKeywords.any((keyword) => upper.contains(keyword));
  }

  /// Check if text has proper capitalization (business name pattern)
  bool _hasProperCapitalization(String text) {
    // Check for proper case (first letter of each word capitalized)
    final words = text.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return false;
    
    int properCaseWords = 0;
    for (String word in words) {
      if (word.isNotEmpty && word[0] == word[0].toUpperCase()) {
        properCaseWords++;
      }
    }
    
    // At least 50% of words should be properly capitalized
    return (properCaseWords / words.length) >= 0.5;
  }

  /// Check if this looks like a total amount based on position and characteristics
  bool looksLikeTotalAmount(double imageHeight, double imageWidth) {
    // Total amounts are typically:
    // 1. In the bottom region of the receipt
    // 2. On the right side
    // 3. Contain currency symbols or numbers
    // 4. Have reasonable confidence
    
    final isInBottom = isInBottomRegion(imageHeight, threshold: 0.6);
    final isOnRight = isInRightRegion(imageWidth, threshold: 0.5);
    final hasGoodConfidence = confidence > 0.7;
    final containsAmount = _containsAmount(text);
    
    return isInBottom && isOnRight && hasGoodConfidence && containsAmount;
  }

  /// Check if this looks like a date based on position and characteristics
  bool looksLikeDate(double imageHeight, double imageWidth) {
    // Dates are typically:
    // 1. In the top or middle region
    // 2. Have date-like patterns
    // 3. Have reasonable confidence
    
    final isInTopOrMiddle = y < imageHeight * 0.6;
    final hasGoodConfidence = confidence > 0.7;
    final hasDatePattern = _hasDatePattern(text);
    
    return isInTopOrMiddle && hasGoodConfidence && hasDatePattern;
  }

  /// Helper method to check if text is mostly numbers
  bool _isMostlyNumbers(String text) {
    final numbers = text.replaceAll(RegExp(r'[^\d]'), '');
    return numbers.length > text.length * 0.7;
  }

  /// Helper method to check if text is mostly special characters
  bool _isMostlySpecialChars(String text) {
    final specialChars = text.replaceAll(RegExp(r'[a-zA-Z0-9\s]'), '');
    return specialChars.length > text.length * 0.5;
  }

  /// Helper method to check if text contains amount patterns
  bool _containsAmount(String text) {
    final amountPatterns = [
      RegExp(r'[\$€£¥₹]\s*\d+\.?\d*'),
      RegExp(r'\d+\.\d{2}'),
      RegExp(r'total.*\d+\.?\d*', caseSensitive: false),
      RegExp(r'amount.*\d+\.?\d*', caseSensitive: false),
    ];
    
    return amountPatterns.any((pattern) => pattern.hasMatch(text));
  }

  /// Helper method to check if text has date patterns
  bool _hasDatePattern(String text) {
    final datePatterns = [
      RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}'),
      RegExp(r'\d{4}-\d{2}-\d{2}'),
      RegExp(r'\d{1,2}\s+\w+\s+\d{4}'),
    ];
    
    return datePatterns.any((pattern) => pattern.hasMatch(text));
  }

  @override
  String toString() {
    return 'RecognizedPosition(text: "$text", x: $x, y: $y, width: $width, height: $height, confidence: $confidence)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecognizedPosition &&
        other.text == text &&
        other.x == x &&
        other.y == y &&
        other.width == width &&
        other.height == height &&
        other.confidence == confidence;
  }

  @override
  int get hashCode {
    return text.hashCode ^
        x.hashCode ^
        y.hashCode ^
        width.hashCode ^
        height.hashCode ^
        confidence.hashCode;
  }
}
