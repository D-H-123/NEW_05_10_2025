// lib/services/ocr/mlkit_ocr_service.dart
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'i_ocr_service.dart';
import 'parcer/receipt_parser.dart';

/// Concrete OCR service using ML Kit on-device text recognition.
/// - Returns both raw text and parsed receipt structure.
/// - Parsing is delegated to ReceiptParser (testable separately).
class MlKitOcrService implements IOcrService {
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  final ReceiptParser _parser;

  MlKitOcrService({ReceiptParser? parser}) : _parser = parser ?? ReceiptParser();

  @override
  Future<OcrResult> processImage(File image) async {
    print('🔍 MAGIC: Starting OCR process for image: ${image.path}');
    
    try {
      final raw0 = await extractRawText(image);
      print('🔍 MAGIC: Raw OCR text length: ${raw0.length}');
      print('🔍 MAGIC: Raw OCR text preview: ${raw0.substring(0, raw0.length > 300 ? 300 : raw0.length)}...');

      // We also want positional data: blocks -> lines mapping with bounding boxes
      final inputImage = InputImage.fromFile(image);
      final recognized = await _textRecognizer.processImage(inputImage);

      final List<OcrLine> lines = [];
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final box = line.boundingBox;
          lines.add(OcrLine(
            line.text,
            left: box.left,
            top: box.top,
            width: box.width,
            height: box.height,
          ));
        }
      }
      
      print('🔍 MAGIC: Found ${lines.length} OCR lines');
      if (lines.isNotEmpty) {
        print('🔍 MAGIC: First few lines:');
        for (int i = 0; i < (lines.length > 5 ? 5 : lines.length); i++) {
          print('  Line $i: "${lines[i].text}"');
        }
      }

      // Parse the raw text directly without corrections for now
      print('🔍 MAGIC: Starting receipt parsing...');
      var parsed = _parser.parse(raw0, lines);
      
      print('🔍 MAGIC: Parsing results:');
      print('  Vendor: ${parsed.vendor}');
      print('  Total: ${parsed.total}');
      print('  Currency: ${parsed.currency}');
      print('  Date: ${parsed.date}');
      print('  Line items: ${parsed.lineItems.length}');

      return OcrResult(
        rawText: raw0,
        lines: lines,
        vendor: parsed.vendor,
        date: parsed.date,
        total: parsed.total,
        currency: parsed.currency,
        category: parsed.category,
        lineItems: parsed.lineItems,
        totalsBreakdown: parsed.totals,
      );
    } catch (e) {
      print('❌ MAGIC: OCR processing failed with error: $e');
      rethrow;
    }
  }

  @override
  Future<String> extractRawText(File image) async {
    final inputImage = InputImage.fromFile(image);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  @override
  void dispose() {
    _textRecognizer.close();
  }
}
