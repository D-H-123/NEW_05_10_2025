// lib/services/ocr/parser/helpers/optimized_regex_util.dart
import 'package:intl/intl.dart';

class AmountMatch {
  final double amount;
  final String? currency;
  final int lineIndex;
  final double confidence;
  final String detectionMethod;
  final String originalText;
  
  AmountMatch(
    this.amount, {
    this.currency,
    required this.lineIndex,
    this.confidence = 0.0,
    this.detectionMethod = 'unknown',
    this.originalText = '',
  });
  
  @override
  String toString() => 'AmountMatch(amount: $amount, currency: $currency, confidence: $confidence, method: $detectionMethod)';
}

class RegexUtil{
  // Enhanced date patterns with better international support
  final List<RegExp> _dateRegexes = [
    // European format: dd/mm/yyyy, dd.mm.yyyy, dd-mm-yyyy
    RegExp(r'(?:Date|TIME):\s*([A-Za-z]+ \d{1,2},?\s*\d{4})', caseSensitive: false),
  
  // Month name formats with better matching
  RegExp(r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec|January|February|March|April|May|June|July|August|September|October|November|December)[a-z]*\.?\s+\d{1,2},?\s*\d{4}\b', caseSensitive: false),
  RegExp(r'\b\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec|January|February|March|April|May|June|July|August|September|October|November|December)[a-z]*\.?\s*,?\s*\d{4}\b', caseSensitive: false),
  
  // European format: dd/mm/yyyy, dd.mm.yyyy, dd-mm-yyyy
  RegExp(r'\b(\d{1,2}[\/\.-]\d{1,2}[\/\.-](?:20)?\d{2,4})\b'),
  // US format: mm/dd/yyyy
  RegExp(r'\b(\d{1,2}[\/\.-]\d{1,2}[\/\.-](?:20)?\d{2,4})\b'),
  // ISO format: yyyy-mm-dd, yyyy/mm/dd
  RegExp(r'\b(\d{4}[\/\.-]\d{1,2}[\/\.-]\d{1,2})\b'),
  ];

  // Multiple number patterns for different formatting styles
  // FIXED: More precise patterns to avoid partial matches
  final List<RegExp> _numberPatterns = [

    // PRIORITY 1: Currency symbols with amounts (highest priority)
    RegExp(r'[\$€£¥₹₩₽¢]\s*([0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{1,2})\b'), // $154.06, €12.34
    RegExp(r'[\$€£¥₹₩₽¢]\s*([0-9]{1,6}\.[0-9]{1,2})\b'), // $154.06, €12.34 (simpler)
    
    RegExp(r'([0-9]{1,3}(?:[. ][0-9]{3})*,[0-9]{1,2})\b'), // 1.234,56 or 1 234,56 or 19,96
  
  // PRIORITY 2: Complete US decimal format 
    RegExp(r'([0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{1,2})\b'), // 1,234.56 or 12.34
    
    // PRIORITY 3: Simple decimals (but be more specific)
    RegExp(r'(\d{1,6}\.\d{1,2})\b'), // 12.34 (but not part of larger numbers)
    RegExp(r'(\d{1,6},\d{1,2})\b'), // 12,34 (but not part of larger numbers)
    
    // PRIORITY 4: Whole numbers only as last resort (and be restrictive)
    RegExp(r'\b(\d{3,8})\b'),
    // // Standard currency with decimals: 12.34, 1,234.56
    // RegExp(r'([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)'),
    // // Simple decimal: 12.34
    // RegExp(r'(\d+\.\d{1,2})'),
    // // European style: 1.234,56 or 1 234,56
    // RegExp(r'([0-9]{1,3}(?:[. ][0-9]{3})*(?:,[0-9]{1,2})?)'),
    // // Simple European decimal: 12,34
    // RegExp(r'(\d+,\d{1,2})'),
    // // With spaces as thousands separator: 1 234 567.89
    // RegExp(r'([0-9]{1,3}(?: [0-9]{3})*(?:\.[0-9]{1,2})?)'),
    // // Fallback: whole numbers only (but be more restrictive)
    // RegExp(r'(\d{3,8})'), // At least 3 digits to avoid small numbers in policy text
  ];
  
  // DEBUG: Log the number patterns being used
  void _logNumberPatterns() {
    print('🔍 DEBUG: Number patterns being used:');
    for (int i = 0; i < _numberPatterns.length; i++) {
      print('  Pattern $i: ${_numberPatterns[i].pattern}');
    }
  }

  // Comprehensive total keywords with priority scoring
  final Map<String, double> _totalKeywords = {
    // High priority - clear final amounts
    
    'TOTAL DUE': 18.0,
    'AMOUNT DUE': 18.0,
    'BALANCE DUE': 18.0,
    'TOTAL AMOUNT DUE': 18.0,
    'AMOUNT TO PAY': 16,
    'PAY AMOUNT': 16,
    'PAYMENT DUE': 16,
    
    // Very high priority - common final totals
    'RECEIPT TOTAL': 20.0,  // Added for your example!
    'FINAL TOTAL': 12.0,
    'GRAND TOTAL': 12.0,
    'INVOICE TOTAL': 11.5,
    'BILL TOTAL': 11.5,
    'ORDER TOTAL': 11.5,
    'TOTAL PAYABLE': 11.0,
    'NET PAYABLE': 11.0,
    'AMOUNT PAYABLE': 11.0,
    
    // High priority - common totals
    'NET TOTAL': 10.0,
    'TOTAL AMOUNT': 10.0,
    'TOTAL COST': 9.5,
    'TOTAL PRICE': 9.5,
    'PURCHASE TOTAL': 9.0,
    'SALE TOTAL': 9.0,
    'TRANSACTION TOTAL': 9.0,
    
    // Medium-high priority - context-specific totals
    'CHECKOUT TOTAL': 8.5,
    'CART TOTAL': 8.5,
    'BASKET TOTAL': 8.5,
    'SUM TOTAL': 8.5,
    'OVERALL TOTAL': 8.5,
    'COMPLETE TOTAL': 8.5,
    
    // Medium priority - general indicators (but TOTAL is very common, so give it higher priority)
    'TOTAL': 10.0,
    'AMOUNT': 6.0,
    'BALANCE': 5.8,
    'SUM': 5.5,
    
    // Medium-low priority - partial amounts
    'SUBTOTAL': 5.0,
    'SUB-TOTAL': 5.0,
    'SUB TOTAL': 5.0,
    'NET AMOUNT': 4.8,
    'BASE AMOUNT': 4.5,
    
    // Tax and fee indicators (lower priority as not final)
    'TOTAL TAX': 4.2,
    'TAX TOTAL': 4.2,
    'TOTAL INCLUDING TAX': 8.0,  // Higher as it's usually final
    'INCLUSIVE OF TAX': 7.5,
    'WITH TAX': 7.0,
    'AFTER TAX': 7.0,
    'TAX': 3.5,
    'VAT': 3.5,
    'GST': 3.5,
    'SERVICE CHARGE': 3.0,
    'SERVICE FEE': 3.0,
    'TIP': 2.5,
    'GRATUITY': 2.5,
    
    // Low priority - might be totals but often not final
    'PAYMENT': 2.0,
    'CHARGE': 2.0,
    'COST': 2.0,
    'PRICE': 2.0,
    'FEE': 2.0,
  };

  // Enhanced currency detection
  final Map<String, List<String>> _currencyPatterns = {
    'USD': ['\$', 'USD', 'US\$', 'DOLLAR', 'DOLLARS', 'US DOLLAR'],
    'EUR': ['€', 'EUR', 'EURO', 'EUROS'],
    'GBP': ['£', 'GBP', 'POUND', 'POUNDS', 'STERLING'],
    'JPY': ['¥', 'JPY', 'YEN'],
    'CAD': ['CAD', 'C\$', 'CANADIAN', 'CAN\$'],
    'AUD': ['AUD', 'A\$', 'AUSTRALIAN', 'AUS\$'],
    'CHF': ['CHF', 'FRANC', 'SWISS'],
    'CNY': ['CNY', '¥', 'YUAN', 'RMB'],
    'INR': ['₹', 'INR', 'RUPEE', 'RUPEES', 'RS'],
    'KRW': ['₩', 'KRW', 'WON'],
    'RUB': ['₽', 'RUB', 'RUBLE', 'RUBLES'],
  };

