// lib/services/ocr/parser/helpers/line_heuristics.dart
import '../../i_ocr_service.dart';

class LineHeuristics {
  /// Enhanced vendor detection using hybrid approach (position + text analysis)
  String? detectMerchant(List<String> lines) {
    print('🔍 MAGIC VENDOR: Starting hybrid vendor detection with ${lines.length} lines');
    
    if (lines.isEmpty) {
      print('🔍 MAGIC VENDOR: No lines to process');
      return null;
    }
    
    // Strategy 1: Position-based detection (prioritizes top lines, larger text)
    final positionBasedVendor = _detectVendorByPosition(lines);
    if (positionBasedVendor != null) {
      print('🔍 MAGIC VENDOR: Position-based detection found: "$positionBasedVendor"');
      return positionBasedVendor;
    }
    
    // Strategy 2: Traditional multi-line detection
    final multiLineVendor = _detectVendorByMultiLine(lines);
    if (multiLineVendor != null) {
      print('🔍 MAGIC VENDOR: Multi-line detection found: "$multiLineVendor"');
      return multiLineVendor;
    }
    
    // Strategy 3: Traditional single-line detection
    final singleLineVendor = _detectVendorBySingleLine(lines);
    if (singleLineVendor != null) {
      print('🔍 MAGIC VENDOR: Single-line detection found: "$singleLineVendor"');
      return singleLineVendor;
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
    
    if (bestVendor != null && bestScore > 0.4) {
      print('🔍 MAGIC VENDOR: Position-based vendor detected: "$bestVendor" (score: $bestScore)');
      return bestVendor;
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
      
      final score = _scoreName(combined);
      print('🔍 MAGIC VENDOR: Combined lines score: $score');
      
      if (score > 0.4) {
        print('🔍 MAGIC VENDOR: Combined lines passed threshold! Returning: "$combined"');
        return combined;
      }
    }
  }
  
  return null;
}

// Add these helper methods
bool _isDateAddressOrPhone(String line) {
  final upper = line.toUpperCase();
  
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
  final upper = line.toUpperCase();
  
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
      final score = _scoreName(cleanLine);
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
    
    final upper = line.toUpperCase();
    
    // Filter out invoice/receipt numbers
    if (upper.contains('RECH.') || upper.contains('RECH NR') || upper.contains('INVOICE NO')) return true;
    if (upper.contains('RECEIPT NO') || upper.contains('RECEIPT #') || upper.contains('INVOICE #')) return true;
    
    // Filter out table/seating info
    if (upper.contains('TISCH') || upper.contains('TABLE') || upper.contains('SEAT')) return true;
    
    // Filter out payment methods
    if (upper.contains('BAR') || upper.contains('CASH') || upper.contains('CREDIT')) return true;
    
    // Filter out postal codes and addresses
    if (RegExp(r'^\d{4,5}\s+[A-Z]').hasMatch(upper)) return true; // Swiss postal code pattern
    if (RegExp(r'^\d{4,5}\s+[A-Z][a-z]+$').hasMatch(line)) return true; // Postal code + city name
    
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
    
    return false;
  }

  /// Check if a line contains menu items, quantities, or prices
  /// Enhanced scoring for position-based vendor detection
  double _calculatePositionBasedVendorScore(String line, int lineIndex, int totalLines) {
    double score = 0.0;
    final upper = line.toUpperCase();
    
    // Higher weight for top lines (position matters more)
    final positionWeight = (totalLines - lineIndex) / totalLines;
    score += positionWeight * 0.4; // 40% weight for position
    
    // Boost for lines that look like company names (proper case, reasonable length)
    if (line.contains(RegExp(r'^[A-Z][a-z]+(\s+[A-Z][a-z]+)*$'))) {
      score += 0.3; // 30% boost for proper case company names
      print('🔍 MAGIC VENDOR: Line "$line" matches company name pattern - +0.3 score');
    }
    
    // Boost for common business keywords
    if (upper.contains('STORE') || upper.contains('SHOP') || upper.contains('MARKET') || 
        upper.contains('SUPERMARKET') || upper.contains('RESTAURANT') || upper.contains('CAFE') ||
        upper.contains('HOTEL') || upper.contains('PHARMACY') || upper.contains('GAS') ||
        upper.contains('STATION') || upper.contains('CENTER') || upper.contains('MALL')) {
      score += 0.2; // 20% boost for business keywords
      print('🔍 MAGIC VENDOR: Line "$line" contains business keywords - +0.2 score');
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
    
    print('🔍 MAGIC VENDOR: Position-based final score for "$line": $score');
    return score;
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
}



