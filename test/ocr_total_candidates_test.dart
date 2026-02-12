import 'package:flutter_test/flutter_test.dart';
import 'package:smart_receipt/core/services/ocr/parcer/helpers/regex_util.dart';

void main() {
  test('findTotalCandidates returns total over subtotal', () {
    final rx = RegexUtil();
    final lines = [
      'SUBTOTAL 10.00',
      'TAX 1.00',
      'TOTAL 11.00',
    ];

    final candidates = rx.findTotalCandidates(lines);
    expect(candidates, isNotEmpty);
    expect(candidates.map((c) => c.amount), contains(11.00));
  });

  test('findTotalCandidates handles total on next line', () {
    final rx = RegexUtil();
    final lines = [
      'TOTAL',
      '15.99',
    ];

    final candidates = rx.findTotalCandidates(lines);
    expect(candidates, isNotEmpty);
    expect(candidates.first.amount, 15.99);
  });
}
