// lib/core/services/ocr/parcer/helpers/vendor_confidence_validator.dart

import 'chain_database.dart';
import 'line_heuristics.dart';

/// Enhanced vendor detection with confidence scoring and validation
class VendorConfidenceValidator {
  static final Map<String, VendorResult> _resultCache = {};
  
  /// Enhanced vendor detection with confidence scoring
  static VendorResult? detectVendorWithConfidence(List<String> lines) {
    // Check cache first
    final cacheKey = lines.join('|').hashCode.toString();
    if (_resultCache.containsKey(cacheKey)) {
      return _resultCache[cacheKey];
    }
    
    print('🔍 CONFIDENCE: Starting enhanced vendor detection with confidence scoring');
    
    // Strategy 1: Try chain database detection (highest accuracy)
    final chainResult = _tryChainDatabaseDetection(lines);
    if (chainResult != null && chainResult.confidence >= 0.8) {
      print('🔍 CONFIDENCE: Chain database detection succeeded with high confidence: ${chainResult.confidence}');
      _resultCache[cacheKey] = chainResult;
      return chainResult;
    }
    
    // Strategy 2: Try heuristic detection with validation
    final heuristicResult = _tryHeuristicDetection(lines);
    if (heuristicResult != null) {
      // Validate heuristic result
      final validatedResult = _validateAndScoreHeuristicResult(heuristicResult, lines);
      if (validatedResult.confidence >= 0.6) {
        print('🔍 CONFIDENCE: Heuristic detection succeeded with confidence: ${validatedResult.confidence}');
        _resultCache[cacheKey] = validatedResult;
        return validatedResult;
      }
    }
    
    // Strategy 3: If chain database had low confidence, but still found something, use it
    if (chainResult != null && chainResult.confidence >= 0.5) {
      print('🔍 CONFIDENCE: Using chain database result with medium confidence: ${chainResult.confidence}');
      _resultCache[cacheKey] = chainResult;
      return chainResult;
    }
    
    // Strategy 4: Use heuristic result even with lower confidence if no better option
    if (heuristicResult != null) {
      final validatedResult = _validateAndScoreHeuristicResult(heuristicResult, lines);
      if (validatedResult.confidence >= 0.4) {
        print('🔍 CONFIDENCE: Using heuristic result with low confidence: ${validatedResult.confidence}');
        _resultCache[cacheKey] = validatedResult;
        return validatedResult;
      }
    }
    
    print('🔍 CONFIDENCE: No vendor detected with sufficient confidence');
    return null;
  }
  
  /// Try chain database detection with confidence scoring
  static VendorResult? _tryChainDatabaseDetection(List<String> lines) {
    final vendor = ChainDatabase.detectVendor(lines);
    if (vendor == null) return null;
    
    final confidence = _calculateChainDatabaseConfidence(vendor, lines);
    final category = ChainDatabase.getVendorCategory(vendor) ?? 'Unknown';
    
    return VendorResult(
      name: vendor,
      confidence: confidence,
      method: 'chain_database',
      category: category,
      originalLines: lines,
    );
  }
  
  /// Try heuristic detection
  static VendorResult? _tryHeuristicDetection(List<String> lines) {
    final vendor = LineHeuristics().detectMerchant(lines);
    if (vendor == null) return null;
    
    return VendorResult(
      name: vendor,
      confidence: 0.5, // Base confidence, will be validated separately
      method: 'heuristic',
      category: _inferCategoryFromName(vendor),
      originalLines: lines,
    );
  }
  
  /// Calculate confidence for chain database results
  static double _calculateChainDatabaseConfidence(String vendor, List<String> lines) {
    double confidence = 0.9; // Base high confidence for chain database matches
    
    // Validate context match
    if (!_hasValidBusinessContext(vendor, lines)) {
      confidence -= 0.3;
      print('🔍 CONFIDENCE: Reduced confidence due to invalid business context');
    }
    
    // Check if vendor appears in top lines (more reliable)
    if (_appearsInTopLines(vendor, lines)) {
      confidence += 0.1;
      print('🔍 CONFIDENCE: Increased confidence - vendor appears in top lines');
    }
    
    // Check for business entity indicators
    if (_hasBusinessEntitySuffix(vendor)) {
      confidence += 0.05;
      print('🔍 CONFIDENCE: Increased confidence - has business entity suffix');
    }
    
    // Validate against known format patterns
    if (_matchesKnownVendorFormat(vendor)) {
      confidence += 0.05;
      print('🔍 CONFIDENCE: Increased confidence - matches known vendor format');
    }
    
    return confidence.clamp(0.0, 1.0);
  }
  
