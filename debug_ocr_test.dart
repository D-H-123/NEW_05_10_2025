import 'dart:io';
import 'lib/core/services/ocr/mlkit_ocr_service.dart';
import 'lib/core/services/ocr/parcer/receipt_parser.dart';
import 'lib/core/services/ocr/parcer/helpers/regex_util.dart';

void main() async {
  print('🔍 DEBUG: Starting OCR pipeline debug test');
  
  // Test with the provided receipt image
  const imagePath = 'assets/test_receipts/ReceiptSwiss.jpg';
  final imageFile = File(imagePath);
  
  if (!imageFile.existsSync()) {
    print('❌ DEBUG: Test image not found at $imagePath');
    return;
  }
  
  print('🔍 DEBUG: Found test image: $imagePath');
  
  // Create OCR service
  final ocrService = MlKitOcrService();
  
  try {
    print('🔍 DEBUG: Starting OCR processing...');
    final result = await ocrService.processImage(imageFile);
    
    print('\n🔍 DEBUG: OCR Results:');
    print('Raw text length: ${result.rawText.length}');
    print('Raw text preview: ${result.rawText.substring(0, result.rawText.length > 500 ? 500 : result.rawText.length)}...');
    print('Lines count: ${result.lines.length}');
    print('Vendor: ${result.vendor}');
    print('Total: ${result.total}');
    print('Currency: ${result.currency}');
    print('Date: ${result.date}');
    print('Line items count: ${result.lineItems.length}');
    
    print('\n🔍 DEBUG: All OCR Lines:');
    for (int i = 0; i < result.lines.length; i++) {
      print('Line $i: "${result.lines[i].text}"');
    }
    
    print('\n🔍 DEBUG: Line Items:');
    for (int i = 0; i < result.lineItems.length; i++) {
      final item = result.lineItems[i];
      print('Item $i: ${item['name']} - ${item['total']} ${result.currency}');
    }
    
    // Test regex patterns directly
    print('\n🔍 DEBUG: Testing regex patterns directly...');
    final regexUtil = RegexUtil();
    final lines = result.lines.map((line) => line.text.trim()).where((s) => s.isNotEmpty).toList();
    
    print('🔍 DEBUG: Testing total detection...');
    final totalResult = regexUtil.findTotalByKeywords(lines);
    print('Total detection result: $totalResult');
    
    // Test currency detection
    print('🔍 DEBUG: Testing currency detection...');
    final currency = regexUtil.detectCurrency(result.rawText);
    print('Currency detection result: $currency');
    
  } catch (e) {
    print('❌ DEBUG: Error during OCR processing: $e');
    print('Stack trace: ${StackTrace.current}');
  } finally {
    ocrService.dispose();
  }
}
