// test/receipt_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_receipt/core/services/ocr/parcer/receipt_parser.dart';
import 'package:smart_receipt/core/services/ocr/i_ocr_service.dart';

void main() {
  test('parse sample receipt text', () {
    final parser = ReceiptParser();

    const sample = '''
Mock Store
123 Main St
Tel: 0123 456 789

01/08/2025

1x Item A 3.50
Item B 6.00
SUBTOTAL 9.50
TAX 0.95
TOTAL 10.45
''';

    final lines = sample.split('\n').map((s) => OcrLine(s)).toList();
    final parsed = parser.parse(sample, lines);

    expect(parsed.vendor, contains('Mock Store'));
    expect(parsed.date, isNotNull);
    expect(parsed.total, closeTo(10.45, 0.01));
    expect(parsed.lineItems.length, greaterThanOrEqualTo(1));
    expect(parsed.totals.containsKey('tax'), true);
  });
}
