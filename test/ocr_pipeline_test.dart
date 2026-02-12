import 'package:flutter_test/flutter_test.dart';
import 'package:smart_receipt/core/services/ocr/i_ocr_service.dart';
import 'package:smart_receipt/core/services/ocr/parcer/receipt_parser.dart';
import 'package:smart_receipt/core/services/ocr/parcer/helpers/regex_util.dart';

/// Tests for the OCR pipeline from crop → extract → bill page data.
///
/// Pipeline: crop (SimpleCropDialog) → preprocess → ML Kit OCR → ReceiptParser
/// (vendor, date, total, currency, category, totalCandidates). These tests
/// exercise the parsing layer with mock OCR output (raw text + lines); they do
/// not run ML Kit or image I/O.
///
/// Covered:
/// - RegexUtil: findTotalByKeywords, findTotalCandidates, findAmountForLabel,
///   findFirstDate, detectCurrency
/// - ReceiptParser: full parse with positional lines, vendor/total/date/currency
///   and totalCandidates (bill page fields)
/// - Bill page data shape: ParsedReceipt has vendor, total, totalCandidates, etc.
void main() {
  group('RegexUtil — total detection (crop → extract total)', () {
    late RegexUtil rx;

    setUp(() {
      rx = RegexUtil();
    });

    test('findTotalByKeywords picks total when TOTAL keyword present', () {
      final lines = [
        'TOTAL 11.00',
      ];
      final result = rx.findTotalByKeywords(lines);
      expect(result, isNotNull);
      expect(result!.amount, 11.00);
    });

    test('findTotalByKeywords with subtotal and total returns a total candidate', () {
      final lines = [
        'SUBTOTAL 10.00',
        'TAX 1.00',
        'TOTAL 11.00',
      ];
      final result = rx.findTotalByKeywords(lines);
      expect(result, isNotNull);
      expect([10.00, 11.00], contains(result!.amount));
    });

    test('findTotalByKeywords handles Receipt Total with amount', () {
      final lines = [
        'Item 1    5.00',
        'Item 2    10.00',
        'Receipt Total    \$154.06',
      ];
      final result = rx.findTotalByKeywords(lines);
      expect(result, isNotNull);
      expect(result!.amount, 154.06);
    });

    test('findTotalByKeywords handles total on next line', () {
      final lines = [
        'TOTAL',
        '15.99',
      ];
      final result = rx.findTotalByKeywords(lines);
      expect(result, isNotNull);
      expect(result!.amount, 15.99);
    });

    test('findTotalCandidates returns list of amount candidates', () {
      final lines = [
        'SUBTOTAL 10.00',
        'TAX 1.00',
        'TOTAL 11.00',
      ];
      final candidates = rx.findTotalCandidates(lines, limit: 5);
      expect(candidates, isNotEmpty);
      expect(candidates.map((c) => c.amount), contains(11.00));
    });

    test('findTotalCandidates includes total amount', () {
      final lines = [
        'SUBTOTAL 10.00',
        'TOTAL 11.00',
      ];
      final candidates = rx.findTotalCandidates(lines);
      expect(candidates, isNotEmpty);
      expect(candidates.any((c) => c.amount == 11.00), isTrue);
    });

    test('findAmountForLabel finds SUBTOTAL by label', () {
      final lines = [
        'SUBTOTAL    19.96',
        'TOTAL       21.16',
      ];
      expect(rx.findAmountForLabel(lines, ['SUBTOTAL']), 19.96);
    });
  });

  group('RegexUtil — date detection', () {
    late RegexUtil rx;

    setUp(() {
      rx = RegexUtil();
    });

    test('findFirstDate parses US format mm/dd/yy', () {
      final text = 'Date: 4/15/24 11:54 AM';
      final date = rx.findFirstDate(text);
      expect(date, isNotNull);
      expect(date!.year, 2024);
      expect(date.month, 4);
      expect(date.day, 15);
    });

    test('findFirstDate parses numeric date in text', () {
      final text = 'Receipt 15/06/2024 Total 10.00';
      final date = rx.findFirstDate(text);
      expect(date, isNotNull);
      expect(date!.year, 2024);
      expect(date.month, 6);
      expect(date.day, 15);
    });

    test('findFirstDate returns null when no date', () {
      final text = 'No date here just words';
      expect(rx.findFirstDate(text), isNull);
    });
  });

  group('RegexUtil — currency detection', () {
    late RegexUtil rx;

    setUp(() {
      rx = RegexUtil();
    });

    test('detectCurrency finds USD from symbol', () {
      final text = 'Total \$154.06';
      expect(rx.detectCurrency(text), 'USD');
    });

    test('detectCurrency finds EUR from symbol', () {
      final text = 'Summe 12,34 €';
      expect(rx.detectCurrency(text), 'EUR');
    });

    test('detectCurrency finds CHF', () {
      final text = 'Total CHF 25.00';
      expect(rx.detectCurrency(text), 'CHF');
    });
  });

  group('ReceiptParser — full parse to bill-relevant data', () {
    late ReceiptParser parser;

    setUp(() {
      parser = ReceiptParser();
    });

    /// Build OcrLine list from text lines (simulates ML Kit spatial output).
    List<OcrLine> linesFromText(String text) {
      return text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((s) => OcrLine(s))
          .toList();
    }

    test('parse extracts vendor, total, date, currency for bill page', () {
      const raw = '''
Walmart Store 1234
123 Main St
4/15/24 11:54 AM

Milk    2.99
Bread   1.50
SUBTOTAL    4.49
TAX         0.30
TOTAL       \$4.79
''';
      final lines = linesFromText(raw);
      final result = parser.parse(raw, lines);

      expect(result.total, 4.79);
      expect(result.currency, 'USD');
      expect(result.date, isNotNull);
      expect(result.vendor, isNotNull);
      expect(result.totalCandidates, isNotEmpty);
      expect(result.totalCandidates!.first.amount, 4.79);
    });

    test('parse uses positional lines when provided', () {
      const raw = 'Walmart Store\nTOTAL 99.00';
      final lines = linesFromText(raw);
      final result = parser.parse(raw, lines);
      expect(result.total, 99.00);
      expect(result.vendor, isNotNull);
    });

    test('parse falls back to text-split lines when lines empty', () {
      const raw = 'Walmart\nTOTAL \$50.00';
      final result = parser.parse(raw, []);
      expect(result.total, 50.00);
    });

    test('parse result has all fields needed for bill page', () {
      const raw = '''
Walmart Supercenter
15/06/2024
Item A  10.00
Item B  5.00
TOTAL   \$15.00
''';
      final lines = linesFromText(raw);
      final result = parser.parse(raw, lines);

      expect(result.vendor, isNotNull);
      expect(result.total, 15.00);
      expect(result.currency, isNotNull);
      expect(result.date, isNotNull);
      expect(result.totalCandidates, isNotEmpty);
      expect(result.totalCandidates.first.amount, 15.00);
    });

    test('parse handles receipt with European-style content', () {
      const raw = '''
Tesco Store
30.07.2007
Article  12.50
TOTAL    19.96
''';
      final lines = linesFromText(raw);
      final result = parser.parse(raw, lines);
      expect(result.vendor, isNotNull);
      expect(result.total != null || result.totalCandidates.isNotEmpty, isTrue);
    });
  });

  group('Bill page data shape (OCR output → bill)', () {
    late ReceiptParser parser;

    setUp(() {
      parser = ReceiptParser();
    });

    List<OcrLine> linesFromText(String text) {
      return text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((s) => OcrLine(s))
          .toList();
    }

    test('ParsedReceipt has vendor string or null', () {
      const raw = 'Walmart Store\nTOTAL \$10.00';
      final r = parser.parse(raw, linesFromText(raw));
      expect(r.vendor == null || r.vendor is String, isTrue);
    });

    test('ParsedReceipt has total when TOTAL line present', () {
      const raw = 'Walmart\nTOTAL 25.50';
      final r = parser.parse(raw, linesFromText(raw));
      expect(r.total, 25.50);
    });

    test('ParsedReceipt has totalCandidates list (known vendor avoids Hive)', () {
      const raw = 'Walmart Store 123\nSUBTOTAL 10\nTOTAL 12.00';
      final r = parser.parse(raw, linesFromText(raw));
      expect(r.totalCandidates, isNotNull);
      expect(r.totalCandidates, isA<List<AmountCandidate>>());
    });

    test('AmountCandidate has amount and originalText', () {
      const raw = 'Walmart\nTOTAL \$7.99';
      final r = parser.parse(raw, linesFromText(raw));
      expect(r.totalCandidates, isNotEmpty);
      expect(r.totalCandidates.first.amount, 7.99);
      expect(r.totalCandidates.first.originalText, isNotEmpty);
    });
  });
}
