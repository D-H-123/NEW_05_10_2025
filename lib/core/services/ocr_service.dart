import 'dart:io';
import 'dart:math' as math;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import '../models/recognized_position.dart';

/// Dedicated OCR service for extracting structured data from receipts
class OCRService {
  static final OCRService _instance = OCRService._internal();
  factory OCRService() => _instance;
  OCRService._internal();

  final TextRecognizer _textRecognizer = TextRecognizer();

  // NEW METHOD - COMMENTED OUT FOR NOW
  // Using legacy OCR system instead due to accuracy issues
  /*
  /// Extract structured receipt data from preprocessed image
  Future<OCRResult> extractReceiptData(File preprocessedImage) async {
    print('🔍 OCR SERVICE: Starting receipt data extraction...');
    
    try {
      // Step 1: Extract text with position information using ML Kit
      final positions = await _extractTextWithPositions(preprocessedImage);
      print('🔍 OCR SERVICE: Text with positions extracted: ${positions.length} elements');
      
      // Step 2: Parse structured data using position-based analysis
      final result = await _parseReceiptDataWithPositions(positions, preprocessedImage);
      print('🔍 OCR SERVICE: Structured data extracted:');
      print('  Vendor: "${result.vendor}"');
      print('  Amount: ${result.amount}');
      print('  Currency: "${result.currency}"');
      print('  Date: ${result.date}');
      
      return result;
      
    } catch (e) {
      print('❌ OCR SERVICE: Error extracting receipt data: $e');
      return OCRResult(
        vendor: null,
        amount: null,
        currency: null,
        date: null,
        rawText: '',
        confidence: 0.0,
      );
    }
  }
  */

