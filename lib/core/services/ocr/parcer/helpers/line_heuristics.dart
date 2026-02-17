// lib/services/ocr/parser/helpers/line_heuristics.dart
import '../../i_ocr_service.dart';
import 'chain_database.dart';
import 'vendor_confidence_validator.dart';

class LineHeuristics {
  /// Enhanced vendor detection with confidence scoring (PHASE 1 IMPROVEMENT)
  VendorResult? detectMerchantWithConfidence(List<String> lines) {
    print('🔍 ENHANCED: Starting Phase 1 enhanced vendor detection with confidence scoring');
    return VendorConfidenceValidator.detectVendorWithConfidence(lines);
  }

  /// Enhanced vendor detection using hybrid approach (chain database + heuristic fallback)
  String? detectMerchant(List<String> lines) {
    print('🔍 MAGIC VENDOR: Starting hybrid vendor detection with ${lines.length} lines');
    
    if (lines.isEmpty) {
      print('🔍 MAGIC VENDOR: No lines to process');
      return null;
    }
    
    // ENHANCED: Pre-process lines to handle OCR concatenation issues
    final processedLines = _preprocessOcrLines(lines);
    print('🔍 MAGIC VENDOR: Processed ${processedLines.length} lines from ${lines.length} original lines');
    
    // Strategy 1: Chain database lookup (fastest and most accurate)
    final chainVendor = ChainDatabase.detectVendor(processedLines);
    if (chainVendor != null) {
      final normalized = ChainDatabase.normalizeVendorName(chainVendor);
      print('🔍 MAGIC VENDOR: Chain database detection found: "$chainVendor" -> normalized: "$normalized"');
      return normalized;
    }
    
    // Strategy 2: Position-based detection (prioritizes top lines, larger text)
    print('🔍 MAGIC VENDOR: Trying position-based detection...');
    final positionBasedVendor = _detectVendorByPosition(processedLines);
    if (positionBasedVendor != null) {
      final formattedVendor = _formatVendorName(positionBasedVendor, processedLines);
      final normalized = ChainDatabase.normalizeVendorName(formattedVendor);
      print('🔍 MAGIC VENDOR: Position-based detection found: "$positionBasedVendor" -> formatted: "$formattedVendor" -> normalized: "$normalized"');
      return normalized;
    } else {
      print('🔍 MAGIC VENDOR: Position-based detection returned null');
    }
    
    // Strategy 3: Traditional multi-line detection
    final multiLineVendor = _detectVendorByMultiLine(processedLines);
    if (multiLineVendor != null) {
      final formattedVendor = _formatVendorName(multiLineVendor, processedLines);
      final normalized = ChainDatabase.normalizeVendorName(formattedVendor);
      print('🔍 MAGIC VENDOR: Multi-line detection found: "$multiLineVendor" -> formatted: "$formattedVendor" -> normalized: "$normalized"');
      return normalized;
    }
    
    // Strategy 4: Traditional single-line detection
    final singleLineVendor = _detectVendorBySingleLine(processedLines);
    if (singleLineVendor != null) {
      final formattedVendor = _formatVendorName(singleLineVendor, processedLines);
      final normalized = ChainDatabase.normalizeVendorName(formattedVendor);
      print('🔍 MAGIC VENDOR: Single-line detection found: "$singleLineVendor" -> formatted: "$formattedVendor" -> normalized: "$normalized"');
      return normalized;
    }
    
    print('🔍 MAGIC VENDOR: No vendor detected with any method');
    return null;
  }
  
  /// Position-based vendor detection (prioritizes top lines, larger text)
  String? _detectVendorByPosition(List<String> lines) {
    print('🔍 MAGIC VENDOR: Starting position-based detection');
    
    // Focus on top 6 lines for position-based detection
    final topLines = lines.take(6).toList();
    print('🔍 MAGIC VENDOR: Analyzing top ${topLines.length} lines for position-based detection');
    
    String? bestVendor;
    double bestScore = 0.0;
    
    for (int i = 0; i < topLines.length; i++) {
      final line = topLines[i].trim();
      if (line.isEmpty) continue;
      
      print('🔍 MAGIC VENDOR: Position analysis - line $i: "$line"');
      
      // NEW: Try to extract clean vendor name from concatenated lines
      final cleanVendorName = _extractCleanVendorName(line);
      if (cleanVendorName != null) {
        print('🔍 MAGIC VENDOR: Extracted clean vendor name: "$cleanVendorName"');
        
        // Skip if the clean name is still not a merchant name
        if (_isNotMerchantName(cleanVendorName)) {
          print('🔍 MAGIC VENDOR: Clean vendor name still filtered out: "$cleanVendorName"');
          continue;
        }
        
        // Enhanced scoring for position-based detection
        final score = _calculatePositionBasedVendorScore(cleanVendorName, i, topLines.length);
        print('🔍 MAGIC VENDOR: Position-based score for clean vendor name: $score');
        
        if (score > bestScore) {
          bestScore = score;
          bestVendor = cleanVendorName;
          print('🔍 MAGIC VENDOR: New best position-based vendor: "$cleanVendorName" (score: $score)');
        }
      } else {
        print('🔍 MAGIC VENDOR: No clean vendor name extracted from line $i: "$line"');
        
        // FALLBACK: Try a simple extraction for concatenated lines
        final simpleExtraction = _simpleVendorExtraction(line);
        if (simpleExtraction != null) {
          print('🔍 MAGIC VENDOR: Simple extraction found: "$simpleExtraction"');
          
          // Skip if the simple extraction is still not a merchant name
          if (_isNotMerchantName(simpleExtraction)) {
            print('🔍 MAGIC VENDOR: Simple extraction still filtered out: "$simpleExtraction"');
          } else {
            // Enhanced scoring for position-based detection
            final score = _calculatePositionBasedVendorScore(simpleExtraction, i, topLines.length);
            print('🔍 MAGIC VENDOR: Position-based score for simple extraction: $score');
            
            if (score > bestScore) {
              bestScore = score;
              bestVendor = simpleExtraction;
              print('🔍 MAGIC VENDOR: New best position-based vendor: "$simpleExtraction" (score: $score)');
            }
          }
        } else {
          // Skip lines that are clearly not vendor names
          if (_isNotMerchantName(line)) {
            print('🔍 MAGIC VENDOR: Skipping line $i (filtered out)');
            continue;
          }
          
          // Enhanced scoring for position-based detection
          final score = _calculatePositionBasedVendorScore(line, i, topLines.length);
          print('🔍 MAGIC VENDOR: Position-based score for line $i: $score');
          
          if (score > bestScore) {
            bestScore = score;
            bestVendor = line;
            print('🔍 MAGIC VENDOR: New best position-based vendor: "$line" (score: $score)');
          }
        }
      }
    }
    
    // ENHANCED: Dynamic threshold based on score quality
    double threshold = 0.3; // Base threshold
    
    // Increase threshold if we have multiple candidates
    if (bestVendor != null) {
      // Check if this looks like a proper business name
      if (_looksLikeProperBusinessName(bestVendor)) {
        threshold = 0.2; // Lower threshold for proper business names
        print('🔍 MAGIC VENDOR: Lowered threshold to $threshold for proper business name');
      } else {
        threshold = 0.5; // Higher threshold for questionable names
        print('🔍 MAGIC VENDOR: Raised threshold to $threshold for questionable name');
      }
    }
    
    if (bestVendor != null && bestScore > threshold) {
      print('🔍 MAGIC VENDOR: Position-based vendor detected: "$bestVendor" (score: $bestScore, threshold: $threshold)');
      return bestVendor;
    } else if (bestVendor != null) {
      print('🔍 MAGIC VENDOR: Best vendor "$bestVendor" failed threshold (score: $bestScore, threshold: $threshold)');
    }
    
    print('🔍 MAGIC VENDOR: No position-based vendor detected (best score: $bestScore)');
    return null;
  }
  
