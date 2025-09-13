import 'package:flutter_test/flutter_test.dart';
import 'package:smart_receipt/core/services/ocr/parcer/helpers/line_heuristics.dart';

void main() {
  group('Vendor Detection Tests', () {
    late LineHeuristics heuristics;

    setUp(() {
      heuristics = LineHeuristics();
    });

    test('Should detect "Berghotel Grosse Scheidegg" as vendor', () {
      final lines = [
        'Berghotel',
        'Grosse Scheidegg',
        '3818 Grindelwald',
        'Familie R. Müller',
        'Rech. Nr 4572',
        'Bar',
        '30.07.2007/13:29:17',
        'Tisch 7/01',
      ];

      final vendor = heuristics.detectMerchant(lines);
      
      expect(vendor, isNotNull);
      expect(vendor, contains('Berghotel'));
      expect(vendor, contains('Grosse Scheidegg'));
      print('✅ Detected vendor: $vendor');
    });

    test('Should not detect "3818 Grindelwald" as vendor', () {
      final lines = [
        '3818 Grindelwald',
        'Rech. Nr 4572',
        'Bar',
        '30.07.2007/13:29:17',
      ];

      final vendor = heuristics.detectMerchant(lines);
      
      expect(vendor, isNull);
      print('✅ Correctly did not detect address as vendor');
    });

    test('Should not detect "Rech. Nr 4572" as vendor', () {
      final lines = [
        'Rech. Nr 4572',
        'Bar',
        '30.07.2007/13:29:17',
      ];

      final vendor = heuristics.detectMerchant(lines);
      
      expect(vendor, isNull);
      print('✅ Correctly did not detect invoice number as vendor');
    });

    test('Should detect single line business name', () {
      final lines = [
        'WALMART SUPERSTORE',
        '123 Main Street',
        'Total: \$45.67',
      ];

      final vendor = heuristics.detectMerchant(lines);
      
      expect(vendor, isNotNull);
      expect(vendor, equals('WALMART SUPERSTORE'));
      print('✅ Detected vendor: $vendor');
    });
  });
}