  /// Validate and score heuristic detection results
  static VendorResult _validateAndScoreHeuristicResult(VendorResult result, List<String> lines) {
    double confidence = 0.5; // Base confidence for heuristic detection
    
    // Check if it's a proper business name
    if (_looksLikeProperBusinessName(result.name)) {
      confidence += 0.2;
      print('🔍 CONFIDENCE: Increased confidence - looks like proper business name');
    }
    
    // Check business context validation
    if (_hasValidBusinessContext(result.name, lines)) {
      confidence += 0.15;
      print('🔍 CONFIDENCE: Increased confidence - has valid business context');
    }
    
    // Check position in receipt
    if (_appearsInTopLines(result.name, lines)) {
      confidence += 0.2;
      print('🔍 CONFIDENCE: Increased confidence - appears in top lines');
    }
    
    // Check for business entity indicators
    if (_hasBusinessEntitySuffix(result.name)) {
      confidence += 0.1;
      print('🔍 CONFIDENCE: Increased confidence - has business entity suffix');
    }
    
    // Check for business type keywords
    if (_hasBusinessTypeKeywords(result.name)) {
      confidence += 0.15;
      print('🔍 CONFIDENCE: Increased confidence - has business type keywords');
    }
    
    // Penalty for obviously invalid patterns
    if (_hasInvalidPatterns(result.name, lines)) {
      confidence -= 0.3;
      print('🔍 CONFIDENCE: Reduced confidence - has invalid patterns');
    }
    
    // Penalty for too generic names
    if (_isTooGeneric(result.name)) {
      confidence -= 0.2;
      print('🔍 CONFIDENCE: Reduced confidence - name too generic');
    }
    
    return VendorResult(
      name: result.name,
      confidence: confidence.clamp(0.0, 1.0),
      method: result.method,
      category: result.category,
      originalLines: result.originalLines,
    );
  }
  
  /// Check if vendor has valid business context
  static bool _hasValidBusinessContext(String vendor, List<String> lines) {
    final text = lines.join(' ').toUpperCase();
    
    // Check for conflicting contexts
    final conflictingKeywords = [
      'PRIVATE PARTY', 'INDIVIDUAL', 'PERSON', 'PERSONAL',
      'REFUND', 'RETURN', 'CREDIT NOTE', 'VOID',
      'INVALID', 'ERROR', 'MISTAKE', 'WRONG'
    ];
    
    for (final keyword in conflictingKeywords) {
      if (text.contains(keyword)) {
        print('🔍 CONFIDENCE: Found conflicting keyword: $keyword');
        return false;
      }
    }
    
    // Check for valid business indicators
    final businessIndicators = [
      'RECEIPT', 'INVOICE', 'BILL', 'STORE', 'SHOP', 'MARKET',
      'RESTAURANT', 'CAFE', 'HOTEL', 'SERVICE', 'COMPANY',
      'TAX', 'VAT', 'GST', 'TOTAL', 'SUBTOTAL'
    ];
    
    for (final indicator in businessIndicators) {
      if (text.contains(indicator)) {
        return true;
      }
    }
    
    return true; // Default to valid if no conflicts found
  }
  
