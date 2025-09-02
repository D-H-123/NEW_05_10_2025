// lib/services/ocr/parser/helpers/line_heuristics.dart

class LineHeuristics {
  /// Detect merchant name from receipt lines using heuristics
  String? detectMerchant(List<String> lines) {
    print('🔍 MAGIC VENDOR: Starting vendor detection with ${lines.length} lines');
    
    if (lines.isEmpty) {
      print('🔍 MAGIC VENDOR: No lines to process');
      return null;
    }
    
    // Look at the first few lines for the merchant name
    final topLines = lines.take(5).toList();
    print('🔍 MAGIC VENDOR: Processing top ${topLines.length} lines');
    
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
    final upper = line.toUpperCase();
    
    // Skip lines that are clearly not merchant names
    if (upper.contains('TOTAL') || upper.contains('SUBTOTAL') || upper.contains('TAX')) return true;
    if (upper.contains('RECEIPT') || upper.contains('INVOICE')) return true;
    if (upper.contains('DATE') || upper.contains('TIME')) return true;
    if (upper.contains('PHONE') || upper.contains('TEL')) return true;
    if (upper.contains('ADDRESS') || upper.contains('STREET')) return true;
    if (upper.contains('THANK') || upper.contains('WELCOME')) return true;
    if (upper.contains('CASHIER') || upper.contains('REGISTER')) return true;
    if (upper.contains('CARD') || upper.contains('PAYMENT')) return true;
    
    // Skip lines that are mostly numbers or special characters
    final digitCount = line.replaceAll(RegExp(r'[^0-9]'), '').length;
    final specialCharCount = line.replaceAll(RegExp(r'[a-zA-Z0-9\s]'), '').length;
    final letterCount = line.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
    
    if (digitCount > letterCount) return true;
    if (specialCharCount > letterCount * 0.5) return true;
    
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
      score += 0.3;
      print('🔍 MAGIC VENDOR: Line "$line" detected as ALL CAPS (likely bold) - +0.3 score');
    } else if (line.contains(RegExp(r'[A-Z]{3,}'))) {
      // Multiple consecutive capitals (3+) - likely emphasis
      score += 0.2;
      print('🔍 MAGIC VENDOR: Line "$line" has multiple consecutive caps - +0.2 score');
    } else if (line.contains(RegExp(r'[A-Z][a-z]+[A-Z][a-z]+'))) {
      // Mixed case with multiple capital letters - likely emphasis
      score += 0.15;
      print('🔍 MAGIC VENDOR: Line "$line" has mixed case emphasis - +0.15 score');
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
      score += 0.1;
      print('🔍 MAGIC VENDOR: Line "$line" matches company name pattern - +0.1 score');
    }
    
    print('🔍 MAGIC VENDOR: Final score for "$line": $score');
    return score;
  }

  /// Extract simple line items: name followed by price at end. Also support "qty x price"
  List<Map<String, dynamic>> extractLineItems(List<String> lines) {
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

        items.add({
          'name': name,
          'qty': qty,
          'price': totalForLine, // keep legacy key
          'total': totalForLine,
          'unitPrice': unitPrice,
        });
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
