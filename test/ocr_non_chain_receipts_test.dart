import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_receipt/core/models/custom_category.dart';
import 'package:smart_receipt/core/services/ocr/i_ocr_service.dart';
import 'package:smart_receipt/core/services/ocr/parcer/helpers/regex_util.dart';
import 'package:smart_receipt/core/services/ocr/parcer/receipt_parser.dart';

/// Tests for **non-chain** (independent merchant) receipts with slightly
/// difficult formatting: ambiguous labels, different date formats, no known
/// chain name. Category inference may run (keyword-based) and uses
/// CategoryService.allCategories, so Hive is initialized in setUpAll.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory' ||
          methodCall.method == 'getTemporaryDirectory') {
        return Directory.systemTemp.path;
      }
      return null;
    });
    final dir = Directory.systemTemp.createTempSync('smart_receipt_hive_test');
    await Hive.initFlutter(dir.path);
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CustomCategoryAdapter());
    }
    await Hive.openBox<CustomCategory>('customCategoriesBox');
  });

  group('RegexUtil — difficult non-chain receipt lines', () {
    late RegexUtil rx;

    setUp(() {
      rx = RegexUtil();
    });

    test('findTotalCandidates returns amounts from difficult receipt with Subtotal and Amount Due', () {
      final lines = [
        "Joe's Corner Store",
        'Subtotal    18.50',
        'Tax          1.48',
        'Amount Due  19.98',
      ];
      final candidates = rx.findTotalCandidates(lines, limit: 10);
      expect(candidates, isNotEmpty);
      final amounts = candidates.map((c) => c.amount).toList();
      expect(amounts, contains(18.50));
    });

    test('findTotalCandidates includes both subtotal and total for ambiguous receipt', () {
      final lines = [
        "Maria's Café",
        'Coffee    4.50',
        'Pastry    3.00',
        'Subtotal  7.50',
        'VAT       0.75',
        'Total     8.25',
      ];
      final candidates = rx.findTotalCandidates(lines, limit: 10);
      expect(candidates.map((c) => c.amount), contains(8.25));
      expect(candidates.any((c) => c.amount == 8.25), isTrue);
    });

    test('findFirstDate parses dd-mm-yyyy style in non-chain receipt', () {
      final text = "Riverside Pharmacy\nReceipt 23-09-2024\nTotal 45.00";
      final date = rx.findFirstDate(text);
      expect(date, isNotNull);
      expect(date!.year, 2024);
      expect(date.month, 9);
      expect(date.day, 23);
    });

    test('findFirstDate parses "Date: 15 Jan 2025" style', () {
      final text = "Local Hardware Store\nDate: 15 Jan 2025\nTotal \$122.00";
      final date = rx.findFirstDate(text);
      expect(date, isNotNull);
      expect(date!.year, 2025);
      expect(date.month, 1);
      expect(date.day, 15);
    });

    test('detectCurrency finds GBP in non-chain receipt', () {
      final text = "London Bookshop\nTotal £29.99";
      expect(rx.detectCurrency(text), 'GBP');
    });
  });

  group('ReceiptParser — non-chain difficult receipts', () {
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

    test('parse independent pizza shop: vendor, total in candidates, date, currency', () {
      const raw = '''
Luigi's Pizza
123 Oak Street
Tel: 555-0123
Date: 12/08/24  3:45 PM

Margherita    12.00
Soda            2.50
Subtotal       14.50
Tax             1.16
TOTAL         \$15.66
''';
      final lines = linesFromText(raw);
      final result = parser.parse(raw, lines);

      expect(result.vendor, isNotNull);
      expect(result.vendor!.toLowerCase(), contains('luigi'));
      expect(result.currency, 'USD');
      expect(result.date, isNotNull);
      expect(result.totalCandidates, isNotEmpty);
      expect(result.totalCandidates.any((c) => c.amount == 15.66), isTrue);
      expect(result.total != null && result.total! >= 14.0 && result.total! <= 16.0, isTrue);
    });

    test('parse pharmacy receipt with "Amount Due" and no \$ symbol on total', () {
      const raw = '''
Riverside Pharmacy
456 Health Ave
23-09-2024

Aspirin    5.99
Vitamins  12.49
Subtotal  18.48
Tax        1.48
Amount Due 19.96
''';
      final lines = linesFromText(raw);
      final result = parser.parse(raw, lines);

      expect(result.vendor, isNotNull);
      expect(result.date, isNotNull);
      expect(result.totalCandidates, isNotEmpty);
      final maxAmount = result.totalCandidates.map((c) => c.amount).reduce((a, b) => a > b ? a : b);
      expect(maxAmount >= 18.0 && maxAmount <= 20.0, isTrue);
    });

    test('parse café receipt with European-style total label', () {
      const raw = '''
Maria's Café
30.07.2024
Coffee    4.50
Cake      3.20
Summe     7.70
MwSt      0.77
Total     8.47
''';
      final lines = linesFromText(raw);
      final result = parser.parse(raw, lines);

      expect(result.vendor, isNotNull);
      expect(result.total, 8.47);
      expect(result.date, isNotNull);
      expect(result.totalCandidates, isNotEmpty);
    });

    test('parse hardware store with messy spacing and Amount Due', () {
      const raw = '''
  Bob's  Hardware
  Receipt 15 Jan 2025
  Nails    12.00
  Paint    45.00
  Subtotal 57.00
  Tax       4.56
  Amount Due  61.56
''';
      final lines = linesFromText(raw);
      final result = parser.parse(raw, lines);

      expect(result.vendor, isNotNull);
      expect(result.date, isNotNull);
      expect(result.totalCandidates, isNotEmpty);
      final amounts = result.totalCandidates.map((c) => c.amount).toList();
      expect(amounts.any((a) => a >= 57.0 && a <= 62.0), isTrue);
    });

    test('parse bookshop with GBP and no clear TOTAL line (total on same line as label)', () {
      const raw = '''
London Bookshop
High Street
Date: 01/02/2025

Book Title    29.99
Total £29.99
''';
      final lines = linesFromText(raw);
      final result = parser.parse(raw, lines);

      expect(result.vendor, isNotNull);
      expect(result.total, 29.99);
      expect(result.currency, 'GBP');
      expect(result.date, isNotNull);
    });
  });
}