  // Patterns to exclude (not actual amounts)
  final List<RegExp> _excludePatterns = [
    RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\b'), // Time
    RegExp(r'\b\d{1,2}[\/\.-]\d{1,2}[\/\.-]\d{2,4}\b'), // Date
    RegExp(r'\b\d{3,4}[-.\s]?\d{3,4}[-.\s]?\d{4}\b'), // Phone
    RegExp(r'\b\d{5}(?:-\d{4})?\b'), // Postal code
    RegExp(r'\b[A-Z]{2}\d{5,}\b'), // License plates, IDs
    RegExp(r'\b\d+%\b'), // Percentages
    RegExp(r'\bQTY\s*:?\s*\d+\b', caseSensitive: false), // Quantities
    RegExp(r'\bQUANTITY\s*:?\s*\d+\b', caseSensitive: false),
    RegExp(r'\bITEM\s*#?\s*\d+\b', caseSensitive: false), // Item numbers
    RegExp(r'\bSKU\s*:?\s*\d+\b', caseSensitive: false),
    RegExp(r'\bUPC\s*:?\s*\d+\b', caseSensitive: false),
    RegExp(r'\bREF\s*#?\s*\d+\b', caseSensitive: false), // Reference numbers
    RegExp(r'\bINV\s*#?\s*\d+\b', caseSensitive: false), // Invoice numbers
    RegExp(r'\bORDER\s*#?\s*\d+\b', caseSensitive: false), // Order numbers
    RegExp(r'\bTRANS\s*#?\s*\d+\b', caseSensitive: false), // Transaction numbers
    RegExp(r'\bCUSTOMER\s*#?\s*\d+\b', caseSensitive: false), // Customer IDs
    RegExp(r'\bTABLE\s*#?\s*\d+\b', caseSensitive: false), // Table numbers
    RegExp(r'\bROOM\s*#?\s*\d+\b', caseSensitive: false), // Room numbers
    RegExp(r'\bGUEST\s*#?\s*\d+\b', caseSensitive: false), // Guest numbers
    RegExp(r'\bSERVER\s*:?\s*\d+\b', caseSensitive: false), // Server IDs
    RegExp(r'\bCASHIER\s*:?\s*\d+\b', caseSensitive: false), // Cashier IDs
    RegExp(r'\bREGISTER\s*:?\s*\d+\b', caseSensitive: false), // Register numbers
    RegExp(r'\bTERM\s*:?\s*\d+\b', caseSensitive: false),
    // Policy and footer text patterns
    RegExp(r'\b\d+\s*DIAS?\b', caseSensitive: false), // "30 dias", "30 days"
    RegExp(r'\b\d+\s*DAYS?\b', caseSensitive: false), // "30 days"
    RegExp(r'\b\d+\s*ARTIGOS?\b', caseSensitive: false), // "30 artigos"
    RegExp(r'\b\d+\s*ITEMS?\b', caseSensitive: false), // "30 items"
    RegExp(r'\b\d+\s*ALIMENTARES?\b', caseSensitive: false), // "30 alimentares"
    RegExp(r'\b\d+\s*FOOD\b', caseSensitive: false), // "30 food"
    RegExp(r'\b\d+\s*TALÃO\b', caseSensitive: false), // "30 talão"
    RegExp(r'\b\d+\s*RECEIPT\b', caseSensitive: false), // "30 receipt"
  ];

  // Enhanced total detection with multiple strategies and confidence scoring
  // AmountMatch? findTotalByKeywords(List<String> lines) {
  //   print('🔍 ENHANCED: Starting multi-strategy total detection with ${lines.length} lines');
    
  //   List<AmountMatch> allCandidates = [];
    
  //   // Strategy 1: Exact keyword matches with position analysis
  //   for (var i = 0; i < lines.length; i++) {
  //     final line = lines[i];
  //     final upperLine = line.toUpperCase();
      
  //     for (final keyword in _totalKeywords.keys) {
  //       if (upperLine.contains(keyword)) {
  //         print('🔍 ENHANCED: Found keyword "$keyword" in line $i: "$line"');
          
  //         final candidates = _extractAmountsFromLine(line, i, keyword);
  //         for (final candidate in candidates) {
  //           // Boost confidence based on keyword priority
  //           final keywordScore = _totalKeywords[keyword]!;
  //           final positionScore = _calculatePositionScore(i, lines.length);
  //           final formatScore = _calculateFormatScore(line);
            
  //           final totalConfidence = keywordScore + positionScore + formatScore;
            
  //           allCandidates.add(AmountMatch(
  //             candidate.amount,
  //             currency: candidate.currency,
  //             lineIndex: i,
  //             confidence: totalConfidence,
  //             detectionMethod: 'keyword_$keyword',
  //             originalText: line,
  //           ));
  //         }
  //       }
  //     }
  //   }
    
  //   // Strategy 2: Pattern-based detection in bottom section
  //   final bottomSection = _getBottomSection(lines, 10);
  //   for (var i = 0; i < bottomSection.length; i++) {
  //     final globalIndex = lines.length - bottomSection.length + i;
  //     final line = bottomSection[i];
      
  //     if (_looksLikeTotalLine(line)) {
  //       print('🔍 ENHANCED: Found total-like pattern in line $globalIndex: "$line"');
        
  //       final candidates = _extractAmountsFromLine(line, globalIndex, 'pattern');
  //       for (final candidate in candidates) {
  //         final positionScore = _calculatePositionScore(globalIndex, lines.length);
  //         final formatScore = _calculateFormatScore(line);
          
  //         allCandidates.add(AmountMatch(
  //           candidate.amount,
  //           currency: candidate.currency,
  //           lineIndex: globalIndex,
  //           confidence: 5.0 + positionScore + formatScore,
  //           detectionMethod: 'pattern_bottom',
  //           originalText: line,
  //         ));
  //       }
  //     }
  //   }
    
  //   // Strategy 3: Largest amount in bottom section (fallback)
  //   // if (allCandidates.isEmpty) {
  //   //   final fallback = _findLargestAmountInBottom(lines, 8);
  //   //   if (fallback != null) {
  //   //     allCandidates.add(fallback);
  //   //   }
  //   // }
    
  //   // Filter and select best candidate
  //   return _selectBestCandidate(allCandidates, lines);
  // }
  // In optimized_regex_util.dart - Replace findTotalByKeywords method
AmountMatch? findTotalByKeywords(List<String> lines) {
  print('🔍 ENHANCED: Starting robust total detection with ${lines.length} lines');
  
  // DEBUG: Log the number patterns being used
  _logNumberPatterns();
  
  // DEBUG: Print all lines being analyzed
  print('🔍 DEBUG: ANALYZING THESE LINES FOR TOTAL:');
  print('=' * 80);
  for (int i = 0; i < lines.length; i++) {
    print('Line $i: "${lines[i]}"');
  }
  print('=' * 80);
  
  
  List<AmountMatch> allCandidates = [];
  
  
  // PRIORITY 1: Look for explicit TOTAL keywords first (highest confidence)
  print('🔍 DEBUG: PRIORITY 1 - Looking for high-priority total keywords (score >= 10.0)');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final upperLine = line.toUpperCase();
    
    // Check for high-priority total keywords
    for (final keyword in _totalKeywords.keys) {
      final keywordScore = _totalKeywords[keyword]!;
      
      // Only process high-confidence total keywords in first pass
      if (keywordScore >= 10.0 && upperLine.contains(keyword)) {
        print('🔍 ENHANCED: Found HIGH PRIORITY keyword "$keyword" (score: $keywordScore) in line $i: "$line"');
        if (upperLine.contains('TAXA') || upperLine.contains('BASE IMP') || 
            upperLine.contains('VAL.TOTAL') || upperLine.contains('VAL.IVA') ||
            (upperLine.contains('B ') && upperLine.contains('%')) ||
            (upperLine.contains('C ') && upperLine.contains('%'))) {
          print('🔍 DEBUG: Skipping tax breakdown line: "$line"');
          continue;
        }
        
        final candidates = _extractAmountsFromLine(line, i, keyword);
        print('🔍 DEBUG: Extracted ${candidates.length} candidates from line $i');
        for (final candidate in candidates) {
          final positionScore = _calculatePositionScore(i, lines.length);
          final formatScore = _calculateFormatScore(line);
          final amountSizeScore = _calculateAmountSizeScore(candidate.amount);
          final visualFormatScore = _calculateVisualFormatScore(line, candidate.amount);
          final contextScore = _calculateContextScore(line, i, lines.length, candidate.amount);
          // MASSIVE bonus for complete decimal amounts
          double decimalBonus = 0.0;
          if (candidate.amount.toString().contains('.') && 
              (candidate.amount * 100) % 100 != 0) { // Has decimal part
            decimalBonus = 20.0; // Huge bonus for complete decimal amounts
            print('🔍 DEBUG: Applied decimal bonus for complete amount: ${candidate.amount}');
          }
          // Very high confidence for explicit totals
          final totalConfidence = keywordScore + positionScore + formatScore + amountSizeScore + visualFormatScore + contextScore + 5.0 + decimalBonus; // Extra boost
          
          print('🔍 DEBUG: Created candidate: amount=${candidate.amount}, confidence=$totalConfidence (base=$keywordScore, position=$positionScore, format=$formatScore, size=$amountSizeScore, visual=$visualFormatScore, context=$contextScore, boost=5.0), method=explicit_total_$keyword');
          
          allCandidates.add(AmountMatch(
            candidate.amount,
            currency: candidate.currency,
            lineIndex: i,
            confidence: totalConfidence,
            detectionMethod: 'explicit_total_$keyword',
            originalText: line,
          ));
        }
      }
    }
  }
  
