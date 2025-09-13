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

  test('parse Swiss receipt with CHF total', () {
    final parser = ReceiptParser();

    const swissReceipt = '''
Berghotel Grosse Scheidegg
3818 Grindelwald
Familie R. Müller

Rech. Nr.: 4572
Bar
30.07.2007 / 13:29:17
Tisch: 7/01

2x Latte Macchiato 4.50 9.00
1x Gloki 5.00 5.00
1x Schweinschnitzel 22.00 22.00
1x Chässpätzli 18.50 18.50

Total 54.50 CHF
Incl. 7.6% MwSt: 3.85
Entspricht in Euro: 36.33

Es bediente Sie: Ursula
MwSt Nr.: 430 234
Tel.: 033 853 67 16
Fax: 033 853 67 19
Email: grossescheidegg@bluewin.ch
''';

    final lines = swissReceipt.split('\n').map((s) => OcrLine(s)).toList();
    final parsed = parser.parse(swissReceipt, lines);

    print('🔍 TEST: Swiss receipt parsing result:');
    print('  Vendor: ${parsed.vendor}');
    print('  Total: ${parsed.total}');
    print('  Currency: ${parsed.currency}');
    print('  Date: ${parsed.date}');

    expect(parsed.vendor, contains('Berghotel'));
    expect(parsed.total, closeTo(54.50, 0.01));
    expect(parsed.currency, 'CHF');
  });
}
