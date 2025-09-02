// lib/services/ocr/parser/receipt_parser.dart
import '../i_ocr_service.dart';
import 'helpers/regex_util.dart';
import 'helpers/line_heuristics.dart';

class ParsedReceipt {
  final String? vendor;
  final DateTime? date;
  final double? total;
  final String? currency;
  final String? category;
  final List<Map<String, dynamic>> lineItems;
  final Map<String, double> totals;

  ParsedReceipt({
    this.vendor,
    this.date,
    this.total,
    this.currency,
    this.category,
    this.lineItems = const [],
    this.totals = const {},
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
    
    final normalized = _preprocess(rawText);
    final lines = normalized.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    
    print('🔍 MAGIC PARSER: After preprocessing, found ${lines.length} lines');
    if (lines.isNotEmpty) {
      print('🔍 MAGIC PARSER: First 5 lines:');
      for (int i = 0; i < (lines.length > 5 ? 5 : lines.length); i++) {
        print('  Line $i: "${lines[i]}"');
      }
    }

    // Vendor detection: top N lines heuristics (ignore phone/address)
    print('🔍 MAGIC PARSER: Starting vendor detection...');
    final vendor = _heuristics.detectMerchant(lines);
    print('🔍 MAGIC PARSER: Detected vendor: "$vendor"');

    // Date detection
    print('🔍 MAGIC PARSER: Starting date detection...');
    final date = _rx.findFirstDate(normalized);
    print('🔍 MAGIC PARSER: Detected date: $date');

    // Enhanced currency detection
    print('🔍 MAGIC PARSER: Starting currency detection...');
    String? currency = _rx.detectCurrency(normalized);
    if (currency == null) {
      currency = _rx.findCurrencySymbol(normalized);
    }
    print('🔍 MAGIC PARSER: Detected currency: "$currency"');

    // Totals detection: first look for explicit keywords; else fallback to max monetary near the end
    print('🔍 MAGIC PARSER: Starting total detection...');
    final totalResult = _rx.findTotalByKeywords(lines) ?? _rx.findFallbackTotal(lines);
    final total = totalResult?.amount;
    final currencyFromTotal = totalResult?.currency ?? currency;
    print('🔍 MAGIC PARSER: Detected total: $total');
    print('🔍 MAGIC PARSER: Currency from total: "$currencyFromTotal"');

    // Subtotal / tax
    final totalsMap = <String, double>{};
    final subtotalVal = _rx.findAmountForLabel(lines, ['SUBTOTAL']);
    if (subtotalVal != null) totalsMap['subtotal'] = subtotalVal;
    final taxVal = _rx.findAmountForLabel(lines, ['TAX', 'VAT', 'SALES TAX']);
    if (taxVal != null) totalsMap['tax'] = taxVal;

    // Line items
    print('🔍 MAGIC PARSER: Starting line items extraction...');
    final items = _heuristics.extractLineItems(lines);
    print('🔍 MAGIC PARSER: Extracted ${items.length} line items');

    // Category inference: by merchant name first, then fallback by keywords in text
    String? category;
    if (vendor != null) {
      final vUp = vendor.toUpperCase();
      if (vUp.contains('WALMART')) category = 'Groceries';
      if (vUp.contains('TESCO')) category = 'Groceries';
      if (vUp.contains('SHELL') || vUp.contains('BP')) category = 'Transport';
      if (vUp.contains('MCDONALD') || vUp.contains('STARBUCKS')) category = 'Food & Dining';
    }
    category ??= _rx.inferCategoryFromText(normalized);
    print('🔍 MAGIC PARSER: Detected category: "$category"');

    final result = ParsedReceipt(
      vendor: vendor,
      date: date,
      total: total,
      currency: currencyFromTotal,
      category: category,
      lineItems: items,
      totals: totalsMap,
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