  // If we found explicit totals, return the best one immediately
  if (allCandidates.isNotEmpty) {
    print('🔍 DEBUG: Found ${allCandidates.length} explicit total candidates, selecting best...');
    final bestExplicit = _selectBestCandidate(allCandidates, lines);
    if (bestExplicit != null && bestExplicit.confidence > 15.0) {
      print('🔍 ENHANCED: Found explicit total with high confidence: $bestExplicit');
      return bestExplicit;
    } else {
      print('🔍 DEBUG: Best explicit candidate confidence too low: ${bestExplicit?.confidence}');
    }
  } else {
    print('🔍 DEBUG: No explicit total candidates found, continuing to other strategies...');
  }
  
  // PRIORITY 2: Look for total-like patterns near the end
  final bottomLines = _getBottomSection(lines, 8);
  for (var i = 0; i < bottomLines.length; i++) {
    final globalIndex = lines.length - bottomLines.length + i;
    final line = bottomLines[i];
    
    if (_isTotalLikeLine(line)) {
      print('🔍 ENHANCED: Found total-like line at $globalIndex: "$line"');
      
      final candidates = _extractAmountsFromLine(line, globalIndex, 'total_pattern');
      for (final candidate in candidates) {
        // Skip if amount is suspiciously small for a total
        if (candidate.amount < 5.0) continue;
        
        final positionScore = _calculatePositionScore(globalIndex, lines.length);
        final formatScore = _calculateFormatScore(line);
        final amountSizeScore = _calculateAmountSizeScore(candidate.amount);
        final visualFormatScore = _calculateVisualFormatScore(line, candidate.amount);
        final contextScore = _calculateContextScore(line, globalIndex, lines.length, candidate.amount);
        
        allCandidates.add(AmountMatch(
          candidate.amount,
          currency: candidate.currency,
          lineIndex: globalIndex,
          confidence: 12.0 + positionScore + formatScore + amountSizeScore + visualFormatScore + contextScore,
          detectionMethod: 'total_pattern',
          originalText: line,
        ));
      }
    }
  }
  
  // PRIORITY 3: Look for medium-priority keywords
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final upperLine = line.toUpperCase();
    
    for (final keyword in _totalKeywords.keys) {
      final keywordScore = _totalKeywords[keyword]!;
      
      // Medium priority keywords (5.0 - 9.9)
      if (keywordScore >= 5.0 && keywordScore < 10.0 && upperLine.contains(keyword)) {
        print('🔍 ENHANCED: Found medium priority keyword "$keyword" in line $i: "$line"');
        
        final candidates = _extractAmountsFromLine(line, i, keyword);
        for (final candidate in candidates) {
          final positionScore = _calculatePositionScore(i, lines.length);
          final formatScore = _calculateFormatScore(line);
          final amountSizeScore = _calculateAmountSizeScore(candidate.amount);
          final visualFormatScore = _calculateVisualFormatScore(line, candidate.amount);
          final contextScore = _calculateContextScore(line, i, lines.length, candidate.amount);
          
          final totalConfidence = keywordScore + positionScore + formatScore + amountSizeScore + visualFormatScore + contextScore;
          
          allCandidates.add(AmountMatch(
            candidate.amount,
            currency: candidate.currency,
            lineIndex: i,
            confidence: totalConfidence,
            detectionMethod: 'medium_keyword_$keyword',
            originalText: line,
          ));
        }
      }
    }
  }
  
  // PRIORITY 3.5: Special case for "TOTAL" keyword (very common)
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final upperLine = line.toUpperCase();
    
    if (upperLine.contains('TOTAL') && RegExp(r'\d+\.\d{2}').hasMatch(line)) {
      print('🔍 ENHANCED: Found TOTAL keyword with decimal amount in line $i: "$line"');
      
      final candidates = _extractAmountsFromLine(line, i, 'TOTAL');
      for (final candidate in candidates) {
        final positionScore = _calculatePositionScore(i, lines.length);
        final formatScore = _calculateFormatScore(line);
        final amountSizeScore = _calculateAmountSizeScore(candidate.amount);
        final visualFormatScore = _calculateVisualFormatScore(line, candidate.amount);
        final contextScore = _calculateContextScore(line, i, lines.length, candidate.amount);
        
        // Give TOTAL keyword a good confidence score
        final totalConfidence = 12.0 + positionScore + formatScore + amountSizeScore + visualFormatScore + contextScore;
        
        allCandidates.add(AmountMatch(
          candidate.amount,
          currency: candidate.currency,
          lineIndex: i,
          confidence: totalConfidence,
          detectionMethod: 'TOTAL_keyword',
          originalText: line,
        ));
      }
    }
  }
  
  // PRIORITY 4: Structural analysis - find amounts that appear after subtotals/tax
  final structuralTotal = _findTotalByStructure(lines);
  if (structuralTotal != null) {
    allCandidates.add(structuralTotal);
  }
  
  // PRIORITY 5: Last resort - but be much more selective
  if (allCandidates.isEmpty || allCandidates.every((c) => c.confidence < 8.0)) {
    print('🔍 ENHANCED: Using selective fallback detection');
    final fallback = _findSelectiveFallback(lines);
    if (fallback != null) {
      allCandidates.add(fallback);
    }
  }
  
  // PRIORITY 6: Ultra-fallback - look for any line with "Total" and a reasonable amount
  if (allCandidates.isEmpty) {
    print('🔍 ENHANCED: Using ultra-fallback detection');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final upperLine = line.toUpperCase();
      
      // Look for any variation of "total" with an amount
      if ((upperLine.contains('TOTAL') || upperLine.contains('TOTALE') || upperLine.contains('TOTAAL')) && 
          RegExp(r'\d+\.?\d*').hasMatch(line)) {
        print('🔍 ENHANCED: Found total-like line in ultra-fallback: "$line"');
        
        final candidates = _extractAmountsFromLine(line, i, 'ultra_fallback');
        for (final candidate in candidates) {
          if (candidate.amount >= 1.0) { // Only reasonable amounts
            final amountSizeScore = _calculateAmountSizeScore(candidate.amount);
            final visualFormatScore = _calculateVisualFormatScore(line, candidate.amount);
            final contextScore = _calculateContextScore(line, i, 100, candidate.amount);
            allCandidates.add(AmountMatch(
              candidate.amount,
              currency: candidate.currency,
              lineIndex: i,
              confidence: 6.0 + amountSizeScore + visualFormatScore + contextScore,
              detectionMethod: 'ultra_fallback',
              originalText: line,
            ));
          }
        }
      }
    }
  }
  
  // PRIORITY 7: Special case for isolated large amounts (common OCR splitting issue)
  // Look for lines that contain only a large amount (like "54,50" on line 27)
  if (allCandidates.isEmpty || allCandidates.every((c) => c.amount < 20.0)) {
    print('🔍 ENHANCED: Looking for isolated large amounts (OCR splitting)');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // Look for lines that are just amounts (common when OCR splits totals)
      if (RegExp(r'^\d+[.,]\d{2}$').hasMatch(line)) {
        final amount = _parseMoneyString(line);
        if (amount != null && amount >= 20.0) { // Only large amounts
          print('🔍 ENHANCED: Found isolated large amount: "$line" -> $amount');
          
          final amountSizeScore = _calculateAmountSizeScore(amount);
          final visualFormatScore = _calculateVisualFormatScore(line, amount);
          final positionScore = _calculatePositionScore(i, lines.length);
          final contextScore = _calculateContextScore(line, i, lines.length, amount);
          
          allCandidates.add(AmountMatch(
            amount,
            currency: null, // Will be detected from context
            lineIndex: i,
            confidence: 8.0 + amountSizeScore + visualFormatScore + positionScore + contextScore,
            detectionMethod: 'isolated_large_amount',
            originalText: line,
          ));
        }
      }
    }
  }
  
  final finalResult = _selectBestCandidate(allCandidates, lines);
  
  print('🔍 DEBUG: FINAL TOTAL DETECTION RESULT:');
  print('=' * 80);
  
  if (finalResult != null) {
    final amountSizeScore = _calculateAmountSizeScore(finalResult.amount);
    final visualFormatScore = _calculateVisualFormatScore(finalResult.originalText, finalResult.amount);
    final contextScore = _calculateContextScore(finalResult.originalText, finalResult.lineIndex, 100, finalResult.amount);
    print('✅ SUCCESS: Found total: ${finalResult.amount} ${finalResult.currency ?? "unknown currency"}');
    print('   Confidence: ${finalResult.confidence} (including amount size bonus: $amountSizeScore, visual format bonus: $visualFormatScore, context bonus: $contextScore)');
    print('   Method: ${finalResult.detectionMethod}');
    print('   Line: ${finalResult.lineIndex}');
    print('   Text: "${finalResult.originalText}"');
  } else {
    print('❌ FAILED: No total found');
    print('   Total candidates analyzed: ${allCandidates.length}');
  }
  print('=' * 80);
  
  return finalResult;
}

