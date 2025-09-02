// lib/services/ocr/i_ocr_service.dart
import 'dart:io';

class OcrLine {
  final String text;
  final double? left;
  final double? top;
  final double? width;
  final double? height;

  OcrLine(this.text, {this.left, this.top, this.width, this.height});
}

class OcrResult {
  final String rawText;
  final List<OcrLine> lines;
  final String? vendor;
  final DateTime? date;
  final double? total;
  final String? currency;
  final String? category;
  final List<Map<String, dynamic>> lineItems; // {'name', 'qty', 'price'}
  final Map<String, double> totalsBreakdown; // subtotal,tax,etc.

  OcrResult({
    required this.rawText,
    required this.lines,
    this.vendor,
    this.date,
    this.total,
    this.currency,
    this.category,
    this.lineItems = const [],
    this.totalsBreakdown = const {},
  });
}

abstract class IOcrService {
  /// Process image file and return a parsed OcrResult
  Future<OcrResult> processImage(File image);

  /// Raw OCR only: return RecognizedText or raw string (optional)
  Future<String> extractRawText(File image);

  void dispose();
}
