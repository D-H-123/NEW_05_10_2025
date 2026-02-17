// lib/services/ocr/parser/receipt_parser.dart
import '../i_ocr_service.dart';
import 'helpers/regex_util.dart';
import 'helpers/line_heuristics.dart';
import 'helpers/chain_database.dart';
import '../../category_service.dart';
import '../ocr_logger.dart';

// Redirect legacy print calls to structured logger
void print(Object? object) => OcrLogger.debug(object?.toString() ?? '');

class ParsedReceipt {
  final String? vendor;
  final DateTime? date;
  final double? total;
  final String? currency;
  final String? category;
  final List<Map<String, dynamic>> lineItems;
  final Map<String, double> totals;
  final List<AmountCandidate> totalCandidates;

  ParsedReceipt({
    this.vendor,
    this.date,
    this.total,
    this.currency,
    this.category,
    this.lineItems = const [],
    this.totals = const {},
    this.totalCandidates = const [],
  });
}

class ReceiptParser {
  final RegexUtil _rx;
  final LineHeuristics _heuristics;

  ReceiptParser({RegexUtil? rx, LineHeuristics? heuristics})
      : _rx = rx ?? RegexUtil(),
        _heuristics = heuristics ?? LineHeuristics();

  /// Parse raw text and optional lines (positional) into structured receipt.
  ParsedReceipt parse(String rawText, List<OcrLine> linesPositional) {
    print('🔍 MAGIC PARSER: Starting to parse receipt');
    print('🔍 MAGIC PARSER: Raw text length: ${rawText.length}');
    print('🔍 MAGIC PARSER: Positional lines count: ${linesPositional.length}');
    
    final normalized = _preprocess(rawText);
    
    // Use positional lines if available, otherwise fallback to text splitting
    List<String> lines;
    if (linesPositional.isNotEmpty) {
      lines = linesPositional.map((line) => line.text.trim()).where((s) => s.isNotEmpty).toList();
      print('🔍 MAGIC PARSER: Using positional lines: ${lines.length}');
    } else {
      lines = normalized.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      print('🔍 MAGIC PARSER: Using text-split lines: ${lines.length}');
    }
    
    print('🔍 MAGIC PARSER: After preprocessing, found ${lines.length} lines');
    if (lines.isNotEmpty) {
      print('🔍 MAGIC PARSER: First 5 lines:');
      for (int i = 0; i < (lines.length > 5 ? 5 : lines.length); i++) {
        print('  Line $i: "${lines[i]}"');
      }
    }
    
    // DEBUG: Print ALL lines to find where $75.00 is coming from
    print('🔍 DEBUG: ALL LINES FOR TOTAL DETECTION:');
    print('=' * 80);
    for (int i = 0; i < lines.length; i++) {
      print('Line $i: "${lines[i]}"');
    }
    print('=' * 80);
    
    // DEBUG: Look specifically for lines containing "TOTAL" or amounts
    print('🔍 DEBUG: LINES CONTAINING TOTAL OR AMOUNTS:');
    print('=' * 80);
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final upperLine = line.toUpperCase();
      if (upperLine.contains('TOTAL') || 
          upperLine.contains('AMOUNT') || 
          RegExp(r'\d+\.\d{2}').hasMatch(line) ||
          RegExp(r'\$\d+').hasMatch(line) ||
          RegExp(r'CHF\s*\d+').hasMatch(upperLine)) {
        print('Line $i: "$line"');
      }
    }
    print('=' * 80);

    // Vendor detection: top N lines heuristics (ignore phone/address)
    print('🔍 MAGIC PARSER: Starting vendor detection...');
    final vendorResult = _heuristics.detectMerchantWithConfidence(lines);
    final vendor = vendorResult?.name;
    print('🔍 MAGIC PARSER: Detected vendor: "$vendor" (confidence: ${vendorResult?.confidence})');

    // Date detection
    print('🔍 MAGIC PARSER: Starting date detection...');
    print('🔍 MAGIC PARSER: Text being analyzed for date: "${normalized.length > 200 ? "${normalized.substring(0, 200)}..." : normalized}"');
    final date = _rx.findFirstDate(normalized);
    print('🔍 MAGIC PARSER: Detected date: $date');

    // Enhanced currency detection
    print('🔍 MAGIC PARSER: Starting currency detection...');
    String? currency = _rx.detectCurrency(normalized);
    currency ??= _rx.detectCurrency(normalized);
    print('🔍 MAGIC PARSER: Detected currency: "$currency"');