// Enhanced method to detect total-like lines
bool _isTotalLikeLine(String line) {
  final upperLine = line.toUpperCase();
  final trimmed = line.trim();
  
  // Must contain an amount
  if (!RegExp(r'\$?\d+\.\d{2}').hasMatch(line)) return false;
  
  // Strong indicators of total lines
  if (upperLine.contains('TOTAL') || 
      upperLine.contains('AMOUNT DUE') || 
      upperLine.contains('BALANCE') ||
      upperLine.contains('PAYABLE')) {
    return true;
  }
  
  // Lines that are clearly formatted as totals
  if (RegExp(r'^[A-Za-z\s]*:?\s*\$\d+\.\d{2}$').hasMatch(trimmed)) {
    // Exclude obvious item lines
    if (!upperLine.contains('QTY') && !upperLine.contains('ITEM') && 
        !RegExp(r'^\d+\s*[xX]').hasMatch(trimmed)) {
      return true;
    }
  }
  
  // Lines with separator formatting (common for totals)
  if (RegExp(r'[-=_]{3,}').hasMatch(line) && RegExp(r'\$\d+\.\d{2}').hasMatch(line)) {
    return true;
  }
  
  return false;
}

// Find total by analyzing receipt structure
AmountMatch? _findTotalByStructure(List<String> lines) {
  print('🔍 ENHANCED: Analyzing receipt structure for total');
  
  int taxIndex = -1;
  
  // Find subtotal and tax lines
  for (int i = 0; i < lines.length; i++) {
    final upperLine = lines[i].toUpperCase();
    
    if (upperLine.contains('SUBTOTAL') && RegExp(r'\d+\.\d{2}').hasMatch(lines[i])) {
      print('🔍 ENHANCED: Found subtotal at line $i');
    }
    
    if ((upperLine.contains('TAX') || upperLine.contains('VAT')) && 
        RegExp(r'\d+\.\d{2}').hasMatch(lines[i]) &&
        !upperLine.contains('TOTAL')) {
      taxIndex = i;
      print('🔍 ENHANCED: Found tax at line $i');
    }
  }
  
  // If we found tax, look for total immediately after
  if (taxIndex != -1) {
    for (int i = taxIndex + 1; i < lines.length && i <= taxIndex + 3; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      final upperLine = line.toUpperCase();
      
      // Skip obvious non-total lines
      if (upperLine.contains('THANK') || upperLine.contains('VISIT') || 
          upperLine.contains('RECEIPT') || line.length > 50) {
        continue;
      }
      
      final candidates = _extractAmountsFromLine(line, i, 'after_tax_structure');
      if (candidates.isNotEmpty) {
        final candidate = candidates.first;
        print('🔍 ENHANCED: Found structural total after tax: ${candidate.amount}');
        
        final amountSizeScore = _calculateAmountSizeScore(candidate.amount);
        final visualFormatScore = _calculateVisualFormatScore(line, candidate.amount);
        final contextScore = _calculateContextScore(line, i, 100, candidate.amount);
        return AmountMatch(
          candidate.amount,
          currency: candidate.currency,
          lineIndex: i,
          confidence: 11.0 + amountSizeScore + visualFormatScore + contextScore,
          detectionMethod: 'structure_after_tax',
          originalText: line,
        );
      }
    }
  }
  
  return null;
}