  /// Multi-line vendor detection (existing logic)
  String? _detectVendorByMultiLine(List<String> lines) {
  print('🔍 MAGIC VENDOR: Starting multi-line detection');
  
  final topLines = lines.take(5).toList();
  print('🔍 MAGIC VENDOR: Processing top ${topLines.length} lines for multi-line detection');
  
  for (int i = 0; i < topLines.length - 1; i++) {
    final line1 = topLines[i].trim();
    final line2 = topLines[i + 1].trim();
    
    if (line1.isEmpty || line2.isEmpty) continue;
    
    // Skip if either line contains menu items, quantities, or prices
    if (_containsMenuItems(line1) || _containsMenuItems(line2)) {
      print('🔍 MAGIC VENDOR: Skipping lines $i+${i+1} - contains menu items');
      continue;
    }
    
    // NEW: Skip if second line looks like date, address, or phone
    if (_isDateAddressOrPhone(line2)) {
      print('🔍 MAGIC VENDOR: Skipping lines $i+${i+1} - second line is date/address/phone');
      continue;
    }
    
    // NEW: Only combine if both lines look like business name parts
    if (_looksLikeBusinessNamePart(line1) && _looksLikeBusinessNamePart(line2)) {
      final combined = '$line1 $line2';
      print('🔍 MAGIC VENDOR: Checking combined business name lines $i+${i+1}: "$combined"');
      
      double score = _scoreName(combined);
      
      // ENHANCED: First line combination gets higher priority
      if (i == 0) {
        score += 0.2; // 20% bonus for first line combination
        print('🔍 MAGIC VENDOR: First line combination bonus: +0.2 (total: $score)');
      }
      
      print('🔍 MAGIC VENDOR: Combined lines score: $score');
      
      // ENHANCED: More flexible threshold for unknown vendors
      if (score > 0.3) {
        print('🔍 MAGIC VENDOR: Combined lines passed threshold! Returning: "$combined"');
        return combined;
      }
    }
  }
  
  return null;
}

// Add these helper methods
bool _isDateAddressOrPhone(String line) {
  // Date patterns
  if (RegExp(r'\b(?:DATE|TIME):', caseSensitive: false).hasMatch(line)) return true;
  if (RegExp(r'\d{1,2}[./]\d{1,2}[./]\d{2,4}').hasMatch(line)) return true;
  if (RegExp(r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)', caseSensitive: false).hasMatch(line)) return true;
  
  // Address patterns
  if (RegExp(r'\b(?:ST|AVE|BLVD|RD|STREET|AVENUE|BOULEVARD|ROAD)', caseSensitive: false).hasMatch(line)) return true;
  if (RegExp(r'\d{5}').hasMatch(line)) return true; // Zip code
  if (RegExp(r'\b[A-Z]{2}\b').hasMatch(line) && line.contains(',')) return true; // State abbreviation
  
  // Phone patterns
  if (RegExp(r'\b(?:PHONE|TEL|FAX):', caseSensitive: false).hasMatch(line)) return true;
  if (RegExp(r'\(\d{3}\)\s*\d{3}[-.\s]?\d{4}').hasMatch(line)) return true;
  
  return false;
}

bool _looksLikeBusinessNamePart(String line) {
  // Skip obvious non-business parts
  if (_isDateAddressOrPhone(line)) return false;
  if (_containsMenuItems(line)) return false;
  if (RegExp(r'^\d+$').hasMatch(line.trim())) return false; // Pure numbers
  
  // Should be mostly letters
  final letterCount = line.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
  final letterRatio = letterCount / line.length;
  
  return letterRatio > 0.5 && line.length >= 3 && line.length <= 30;
}
  
  /// Single-line vendor detection (existing logic)
  String? _detectVendorBySingleLine(List<String> lines) {
    print('🔍 MAGIC VENDOR: Starting single-line detection');
    
    // Look at the first few lines for the merchant name
    final topLines = lines.take(5).toList();
    print('🔍 MAGIC VENDOR: Processing top ${topLines.length} lines for single-line detection');
    
    // Fallback to single line detection
    for (int i = 0; i < topLines.length; i++) {
      String line = topLines[i];
      final cleanLine = line.trim();
      print('🔍 MAGIC VENDOR: Processing line $i: "$cleanLine"');
      
      if (cleanLine.isEmpty) {
        print('🔍 MAGIC VENDOR: Line $i is empty, skipping');
        continue;
      }
      
      // Skip lines that are clearly not merchant names
      if (_isNotMerchantName(cleanLine)) {
        print('🔍 MAGIC VENDOR: Line $i is not a merchant name, skipping');
        continue;
      }
      
      // Score the line based on merchant name characteristics
      double score = _scoreName(cleanLine);
      
      // ENHANCED: First line gets higher priority
      if (i == 0) {
        score += 0.2; // 20% bonus for first line
        print('🔍 MAGIC VENDOR: First line bonus for "$cleanLine" - +0.2 (total: $score)');
      }
      
      print('🔍 MAGIC VENDOR: Line $i score: $score');
      
      if (score > 0.4) { // Even lower threshold to catch more potential vendors
        print('🔍 MAGIC VENDOR: Line $i passed threshold! Returning: "$cleanLine"');
        return cleanLine;
      } else {
        print('🔍 MAGIC VENDOR: Line $i failed threshold (0.4), score was $score');
      }

    }
    
    print('🔍 MAGIC VENDOR: No suitable vendor found');
    return null;
  }

  bool _isNotMerchantName(String line) {
    if (line.isEmpty) return true;
    
    print('🔍 FILTER: Checking if line is not merchant name: "$line"');
    
    final upper = line.toUpperCase();
    
    // ENHANCED: Filter out receipt system labels and common non-business terms
    final receiptLabels = [
      'STATION', 'TERMINAL', 'REGISTER', 'CASHIER', 'CLERK', 'EMPLOYEE',
      'RECEIPT', 'INVOICE', 'BILL', 'TICKET', 'ORDER', 'TRANSACTION',
      'DATE', 'TIME', 'REF', 'REFERENCE', 'ID', 'NUMBER', 'NO', 'NR',
      'TOTAL', 'SUBTOTAL', 'TAX', 'PAYMENT', 'CASH', 'CARD', 'CHANGE',
      'THANK', 'VISIT', 'AGAIN', 'WELCOME', 'GOODBYE', 'BYE',
      'ITEM', 'ITEMS', 'QUANTITY', 'QTY', 'PRICE', 'AMOUNT',
      'DISCOUNT', 'COUPON', 'PROMO', 'SALE', 'SPECIAL',
      'CUSTOMER', 'GUEST', 'MEMBER', 'VIP', 'LOYALTY'
    ];
    
    // ENHANCED: Filter out common product brand names
    final productBrands = [
      'QUAKER', 'COCA', 'PEPSI', 'NESTLE', 'KRAFT', 'HEINZ', 'CAMPBELL',
      'GENERAL', 'MILLS', 'KELLOGG', 'POST', 'CHEERIOS', 'FROSTED', 'LUCKY',
      'CHARMS', 'HONEY', 'NUT', 'FROOT', 'LOOPS', 'CORN', 'FLAKES',
      'COKE', 'SPRITE', 'FANTA', 'MOUNTAIN', 'DEW', 'GATORADE', 'POWERADE',
      'SNICKERS', 'MARS', 'TWIX', 'MILKY', 'WAY', 'KIT', 'KAT', 'REESES',
      'OREO', 'CHIPS', 'AHOY', 'NUTTER', 'BUTTER', 'GIRL', 'SCOUT',
      'DORITOS', 'CHEETOS', 'FRITOS', 'LAYS', 'PRINGLES', 'RUFFLES'
    ];
    
    for (final label in receiptLabels) {
      if (upper == label || upper.startsWith('$label ') || upper.endsWith(' $label')) {
        print('🔍 FILTER: Filtered out receipt label: "$line" (matched: $label)');
        return true;
      }
    }
    
    // ENHANCED: Filter out product brand names
    for (final brand in productBrands) {
      if (upper == brand || upper.startsWith('$brand ') || upper.endsWith(' $brand') || 
          upper.contains(' $brand ') || upper.startsWith(brand)) {
        print('🔍 FILTER: Filtered out product brand: "$line" (matched: $brand)');
        return true;
      }
    }
    
    // Filter out lines that are just numbers with labels
    if (RegExp(r'^(STATION|TERMINAL|REGISTER|CASHIER|CLERK|EMPLOYEE|REF|REFERENCE|ID|NO|NR)\s*\d+$', caseSensitive: false).hasMatch(line)) {
      print('🔍 FILTER: Filtered out numbered receipt label: "$line"');
      return true;
    }
    
    // Filter out invoice/receipt numbers
    if (upper.contains('RECH.') || upper.contains('RECH NR') || upper.contains('INVOICE NO')) return true;
    if (upper.contains('RECEIPT NO') || upper.contains('RECEIPT #') || upper.contains('INVOICE #')) return true;
    
    // Filter out table/seating info
    if (upper.contains('TISCH') || upper.contains('TABLE') || upper.contains('SEAT')) return true;
    
    // Filter out payment methods
    if (upper.contains('BAR') || upper.contains('CASH') || upper.contains('CREDIT')) return true;
    
    // ENHANCED: Filter out addresses and phone numbers
    if (RegExp(r'^\d{4,5}\s+[A-Z]').hasMatch(upper)) return true; // Swiss postal code pattern
    if (RegExp(r'^\d{4,5}\s+[A-Z][a-z]+$').hasMatch(line)) return true; // Postal code + city name
    
    // NEW: Filter out US addresses (street number + street name)
    if (RegExp(r'\d{2,5}\s+[A-Za-z\s]+(?:Ave|St|Rd|Blvd|Dr|Ln|Way|Pl|Ct)').hasMatch(line)) return true;
    
    // NEW: Filter out phone numbers (various formats)
    if (RegExp(r'\(\d{3}\)\d{3}-\d{4}').hasMatch(line)) {
      print('🔍 FILTER: Filtered out phone number (format 1): "$line"');
      return true; // (718)651-3838
    }
    if (RegExp(r'\(\d{3}\)\s*\d{3}-\d{4}').hasMatch(line)) {
      print('🔍 FILTER: Filtered out phone number (format 2): "$line"');
      return true; // (718) 651-3838
    }
    if (RegExp(r'\d{3}-\d{3}-\d{4}').hasMatch(line)) {
      print('🔍 FILTER: Filtered out phone number (format 3): "$line"');
      return true; // 718-651-3838
    }
    if (RegExp(r'\d{3}\.\d{3}\.\d{4}').hasMatch(line)) {
      print('🔍 FILTER: Filtered out phone number (format 4): "$line"');
      return true; // 718.651.3838
    }
    if (RegExp(r'\d{10}').hasMatch(line.replaceAll(RegExp(r'[^\d]'), ''))) {
      print('🔍 FILTER: Filtered out phone number (format 5): "$line"');
      return true; // 7186513838
    }
    
    // ENHANCED: Filter out any line that is primarily phone numbers
    if (RegExp(r'^\(\d{3}\)\d{3}-\d{4}$').hasMatch(line)) {
      print('🔍 FILTER: Filtered out exact phone number (format 6): "$line"');
      return true; // Exact phone number match
    }
    if (RegExp(r'^\d{3}-\d{3}-\d{4}$').hasMatch(line)) {
      print('🔍 FILTER: Filtered out exact phone number (format 7): "$line"');
      return true; // Exact phone number match
    }
    if (RegExp(r'^\d{3}\.\d{3}\.\d{4}$').hasMatch(line)) {
      print('🔍 FILTER: Filtered out exact phone number (format 8): "$line"');
      return true; // Exact phone number match
    }
    
    // NEW: Filter out ZIP codes (5 digits)
    if (RegExp(r'\b\d{5}\b').hasMatch(line)) return true; // 11373
    
    // NEW: Filter out lines with too many numbers (addresses, phone numbers, etc.)
    final numberCount = RegExp(r'\d').allMatches(line).length;
    final totalChars = line.replaceAll(RegExp(r'\s'), '').length;
    if (totalChars > 0 && (numberCount / totalChars) > 0.3) return true; // More than 30% numbers
    
    // ENHANCED: Filter out lines that are primarily phone numbers or numbers
    if (RegExp(r'^[\(\d\s\-\.\)]+$').hasMatch(line)) {
      print('🔍 FILTER: Filtered out phone number characters only: "$line"');
      return true; // Only contains phone number characters
    }
    if (RegExp(r'^\d+$').hasMatch(line.trim())) {
      print('🔍 FILTER: Filtered out numbers only: "$line"');
      return true; // Only numbers
    }
    if (RegExp(r'^\(\d+\)$').hasMatch(line.trim())) {
      print('🔍 FILTER: Filtered out parentheses with numbers: "$line"');
      return true; // Only parentheses with numbers
    }
    
    // Filter out time formats
    if (RegExp(r'\d{2}:\d{2}:\d{2}').hasMatch(line)) return true;
    
    // Filter out menu items and quantities
    if (_containsMenuItems(line)) return true;
    
    // Filter out prices and totals
    if (RegExp(r'^\d+\.\d+\s*[A-Z]{3}$').hasMatch(upper)) return true; // 4.50 CHF
    if (RegExp(r'^\d+\.\d+$').hasMatch(line)) return true; // 4.50
    
    // Filter out very short lines (likely not business names)
    if (line.trim().length < 3) return true;
    
    // Filter out lines that are mostly numbers
    if (RegExp(r'^\d+$').hasMatch(line.trim())) return true;
    
    // NEW: Filter out concatenated lines with addresses/phone numbers
    if (upper.contains('AVE') && upper.contains('NY')) return true; // Contains "Ave" and "NY"
    if (upper.contains('ST') && upper.contains('NY')) return true; // Contains "St" and "NY"
    if (upper.contains('RD') && upper.contains('NY')) return true; // Contains "Rd" and "NY"
    
    print('🔍 FILTER: Line passed all filters: "$line"');
    return false;
  }

  /// Extract clean vendor name from concatenated lines with addresses/phone numbers
  String? _extractCleanVendorName(String line) {
    print('🔍 MAGIC VENDOR: Extracting clean vendor name from: "$line"');
    
    // Check if line contains address/phone patterns that should be filtered out
    if (!_containsAddressOrPhonePatterns(line)) {
      print('🔍 MAGIC VENDOR: Line does not contain address/phone patterns, returning null');
      return null;
    }
    
    // Try to extract the business name part before address/phone information
    String cleanName = line;
    
    print('🔍 MAGIC VENDOR: Original line: "$cleanName"');
    
    // Remove phone numbers
    cleanName = cleanName.replaceAll(RegExp(r'\(\d{3}\)\d{3}-\d{4}'), '');
    cleanName = cleanName.replaceAll(RegExp(r'\d{3}-\d{3}-\d{4}'), '');
    cleanName = cleanName.replaceAll(RegExp(r'\d{3}\.\d{3}\.\d{4}'), '');
    print('🔍 MAGIC VENDOR: After removing phone numbers: "$cleanName"');
    
    // Remove addresses (street number + street name) - handle concatenated format
    cleanName = cleanName.replaceAll(RegExp(r'\d{2,5}[A-Za-z]*(?:Ave|St|Rd|Blvd|Dr|Ln|Way|Pl|Ct)'), '');
    print('🔍 MAGIC VENDOR: After removing addresses: "$cleanName"');
    
    // Remove ZIP codes
    cleanName = cleanName.replaceAll(RegExp(r'\d{5}'), '');
    print('🔍 MAGIC VENDOR: After removing ZIP codes: "$cleanName"');
    
    // Remove city, state patterns - handle concatenated format
    cleanName = cleanName.replaceAll(RegExp(r'[A-Za-z]+,\s*[A-Z]{2}\d{5}'), '');
    cleanName = cleanName.replaceAll(RegExp(r'[A-Za-z]+[A-Z]{2}\d{5}'), '');
    print('🔍 MAGIC VENDOR: After removing city/state patterns: "$cleanName"');
    
    // Clean up extra spaces and punctuation
    cleanName = cleanName
        .replaceAll(RegExp(r'[,\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    print('🔍 MAGIC VENDOR: After cleaning spaces/punctuation: "$cleanName"');
    
    // ENHANCED: Try to extract just the business name part
    // Look for common business name patterns
    final businessNameMatch = RegExp(r'^([A-Za-z\s&]+?)(?:\d|\(|$)', caseSensitive: false).firstMatch(cleanName);
    if (businessNameMatch != null) {
      final extractedName = businessNameMatch.group(1)?.trim();
      if (extractedName != null && extractedName.length >= 3) {
        cleanName = extractedName;
        print('🔍 MAGIC VENDOR: Extracted business name pattern: "$cleanName"');
      }
    }
    
    // Check if we have a meaningful business name left
    if (cleanName.length < 3 || cleanName.length > 50) {
      print('🔍 MAGIC VENDOR: Clean name too short or too long: "$cleanName" (length: ${cleanName.length})');
      return null;
    }
    
    // Check if it still contains too many numbers
    final numberCount = RegExp(r'\d').allMatches(cleanName).length;
    final totalChars = cleanName.replaceAll(RegExp(r'\s'), '').length;
    if (totalChars > 0 && (numberCount / totalChars) > 0.2) {
      print('🔍 MAGIC VENDOR: Clean name still has too many numbers: "$cleanName" ($numberCount/$totalChars = ${numberCount/totalChars})');
      return null;
    }
    
    print('🔍 MAGIC VENDOR: Successfully extracted clean vendor name: "$cleanName"');
    return cleanName;
  }

  /// Check if line contains address or phone patterns
  bool _containsAddressOrPhonePatterns(String line) {
    // Check for phone numbers
    if (RegExp(r'\(\d{3}\)\d{3}-\d{4}').hasMatch(line)) return true;
    if (RegExp(r'\d{3}-\d{3}-\d{4}').hasMatch(line)) return true;
    if (RegExp(r'\d{3}\.\d{3}\.\d{4}').hasMatch(line)) return true;
    
    // Check for addresses (both spaced and concatenated formats)
    if (RegExp(r'\d{2,5}\s+[A-Za-z\s]+(?:Ave|St|Rd|Blvd|Dr|Ln|Way|Pl|Ct)').hasMatch(line)) return true;
    if (RegExp(r'\d{2,5}[A-Za-z]*(?:Ave|St|Rd|Blvd|Dr|Ln|Way|Pl|Ct)').hasMatch(line)) return true;
    
    // Check for ZIP codes
    if (RegExp(r'\b\d{5}\b').hasMatch(line)) return true;
    if (RegExp(r'\d{5}').hasMatch(line)) return true;
    
    // Check for city, state, ZIP patterns (both spaced and concatenated)
    if (RegExp(r'[A-Za-z]+,\s*[A-Z]{2}\s+\d{5}').hasMatch(line)) return true;
    if (RegExp(r'[A-Za-z]+[A-Z]{2}\d{5}').hasMatch(line)) return true;
    
    return false;
  }

  /// Simple vendor extraction for concatenated lines
  String? _simpleVendorExtraction(String line) {
    print('🔍 MAGIC VENDOR: Simple extraction from: "$line"');
    
    // Try to find the first meaningful word or phrase before numbers/addresses
    // Look for patterns like "HongKong" or "Supermarket" before numbers
    final match = RegExp(r'^([A-Za-z]+)', caseSensitive: false).firstMatch(line);
    if (match != null) {
      final firstWord = match.group(1);
      if (firstWord != null && firstWord.length >= 3) {
        print('🔍 MAGIC VENDOR: Simple extraction found first word: "$firstWord"');
        return firstWord;
      }
    }
    
    // Try to find words before common address/phone patterns
    final beforeAddress = RegExp(r'^([A-Za-z\s]+?)(?:\d|\(|Ave|St|Rd|Blvd|Dr|Ln|Way|Pl|Ct)', caseSensitive: false).firstMatch(line);
    if (beforeAddress != null) {
      final extracted = beforeAddress.group(1)?.trim();
      if (extracted != null && extracted.length >= 3) {
        print('🔍 MAGIC VENDOR: Simple extraction found before address: "$extracted"');
        return extracted;
      }
    }
    
    print('🔍 MAGIC VENDOR: Simple extraction failed');
    return null;
  }

  /// Check if a line contains menu items, quantities, or prices
  /// Enhanced scoring for position-based vendor detection
  double _calculatePositionBasedVendorScore(String line, int lineIndex, int totalLines) {
    double score = 0.0;
    final upper = line.toUpperCase();
    
    // ENHANCED: First line bonus for receipts (most receipts have vendor name in first line)
    if (lineIndex == 0) {
      score += 0.4; // 40% bonus for first line
      print('🔍 MAGIC VENDOR: First line bonus for "$line" - +0.4 score');
    }
    
    // Higher weight for top lines (position matters more)
    final positionWeight = (totalLines - lineIndex) / totalLines;
    score += positionWeight * 0.3; // 30% weight for position (reduced from 40%)
    
    // Boost for lines that look like company names (proper case, reasonable length)
    if (line.contains(RegExp(r'^[A-Z][a-z]+(\s+[A-Z][a-z]+)*$'))) {
      score += 0.3; // 30% boost for proper case company names
      print('🔍 MAGIC VENDOR: Line "$line" matches company name pattern - +0.3 score');
    }
    
    // ENHANCED: Boost for business type indicators (Supermarket, Store, Market, etc.)
    final businessTypeKeywords = ['SUPERMARKET', 'MARKET', 'STORE', 'SHOP', 'RESTAURANT', 'CAFE', 
                                 'HOTEL', 'PHARMACY', 'DROGERIE', 'DROGERIEMARKT', 'CENTER', 'MALL', 
                                 'PLAZA', 'SQUARE', 'BAKERY', 'DELI', 'GROCERY', 'FOOD', 'GAS'];
    
    bool hasBusinessTypeKeyword = false;
    for (final keyword in businessTypeKeywords) {
      if (upper.contains(keyword)) {
        // Only boost if the keyword is part of a meaningful business name (not standalone)
        if (line.length > keyword.length + 2) { // Business name should be longer than just the keyword
          hasBusinessTypeKeyword = true;
          score += 0.3; // 30% boost for business type keywords (higher than general keywords)
          print('🔍 MAGIC VENDOR: Line "$line" contains business type keyword "$keyword" - +0.3 score');
          break;
        }
      }
    }
    
    // General business keywords (lower priority than business type)
    final businessKeywords = ['COMPANY', 'CORP', 'INC', 'LLC', 'LTD', 'LIMITED', 'ENTERPRISES', 'GROUP', 'SYSTEMS'];
    
    bool hasBusinessKeyword = false;
    for (final keyword in businessKeywords) {
      if (upper.contains(keyword)) {
        // Only boost if the keyword is part of a meaningful business name (not standalone)
        if (line.length > keyword.length + 2) { // Business name should be longer than just the keyword
          hasBusinessKeyword = true;
          break;
        }
      }
    }
    
    if (hasBusinessKeyword && !hasBusinessTypeKeyword) {
      score += 0.15; // 15% boost for general business keywords (lower than business type)
      print('🔍 MAGIC VENDOR: Line "$line" contains general business keywords - +0.15 score');
    }
    
    // Boost for well-known brand names (like TARGET, WALMART, etc.)
    if (upper.contains('TARGET') || upper.contains('WALMART') || upper.contains('TESCO') ||
        upper.contains('MCDONALD') || upper.contains('STARBUCKS') || upper.contains('SHELL') ||
        upper.contains('BP') || upper.contains('AMAZON') || upper.contains('APPLE') ||
        upper.contains('GOOGLE') || upper.contains('MICROSOFT') || upper.contains('NIKE') ||
        upper.contains('ADIDAS') || upper.contains('COCA') || upper.contains('PEPSI')) {
      score += 0.4; // 40% boost for well-known brands
      print('🔍 MAGIC VENDOR: Line "$line" contains well-known brand - +0.4 score');
    }
    
    // ENHANCED: Boost for receipt-specific formatting patterns
    if (upper == line && line.length > 3 && line.length < 30) {
      // All caps, reasonable length - very likely company name
      score += 0.5; // 50% boost for all-caps company names
      print('🔍 MAGIC VENDOR: Line "$line" is all-caps company name - +0.5 score');
    }
    
    // ENHANCED: Boost for lines with business entity indicators
    if (upper.contains('LTD') || upper.contains('INC') || upper.contains('LLC') || 
        upper.contains('CORP') || upper.contains('GMBH') || upper.contains('AG') ||
        upper.contains('STORE') || upper.contains('SHOP') || upper.contains('MARKET')) {
      score += 0.3; // 30% boost for business entity indicators
      print('🔍 MAGIC VENDOR: Line "$line" contains business entity indicators - +0.3 score');
    }
    
    // ENHANCED: Boost for lines that look like store names (mixed case, reasonable length)
    if (line.contains(RegExp(r'^[A-Z][a-z]+(\s+[A-Z][a-z]+)*$')) && 
        line.length >= 4 && line.length <= 25) {
      score += 0.35; // 35% boost for proper case store names
      print('🔍 MAGIC VENDOR: Line "$line" looks like proper store name - +0.35 score');
    }
    
    // Penalty for lines that look like addresses, phone numbers, or dates
    if (RegExp(r'^\d+').hasMatch(line) || // Starts with numbers
        RegExp(r'\d{3}[-.]?\d{3}[-.]?\d{4}').hasMatch(line) || // Phone number
        RegExp(r'\d{1,2}[./]\d{1,2}[./]\d{2,4}').hasMatch(line)) { // Date
      score -= 0.3; // 30% penalty
      print('🔍 MAGIC VENDOR: Line "$line" looks like address/phone/date - -0.3 penalty');
    }
    
    // Penalty for very short or very long lines
    if (line.length < 3) {
      score -= 0.2; // 20% penalty for too short
    } else if (line.length > 50) {
      score -= 0.1; // 10% penalty for too long
    }
    
    // ENHANCED: Apply business name validation penalties
    score = _applyBusinessNameValidation(line, score);
    
    print('🔍 MAGIC VENDOR: Position-based final score for "$line": $score');
    return score;
  }

  /// Apply comprehensive business name validation and penalties
  double _applyBusinessNameValidation(String line, double score) {
    final upper = line.toUpperCase();
    
    // Penalty for single words that are common receipt terms
    final singleWordPenalties = [
      'STATION', 'TERMINAL', 'REGISTER', 'CASHIER', 'CLERK', 'EMPLOYEE',
      'RECEIPT', 'INVOICE', 'BILL', 'TICKET', 'ORDER', 'TRANSACTION',
      'DATE', 'TIME', 'REF', 'REFERENCE', 'ID', 'NUMBER', 'NO', 'NR',
      'TOTAL', 'SUBTOTAL', 'TAX', 'PAYMENT', 'CASH', 'CARD', 'CHANGE',
      'ITEM', 'ITEMS', 'QUANTITY', 'QTY', 'PRICE', 'AMOUNT',
      'DISCOUNT', 'COUPON', 'PROMO', 'SALE', 'SPECIAL',
      'CUSTOMER', 'GUEST', 'MEMBER', 'VIP', 'LOYALTY',
      'THANK', 'VISIT', 'AGAIN', 'WELCOME', 'GOODBYE', 'BYE'
    ];
    
    if (singleWordPenalties.contains(upper)) {
      score -= 0.5; // 50% penalty for single receipt terms
      print('🔍 MAGIC VENDOR: Applied single word penalty for "$line" - -0.5 score');
    }
    
    // Penalty for lines that are too generic or common
    final genericTerms = ['STORE', 'SHOP', 'MARKET', 'CENTER', 'MALL', 'PLACE', 'SPOT'];
    if (genericTerms.contains(upper) && line.length <= 6) {
      score -= 0.3; // 30% penalty for generic single words
      print('🔍 MAGIC VENDOR: Applied generic term penalty for "$line" - -0.3 score');
    }
    
    // Penalty for lines that look like system messages
    if (upper.contains('SYSTEM') || upper.contains('ERROR') || upper.contains('WARNING') ||
        upper.contains('NOTICE') || upper.contains('ALERT') || upper.contains('MESSAGE')) {
      score -= 0.4; // 40% penalty for system messages
      print('🔍 MAGIC VENDOR: Applied system message penalty for "$line" - -0.4 score');
    }
    
    // Penalty for lines that are mostly numbers or special characters
    final numberCount = RegExp(r'\d').allMatches(line).length;
    final specialCharCount = RegExp(r'[^\w\s]').allMatches(line).length;
    final totalChars = line.replaceAll(RegExp(r'\s'), '').length;
    
    if (totalChars > 0) {
      final numberRatio = numberCount / totalChars;
      final specialCharRatio = specialCharCount / totalChars;
      
      if (numberRatio > 0.5) {
        score -= 0.4; // 40% penalty for mostly numbers
        print('🔍 MAGIC VENDOR: Applied number ratio penalty for "$line" - -0.4 score');
      }
      
      if (specialCharRatio > 0.3) {
        score -= 0.3; // 30% penalty for too many special characters
        print('🔍 MAGIC VENDOR: Applied special char ratio penalty for "$line" - -0.3 score');
      }
    }
    
    // Bonus for lines that look like proper business names
    if (_looksLikeProperBusinessName(line)) {
      score += 0.3; // 30% bonus for proper business names
      print('🔍 MAGIC VENDOR: Applied proper business name bonus for "$line" - +0.3 score');
    }
    
    return score;
  }

  /// Check if a line looks like a proper business name
  bool _looksLikeProperBusinessName(String line) {
    if (line.length < 3 || line.length > 50) return false;
    
    // Must contain at least one letter
    if (!RegExp(r'[a-zA-Z]').hasMatch(line)) return false;
    
    // Should not be mostly numbers or special characters
    final letterCount = RegExp(r'[a-zA-Z]').allMatches(line).length;
    final totalChars = line.replaceAll(RegExp(r'\s'), '').length;
    if (totalChars > 0 && (letterCount / totalChars) < 0.5) return false;
    
    // Should not be a single common word
    final commonWords = ['STORE', 'SHOP', 'MARKET', 'CENTER', 'MALL', 'PLACE', 'SPOT', 'STATION'];
    if (commonWords.contains(line.toUpperCase()) && line.length <= 8) return false;
    
    // Should have some variety in characters (not all the same)
    final uniqueChars = line.toUpperCase().split('').toSet().length;
    if (uniqueChars < 3) return false;
    
    return true;
  }

  /// Pre-process OCR lines to handle concatenation issues
  List<String> _preprocessOcrLines(List<String> lines) {
    print('🔍 PREPROCESS: Starting OCR line preprocessing');
    final processedLines = <String>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      print('🔍 PREPROCESS: Processing line $i: "$line"');
      
      // Check if this line looks like it contains multiple concatenated elements
      if (_looksLikeConcatenatedLine(line)) {
        print('🔍 PREPROCESS: Line $i looks concatenated, attempting to split');
        final splitLines = _splitConcatenatedLine(line);
        processedLines.addAll(splitLines);
        print('🔍 PREPROCESS: Split line $i into ${splitLines.length} parts: $splitLines');
      } else {
        processedLines.add(line);
        print('🔍 PREPROCESS: Line $i kept as-is');
      }
    }
    
    print('🔍 PREPROCESS: Preprocessing complete. ${lines.length} -> ${processedLines.length} lines');
    return processedLines;
  }

  /// Check if a line looks like it contains concatenated elements
  bool _looksLikeConcatenatedLine(String line) {
    // Check for patterns that suggest concatenation
    if (line.length > 50) return true; // Very long lines are likely concatenated
    
    // Check for mixed case patterns that suggest concatenation
    if (line.contains(RegExp(r'[a-z][A-Z]'))) return true; // camelCase pattern
    
    // Check for product name patterns mixed with business names
    final productKeywords = ['QUAKER', 'COCA', 'PEPSI', 'NESTLE', 'KRAFT', 'HEINZ', 'CAMPBELL', 
                            'GENERAL', 'MILLS', 'KELLOGG', 'POST', 'CHEERIOS', 'FROSTED', 'LUCKY',
                            'CHARMS', 'HONEY', 'NUT', 'CHEERIOS', 'FROOT', 'LOOPS', 'CORN', 'FLAKES'];
    
    // Check for concatenated business names (e.g., "REWEMarkt" should be "REWE MARKT")
    final businessConcatenationPatterns = ['REWEMARKT', 'ALDI', 'LIDL', 'TESCO', 'SAINSBURY', 'MORRISONS', 'WAITROSE'];
    
    // Check for brand slogans that get concatenated with brand names
    final brandSloganPatterns = [
      'EXPECTIARGETMORE', // TARGET: "EXPECT MORE" + "TARGET"
      'EXPECTTARGETMORE', // TARGET: "EXPECT" + "TARGET" + "MORE"
      'TARGETMOREPAY',    // TARGET: "TARGET" + "MORE" + "PAY"
      'WALMARTALWAYS',    // WALMART: "WALMART" + "ALWAYS"
      'SAVEMONEYLIVE',    // WALMART: "SAVE MONEY" + "LIVE"
      'STARBUCKSINSPIRE', // STARBUCKS: "STARBUCKS" + "INSPIRE"
      'MCDONALDSIM',      // MCDONALD'S: "MCDONALD'S" + "LOVIN' IT"
      'AMAZONWORKHARD',   // AMAZON: "AMAZON" + "WORK HARD"
      'APPLEITHINK',      // APPLE: "APPLE" + "THINK DIFFERENT"
    ];
    
    for (final keyword in productKeywords) {
      if (line.toUpperCase().contains(keyword)) {
        // If it contains a product keyword, it might be concatenated
        return true;
      }
    }
    
    for (final pattern in businessConcatenationPatterns) {
      if (line.toUpperCase().contains(pattern)) {
        // If it contains a concatenated business pattern, it might be concatenated
        return true;
      }
    }
    
    for (final pattern in brandSloganPatterns) {
      if (line.toUpperCase().contains(pattern)) {
        // If it contains a brand slogan pattern, it might be concatenated
        return true;
      }
    }
    
    // Check for business name + product name patterns
    if (line.contains(RegExp(r'[A-Z]{2,}[a-z]+[A-Z]{2,}'))) return true; // Mixed case patterns
    
    return false;
  }

  /// Split a concatenated line into separate elements
  List<String> _splitConcatenatedLine(String line) {
    // Strategy 1: Split on common product brand boundaries
    final productBrands = ['QUAKER', 'COCA', 'PEPSI', 'NESTLE', 'KRAFT', 'HEINZ', 'CAMPBELL', 
                          'GENERAL', 'MILLS', 'KELLOGG', 'POST', 'CHEERIOS', 'FROSTED', 'LUCKY',
                          'CHARMS', 'HONEY', 'NUT', 'FROOT', 'LOOPS', 'CORN', 'FLAKES'];
    
    // Strategy 1.5: Handle specific business concatenation patterns
    final businessConcatenationPatterns = {
      'REWEMARKT': 'REWE MARKT',
      'ALDI': 'ALDI',
      'LIDL': 'LIDL',
      'TESCO': 'TESCO',
      'SAINSBURY': 'SAINSBURY\'S',
      'MORRISONS': 'MORRISONS',
      'WAITROSE': 'WAITROSE'
    };
    
    for (final entry in businessConcatenationPatterns.entries) {
      if (line.toUpperCase().contains(entry.key)) {
        return [entry.value];
      }
    }
    
    // Strategy 1.6: Handle brand slogan concatenation patterns
    final brandSloganPatterns = {
      'EXPECTIARGETMORE': 'TARGET',     // "EXPECT MORE" + "TARGET"
      'EXPECTTARGETMORE': 'TARGET',     // "EXPECT" + "TARGET" + "MORE"
      'TARGETMOREPAY': 'TARGET',        // "TARGET" + "MORE" + "PAY"
      'WALMARTALWAYS': 'WALMART',       // "WALMART" + "ALWAYS"
      'SAVEMONEYLIVE': 'WALMART',       // "SAVE MONEY" + "LIVE"
      'STARBUCKSINSPIRE': 'STARBUCKS',  // "STARBUCKS" + "INSPIRE"
      'MCDONALDSIM': 'MCDONALD\'S',     // "MCDONALD'S" + "LOVIN' IT"
      'AMAZONWORKHARD': 'AMAZON',       // "AMAZON" + "WORK HARD"
      'APPLEITHINK': 'APPLE',           // "APPLE" + "THINK DIFFERENT"
    };
    
    for (final entry in brandSloganPatterns.entries) {
      if (line.toUpperCase().contains(entry.key)) {
        return [entry.value];
      }
    }
    
    String remaining = line;
    for (final brand in productBrands) {
      final regex = RegExp(brand, caseSensitive: false);
      if (regex.hasMatch(remaining)) {
        final splitParts = remaining.split(regex);
        if (splitParts.length > 1) {
          // Found a brand split
          final beforeBrand = splitParts[0].trim();
          final afterBrand = brand + splitParts.sublist(1).join(brand).trim();
          
          final result = <String>[];
          if (beforeBrand.isNotEmpty) {
            result.add(beforeBrand);
          }
          if (afterBrand.isNotEmpty) {
            result.add(afterBrand);
          }
          return result;
        }
      }
    }
    
    // Strategy 2: Split on camelCase boundaries
    if (line.contains(RegExp(r'[a-z][A-Z]'))) {
      final camelCaseSplit = line.split(RegExp(r'(?<=[a-z])(?=[A-Z])'));
      if (camelCaseSplit.length > 1) {
        return camelCaseSplit.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
    }
    
    // Strategy 3: Split on all-caps boundaries
    if (line.contains(RegExp(r'[A-Z]{3,}[a-z]+[A-Z]{3,}'))) {
      final allCapsSplit = line.split(RegExp(r'(?<=[A-Z]{3,})(?=[a-z]+[A-Z]{3,})'));
      if (allCapsSplit.length > 1) {
        return allCapsSplit.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
    }
    
    // Strategy 4: Smart brand extraction from concatenated text
    final extractedBrand = _extractBrandFromConcatenatedText(line);
    if (extractedBrand != null) {
      return [extractedBrand];
    }
    
    // Strategy 5: If no splitting strategy works, return the original line
    return [line];
  }

  /// Extract brand name from concatenated text with slogans
  String? _extractBrandFromConcatenatedText(String line) {
    final upperLine = line.toUpperCase();
    
    // List of major brands to look for within concatenated text
    final majorBrands = [
      'TARGET', 'WALMART', 'COSTCO', 'KROGER', 'SAFEWAY', 'WHOLE FOODS', 'TRADER JOE\'S',
      'AMAZON', 'APPLE', 'MICROSOFT', 'GOOGLE', 'BEST BUY', 'NIKE', 'ADIDAS', 'GAP',
      'MCDONALD\'S', 'STARBUCKS', 'KFC', 'SUBWAY', 'BURGER KING', 'IKEA', 'HOME DEPOT',
      'LOWE\'S', 'CVS', 'WALGREENS', 'SHELL', 'BP', 'EXXON', 'ALDI', 'LIDL', 'TESCO',
      'CARREFOUR', 'REWE', 'ASDA', 'SAINSBURY\'S', 'MORRISONS', 'WAITROSE'
    ];
    
    // Look for brand names within the concatenated text
    for (final brand in majorBrands) {
      if (upperLine.contains(brand)) {
        print('🔍 PREPROCESS: Extracted brand "$brand" from concatenated text: "$line"');
        return brand;
      }
    }
    
    return null;
  }

  bool _containsMenuItems(String line) {
    final upper = line.toUpperCase();
    
    // Menu item patterns
    if (RegExp(r'\d+x\s*[A-Z]', caseSensitive: false).hasMatch(line)) return true; // 1xGloki, 2xLatte
    if (RegExp(r'\d+\s*[A-Z]', caseSensitive: false).hasMatch(line)) return true;  // 1 Gloki, 2 Latte
    if (RegExp(r'^\d+\.\d+\s*[A-Z]{3}', caseSensitive: false).hasMatch(line)) return true; // 4.50 CHF
    if (RegExp(r'^\d+\.\d+$', caseSensitive: false).hasMatch(line)) return true; // 4.50
    
    // Menu item keywords
    if (upper.contains('LATTE') || upper.contains('MACCHIATO') || upper.contains('SCHNITZEL')) return true;
    if (upper.contains('GLOKI') || upper.contains('CHÄSSPÄTZLI')) return true;
    if (upper.contains('TOTAL') || upper.contains('CHF') || upper.contains('EUR')) return true;
    
    return false;
  }

  double _scoreName(String line) {
    final upper = line.toUpperCase();
    double score = 0.0;
    
    // Prefer lines with proper capitalization (first letter of each word)
    final words = line.split(' ');
    int properCaseWords = 0;
    for (String word in words) {
      if (word.isNotEmpty && word[0] == word[0].toUpperCase()) {
        properCaseWords++;
      }
    }
    score += (properCaseWords / words.length) * 0.2;
    
    // Prefer lines with reasonable length (3-50 characters)
    if (line.length >= 3 && line.length <= 50) {
      score += 0.15;
    }
    
    // Prefer lines with mostly letters
    final letterCount = line.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
    final letterRatio = letterCount / line.length;
    score += letterRatio * 0.2;
    
    // Prefer lines with 2-5 words
    if (words.length >= 2 && words.length <= 5) {
      score += 0.15;
    }
    
    // ENHANCED: Better bold text detection
    if (upper == line && line.length > 2) {
      // All caps with more than 2 characters - very likely bold
      score += 0.4; // Increased from 0.3 to 0.4
      print('🔍 MAGIC VENDOR: Line "$line" detected as ALL CAPS (likely bold) - +0.4 score');
    } else if (line.contains(RegExp(r'[A-Z]{3,}'))) {
      // Multiple consecutive capitals (3+) - likely emphasis
      score += 0.25; // Increased from 0.2 to 0.25
      print('🔍 MAGIC VENDOR: Line "$line" has multiple consecutive caps - +0.25 score');
    } else if (line.contains(RegExp(r'[A-Z][a-z]+[A-Z][a-z]+'))) {
      // Mixed case with multiple capital letters - likely emphasis
      score += 0.2; // Increased from 0.15 to 0.2
      print('🔍 MAGIC VENDOR: Line "$line" has mixed case emphasis - +0.2 score');
    }
    
    // NEW: Boost for hotel/restaurant keywords (common in receipts)
    if (upper.contains('HOTEL') || upper.contains('RESTAURANT') || upper.contains('BERG')) {
      score += 0.3; // High boost for hospitality keywords
      print('🔍 MAGIC VENDOR: Line "$line" contains hospitality keywords - +0.3 score');
    }
    
    // ENHANCED: Business name pattern detection
    if (upper.contains('STORE') || upper.contains('SHOP') || upper.contains('MARKET') || upper.contains('MART')) {
      score += 0.15;
      print('🔍 MAGIC VENDOR: Line "$line" contains retail keywords - +0.15 score');
    }
    if (upper.contains('RESTAURANT') || upper.contains('CAFE') || upper.contains('PIZZA') || upper.contains('FOOD')) {
      score += 0.15;
      print('🔍 MAGIC VENDOR: Line "$line" contains food keywords - +0.15 score');
    }
    if (upper.contains('GAS') || upper.contains('FUEL') || upper.contains('STATION') || upper.contains('OIL')) {
      score += 0.15;
      print('🔍 MAGIC VENDOR: Line "$line" contains fuel keywords - +0.15 score');
    }
    if (upper.contains('PHARMACY') || upper.contains('DRUG') || upper.contains('MEDICAL')) {
      score += 0.15;
      print('🔍 MAGIC VENDOR: Line "$line" contains medical keywords - +0.15 score');
    }
    
    // NEW: Boost for lines that look like company names
    if (line.contains(RegExp(r'^[A-Z][a-z]+(\s+[A-Z][a-z]+)*$'))) {
      // Proper case company name pattern
      score += 0.2; // Increased from 0.1 to 0.2
      print('🔍 MAGIC VENDOR: Line "$line" matches company name pattern - +0.2 score');
    }
    
    // NEW: Penalty for lines that look like invoice numbers or dates
    if (RegExp(r'^\d{1,2}[./]\d{1,2}[./]\d{2,4}').hasMatch(line)) {
      score -= 0.5; // Heavy penalty for date patterns
      print('🔍 MAGIC VENDOR: Line "$line" looks like a date - -0.5 penalty');
    }
    if (RegExp(r'^RECH\.?\s*NR?\.?\s*\d+', caseSensitive: false).hasMatch(line)) {
      score -= 0.8; // Very heavy penalty for invoice numbers
      print('🔍 MAGIC VENDOR: Line "$line" looks like an invoice number - -0.8 penalty');
    }
    
    print('🔍 MAGIC VENDOR: Final score for "$line": $score');
    return score;
  }

  /// Extract simple line items: name followed by price at end. Also support "qty x price"
  List<Map<String, dynamic>> extractLineItems(List<String> lines, [List<OcrLine>? linesPositional]) {
    final items = <Map<String, dynamic>>[];
    // Capture trailing monetary value; allow a trailing single letter (e.g., Walmart's "0.97 X")
    final moneyRx = RegExp(r'([€£$])?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})?)\s*[A-Za-z]?$');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      // ignore lines that contain SUBTOTAL/TAX/TOTAL or void markers
      final u = line.toUpperCase();
      if (u.contains('TOTAL') || u.contains('SUBTOTAL') || u.contains('TAX') || u.contains('VAT')) continue;
      if (u.contains('VOID')) continue;

      // Find money matches
      final matches = moneyRx.allMatches(line).toList();
      if (matches.isNotEmpty) {
        final last = matches.last;
        final priceStr = last.group(2)!;
        final price = _parseMoney(priceStr);
        if (price == null) continue;

        // name portion is text before the match
        final namePart = line.substring(0, last.start).trim();
        if (namePart.isEmpty) continue;

        // qty support: "4x", "x4", "4X", and patterns like "3 AT ..."
        int qty = 1;
        String name = namePart;
        final q1 = RegExp(r'(\d+)\s*[xX]\s*$', caseSensitive: false).firstMatch(namePart);
        final q2 = RegExp(r'^[xX]\s*(\d+)\b').firstMatch(namePart);
        final q3 = RegExp(r'\b(\d+)\s+AT\b', caseSensitive: false).firstMatch(namePart);
        if (q1 != null) {
          qty = int.tryParse(q1.group(1)!) ?? 1;
          name = namePart.substring(0, q1.start).trim();
        } else if (q2 != null) {
          qty = int.tryParse(q2.group(1)!) ?? 1;
          name = namePart.substring(q2.end).trim();
        } else if (q3 != null) {
          qty = int.tryParse(q3.group(1)!) ?? 1;
          // Keep full name; promo text like "3 AT 1 FOR" will remain in name, but qty is captured
        }

        final totalForLine = price; // price captured is the line total on most receipts
        final unitPrice = totalForLine / (qty == 0 ? 1 : qty);

        // Add positional information if available
        Map<String, dynamic> item = {
          'name': name,
          'qty': qty,
          'price': totalForLine, // keep legacy key
          'total': totalForLine,
          'unitPrice': unitPrice,
        };
        
        // Add positional data if available
        if (linesPositional != null && i < linesPositional.length) {
          final ocrLine = linesPositional[i];
          item['position'] = {
            'left': ocrLine.left,
            'top': ocrLine.top,
            'width': ocrLine.width,
            'height': ocrLine.height,
          };
        }
        
        items.add(item);
      }
    }

    // Optional: merge items with same name
    final merged = <String, Map<String, dynamic>>{};
    for (final it in items) {
      final key = _normalizeKey(it['name'] as String);
      if (merged.containsKey(key)) {
        merged[key]!['total'] = (merged[key]!['total'] as double) + (it['total'] as double);
        merged[key]!['price'] = merged[key]!['total']; // maintain legacy alias
        merged[key]!['qty'] = (merged[key]!['qty'] as int) + (it['qty'] as int);
        final q = merged[key]!['qty'] as int;
        merged[key]!['unitPrice'] = q == 0 ? merged[key]!['total'] : (merged[key]!['total'] as double) / q;
      } else {
        merged[key] = <String, dynamic>{
          'name': it['name'],
          'qty': it['qty'],
          'price': it['total'],
          'total': it['total'],
          'unitPrice': it['unitPrice'],
        };
        
        // Preserve positional data if available
        if (it.containsKey('position')) {
          merged[key]!['position'] = it['position'];
        }
      }
    }
    return merged.values.toList();
  }

  double? _parseMoney(String s) {
    s = s.replaceAll(' ', '');
    if (s.contains(',') && s.contains('.')) {
      final lastComma = s.lastIndexOf(',');
      final lastDot = s.lastIndexOf('.');
      if (lastComma > lastDot) {
        s = s.replaceAll('.', '');
        s = s.replaceAll(',', '.');
      } else {
        s = s.replaceAll(',', '');
      }
    } else if (s.contains(',')) {
      if (RegExp(r',\d{2}$').hasMatch(s)) {
        s = s.replaceAll(',', '.');
      } else {
        s = s.replaceAll(',', '');
      }
    }
    try {
      return double.parse(s);
    } catch (e) {
      return null;
    }
  }

  String _normalizeKey(String s) {
    return s
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Format vendor name to "XYZ(first line or main name) Abc Cde" format
  String _formatVendorName(String detectedVendor, List<String> allLines) {
    print('🔍 MAGIC VENDOR: Formatting vendor name: "$detectedVendor"');
    
    // Clean the detected vendor name
    String cleanVendor = detectedVendor.trim();
    
    // If the vendor name is already well-formatted, return as is
    if (cleanVendor.length <= 50 && !cleanVendor.contains(RegExp(r'[0-9]{4,}')) && 
        !cleanVendor.contains(RegExp(r'[A-Z]{10,}')) && 
        cleanVendor.split(' ').length <= 5) {
      print('🔍 MAGIC VENDOR: Vendor name already well-formatted: "$cleanVendor"');
      return cleanVendor;
    }
    
    // Extract the main name (first significant word or phrase)
    String mainName = _extractMainName(cleanVendor);
    print('🔍 MAGIC VENDOR: Extracted main name: "$mainName"');
    
    // Look for additional context from surrounding lines
    String additionalContext = _extractAdditionalContext(detectedVendor, allLines);
    print('🔍 MAGIC VENDOR: Extracted additional context: "$additionalContext"');
    
    // Combine main name and additional context
    String formattedVendor;
    if (additionalContext.isNotEmpty && additionalContext != mainName) {
      formattedVendor = '$mainName $additionalContext';
    } else {
      formattedVendor = mainName;
    }
    
    // Clean up the final result
    formattedVendor = formattedVendor
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s\-\.&]'), '') // Remove special chars except common business chars
        .trim();
    
    print('🔍 MAGIC VENDOR: Final formatted vendor: "$formattedVendor"');
    return formattedVendor;
  }
  
  /// Extract the main name from vendor string
  String _extractMainName(String vendor) {
    // Split by common separators and take the first meaningful part
    final parts = vendor.split(RegExp(r'[,\-\|/]'));
    String mainPart = parts.first.trim();
    
    // If the main part is too long, try to extract the first few words
    if (mainPart.length > 30) {
      final words = mainPart.split(' ');
      if (words.length > 3) {
        mainPart = words.take(3).join(' ');
      }
    }
    
    // Clean up the main part
    mainPart = mainPart
        .replaceAll(RegExp(r'[^\w\s\-\.&]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    return mainPart.isNotEmpty ? mainPart : vendor;
  }
  
  /// Extract additional context from surrounding lines
  String _extractAdditionalContext(String detectedVendor, List<String> allLines) {
    // Find the line index of the detected vendor
    int vendorLineIndex = -1;
    for (int i = 0; i < allLines.length; i++) {
      if (allLines[i].trim().contains(detectedVendor.trim())) {
        vendorLineIndex = i;
        break;
      }
    }
    
    if (vendorLineIndex == -1) return '';
    
    // Look at the next line for additional context
    if (vendorLineIndex + 1 < allLines.length) {
      String nextLine = allLines[vendorLineIndex + 1].trim();
      
      // Skip if next line contains numbers, prices, or looks like menu items
      if (!_containsMenuItems(nextLine) && 
          !nextLine.contains(RegExp(r'[0-9]{2,}')) &&
          nextLine.length > 2 && nextLine.length < 30) {
        
        // Clean the additional context
        String additionalContext = nextLine
            .replaceAll(RegExp(r'[^\w\s\-\.&]'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        
        return additionalContext;
      }
    }
    
    return '';
  }
}