    // Totals detection: use enhanced keyword-based detection with fallback
    print('🔍 MAGIC PARSER: Starting total detection...');
    AmountMatch? totalResult;
    double? total;
    try {
      totalResult = _rx.findTotalByKeywords(lines);
      total = totalResult?.amount;
      print('🔍 MAGIC PARSER: findTotalByKeywords() completed successfully');
    } catch (e, stackTrace) {
      OcrLogger.error('Exception in findTotalByKeywords(): $e');
      OcrLogger.error('Stack trace: $stackTrace');
      total = null;
    }
    final currencyFromTotal = totalResult?.currency ?? currency;
    print('🔍 MAGIC PARSER: Detected total: $total');
    print('🔍 MAGIC PARSER: Currency from total: "$currencyFromTotal"');
    final totalCandidates = _rx.findTotalCandidates(lines);

    // Subtotal / tax
    final totalsMap = <String, double>{};
    final subtotalVal = _rx.findAmountForLabel(lines, ['SUBTOTAL']);
    if (subtotalVal != null) totalsMap['subtotal'] = subtotalVal;
    final taxVal = _rx.findAmountForLabel(lines, ['TAX', 'VAT', 'SALES TAX']);
    if (taxVal != null) totalsMap['tax'] = taxVal;

    // Line items
    print('🔍 MAGIC PARSER: Starting line items extraction...');
    final items = _heuristics.extractLineItems(lines, linesPositional);
    print('🔍 MAGIC PARSER: Extracted ${items.length} line items');

    // Validate total against sum of line items when possible
    if (total != null && items.isNotEmpty) {
      final itemsSum = items
          .map((item) => item['total'] as double? ?? item['price'] as double? ?? 0.0)
          .fold(0.0, (a, b) => a + b);
      final tolerance = (itemsSum * 0.02).clamp(0.05, 1.0);
      final diff = (itemsSum - total).abs();
      if (itemsSum > 0 && diff > tolerance) {
        print('🔍 MAGIC PARSER: Total mismatch vs items sum. total=$total, itemsSum=$itemsSum, diff=$diff, tolerance=$tolerance');
        final fallbackTotal = _rx.findTotalNearAmount(lines, itemsSum, tolerance);
        if (fallbackTotal != null) {
          print('🔍 MAGIC PARSER: Using total aligned with item sum: ${fallbackTotal.amount}');
          total = fallbackTotal.amount;
        } else {
          print('🔍 MAGIC PARSER: No better total found near items sum');
        }
      }
    }

    // Category inference: by chain database first, then fallback by keywords in text
    String? category;
    if (vendor != null) {
      // Try chain database first (most accurate)
      category = ChainDatabase.getCategory(vendor);
      print('🔍 MAGIC PARSER: Chain database category for "$vendor": "$category"');
      
      // Normalize category name using centralized service
      if (category != null) {
        category = CategoryService.normalizeCategory(category);
        print('🔍 MAGIC PARSER: Normalized category: "$category"');
      }
      
      // Fallback to heuristic category detection
      if (category == null) {
        final vUp = vendor.toUpperCase();
        if (vUp.contains('WALMART')) category = 'Groceries';
        if (vUp.contains('TESCO')) category = 'Groceries';
        if (vUp.contains('SHELL') || vUp.contains('BP')) category = 'Transportation';
        if (vUp.contains('MCDONALD') || vUp.contains('STARBUCKS')) category = 'Food & Dining';
        print('🔍 MAGIC PARSER: Heuristic category for "$vendor": "$category"');
      }
    }
    category ??= _rx.inferCategoryFromText(normalized);
    
    // Normalize the final category
    if (category != null) {
      category = CategoryService.normalizeCategory(category);
    }
    
    print('🔍 MAGIC PARSER: Final detected category: "$category"');

    final result = ParsedReceipt(
      vendor: vendor,
      date: date,
      total: total,
      currency: currencyFromTotal,
      category: category,
      lineItems: items,
      totals: totalsMap,
      totalCandidates: totalCandidates,
    );
    
    print('🔍 MAGIC PARSER: Final parsing result:');
    print('  Vendor: "${result.vendor}"');
    print('  Total: ${result.total}');
    print('  Currency: "${result.currency}"');
    print('  Date: ${result.date}');
    print('  Category: "${result.category}"');
    print('  Line items: ${result.lineItems.length}');
    
    return result;
  }

  String _preprocess(String text) {
    // normalize whitespace, unify newlines, remove weird chars
    var s = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    // Normalize multiple spaces to single
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    // Trim surrounding whitespace on each line
    s = s.split('\n').map((l) => l.trim()).join('\n');
    return s;
  }
}