  /// Check if vendor appears in top lines of receipt
  static bool _appearsInTopLines(String vendor, List<String> lines) {
    final vendorUpper = vendor.toUpperCase();
    final topLines = lines.take(3).toList();
    
    for (final line in topLines) {
      if (line.toUpperCase().contains(vendorUpper)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Check if vendor has business entity suffix
  static bool _hasBusinessEntitySuffix(String vendor) {
    final vendorUpper = vendor.toUpperCase();
    final businessSuffixes = [
      'INC', 'LLC', 'CORP', 'LTD', 'LIMITED', 'GMBH', 'AG',
      'S.A.', 'S.L.', 'S.R.L.', 'BV', 'NV', 'AS', 'AB', 'OY'
    ];
    
    for (final suffix in businessSuffixes) {
      if (vendorUpper.contains(suffix)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Check if vendor matches known vendor format patterns
  static bool _matchesKnownVendorFormat(String vendor) {
    // Check for proper capitalization patterns
    if (RegExp(r'^[A-Z][a-z]+(\s+[A-Z][a-z]+)*$').hasMatch(vendor)) {
      return true; // Proper case business name
    }
    
    // Check for all caps business name
    if (RegExp(r'^[A-Z]+(\s+[A-Z]+)*$').hasMatch(vendor) && vendor.length >= 3) {
      return true; // All caps business name
    }
    
    // Check for mixed case with numbers (common for chains)
    if (RegExp(r'^[A-Za-z]+[0-9]*(\s+[A-Za-z]+[0-9]*)*$').hasMatch(vendor)) {
      return true; // Business name with numbers
    }
    
    return false;
  }
  
  /// Check if name looks like a proper business name
  static bool _looksLikeProperBusinessName(String name) {
    if (name.length < 3 || name.length > 50) return false;
    
    // Must contain at least one letter
    if (!RegExp(r'[a-zA-Z]').hasMatch(name)) return false;
    
    // Should not be mostly numbers
    final letterCount = RegExp(r'[a-zA-Z]').allMatches(name).length;
    final totalChars = name.replaceAll(RegExp(r'\s'), '').length;
    if (totalChars > 0 && (letterCount / totalChars) < 0.6) return false;
    
    // Should have reasonable word count
    final words = name.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length > 6) return false; // Too many words
    
    return true;
  }
  
  /// Check if vendor has business type keywords
  static bool _hasBusinessTypeKeywords(String vendor) {
    final vendorUpper = vendor.toUpperCase();
    final businessKeywords = [
      'STORE', 'SHOP', 'MARKET', 'MART', 'SUPERMARKET',
      'RESTAURANT', 'CAFE', 'COFFEE', 'PIZZA', 'FOOD',
      'HOTEL', 'MOTEL', 'INN', 'LODGE',
      'PHARMACY', 'DRUG', 'MEDICAL', 'CLINIC',
      'GAS', 'FUEL', 'STATION', 'OIL',
      'BANK', 'CREDIT', 'FINANCE', 'INSURANCE',
      'AUTO', 'CAR', 'REPAIR', 'SERVICE',
      'HOME', 'HARDWARE', 'DEPOT', 'CENTER'
    ];
    
    for (final keyword in businessKeywords) {
      if (vendorUpper.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Check for invalid patterns that suggest wrong detection
  static bool _hasInvalidPatterns(String vendor, List<String> lines) {
    final vendorUpper = vendor.toUpperCase();
    
    // Check for patterns that indicate this is not a vendor name
    final invalidPatterns = [
      // Receipt system info
      'RECEIPT', 'INVOICE', 'BILL', 'TICKET', 'ORDER',
      'TRANSACTION', 'REFERENCE', 'ID', 'NUMBER',
      // Dates and times
      'DATE', 'TIME', 'AM', 'PM',
      // Payment info
      'CASH', 'CARD', 'PAYMENT', 'CHANGE', 'DUE',
      // Quantities and items
      'QTY', 'QUANTITY', 'ITEM', 'TOTAL', 'SUBTOTAL',
      // Contact info
      'PHONE', 'TEL', 'FAX', 'EMAIL', 'WWW', 'HTTP'
    ];
    
    for (final pattern in invalidPatterns) {
      if (vendorUpper == pattern || vendorUpper.startsWith('$pattern ') || vendorUpper.endsWith(' $pattern')) {
        return true;
      }
    }
    
    // Check if vendor is a line that contains receipt metadata
    if (RegExp(r'^\d+$').hasMatch(vendor)) return true; // Just numbers
    if (RegExp(r'^\d{1,2}[:/]\d{1,2}').hasMatch(vendor)) return true; // Date/time
    if (RegExp(r'[\(\)\-\d]{10,}').hasMatch(vendor)) return true; // Phone number
    
    return false;
  }
  
  /// Check if vendor name is too generic
  static bool _isTooGeneric(String vendor) {
    final vendorUpper = vendor.toUpperCase();
    final genericNames = [
      'STORE', 'SHOP', 'MARKET', 'CENTER', 'COMPANY',
      'SERVICE', 'BUSINESS', 'ENTERPRISE', 'GROUP',
      'RESTAURANT', 'CAFE', 'HOTEL', 'MOTEL'
    ];
    
    // Single generic word
    if (genericNames.contains(vendorUpper)) {
      return true;
    }
    
    // Very short generic phrases
    if (vendor.length <= 5 && genericNames.any((g) => vendorUpper.contains(g))) {
      return true;
    }
    
    return false;
  }
  
  /// Infer category from vendor name
  static String _inferCategoryFromName(String vendor) {
    final vendorUpper = vendor.toUpperCase();
    
    // Check against known categories
    if (vendorUpper.contains('MARKET') || vendorUpper.contains('GROCERY') || 
        vendorUpper.contains('SUPERMARKET') || vendorUpper.contains('FOOD')) {
      return 'Groceries';
    }
    
    if (vendorUpper.contains('RESTAURANT') || vendorUpper.contains('CAFE') || 
        vendorUpper.contains('PIZZA') || vendorUpper.contains('BURGER')) {
      return 'Food & Dining';
    }
    
    if (vendorUpper.contains('GAS') || vendorUpper.contains('FUEL') || 
        vendorUpper.contains('STATION') || vendorUpper.contains('OIL')) {
      return 'Transport & Fuel';
    }
    
    if (vendorUpper.contains('PHARMACY') || vendorUpper.contains('DRUG') || 
        vendorUpper.contains('MEDICAL')) {
      return 'Pharmacy & Health';
    }
    
    if (vendorUpper.contains('HOTEL') || vendorUpper.contains('MOTEL') || 
        vendorUpper.contains('INN')) {
      return 'Travel & Lodging';
    }
    
    return 'General Retail';
  }
  
  /// Clear the result cache (useful for testing)
  static void clearCache() {
    _resultCache.clear();
  }
}

/// Result of vendor detection with confidence score
class VendorResult {
  final String name;
  final double confidence;
  final String method;
  final String category;
  final List<String> originalLines;
  
  VendorResult({
    required this.name,
    required this.confidence,
    required this.method,
    required this.category,
    required this.originalLines,
  });
  
  @override
  String toString() {
    return 'VendorResult(name: $name, confidence: ${(confidence * 100).toStringAsFixed(1)}%, method: $method, category: $category)';
  }
  
  /// Convert to a map for JSON serialization
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'confidence': confidence,
      'method': method,
      'category': category,
      'confidencePercentage': (confidence * 100).round(),
    };
  }
}