  /// Extract raw text from image using ML Kit
  Future<String> _extractRawText(File imageFile) async {
    try {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);
      
    return recognizedText.text;
    } catch (e) {
      print('❌ OCR SERVICE: Error extracting raw text: $e');
      throw Exception('Failed to extract text from image: $e');
    }
  }

  /// Extract text with position information using ML Kit
  Future<List<RecognizedPosition>> _extractTextWithPositions(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      final positions = <RecognizedPosition>[];
      
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          for (final element in line.elements) {
            positions.add(RecognizedPosition(
              text: element.text,
              x: element.boundingBox.left.toDouble(),
              y: element.boundingBox.top.toDouble(),
              width: element.boundingBox.width.toDouble(),
              height: element.boundingBox.height.toDouble(),
              confidence: 0.8, // ML Kit doesn't provide confidence, using default
            ));
          }
        }
      }
      
      print('🔍 OCR SERVICE: Extracted ${positions.length} text elements with positions');
      return positions;
    } catch (e) {
      print('❌ OCR SERVICE: Error extracting text with positions: $e');
      throw Exception('Failed to extract text with positions from image: $e');
    }
  }

  /// Parse structured data using position-based analysis (ENHANCED METHOD)
  Future<OCRResult> _parseReceiptDataWithPositions(List<RecognizedPosition> positions, File imageFile) async {
    print('🔍 OCR SERVICE: Parsing receipt data using position-based analysis...');
    
    // Get image dimensions for position analysis
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image for position analysis');
    }
    
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();
    
    print('🔍 OCR SERVICE: Image dimensions: ${imageWidth}x${imageHeight}');
    
    String? vendor;
    double? amount;
    String? currency;
    DateTime? date;
    double confidence = 0.0;
    
    // Parse vendor name using position-based analysis
    vendor = _extractVendorNameWithPositions(positions, imageWidth, imageHeight);
    
    // Parse amount using position-based analysis
    final amountResult = _extractAmountWithPositions(positions, imageWidth, imageHeight);
    amount = amountResult['amount'];
    currency = amountResult['currency'];
    
    // Parse date using position-based analysis
    date = _extractDateWithPositions(positions, imageWidth, imageHeight);
    
    // Calculate confidence based on how much data we extracted
    confidence = _calculateConfidence(vendor, amount, date);
    
    // Create raw text from all positions
    final rawText = positions.map((pos) => pos.text).join(' ');
    
    return OCRResult(
      vendor: vendor,
      amount: amount,
      currency: currency,
      date: date,
      rawText: rawText,
      confidence: confidence,
    );
  }

  /// Parse structured data from raw OCR text (LEGACY METHOD - kept for fallback)
  OCRResult _parseReceiptData(String rawText) {
    print('🔍 OCR SERVICE: Parsing receipt data from raw text...');
    
    final lines = rawText.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
    
    String? vendor;
    double? amount;
    String? currency;
    DateTime? date;
    double confidence = 0.0;
    
    // Parse vendor name (usually first few lines, look for business-like text)
    vendor = _extractVendorName(lines);
    
    // Parse amount (look for total, grand total, etc.)
    final amountResult = _extractAmount(lines);
    amount = amountResult['amount'];
    currency = amountResult['currency'];
    
    // Parse date (look for various date formats)
    date = _extractDate(lines);
    
    // Calculate confidence based on how much data we extracted
    confidence = _calculateConfidence(vendor, amount, date);
    
    return OCRResult(
      vendor: vendor,
      amount: amount,
      currency: currency,
      date: date,
      rawText: rawText,
      confidence: confidence,
    );
  }

  /// Extract vendor name using position-based analysis (ENHANCED METHOD)
  String? _extractVendorNameWithPositions(List<RecognizedPosition> positions, double imageWidth, double imageHeight) {
    print('🔍 OCR SERVICE: Extracting vendor name using position-based analysis...');
    print('🔍 OCR SERVICE: Total positions to analyze: ${positions.length}');
    
    // Enhanced vendor detection with multiple strategies
    String? vendor = _extractVendorByPosition(positions, imageWidth, imageHeight);
    if (vendor != null) {
      print('✅ OCR SERVICE: Found vendor by position: "$vendor"');
      return vendor;
    }
    
    // Fallback: Use text-based analysis with position hints
    vendor = _extractVendorByTextAnalysis(positions, imageWidth, imageHeight);
    if (vendor != null) {
      print('✅ OCR SERVICE: Found vendor by text analysis: "$vendor"');
      return vendor;
    }
    
    // Last resort: Use first few lines with basic filtering
    vendor = _extractVendorByTopLines(positions, imageHeight);
    if (vendor != null) {
      print('✅ OCR SERVICE: Found vendor by top lines: "$vendor"');
      return vendor;
    }
    
    print('⚠️ OCR SERVICE: No vendor found with any method');
    return null;
  }

  /// Strategy 1: Position-based vendor detection
  String? _extractVendorByPosition(List<RecognizedPosition> positions, double imageWidth, double imageHeight) {
    print('🔍 OCR SERVICE: Strategy 1 - Position-based detection...');
    
    // Filter positions that look like vendor names
    final vendorCandidates = positions.where((pos) => 
      pos.looksLikeVendorName(imageHeight, imageWidth)
    ).toList();
    
    print('🔍 OCR SERVICE: Found ${vendorCandidates.length} position-based candidates');
    
    if (vendorCandidates.isEmpty) {
      return null;
    }
    
    // Sort by Y position (top to bottom) and then by confidence
    vendorCandidates.sort((a, b) {
      final yComparison = a.y.compareTo(b.y);
      if (yComparison != 0) return yComparison;
      return b.confidence.compareTo(a.confidence);
    });
    
    final bestVendor = vendorCandidates.first;
    print('🔍 OCR SERVICE: Best position candidate: "${bestVendor.text}" at (${bestVendor.x}, ${bestVendor.y})');
    
    return bestVendor.text;
  }

  /// Strategy 2: Text-based analysis with position hints
  String? _extractVendorByTextAnalysis(List<RecognizedPosition> positions, double imageWidth, double imageHeight) {
    print('🔍 OCR SERVICE: Strategy 2 - Text analysis with position hints...');
    
    // Get top 30% of image positions
    final topPositions = positions.where((pos) => pos.y < imageHeight * 0.3).toList();
    print('🔍 OCR SERVICE: Analyzing ${topPositions.length} positions in top 30%');
    
    // Sort by Y position (top to bottom)
    topPositions.sort((a, b) => a.y.compareTo(b.y));
    
    for (final pos in topPositions) {
      final text = pos.text.trim();
      print('🔍 OCR SERVICE: Analyzing text: "$text"');
      
      // Skip if too short or too long
      if (text.length < 3 || text.length > 60) {
        print('🔍 OCR SERVICE: Skipping - length ${text.length}');
        continue;
      }
      
      // Skip if mostly numbers or special characters
      if (_isMostlyNumbers(text) || _isMostlySpecialChars(text)) {
        print('🔍 OCR SERVICE: Skipping - mostly numbers/special chars');
        continue;
      }
      
      // Skip if looks like address, phone, or date
      if (_isAddressLine(text) || _isPhoneLine(text) || _isDateLine(text)) {
        print('🔍 OCR SERVICE: Skipping - looks like address/phone/date');
        continue;
      }
      
      // Skip if contains menu items or prices
      if (_containsMenuItems(text)) {
        print('🔍 OCR SERVICE: Skipping - contains menu items');
        continue;
      }
      
      // Score the text as potential vendor name
      final score = _scoreVendorName(text);
      print('🔍 OCR SERVICE: Text "$text" scored: $score');
      
      if (score > 0.3) { // Lower threshold for better detection
        print('✅ OCR SERVICE: Text analysis found vendor: "$text" (score: $score)');
        return text;
      }
    }
    
    return null;
  }

  /// Strategy 3: Top lines fallback
  String? _extractVendorByTopLines(List<RecognizedPosition> positions, double imageHeight) {
    print('🔍 OCR SERVICE: Strategy 3 - Top lines fallback...');
    
    // Get top 40% of image positions
    final topPositions = positions.where((pos) => pos.y < imageHeight * 0.4).toList();
    
    // Sort by Y position (top to bottom)
    topPositions.sort((a, b) => a.y.compareTo(b.y));
    
    // Take first 5 positions
    final top5 = topPositions.take(5).toList();
    print('🔍 OCR SERVICE: Analyzing top 5 positions');
    
    for (final pos in top5) {
      final text = pos.text.trim();
      print('🔍 OCR SERVICE: Checking: "$text"');
      
      // Basic filtering
      if (text.length >= 3 && text.length <= 50 && !_isMostlyNumbers(text)) {
        print('✅ OCR SERVICE: Top lines fallback found vendor: "$text"');
        return text;
      }
    }
    
    return null;
  }

  /// Extract amount using position-based analysis (ENHANCED METHOD)
  Map<String, dynamic> _extractAmountWithPositions(List<RecognizedPosition> positions, double imageWidth, double imageHeight) {
    print('🔍 OCR SERVICE: Extracting amount using position-based analysis...');
    
    // Filter positions that look like total amounts
    final amountCandidates = positions.where((pos) => 
      pos.looksLikeTotalAmount(imageHeight, imageWidth)
    ).toList();
    
    if (amountCandidates.isEmpty) {
      print('⚠️ OCR SERVICE: No amount candidates found using position analysis');
      return {'amount': null, 'currency': null};
    }
    
    // Sort by confidence and position (prefer bottom-right)
    amountCandidates.sort((a, b) {
      final confidenceComparison = b.confidence.compareTo(a.confidence);
      if (confidenceComparison != 0) return confidenceComparison;
      
      // Prefer positions that are more to the right and bottom
      final rightComparison = b.x.compareTo(a.x);
      if (rightComparison != 0) return rightComparison;
      return b.y.compareTo(a.y);
    });
    
    final bestAmount = amountCandidates.first;
    print('✅ OCR SERVICE: Found amount candidate: "${bestAmount.text}" at position (${bestAmount.x}, ${bestAmount.y})');
    
    // Extract amount and currency from the text
    final amountMatch = RegExp(r'[\$€£¥₹]?\s*(\d+\.?\d*)').firstMatch(bestAmount.text);
    if (amountMatch != null) {
      final amountStr = amountMatch.group(1);
      if (amountStr != null) {
        final amount = double.tryParse(amountStr);
        final currency = _extractCurrencySymbol(bestAmount.text);
        return {'amount': amount, 'currency': currency};
      }
    }
    
    return {'amount': null, 'currency': null};
  }

  /// Extract date using position-based analysis (ENHANCED METHOD)
  DateTime? _extractDateWithPositions(List<RecognizedPosition> positions, double imageWidth, double imageHeight) {
    print('🔍 OCR SERVICE: Extracting date using position-based analysis...');
    
    // Filter positions that look like dates
    final dateCandidates = positions.where((pos) => 
      pos.looksLikeDate(imageHeight, imageWidth)
    ).toList();
    
    if (dateCandidates.isEmpty) {
      print('⚠️ OCR SERVICE: No date candidates found using position analysis');
      return null;
    }
    
    // Sort by confidence and position (prefer top-middle)
    dateCandidates.sort((a, b) {
      final confidenceComparison = b.confidence.compareTo(a.confidence);
      if (confidenceComparison != 0) return confidenceComparison;
      
      // Prefer positions that are more to the top
      return a.y.compareTo(b.y);
    });
    
    final bestDate = dateCandidates.first;
    print('✅ OCR SERVICE: Found date candidate: "${bestDate.text}" at position (${bestDate.x}, ${bestDate.y})');
    
    // Parse the date
    return _parseDateFromText(bestDate.text);
  }

  /// Extract vendor name from receipt lines (LEGACY METHOD)
  String? _extractVendorName(List<String> lines) {
    // Look for vendor name in first few lines
    for (int i = 0; i < math.min(5, lines.length); i++) {
      final line = lines[i];
      
      // Skip lines that look like addresses, phone numbers, or dates
      if (_isAddressLine(line) || _isPhoneLine(line) || _isDateLine(line)) {
        continue;
      }
      
      // Skip lines that are too short or too long
      if (line.length < 3 || line.length > 50) {
        continue;
      }
      
      // Skip lines that are mostly numbers or special characters
      if (_isMostlyNumbers(line) || _isMostlySpecialChars(line)) {
        continue;
      }
      
      // This looks like a vendor name
      return line;
    }
    
    return null;
  }

  /// Extract amount and currency from receipt lines
  Map<String, dynamic> _extractAmount(List<String> lines) {
    double? amount;
    String? currency;
    
    // Look for total, grand total, amount, etc.
    final totalKeywords = ['total', 'grand total', 'amount', 'sum', 'balance', 'due'];
    
    for (final line in lines) {
      final lowerLine = line.toLowerCase();
      
      // Check if line contains total keywords
      bool hasTotalKeyword = totalKeywords.any((keyword) => lowerLine.contains(keyword));
      
      if (hasTotalKeyword || _looksLikeTotalLine(line)) {
        // Extract amount from this line
        final amountMatch = RegExp(r'[\$€£¥₹]?\s*(\d+\.?\d*)').firstMatch(line);
        if (amountMatch != null) {
          final amountStr = amountMatch.group(1);
          if (amountStr != null) {
            amount = double.tryParse(amountStr);
            if (amount != null) {
              // Extract currency symbol
              currency = _extractCurrencySymbol(line);
              break;
            }
          }
        }
      }
    }
    
    // If no total found, look for any amount that might be the total
    if (amount == null) {
      for (final line in lines) {
        final amountMatch = RegExp(r'[\$€£¥₹]?\s*(\d+\.?\d*)').firstMatch(line);
        if (amountMatch != null) {
          final amountStr = amountMatch.group(1);
          if (amountStr != null) {
            final potentialAmount = double.tryParse(amountStr);
            if (potentialAmount != null && potentialAmount > 0) {
              amount = potentialAmount;
              currency = _extractCurrencySymbol(line);
              break;
            }
          }
        }
      }
    }
    
    return {'amount': amount, 'currency': currency};
  }

  /// Extract date from receipt lines
  DateTime? _extractDate(List<String> lines) {
    final dateFormats = [
      DateFormat('MM/dd/yyyy'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('MMM dd, yyyy'),
      DateFormat('dd MMM yyyy'),
      DateFormat('MM-dd-yyyy'),
      DateFormat('dd-MM-yyyy'),
    ];
    
    for (final line in lines) {
      for (final format in dateFormats) {
        try {
          final date = format.parse(line);
          // Check if date is reasonable (not too far in future or past)
          final now = DateTime.now();
          final yearDiff = (date.year - now.year).abs();
          if (yearDiff <= 2) {
            return date;
          }
        } catch (e) {
          // Continue to next format
        }
      }
    }
    
    return null;
  }

  /// Extract currency symbol from line
  String? _extractCurrencySymbol(String line) {
    final currencySymbols = ['\$', '€', '£', '¥', '₹', 'USD', 'EUR', 'GBP', 'JPY', 'INR'];
    
    for (final symbol in currencySymbols) {
      if (line.contains(symbol)) {
        return symbol;
      }
    }
    
    return null;
  }

  /// Check if line looks like a total line
  bool _looksLikeTotalLine(String line) {
    final totalPatterns = [
      RegExp(r'total.*\d+\.?\d*', caseSensitive: false),
      RegExp(r'amount.*\d+\.?\d*', caseSensitive: false),
      RegExp(r'sum.*\d+\.?\d*', caseSensitive: false),
    ];
    
    return totalPatterns.any((pattern) => pattern.hasMatch(line));
  }

  /// Check if line is an address line
  bool _isAddressLine(String line) {
    final addressKeywords = ['street', 'avenue', 'road', 'lane', 'drive', 'boulevard', 'st', 'ave', 'rd', 'ln', 'dr', 'blvd'];
    final lowerLine = line.toLowerCase();
    return addressKeywords.any((keyword) => lowerLine.contains(keyword));
  }

  /// Check if line is a phone line
  bool _isPhoneLine(String line) {
    final phonePattern = RegExp(r'\(\d{3}\)\s*\d{3}-\d{4}|\d{3}-\d{3}-\d{4}|\+\d{1,3}\s*\d{3,4}\s*\d{3,4}');
    return phonePattern.hasMatch(line);
  }

  /// Check if line is a date line
  bool _isDateLine(String line) {
    final datePattern = RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}-\d{2}-\d{2}');
    return datePattern.hasMatch(line);
  }

  /// Check if line is mostly numbers
  bool _isMostlyNumbers(String line) {
    final numbers = line.replaceAll(RegExp(r'[^\d]'), '');
    return numbers.length > line.length * 0.7;
  }

  /// Check if line is mostly special characters
  bool _isMostlySpecialChars(String line) {
    final specialChars = line.replaceAll(RegExp(r'[a-zA-Z0-9\s]'), '');
    return specialChars.length > line.length * 0.5;
  }

  /// Parse date from text using various formats
  DateTime? _parseDateFromText(String text) {
    final dateFormats = [
      DateFormat('MM/dd/yyyy'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('MMM dd, yyyy'),
      DateFormat('dd MMM yyyy'),
      DateFormat('MM-dd-yyyy'),
      DateFormat('dd-MM-yyyy'),
    ];
    
    for (final format in dateFormats) {
      try {
        final date = format.parse(text);
        // Check if date is reasonable (not too far in future or past)
        final now = DateTime.now();
        final yearDiff = (date.year - now.year).abs();
        if (yearDiff <= 2) {
          return date;
        }
      } catch (e) {
        // Continue to next format
      }
    }
    
    return null;
  }

  /// Score a text as potential vendor name (0.0 to 1.0)
  double _scoreVendorName(String text) {
    double score = 0.0;
    final upper = text.toUpperCase();
    
    // Length scoring (3-50 characters is good)
    if (text.length >= 3 && text.length <= 50) {
      score += 0.2;
    }
    
    // Letter ratio (mostly letters is good)
    final letterCount = text.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
    final letterRatio = letterCount / text.length;
    score += letterRatio * 0.2;
    
    // Word count (2-5 words is typical for business names)
    final words = text.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length >= 2 && words.length <= 5) {
      score += 0.15;
    }
    
    // Proper capitalization bonus
    int properCaseWords = 0;
    for (String word in words) {
      if (word.isNotEmpty && word[0] == word[0].toUpperCase()) {
        properCaseWords++;
      }
    }
    if (words.isNotEmpty) {
      score += (properCaseWords / words.length) * 0.15;
    }
    
    // Business keywords bonus
    if (upper.contains('STORE') || upper.contains('SHOP') || upper.contains('MARKET') || 
        upper.contains('MART') || upper.contains('SUPERMARKET')) {
      score += 0.2;
    }
    if (upper.contains('RESTAURANT') || upper.contains('CAFE') || upper.contains('PIZZA') || 
        upper.contains('FOOD') || upper.contains('HOTEL')) {
      score += 0.2;
    }
    if (upper.contains('GAS') || upper.contains('FUEL') || upper.contains('STATION')) {
      score += 0.15;
    }
    if (upper.contains('PHARMACY') || upper.contains('DRUG') || upper.contains('MEDICAL')) {
      score += 0.15;
    }
    
    // All caps bonus (often indicates business names)
    if (upper == text && text.length > 2) {
      score += 0.25;
    }
    
    // Mixed case with emphasis bonus
    if (text.contains(RegExp(r'[A-Z]{3,}'))) {
      score += 0.15;
    }
    
    // Penalties
    if (RegExp(r'^\d+$').hasMatch(text.trim())) {
      score -= 0.5; // Mostly numbers
    }
    if (RegExp(r'^\d{1,2}[./]\d{1,2}[./]\d{2,4}').hasMatch(text)) {
      score -= 0.3; // Date pattern
    }
    if (RegExp(r'^\d+\.\d+$').hasMatch(text)) {
      score -= 0.4; // Price pattern
    }
    
    return score.clamp(0.0, 1.0);
  }

  /// Check if text contains menu items
  bool _containsMenuItems(String text) {
    final upper = text.toUpperCase();
    
    // Menu item patterns
    if (RegExp(r'\d+x\s*[A-Z]', caseSensitive: false).hasMatch(text)) return true;
    if (RegExp(r'\d+\s*[A-Z]', caseSensitive: false).hasMatch(text)) return true;
    if (RegExp(r'^\d+\.\d+\s*[A-Z]{3}', caseSensitive: false).hasMatch(text)) return true;
    if (RegExp(r'^\d+\.\d+$', caseSensitive: false).hasMatch(text)) return true;
    
    // Menu keywords
    if (upper.contains('LATTE') || upper.contains('MACCHIATO') || upper.contains('SCHNITZEL')) return true;
    if (upper.contains('TOTAL') || upper.contains('CHF') || upper.contains('EUR')) return true;
    
    return false;
  }

  /// Calculate confidence score based on extracted data
  double _calculateConfidence(String? vendor, double? amount, DateTime? date) {
    double confidence = 0.0;
    
    if (vendor != null && vendor.isNotEmpty) confidence += 0.4;
    if (amount != null && amount > 0) confidence += 0.4;
    if (date != null) confidence += 0.2;
    
    return confidence;
  }

  /// Dispose resources
  void dispose() {
    _textRecognizer.close();
  }
}

/// Result model for OCR extraction
class OCRResult {
  final String? vendor;
  final double? amount;
  final String? currency;
  final DateTime? date;
  final String rawText;
  final double confidence;

  OCRResult({
    required this.vendor,
    required this.amount,
    required this.currency,
    required this.date,
    required this.rawText,
    required this.confidence,
  });

  @override
  String toString() {
    return 'OCRResult(vendor: $vendor, amount: $amount, currency: $currency, date: $date, confidence: $confidence)';
  }
}