// More selective fallback that avoids item amounts
AmountMatch? _findSelectiveFallback(List<String> lines) {
  print('🔍 ENHANCED: Using selective fallback detection');
  
  final bottomSection = _getBottomSection(lines, 6);
  List<AmountMatch> candidates = [];
  
  for (var i = 0; i < bottomSection.length; i++) {
    final globalIndex = lines.length - bottomSection.length + i;
    final line = bottomSection[i].trim();
    
    // Skip lines that are obviously items
    if (_isObviousItemLine(line)) {
      print('🔍 ENHANCED: Skipping obvious item line: "$line"');
      continue;
    }
    
    final amounts = _extractAmountsFromLine(line, globalIndex, 'selective_fallback');
    for (final amount in amounts) {
      // Only consider reasonable totals
      if (amount.amount >= 5.0) {
        final amountSizeScore = _calculateAmountSizeScore(amount.amount);
        final visualFormatScore = _calculateVisualFormatScore(line, amount.amount);
        final contextScore = _calculateContextScore(line, globalIndex, lines.length, amount.amount);
        candidates.add(AmountMatch(
          amount.amount,
          currency: amount.currency,
          lineIndex: globalIndex,
          confidence: 4.0 + _calculatePositionScore(globalIndex, lines.length) + amountSizeScore + visualFormatScore + contextScore,
          detectionMethod: 'selective_fallback',
          originalText: line,
        ));
      }
    }
  }
  
  // Return the last (bottommost) reasonable amount
  if (candidates.isNotEmpty) {
    candidates.sort((a, b) => b.lineIndex.compareTo(a.lineIndex));
    return candidates.first;
  }
  
  return null;
}
bool _isObviousItemLine(String line) {
  final upperLine = line.toUpperCase();
  final trimmed = line.trim();
  
  // Quantity patterns
  if (RegExp(r'^\d+\s*[xX]\s*').hasMatch(trimmed)) return true;
  if (RegExp(r'\b\d+\s*AT\s*\$').hasMatch(upperLine)) return true;
  if (upperLine.contains('QTY') || upperLine.contains('QUANTITY')) return true;
  
  // Item description patterns
  if (RegExp(r'^[A-Za-z][a-z\s]*\s+\$\d+\.\d{2}$').hasMatch(trimmed) && 
      trimmed.length > 15) return true;
  
  // Lines that contain item-like words
  final itemWords = ['BURGER', 'PIZZA', 'DRINK', 'COFFEE', 'SANDWICH', 'SALAD', 'BOWL'];
  for (final word in itemWords) {
    if (upperLine.contains(word)) return true;
  }
  
  return false;
}



  // FIX: Deduplicate candidates and prioritize complete matches
  List<AmountMatch> _deduplicateAndPrioritizeCandidates(List<AmountMatch> candidates) {
    if (candidates.isEmpty) return candidates;
    
    print('🔍 DEBUG: Deduplicating ${candidates.length} candidates');
    
    // Group candidates by amount
    final Map<double, List<AmountMatch>> amountGroups = {};
    for (final candidate in candidates) {
      amountGroups.putIfAbsent(candidate.amount, () => []).add(candidate);
    }
    
    print('🔍 DEBUG: Found ${amountGroups.length} unique amounts');
    
    List<AmountMatch> bestCandidates = [];
    
    for (final entry in amountGroups.entries) {
      final amount = entry.key;
      final candidatesForAmount = entry.value;
      
      print('🔍 DEBUG: Amount $amount has ${candidatesForAmount.length} candidates');
      
      // For each amount, pick the best candidate
      AmountMatch? bestCandidate;
      
      for (final candidate in candidatesForAmount) {
        if (bestCandidate == null) {
          bestCandidate = candidate;
          continue;
        }
        
        // Prioritize complete matches (longer original text)
        final currentLength = candidate.originalText.length;
        final bestLength = bestCandidate.originalText.length;
        
        if (currentLength > bestLength) {
          // Longer match is better (more complete)
          bestCandidate = candidate;
          print('🔍 DEBUG: Chose longer match for $amount: "${candidate.originalText}" (${currentLength} chars) over "${bestCandidate.originalText}" (${bestLength} chars)');
        } else if (currentLength == bestLength) {
          // Same length, choose higher confidence
          if (candidate.confidence > bestCandidate.confidence) {
            bestCandidate = candidate;
            print('🔍 DEBUG: Chose higher confidence for $amount: ${candidate.confidence} over ${bestCandidate.confidence}');
          }
        }
      }
      
      if (bestCandidate != null) {
        bestCandidates.add(bestCandidate);
        print('🔍 DEBUG: Selected best candidate for amount $amount: $bestCandidate');
      }
    }
    
    // Sort by confidence (highest first)
    bestCandidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    print('🔍 DEBUG: Final deduplicated candidates: ${bestCandidates.length}');
    for (int i = 0; i < bestCandidates.length; i++) {
      print('  Final candidate $i: ${bestCandidates[i]}');
    }
    
    return bestCandidates;
  }

  // Extract all possible amounts from a line
  List<AmountMatch> _extractAmountsFromLine(String line, int lineIndex, String method) {
    List<AmountMatch> candidates = [];
    
    // DEBUG: Log every line being processed for amount extraction
    print('🔍 DEBUG: Extracting amounts from line $lineIndex: "$line" (method: $method)');
    // FIRST: Try to find complete decimal amounts (highest priority)
    final completeDecimalPatterns = [
      RegExp(r'([0-9]{1,6},[0-9]{2})\b'), // European: 19,96
      RegExp(r'([0-9]{1,6}\.[0-9]{2})\b'), // US: 19.96
    ];
    bool foundCompleteDecimal = false;
    for (final pattern in completeDecimalPatterns) {
      final matches = pattern.allMatches(line);
      for (final match in matches) {
        final numberText = match.group(1)!;
        
        if (_shouldExcludeNumber(line, match.start, match.end)) {
          continue;
        }
        // NEW: Check if this is a partial number
        if (_isPartialNumber(numberText, line)) {
          print('🔍 DEBUG: Rejected partial number "$numberText" from line: "$line"');
          continue;
        }
        
        final amount = _parseMoneyString(numberText);
        if (amount != null && _isValidAmount(amount, line)) {
          final currency = _detectCurrencyInLine(line);
          candidates.add(AmountMatch(
            amount,
            currency: currency,
            lineIndex: lineIndex,
            confidence: 10.0, // Base confidence for complete decimals
            detectionMethod: method,
            originalText: line,
          ));
          foundCompleteDecimal = true;
          print('🔍 DEBUG: Found complete decimal: $amount from "$numberText"');
          
          // Special debug for 154.06
          if (amount == 154.06) {
            print('🔍 DEBUG: SUCCESS! 154.06 was extracted and validated!');
          }
        } else if (amount == 154.06) {
          print('🔍 DEBUG: 154.06 was parsed but failed validation!');
        }
      }
    }
    
    // If we found complete decimals, don't look for partial numbers
    if (foundCompleteDecimal) {
      print('🔍 DEBUG: Found complete decimals, skipping partial number detection');
      return _deduplicateAndPrioritizeCandidates(candidates);
    }
    // Try each number pattern
    for (int patternIndex = 0; patternIndex < _numberPatterns.length; patternIndex++) {
      final pattern = _numberPatterns[patternIndex];
      final matches = pattern.allMatches(line);
      print('🔍 DEBUG: Pattern $patternIndex "${pattern.pattern}" found ${matches.length} matches');
      
      for (final match in matches) {
        final numberText = match.group(1)!;
        print('🔍 DEBUG: Found number text: "$numberText" at position ${match.start}-${match.end}');
        
        // Special debug for currency patterns
        if (patternIndex == 0 || patternIndex == 1) {
          print('🔍 DEBUG: Currency pattern $patternIndex matched: "$numberText" from line: "$line"');
        }
        
        // Skip if it matches exclude patterns
        if (_shouldExcludeNumber(line, match.start, match.end)) {
          print('🔍 DEBUG: Excluded number "$numberText" due to exclude patterns');
          continue;
        }
        
        final amount = _parseMoneyString(numberText);
        print('🔍 DEBUG: Parsed amount: $amount from "$numberText"');
        
        if (amount != null && _isValidAmount(amount, line)) {
          final currency = _detectCurrencyInLine(line);
          final amountSizeScore = _calculateAmountSizeScore(amount);
          final visualFormatScore = _calculateVisualFormatScore(line, amount);
          final contextScore = _calculateContextScore(line, lineIndex, 100, amount); // Use 100 as default totalLines
          final candidate = AmountMatch(
            amount,
            currency: currency,
            lineIndex: lineIndex,
            confidence: amountSizeScore + visualFormatScore + contextScore, // Include amount size, visual format, and context in base confidence
            detectionMethod: method,
            originalText: line,
          );
          print('🔍 DEBUG: Created candidate: $candidate');
          candidates.add(candidate);
        } else {
          print('🔍 DEBUG: Rejected amount $amount from "$numberText" (invalid or null)');
          if (amount != null) {
            print('🔍 DEBUG: Amount validation failed for: $amount in line: "$line"');
          }
        }
      }
    }
    
    print('🔍 DEBUG: Line $lineIndex produced ${candidates.length} candidates');
    
    // FIX: Deduplicate candidates and prioritize complete matches
    final deduplicatedCandidates = _deduplicateAndPrioritizeCandidates(candidates);
    print('🔍 DEBUG: After deduplication: ${deduplicatedCandidates.length} candidates');
    
    return deduplicatedCandidates;
  }

  // Enhanced amount parsing with better international support
  double? _parseMoneyString(String s) {
    final originalS = s;
    s = s.trim().replaceAll(' ', '');
    
    print('🔍 DEBUG: Parsing money string: "$originalS" -> "$s"');
    
    // Handle different decimal separators
    if (s.contains(',') && s.contains('.')) {
      final lastComma = s.lastIndexOf(',');
      final lastDot = s.lastIndexOf('.');
      
      if (lastComma > lastDot) {
        // European style: 1.234,56
        s = s.replaceAll('.', '').replaceAll(',', '.');
        print('🔍 DEBUG: European style detected, converted to: "$s"');
      } else {
        // US style: 1,234.56
        s = s.replaceAll(',', '');
        print('🔍 DEBUG: US style detected, converted to: "$s"');
      }
    } else if (s.contains(',')) {
      // Could be thousands separator or decimal
      final commaIndex = s.lastIndexOf(',');
      final digitsAfterComma = s.substring(commaIndex + 1).length;
      final digitsBefore = s.substring(0, commaIndex);

      
      
      if (digitsAfterComma == 2 && !digitsBefore.contains(',') && 
      !digitsBefore.contains('.') &&
      digitsBefore.length <= 6) {
        // Likely decimal: 12,34
        s = s.replaceAll(',', '.');
        print('🔍 DEBUG: Decimal comma detected, converted to: "$s"');
      } else {
        // Likely thousands: 1,234 or 12,345
        s = s.replaceAll(',', '');
        print('🔍 DEBUG: Thousands comma detected, converted to: "$s"');
      }
    }
    
    try {
      final amount = double.parse(s);
      print('🔍 DEBUG: Successfully parsed "$originalS" -> "$s" -> $amount');
      return amount;
    } catch (e) {
      print('🔍 DEBUG: Failed to parse "$originalS" -> "$s": $e');
      return null;
    }
  }

  // Enhanced validation with more sophisticated rules
  bool _isValidAmount(double amount, String line) {
    // Basic range check
    if (amount <= 0 || amount > 1000000) {
      return false;
    }
    
    // Special debug for 154.06
    if (amount == 154.06 || line.contains('154.06') || line.contains('154,06')) {
      print('🔍 DEBUG: Found 154.06 in line: "$line"');
      print('🔍 DEBUG: Amount: $amount, Upper line: "${line.toUpperCase()}"');
    }
    
    // Check context for invalid patterns
    final upperLine = line.toUpperCase();
    
    // Skip obvious non-amounts
    final invalidContexts = [
      'QTY', 'QUANTITY', 'ITEM #', 'SKU', 'UPC', 'BARCODE',
      'ORDER #', 'INVOICE #', 'TRANS #', 'REF #', 'P.O.#',
      'TABLE', 'ROOM', 'SEAT', 'GUEST', 'SERVER', 'CASHIER', 'REGISTER',
      'PHONE', 'TEL', 'FAX', 'ZIP', 'POSTAL', 'ADDRESS',
      'WEIGHT', 'LBS', 'KG', 'OZ', 'GRAMS',
      'TEMP', 'TEMPERATURE', '°F', '°C',
      'TIME', 'AM', 'PM', 'HOURS', 'MINS',
      'DATE', 'YEAR', 'MONTH', 'DAY',
      'VERSION', 'V.', 'VER',
      // Policy and footer text
      'DIAS', 'DAYS', 'ARTIGOS', 'ITEMS', 'ALIMENTARES', 'FOOD',
      'TALÃO', 'OBRIGADO', 'THANK', 'VISIT', 'RETURN',
      'POLICY', 'DEVOLUÇÃO', 'COMPROVANTE', 'RECIBO'
    ];
    
    // Check for tax section keywords (but allow if it's clearly a total)
    final taxSectionKeywords = [
      'TAXA', 'TAX', 'VAT', 'IVA', 'BASE IMP', 'VAL.TOTAL', 'VAL.IVA',
      'IMPOSTO', 'TRIBUTAÇÃO', 'ALIQUOTA'
    ];

    for (final taxKeyword in taxSectionKeywords) {
      if (upperLine.contains(taxKeyword) && !upperLine.contains('TOTAL')) {
        print('🔍 DEBUG: Rejecting amount $amount due to tax section context: "$taxKeyword" in line: "$line"');
        return false;
      }
    }
    
    // Check for invalid contexts (but allow valid total contexts)
    for (final context in invalidContexts) {
      if (upperLine.contains(context)) {
        print('🔍 DEBUG: Rejecting amount $amount due to invalid context: "$context" in line: "$line"');
        return false;
      }
    }
    
    // Special handling for RECEIPT context - allow valid total contexts, reject invalid ones
    if (upperLine.contains('RECEIPT')) {
      // Allow these valid total contexts (including concatenated versions)
      final validReceiptContexts = [
        'RECEIPT TOTAL', 'RECEIPT AMOUNT', 'RECEIPT DUE', 'RECEIPT BALANCE',
        'TOTAL RECEIPT', 'AMOUNT RECEIPT', 'DUE RECEIPT', 'BALANCE RECEIPT',
        // Handle concatenated versions (common OCR issue)
        'RECEIPTTOTAL', 'RECEIPTAMOUNT', 'RECEIPTDUE', 'RECEIPTBALANCE',
        'TOTALRECEIPT', 'AMOUNTRECEIPT', 'DUERECEIPT', 'BALANCERECEIPT',
        // Handle with underscores or other separators
        'RECEIPT_TOTAL', 'RECEIPT_AMOUNT', 'RECEIPT_DUE', 'RECEIPT_BALANCE',
        'TOTAL_RECEIPT', 'AMOUNT_RECEIPT', 'DUE_RECEIPT', 'BALANCE_RECEIPT'
      ];
      
      bool isValidReceiptContext = false;
      for (final validContext in validReceiptContexts) {
        if (upperLine.contains(validContext)) {
          isValidReceiptContext = true;
          print('🔍 DEBUG: Allowing amount $amount due to valid receipt context: "$validContext" in line: "$line"');
          break;
        }
      }
      
      // If it's not a valid receipt context, reject it
      if (!isValidReceiptContext) {
        print('🔍 DEBUG: Rejecting amount $amount due to invalid receipt context in line: "$line"');
        return false;
      }
    }
    
    // Reasonable amount checks
    if (amount < 0.01) return false; // Too small
    if (amount.toString().length > 10) return false; // Too many digits
    
    // FIX: Reject obviously partial matches
    // If the line contains a larger amount, reject smaller amounts that might be partial matches
    final allNumbers = RegExp(r'\d+\.?\d*').allMatches(line).map((m) => double.tryParse(m.group(0)!) ?? 0).toList();
    if (allNumbers.length > 1) {
      final maxAmount = allNumbers.reduce((a, b) => a > b ? a : b);
      // If this amount is significantly smaller than the max amount in the line, it might be a partial match
      if (amount < maxAmount * 0.1 && amount < 100) {
        print('🔍 DEBUG: Rejecting potential partial match: $amount (max in line: $maxAmount)');
        return false;
      }
    }
    
    // FIX: Additional check for decimal partial matches
    // If the line contains a decimal amount and this amount matches the decimal part, reject it
    final decimalMatches = RegExp(r'\d+\.(\d{2})').allMatches(line);
    for (final match in decimalMatches) {
      final decimalPart = match.group(1)!;
      final decimalValue = double.tryParse(decimalPart);
      if (decimalValue != null && amount == decimalValue) {
        print('🔍 DEBUG: Rejecting decimal partial match: $amount (decimal part of larger amount)');
        return false;
      }
    }
    
    // FIX: Reject amounts that are clearly decimal parts of larger amounts
    // Check if this amount appears as a decimal part in the line
    final fullDecimalPattern = RegExp(r'\$?(\d+)\.(\d{2})');
    final fullMatches = fullDecimalPattern.allMatches(line);
    for (final match in fullMatches) {
      final wholePart = double.tryParse(match.group(1)!) ?? 0;
      final decimalPart = double.tryParse(match.group(2)!) ?? 0;
      final fullAmount = wholePart + (decimalPart / 100);
      
      // If this amount equals the decimal part and there's a larger full amount, reject it
      if (amount == decimalPart && fullAmount > amount) {
        print('🔍 DEBUG: Rejecting decimal part match: $amount (part of $fullAmount)');
        return false;
      }
    }
    
    // FIX: Additional check - if line contains a decimal amount, reject any amount that's just the decimal part
    final hasDecimalAmount = RegExp(r'\d+\.\d{2}').hasMatch(line);
    if (hasDecimalAmount) {
      // Extract all decimal amounts from the line
      final decimalAmounts = RegExp(r'(\d+\.\d{2})').allMatches(line)
          .map((m) => double.tryParse(m.group(1)!) ?? 0)
          .toList();
      
      // If this amount is less than 100 and there's a decimal amount in the line, 
      // check if this amount could be a decimal part
      if (amount < 100 && decimalAmounts.isNotEmpty) {
        for (final decimalAmount in decimalAmounts) {
          final decimalPart = (decimalAmount * 100) % 100;
          if (amount == decimalPart && decimalAmount > amount) {
            print('🔍 DEBUG: Rejecting potential decimal part: $amount (could be part of $decimalAmount)');
            return false;
          }
        }
      }
    }
    
    return true;
  }

  // Calculate position-based confidence score
  double _calculatePositionScore(int lineIndex, int totalLines) {
    final fromBottom = totalLines - lineIndex;
    
    // Higher score for lines near the bottom
    if (fromBottom <= 3) return 3.0; // Last 3 lines
    if (fromBottom <= 5) return 2.0; // Lines 4-5 from bottom
    if (fromBottom <= 10) return 1.0; // Lines 6-10 from bottom
    return 0.0;
  }

  // Calculate amount size confidence score (larger amounts more likely to be totals)
  double _calculateAmountSizeScore(double amount) {
    // Give EXTREMELY high confidence to larger amounts (more likely to be totals)
    // This is a general real-world rule: totals are usually larger than individual items
    if (amount >= 100) return 15.0;     // Very large amounts (very likely total)
    if (amount >= 50) return 12.0;      // Large amounts (likely total)
    if (amount >= 20) return 8.0;       // Medium-large amounts (could be total)
    if (amount >= 10) return 4.0;       // Medium amounts (less likely total)
    if (amount >= 5) return 2.0;        // Small-medium amounts (unlikely total)
    return 0.0;                         // Small amounts (very unlikely total)
  }

  // Calculate visual formatting confidence score (bold, larger, prominent amounts)
  double _calculateVisualFormatScore(String line, double amount) {
    double score = 0.0;
    final upperLine = line.toUpperCase();
    
    // Check for visual prominence indicators (OCR often doesn't preserve bold, so look for other clues)
    if (RegExp(r'[*]{2,}').hasMatch(line)) score += 5.0; // Bold markers
    if (RegExp(r'[_]{2,}').hasMatch(line)) score += 4.0; // Underline markers
    if (RegExp(r'[=]{2,}').hasMatch(line)) score += 4.0; // Double line markers
    if (RegExp(r'[-]{3,}').hasMatch(line)) score += 3.0; // Dashed line markers
    
    // Check for spacing that indicates prominence
    if (RegExp(r'\s{5,}').hasMatch(line)) score += 2.0; // Large spacing
    if (RegExp(r'\s{3,}').hasMatch(line)) score += 1.0; // Medium spacing
    
    // Check for currency symbols that indicate prominence
    if (line.contains('CHF') || line.contains('EUR') || line.contains('USD') || line.contains(r'$')) {
      score += 2.0;
    }
    
    // Check for total keywords that indicate prominence
    if (upperLine.contains('TOTAL') || upperLine.contains('AMOUNT') || upperLine.contains('DUE')) {
      score += 3.0;
    }
    
    // Check for colon formatting (common in totals: "Total: 54.50")
    if (line.contains(':') && RegExp(r'\d+\.\d{2}').hasMatch(line)) {
      score += 2.0;
    }
    
    // Check for line position (totals are usually near the end)
    // This will be calculated separately, but we can give bonus for being in bottom section
    
    // Give MASSIVE extra score for amounts that are significantly larger than typical item prices
    if (amount >= 50) score += 5.0;  // Large amounts get huge visual prominence bonus
    if (amount >= 100) score += 8.0; // Very large amounts get even more
    
    // Check for isolated amounts (just the number, no other text) - often indicates prominence
    final cleanLine = line.trim();
    if (RegExp(r'^\d+[.,]\d{2}$').hasMatch(cleanLine)) {
      score += 3.0; // Isolated amount gets prominence bonus
    }
    
    // Check for amounts at the end of lines (common for totals)
    if (RegExp(r'\d+[.,]\d{2}\s*$').hasMatch(line)) {
      score += 1.0;
    }
    
    return score;
  }

  // Calculate context-based confidence score (exclude footer text, policy text, etc.)
  double _calculateContextScore(String line, int lineIndex, int totalLines, double amount) {
    double score = 0.0;
    final upperLine = line.toUpperCase();
    
    // PENALIZE footer text and policy text (common sources of false positives)
    final footerKeywords = [
      'OBRIGADO', 'THANK', 'VISIT', 'RETURN', 'POLICY', 'DEVOLUÇÃO', 'TALÃO',
      'RECEIPT', 'RECIBO', 'COMPROVANTE', 'CHANGE', 'TROCO', 'DINHEIRO', 'CASH',
      'CARD', 'CARTÃO', 'DEBIT', 'CREDIT', 'TRANSACTION', 'TRANSACÇÃO'
    ];
    
    for (final keyword in footerKeywords) {
      if (upperLine.contains(keyword)) {
        score -= 10.0; // Heavy penalty for footer text
        print('🔍 DEBUG: Penalizing footer text: "$line" (contains: $keyword)');
        break;
      }
    }
    
    // PENALIZE lines that are clearly not totals
    if (upperLine.contains('DIAS') || upperLine.contains('DAYS') || 
        upperLine.contains('ARTIGOS') || upperLine.contains('ITEMS') ||
        upperLine.contains('ALIMENTARES') || upperLine.contains('FOOD')) {
      score -= 8.0; // Penalty for policy text
      print('🔍 DEBUG: Penalizing policy text: "$line"');
    }
    
    // BONUS for lines that look like totals
    if (upperLine.contains('TOTAL') && RegExp(r'\d+[.,]\d{2}').hasMatch(line)) {
      score += 5.0; // Bonus for explicit total lines
      print('🔍 DEBUG: Bonus for total line: "$line"');
    }
    
    // BONUS for lines near the end but not in the very last lines (footer)
    final fromBottom = totalLines - lineIndex;
    if (fromBottom >= 3 && fromBottom <= 8) { // Sweet spot for totals
      score += 2.0;
    } else if (fromBottom <= 2) { // Very last lines are often footer
      score -= 3.0;
    }
    
    // BONUS for lines with reasonable total amounts (not too small, not too large)
    if (amount >= 5.0 && amount <= 200.0) {
      score += 1.0;
    }
    
    return score;
  }

  // Calculate format-based confidence score
  double _calculateFormatScore(String line) {
    double score = 0.0;
    
    // Currency symbol present
    if (_detectCurrencyInLine(line) != null) {
      score += 2.0;
    }
    
    // Well-formatted with spacing (label and amount separated)
    if (RegExp(r'\s{3,}').hasMatch(line)) {
      score += 1.0;
    }
    
    // Contains decimal places
    if (RegExp(r'\d+\.\d{2}\b').hasMatch(line)) {
      score += 0.5;
    }
    
    // Clear separation between text and numbers
    if (RegExp(r'[A-Za-z]\s+[\d\$€£¥]').hasMatch(line)) {
      score += 0.5;
    }
    
    return score;
  }


  // Enhanced currency detection with context awareness
  String? _detectCurrencyInLine(String line) {
    final upperLine = line.toUpperCase();
    
    // Check each currency pattern
    for (final currency in _currencyPatterns.keys) {
      for (final pattern in _currencyPatterns[currency]!) {
        if (line.contains(pattern) || upperLine.contains(pattern.toUpperCase())) {
          return currency;
        }
      }
    }
    
    return null;
  }

  // Check if number should be excluded based on context
  bool _shouldExcludeNumber(String line, int start, int end) {
    final before = start > 0 ? line.substring(0, start) : '';
    final after = end < line.length ? line.substring(end) : '';
    final context = '$before|${line.substring(start, end)}|$after'.toUpperCase();
    
    for (final pattern in _excludePatterns) {
      if (pattern.hasMatch(context)) {
        return true;
      }
    }
    
    return false;
  }

  // Get bottom section of receipt
  List<String> _getBottomSection(List<String> lines, int count) {
    final start = (lines.length - count).clamp(0, lines.length);
    return lines.sublist(start);
  }


  // Select the best candidate based on confidence and validation
  // AmountMatch? _selectBestCandidate(List<AmountMatch> candidates, List<String> lines) {
  //   if (candidates.isEmpty) {
  //     print('🔍 ENHANCED: No candidates found');
  //     return null;
  //   }
    
  //   print('🔍 ENHANCED: Evaluating ${candidates.length} candidates');
    
  //   // DEBUG: Log ALL candidates with full details
  //   print('🔍 DEBUG: ALL CANDIDATES BEFORE SORTING:');
  //   for (var i = 0; i < candidates.length; i++) {
  //     final candidate = candidates[i];
  //     print('  Candidate $i: amount=${candidate.amount}, confidence=${candidate.confidence}, method=${candidate.detectionMethod}, line=${candidate.lineIndex}, text="${candidate.originalText}"');
  //   }
    
  //   // Sort by confidence (highest first)
  //   candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    
  //   // Log top candidates
  //   for (var i = 0; i < candidates.length && i < 5; i++) {
  //     print('🔍 ENHANCED: Candidate ${i + 1}: ${candidates[i]}');
  //   }
    
  //   // Additional validation for top candidate
  //   final best = candidates.first;
    
  //   // Sanity check: if the best candidate is much smaller than others,
  //   // it might be wrong (e.g., tax vs total)
  //   if (candidates.length > 1) {
  //     final second = candidates[1];
  //     if (best.amount < second.amount * 0.5 && 
  //         second.confidence > best.confidence * 0.7) {
  //       print('🔍 ENHANCED: Switching to second candidate due to amount comparison');
  //       return second;
  //     }
  //   }
    
  //   print('🔍 ENHANCED: Selected best candidate: $best');
  //   return best;
  // }


AmountMatch? _selectBestCandidate(List<AmountMatch> candidates, List<String> lines) {
  if (candidates.isEmpty) {
    print('🔍 ENHANCED: No candidates found');
    return null;
  }
  
  print('🔍 ENHANCED: Evaluating ${candidates.length} candidates');
  
  // DEBUG: Log ALL candidates with full details
  print('🔍 DEBUG: ALL CANDIDATES BEFORE SORTING:');
  for (var i = 0; i < candidates.length; i++) {
    final candidate = candidates[i];
    print('  Candidate $i: amount=${candidate.amount}, confidence=${candidate.confidence}, method=${candidate.detectionMethod}, line=${candidate.lineIndex}, text="${candidate.originalText}"');
  }

  final receiptTotalCandidates = candidates.where((candidate) => 
      candidate.detectionMethod.contains('RECEIPT_TOTAL') || 
      candidate.detectionMethod.contains('RECEIPT TOTAL') ||
      candidate.detectionMethod.contains('explicit_total_RECEIPT TOTAL')).toList();

  if (receiptTotalCandidates.isNotEmpty) {
    print('🔍 ENHANCED: Found RECEIPT TOTAL candidates, prioritizing...');
    receiptTotalCandidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    final bestReceiptTotal = receiptTotalCandidates.first;
    print('🔍 ENHANCED: Selected RECEIPT TOTAL candidate: $bestReceiptTotal');
    return bestReceiptTotal;
  }
  
  // Sort by confidence (highest first)
  candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
  
  // Log top candidates
  for (var i = 0; i < candidates.length && i < 3; i++) {
    print('🔍 ENHANCED: Candidate ${i + 1}: ${candidates[i]}');
  }
  
  final best = candidates.first;
  
  // Additional validation: if best candidate is from explicit total keywords, trust it
  if (best.detectionMethod.startsWith('explicit_total')) {
    print('🔍 ENHANCED: Using explicit total: $best');
    return best;
  }
  
  // FIX: ULTRA-AGGRESSIVE logic for selecting the best total
  // ALWAYS prefer larger amounts over smaller ones (real-world rule: totals are larger)
  if (candidates.length > 1) {
    // Sort all candidates by amount size (largest first)
    candidates.sort((a, b) => b.amount.compareTo(a.amount));
    final largestCandidate = candidates.first;
    
    print('🔍 DEBUG: Largest amount found: ${largestCandidate.amount} with confidence: ${largestCandidate.confidence}');
    
    // If the largest amount is significantly larger than others, ALWAYS pick it
    if (candidates.length > 1) {
      final secondLargest = candidates[1].amount;
      if (largestCandidate.amount > secondLargest * 1.1) { // Very low threshold - any significant difference
        print('🔍 ENHANCED: Selected significantly larger amount: ${largestCandidate.amount} vs ${secondLargest}');
        return largestCandidate;
      }
    }
    
    // If largest amount is reasonable (>= 10), prefer it even if confidence is lower
    if (largestCandidate.amount >= 10.0) {
      // Check if it's not an obvious item line
      final line = lines[largestCandidate.lineIndex];
      if (!_isObviousItemLine(line)) {
        print('🔍 ENHANCED: Selected largest reasonable amount (not item): $largestCandidate');
        return largestCandidate;
      }
    }
    
    // Find candidates with high confidence (within 10.0 of the best) - very lenient
    final bestConfidence = best.confidence;
    final highConfidenceCandidates = candidates.where((c) => 
        (bestConfidence - c.confidence) <= 10.0).toList();
    
    print('🔍 DEBUG: High confidence candidates (within 10.0 of best): ${highConfidenceCandidates.length}');
    
    if (highConfidenceCandidates.length > 1) {
      // Among high confidence candidates, prefer larger amounts
      highConfidenceCandidates.sort((a, b) => b.amount.compareTo(a.amount));
      final largestHighConfidence = highConfidenceCandidates.first;
      
      print('🔍 ENHANCED: Selected largest among high confidence: $largestHighConfidence');
      return largestHighConfidence;
    }
    
    // Fallback: prefer the one that's not an obvious item amount
    for (final candidate in candidates) {
      final line = lines[candidate.lineIndex];
      if (!_isObviousItemLine(line) && candidate.confidence > 2.0) { // Very low threshold
        print('🔍 ENHANCED: Selected non-item candidate: $candidate');
        return candidate;
      }
    }
    
    // Last resort: just pick the largest amount if it's reasonable
    if (largestCandidate.amount >= 5.0) { // Lower threshold
      print('🔍 ENHANCED: Last resort - selected largest amount: $largestCandidate');
      return largestCandidate;
    }
  }
  
  print('🔍 ENHANCED: Selected best candidate: $best');
  return best;
}


  // Enhanced date detection with better parsing
  DateTime? findFirstDate(String text) {
  print('🔍 ENHANCED: Starting date detection in text: "${text.substring(0, text.length > 100 ? 100 : text.length)}..."');
  
  for (int i = 0; i < _dateRegexes.length; i++) {
    final pattern = _dateRegexes[i];
    final match = pattern.firstMatch(text);
    if (match != null) {
      // For labeled dates, extract the actual date part
      final dateStr = match.groupCount > 0 ? match.group(1)! : match.group(0)!;
      print('🔍 ENHANCED: Found date match with pattern $i: "$dateStr"');
      
      final date = _tryParseDate(dateStr);
      if (date != null && _isReasonableDate(date)) {
        print('🔍 ENHANCED: Successfully parsed date: $date');
        return date;
      } else {
        print('🔍 ENHANCED: Failed to parse or unreasonable date: "$dateStr"');
      }
    }
  }
  
  print('🔍 ENHANCED: No date found');
  return null;
}

  // Enhanced date parsing with more formats
  DateTime? _tryParseDate(String s) {
  print('🔍 ENHANCED: Trying to parse date: "$s"');
  
  // Handle month names first
  if (RegExp(r'[A-Za-z]').hasMatch(s)) {
    final monthFormats = [
      'MMMM d, yyyy',  // April 5, 2024
      'MMM d, yyyy',   // Apr 5, 2024
      'd MMMM yyyy',   // 5 April 2024
      'd MMM yyyy',    // 5 Apr 2024
      'MMMM d yyyy',   // April 5 2024 (no comma)
      'MMM d yyyy',    // Apr 5 2024 (no comma)
    ];
    
    for (final format in monthFormats) {
      try {
        final dateFormat = DateFormat(format);
        final parsed = dateFormat.parseLoose(s);
        print('🔍 ENHANCED: Successfully parsed "$s" with format "$format": $parsed');
        return parsed;
      } catch (e) {
        // Continue to next format
      }
    }
  }
  
  // Handle numeric formats
  final numericFormats = [
    'dd/MM/yyyy', 'dd.MM.yyyy', 'dd-MM-yyyy',
    'MM/dd/yyyy', 'MM.dd.yyyy', 'MM-dd-yyyy',
    'yyyy-MM-dd', 'yyyy/MM/dd', 'yyyy.MM.dd',
    'd/M/yyyy', 'd.M.yyyy', 'd-M-yyyy',
    'M/d/yyyy', 'M.d.yyyy', 'M-d-yyyy',
    'dd/MM/yy', 'MM/dd/yy', 'yy-MM-dd',
  ];
  
  for (final format in numericFormats) {
    try {
      final dateFormat = DateFormat(format);
      final parsed = dateFormat.parseLoose(s);
      print('🔍 ENHANCED: Successfully parsed "$s" with format "$format": $parsed');
      return parsed;
    } catch (e) {
      // Continue to next format
    }
  }
  
  // Fallback: try generic parsing
  try {
    final normalized = s.replaceAll('.', '-').replaceAll('/', '-');
    final parsed = DateTime.parse(normalized);
    print('🔍 ENHANCED: Successfully parsed "$s" with fallback parsing: $parsed');
    return parsed;
  } catch (e) {
    print('🔍 ENHANCED: All parsing attempts failed for "$s"');
    return null;
  }
}

  // Validate date is reasonable for a receipt
  bool _isReasonableDate(DateTime date) {
    final now = DateTime.now();
    final future = now.add(const Duration(days: 30));
    final past = now.subtract(const Duration(days: 365 * 10)); // 10 years ago
    
    return date.isAfter(past) && date.isBefore(future);
  }

  // Enhanced category inference
  String? inferCategoryFromText(String text) {
    final upperText = text.toUpperCase();
    
    final categories = {
      'Transport': ['FUEL', 'GAS', 'GASOLINE', 'PETROL', 'DIESEL', 'SHELL', 'BP', 'EXXON', 'CHEVRON', 'TAXI', 'UBER', 'LYFT', 'PARKING'],
      'Groceries': ['GROCERY', 'SUPERMARKET', 'MARKET', 'WALMART', 'TARGET', 'COSTCO', 'WHOLE FOODS', 'KROGER', 'SAFEWAY'],
      'Food & Dining': ['RESTAURANT', 'CAFE', 'COFFEE', 'PIZZA', 'BAR', 'DINER', 'MCDONALD', 'BURGER', 'STARBUCKS', 'SUBWAY'],
      'Pharmacy': ['PHARMACY', 'DRUG', 'CVS', 'WALGREENS', 'RITE AID', 'MEDICINE', 'PRESCRIPTION'],
      'Retail': ['STORE', 'SHOP', 'AMAZON', 'EBAY', 'BEST BUY', 'HOME DEPOT', 'LOWES'],
      'Entertainment': ['MOVIE', 'CINEMA', 'THEATER', 'NETFLIX', 'SPOTIFY', 'GAME'],
      'Utilities': ['ELECTRIC', 'GAS COMPANY', 'WATER', 'INTERNET', 'PHONE', 'CABLE'],
      'Healthcare': ['HOSPITAL', 'DOCTOR', 'MEDICAL', 'DENTAL', 'CLINIC'],
    };
    
    for (final category in categories.keys) {
      for (final keyword in categories[category]!) {
        if (upperText.contains(keyword)) {
          return category;
        }
      }
    }
    
    return null;
  }

  // Find specific amounts (like tax, subtotal) with enhanced detection
  double? findAmountForLabel(List<String> lines, List<String> labels) {
    print('🔍 ENHANCED: Looking for labels: $labels');
    
    for (var i = 0; i < lines.length; i++) {
      final upperLine = lines[i].toUpperCase();
      
      for (final label in labels) {
        if (upperLine.contains(label.toUpperCase())) {
          print('🔍 ENHANCED: Found label "$label" in line $i: "${lines[i]}"');
          
          // Try same line first
          final sameLine = _extractAmountsFromLine(lines[i], i, 'label_$label');
          if (sameLine.isNotEmpty) {
            return sameLine.first.amount;
          }
          
          // Try adjacent lines
          for (final offset in [1, -1, 2, -2]) {
            final adjacentIndex = i + offset;
            if (adjacentIndex >= 0 && adjacentIndex < lines.length) {
              final adjacentCandidates = _extractAmountsFromLine(lines[adjacentIndex], adjacentIndex, 'label_adjacent');
              if (adjacentCandidates.isNotEmpty) {
                return adjacentCandidates.first.amount;
              }
            }
          }
        }
      }
    }
    
    return null;
  }

  // Get currency symbol from code
  String? getCurrencySymbol(String currencyCode) {
    final patterns = _currencyPatterns[currencyCode.toUpperCase()];
    return patterns?.first;
  }

  // Comprehensive currency detection with context
  String? detectCurrency(String text) {
    print('🔍 ENHANCED: Starting comprehensive currency detection');
    
    // Try line-by-line detection first for better context
    final lines = text.split('\n');
    for (final line in lines) {
      final currency = _detectCurrencyInLine(line);
      if (currency != null && line.contains(RegExp(r'\d'))) {
        print('🔍 ENHANCED: Found currency $currency in line with numbers');
        return currency;
      }
    }
    
    // Fallback to full text detection
    return _detectCurrencyInLine(text);
  }
}
bool _isPartialNumber(String numberText, String fullLine) {
  // Check if this number appears to be part of a larger decimal number
  final numberIndex = fullLine.indexOf(numberText);
  if (numberIndex == -1) return false;
  
  final beforeChar = numberIndex > 0 ? fullLine[numberIndex - 1] : '';
  final afterIndex = numberIndex + numberText.length;
  final afterChar = afterIndex < fullLine.length ? fullLine[afterIndex] : '';
  
  // Only consider it partial if it's clearly part of a larger number
  // Check if it's part of a decimal number (but be more specific)
  if (beforeChar == ',' || beforeChar == '.') {
    // Check if this is a thousands separator (like 1,234.56)
    if (beforeChar == ',' && numberText.length <= 3) {
      return true; // Part of thousands separator
    }
    // Check if this is a decimal part (like 123.45 where we found "45")
    if (beforeChar == '.' && numberText.length <= 2) {
      return true; // Part of decimal
    }
  }
  
  if (afterChar == ',' || afterChar == '.') {
    // Check if this is a thousands separator (like 1,234.56)
    if (afterChar == ',' && numberText.length <= 3) {
      return true; // Part of thousands separator
    }
    // Check if this is a decimal part (like 123.45 where we found "123")
    if (afterChar == '.' && numberText.length <= 3) {
      return true; // Part of decimal
    }
  }
  
  // Check if there's a decimal number in the same line that contains this
  // But only if the number is small (likely a partial)
  if (numberText.length <= 2) {
    final decimalPattern = RegExp(r'\d+[,.]\d+');
    final decimalMatches = decimalPattern.allMatches(fullLine);
    
    for (final match in decimalMatches) {
      final decimalText = match.group(0)!;
      if (decimalText.contains(numberText) && decimalText != numberText) {
        return true; // This small number is part of a larger decimal
      }
    }
  }
  
  return false;
}