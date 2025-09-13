// // lib/services/ocr/mlkit_ocr_service.dart
// import 'dart:io';
// import 'dart:async';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
// import 'i_ocr_service.dart';
// import 'parcer/receipt_parser.dart';
// import '../image_preprocessing_service.dart';

// /// Concrete OCR service using ML Kit on-device text recognition.
// /// - Returns both raw text and parsed receipt structure.
// /// - Parsing is delegated to ReceiptParser (testable separately).
// class MlKitOcrService implements IOcrService {
//   final TextRecognizer _textRecognizer =
//       TextRecognizer(script: TextRecognitionScript.latin);

//   final ReceiptParser _parser;
//   final ImagePreprocessingService _preprocessor;

//   MlKitOcrService({
//     ReceiptParser? parser,
//     ImagePreprocessingService? preprocessor,
//   }) : _parser = parser ?? ReceiptParser(),
//        _preprocessor = preprocessor ?? ImagePreprocessingService();

//   @override
//   Future<OcrResult> processImage(File image) async {
//     print('🔍 MAGIC: Starting OCR process for image: ${image.path}');
    
//     try {
//       // Add timeout protection to prevent infinite OCR loops
//       final result = await Future.any([
//         _processImageInternal(image),
//         Future.delayed(const Duration(seconds: 45), () {
//           throw TimeoutException('OCR processing timed out after 45 seconds', const Duration(seconds: 45));
//         }),
//       ]);
      
//       return result;
//     } catch (e) {
//       print('❌ MAGIC: OCR processing failed with error: $e');
//       rethrow;
//     }
//   }

//   @override
//   Future<String> extractRawText(File image) async {
//     print('🔍 MAGIC: Extracting raw text from image: ${image.path}');
    
//     try {
//       final inputImage = InputImage.fromFile(image);
//       final recognizedText = await _textRecognizer.processImage(inputImage);
      
//       print('🔍 MAGIC: Raw text extracted successfully');
//       return recognizedText.text;
//     } catch (e) {
//       print('❌ MAGIC: Raw text extraction failed: $e');
//       rethrow;
//     }
//   }

//   /// Internal image processing method with timeout protection
//   Future<OcrResult> _processImageInternal(File image) async {
//     print('🔍 MAGIC: Processing image internally...');
    
//     // Step 1: Preprocess the image for better OCR accuracy
//     print('🔍 MAGIC: Starting image preprocessing...');
//     File preprocessedImage;
//     try {
//       preprocessedImage = await Future.any([
//         _preprocessor.preprocessForDocumentType(image, DocumentType.receipt),
//         Future.delayed(const Duration(seconds: 20), () {
//           throw TimeoutException('Image preprocessing timed out after 20 seconds', const Duration(seconds: 20));
//         }),
//       ]);
//       print('🔍 MAGIC: Image preprocessing completed successfully');
//     } catch (e) {
//       print('⚠️ MAGIC: Image preprocessing failed, using original image: $e');
//       preprocessedImage = image;
//     }
    
//     // Step 2: Extract text from preprocessed image
//     final raw0 = await Future.any([
//       extractRawText(preprocessedImage),
//       Future.delayed(const Duration(seconds: 15), () {
//         throw TimeoutException('Text extraction timed out after 15 seconds', const Duration(seconds: 15));
//       }),
//     ]);
//     print('🔍 MAGIC: Raw OCR text length: ${raw0.length}');
//     print('🔍 MAGIC: Raw OCR text preview: ${raw0.substring(0, raw0.length > 300 ? 300 : raw0.length)}...');
    
//     // DEBUG: Print the FULL raw OCR text to find where $75.00 is coming from
//     print('🔍 DEBUG: FULL RAW OCR TEXT:');
//     print('=' * 80);
//     print(raw0);
//     print('=' * 80);
    
//     // DEBUG: Print each line separately for better analysis
//     print('🔍 DEBUG: RAW OCR TEXT BY LINES:');
//     print('=' * 80);
//     final rawLines = raw0.split('\n');
//     for (int i = 0; i < rawLines.length; i++) {
//       print('Line $i: "${rawLines[i]}"');
//     }
//     print('=' * 80);

//     // We also want positional data: blocks -> lines mapping with bounding boxes
//     final inputImage = InputImage.fromFile(preprocessedImage);
//     final recognized = await Future.any([
//       _textRecognizer.processImage(inputImage),
//       Future.delayed(const Duration(seconds: 10), () {
//         throw TimeoutException('Text recognition timed out after 10 seconds', const Duration(seconds: 10));
//       }),
//     ]);

//     final List<OcrLine> lines = [];
//     for (final block in recognized.blocks) {
//       for (final line in block.lines) {
//         final box = line.boundingBox;
//         lines.add(OcrLine(
//           line.text,
//           left: box.left,
//           top: box.top,
//           width: box.width,
//           height: box.height,
//         ));
//       }
//     }
    
//     print('🔍 MAGIC: Found ${lines.length} OCR lines');
//     if (lines.isNotEmpty) {
//       print('🔍 MAGIC: First few lines:');
//       for (int i = 0; i < (lines.length > 5 ? 5 : lines.length); i++) {
//         print('  Line $i: "${lines[i].text}"');
//       }
//     }

//     // Parse the raw text directly without corrections for now
//     print('🔍 MAGIC: Starting receipt parsing...');
//     var parsed = _parser.parse(raw0, lines);
    
//     print('🔍 MAGIC: Parsing results:');
//     print('  Vendor: ${parsed.vendor}');
//     print('  Total: ${parsed.total}');
//     print('  Currency: ${parsed.currency}');
//     print('  Date: ${parsed.date}');
//     print('  Line items: ${parsed.lineItems.length}');

//     return OcrResult(
//       rawText: raw0,
//       lines: lines,
//       vendor: parsed.vendor,
//       date: parsed.date,
//       total: parsed.total,
//       currency: parsed.currency,
//       category: parsed.category,
//       lineItems: parsed.lineItems,
//       totalsBreakdown: parsed.totals,
//     );
//   }

//   /// Process an already preprocessed image (no additional preprocessing)
//   /// Added timeout protection to prevent infinite loops
//   Future<OcrResult> processPreprocessedImage(File preprocessedImage) async {
//     print('🔍 MAGIC: Starting OCR process for preprocessed image: ${preprocessedImage.path}');
    
//     try {
//       // Add timeout protection to prevent infinite OCR loops
//       final result = await Future.any([
//         _processPreprocessedImageInternal(preprocessedImage),
//         Future.delayed(const Duration(seconds: 30), () {
//           throw TimeoutException('OCR processing timed out after 30 seconds', const Duration(seconds: 30));
//         }),
//       ]);
      
//       return result;
//     } catch (e) {
//       print('❌ MAGIC: OCR processing failed with error: $e');
//       rethrow;
//     }
//   }

//   /// Internal OCR processing method with timeout protection
//   Future<OcrResult> _processPreprocessedImageInternal(File preprocessedImage) async {
//     print('🔍 MAGIC: Processing preprocessed image internally...');
    
//     // Extract text from preprocessed image with timeout
//     final raw0 = await Future.any([
//       extractRawText(preprocessedImage),
//       Future.delayed(const Duration(seconds: 15), () {
//         throw TimeoutException('Text extraction timed out after 15 seconds', const Duration(seconds: 15));
//       }),
//     ]);
    
//     print('🔍 MAGIC: Raw OCR text length: ${raw0.length}');
//     print('🔍 MAGIC: Raw OCR text preview: ${raw0.substring(0, raw0.length > 300 ? 300 : raw0.length)}...');

//     // Get positional data: blocks -> lines mapping with bounding boxes
//     final inputImage = InputImage.fromFile(preprocessedImage);
//     final recognized = await Future.any([
//       _textRecognizer.processImage(inputImage),
//       Future.delayed(const Duration(seconds: 10), () {
//         throw TimeoutException('Text recognition timed out after 10 seconds', const Duration(seconds: 10));
//       }),
//     ]);

//     final List<OcrLine> lines = [];
//     for (final block in recognized.blocks) {
//       for (final line in block.lines) {
//         final box = line.boundingBox;
//         lines.add(OcrLine(
//           line.text,
//           left: box.left,
//           top: box.top,
//           width: box.width,
//           height: box.height,
//         ));
//       }
//     }
    
//     print('🔍 MAGIC: Found ${lines.length} OCR lines');
//     if (lines.isNotEmpty) {
//       print('🔍 MAGIC: First few lines:');
//       for (int i = 0; i < (lines.length > 5 ? 5 : lines.length); i++) {
//         print('  Line $i: "${lines[i].text}"');
//       }
//     }

//     // Parse the raw text
//     print('🔍 MAGIC: Starting receipt parsing...');
//     var parsed = _parser.parse(raw0, lines);
    
//     print('🔍 MAGIC: Parsing results:');
//     print('  Vendor: ${parsed.vendor}');
//     print('  Total: ${parsed.total}');
//     print('  Currency: ${parsed.currency}');
//     print('  Date: ${parsed.date}');
//     print('  Line items: ${parsed.lineItems.length}');

//     return OcrResult(
//       rawText: raw0,
//       lines: lines,
//       vendor: parsed.vendor,
//       date: parsed.date,
//       total: parsed.total,
//       currency: parsed.currency,
//       category: parsed.category,
//       lineItems: parsed.lineItems,
//       totalsBreakdown: parsed.totals,
//     );
//   }

//   // REMOVED: Duplicate extractRawText method - using disabled version above

//   @override
//   void dispose() {
//     _textRecognizer.close();
//   }
// }


// lib/services/ocr/mlkit_ocr_service.dart
import 'dart:io';
import 'dart:async';
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

  // CHANGED: Removed ImagePreprocessingService dependency
  MlKitOcrService({
    ReceiptParser? parser,
  }) : _parser = parser ?? ReceiptParser();

  @override
  Future<OcrResult> processImage(File image) async {
    print('🔍 MAGIC: Starting OCR process for image: ${image.path}');
    
    try {
      // Add timeout protection to prevent infinite OCR loops
      final result = await Future.any([
        _processImageInternal(image),
        Future.delayed(const Duration(seconds: 45), () {
          throw TimeoutException('OCR processing timed out after 45 seconds', const Duration(seconds: 45));
        }),
      ]);
      
      return result;
    } catch (e) {
      print('❌ MAGIC: OCR processing failed with error: $e');
      rethrow;
    }
  }

  @override
  Future<String> extractRawText(File image) async {
    print('🔍 MAGIC: Extracting raw text from image: ${image.path}');
    
    try {
      final inputImage = InputImage.fromFile(image);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      print('🔍 MAGIC: Raw text extracted successfully');
      return recognizedText.text;
    } catch (e) {
      print('❌ MAGIC: Raw text extraction failed: $e');
      rethrow;
    }
  }

  // NEW: Enhanced method to build spatially-aware lines that maintain receipt structure
  List<OcrLine> _buildSpatiallyAwareLines(RecognizedText recognized) {
    print('🔍 ENHANCED: Building spatially-aware lines from ${recognized.blocks.length} blocks');
    
    // Collect all text elements with their positions
    List<_TextElement> elements = [];
    
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          final box = element.boundingBox;
          elements.add(_TextElement(
            text: element.text,
            left: box.left,
            top: box.top,
            right: box.right,
            bottom: box.bottom,
            width: box.width,
            height: box.height,
          ));
        }
      }
    }
    
    print('🔍 ENHANCED: Found ${elements.length} text elements');
    
    // Sort elements by vertical position (top to bottom)
    elements.sort((a, b) => a.top.compareTo(b.top));
    
    // Group elements into logical lines based on vertical proximity
    List<List<_TextElement>> lineGroups = [];
    List<_TextElement> currentLineGroup = [];
    double lastBottom = -1;
    
    for (final element in elements) {
      // If this element is significantly below the last one, start a new line
      final verticalGap = element.top - lastBottom;
      final shouldStartNewLine = verticalGap > (element.height * 0.3) && currentLineGroup.isNotEmpty;
      
      if (shouldStartNewLine) {
        if (currentLineGroup.isNotEmpty) {
          lineGroups.add(List.from(currentLineGroup));
          currentLineGroup.clear();
        }
      }
      
      currentLineGroup.add(element);
      lastBottom = element.bottom;
    }
    
    // Add the final group
    if (currentLineGroup.isNotEmpty) {
      lineGroups.add(currentLineGroup);
    }
    
    print('🔍 ENHANCED: Grouped into ${lineGroups.length} logical lines');
    
    // Build OcrLine objects from groups
    List<OcrLine> ocrLines = [];
    for (int i = 0; i < lineGroups.length; i++) {
      final group = lineGroups[i];
      
      // Sort elements in the group by horizontal position (left to right)
      group.sort((a, b) => a.left.compareTo(b.left));
      
      // Combine text with appropriate spacing
      final combinedText = _combineElementsWithSpacing(group);
      
      // Calculate bounding box for the entire line
      final minLeft = group.map((e) => e.left).reduce((a, b) => a < b ? a : b);
      final minTop = group.map((e) => e.top).reduce((a, b) => a < b ? a : b);
      final maxRight = group.map((e) => e.right).reduce((a, b) => a > b ? a : b);
      final maxBottom = group.map((e) => e.bottom).reduce((a, b) => a > b ? a : b);
      
      ocrLines.add(OcrLine(
        combinedText,
        left: minLeft,
        top: minTop,
        width: maxRight - minLeft,
        height: maxBottom - minTop,
      ));
      
      print('🔍 ENHANCED: Line $i: "$combinedText"');
    }
    
    return ocrLines;
  }
  
  // NEW: Combine text elements with intelligent spacing to preserve "Total 19.96" format
  String _combineElementsWithSpacing(List<_TextElement> elements) {
    if (elements.isEmpty) return '';
    if (elements.length == 1) return elements.first.text;
    
    final buffer = StringBuffer();
    buffer.write(elements.first.text);
    
    for (int i = 1; i < elements.length; i++) {
      final current = elements[i];
      final previous = elements[i - 1];
      
      // Calculate horizontal gap between elements
      final gap = current.left - previous.right;
      final avgWidth = (current.width + previous.width) / 2;
      final relativeGap = gap / avgWidth;
      
      // Add appropriate spacing based on gap size
      if (relativeGap > 1.0) {
        // Large gap - likely separate fields (e.g., "Total    19.96")
        buffer.write('    '); // 4 spaces for large gaps
      } else if (relativeGap > 0.3) {
        // Medium gap - normal word spacing
        buffer.write(' ');
      } else {
        // Small/no gap - elements are touching (common in amounts like "19.96")
        // No space needed
      }
      
      buffer.write(current.text);
    }
    
    return buffer.toString();
  }
  
  // NEW: Create a reconstructed text that better preserves spatial relationships
  String _createSpatiallyAwareText(List<OcrLine> lines) {
    print('🔍 ENHANCED: Creating spatially-aware text from ${lines.length} lines');
    
    final buffer = StringBuffer();
    for (int i = 0; i < lines.length; i++) {
      buffer.writeln(lines[i].text);
    }
    
    final result = buffer.toString();
    print('🔍 ENHANCED: Spatially-aware text preview: ${result.substring(0, result.length > 500 ? 500 : result.length)}...');
    
    return result;
  }

  /// Internal image processing method with timeout protection
  Future<OcrResult> _processImageInternal(File image) async {
    print('🔍 MAGIC: Processing image internally...');
    
    // REMOVED: All preprocessing code - using image directly
    
    // CHANGED: Get ML Kit recognition results directly from input image
    final inputImage = InputImage.fromFile(image);
    final recognized = await Future.any([
      _textRecognizer.processImage(inputImage),
      Future.delayed(const Duration(seconds: 15), () {
        throw TimeoutException('Text recognition timed out after 15 seconds', const Duration(seconds: 15));
      }),
    ]);
    
    // NEW: Build spatially-aware lines instead of using default ML Kit lines
    final lines = _buildSpatiallyAwareLines(recognized);
    
    // NEW: Create improved raw text from spatial lines
    final spatialRawText = _createSpatiallyAwareText(lines);
    
    // DEBUG: Compare original vs spatial text
    print('🔍 DEBUG: ORIGINAL RAW OCR TEXT:');
    print('=' * 80);
    print(recognized.text);
    print('=' * 80);
    
    print('🔍 DEBUG: ENHANCED SPATIAL RAW TEXT:');
    print('=' * 80);
    print(spatialRawText);
    print('=' * 80);
    
    print('🔍 DEBUG: ENHANCED SPATIAL TEXT BY LINES:');
    print('=' * 80);
    for (int i = 0; i < lines.length; i++) {
      print('Line $i: "${lines[i].text}"');
    }
    print('=' * 80);

    // CHANGED: Parse using the enhanced spatial text instead of original raw text
    print('🔍 MAGIC: Starting receipt parsing with enhanced spatial text...');
    var parsed = _parser.parse(spatialRawText, lines);
    
    // NEW: Fallback strategy - if spatial parsing fails, try with original text
    if (parsed.total == null || parsed.total == 0.0) {
      print('🔍 FALLBACK: Spatial parsing failed, trying with original text...');
      
      // Create basic OcrLine objects for fallback
      final fallbackLines = <OcrLine>[];
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final box = line.boundingBox;
          fallbackLines.add(OcrLine(
            line.text,
            left: box.left,
            top: box.top,
            width: box.width,
            height: box.height,
          ));
        }
      }
      
      parsed = _parser.parse(recognized.text, fallbackLines);
    }
    
    print('🔍 MAGIC: Final parsing results:');
    print('  Vendor: ${parsed.vendor}');
    print('  Total: ${parsed.total}');
    print('  Currency: ${parsed.currency}');
    print('  Date: ${parsed.date}');
    print('  Line items: ${parsed.lineItems.length}');

    // CHANGED: Return enhanced spatial text instead of original raw text
    return OcrResult(
      rawText: spatialRawText, // Use enhanced text
      lines: lines,
      vendor: parsed.vendor,
      date: parsed.date,
      total: parsed.total,
      currency: parsed.currency,
      category: parsed.category,
      lineItems: parsed.lineItems,
      totalsBreakdown: parsed.totals,
    );
  }

  /// Process an already preprocessed image (no additional preprocessing)
  /// CHANGED: Removed preprocessing logic, added enhanced spatial processing
  Future<OcrResult> processPreprocessedImage(File preprocessedImage) async {
    print('🔍 MAGIC: Starting OCR process for preprocessed image: ${preprocessedImage.path}');
    
    try {
      // Add timeout protection to prevent infinite OCR loops
      final result = await Future.any([
        _processPreprocessedImageInternal(preprocessedImage),
        Future.delayed(const Duration(seconds: 30), () {
          throw TimeoutException('OCR processing timed out after 30 seconds', const Duration(seconds: 30));
        }),
      ]);
      
      return result;
    } catch (e) {
      print('❌ MAGIC: OCR processing failed with error: $e');
      rethrow;
    }
  }

  /// Internal OCR processing method with timeout protection
  Future<OcrResult> _processPreprocessedImageInternal(File preprocessedImage) async {
    print('🔍 MAGIC: Processing preprocessed image internally...');
    
    // CHANGED: Get ML Kit recognition results directly
    final inputImage = InputImage.fromFile(preprocessedImage);
    final recognized = await Future.any([
      _textRecognizer.processImage(inputImage),
      Future.delayed(const Duration(seconds: 10), () {
        throw TimeoutException('Text recognition timed out after 10 seconds', const Duration(seconds: 10));
      }),
    ]);

    // NEW: Build spatially-aware lines
    final lines = _buildSpatiallyAwareLines(recognized);
    
    // NEW: Create improved raw text
    final spatialRawText = _createSpatiallyAwareText(lines);
    
    print('🔍 MAGIC: Enhanced OCR text length: ${spatialRawText.length}');
    print('🔍 MAGIC: Enhanced OCR text preview: ${spatialRawText.substring(0, spatialRawText.length > 300 ? 300 : spatialRawText.length)}...');

    // CHANGED: Parse the enhanced text instead of original
    print('🔍 MAGIC: Starting receipt parsing...');
    var parsed = _parser.parse(spatialRawText, lines);
    
    // NEW: Fallback strategy
    if (parsed.total == null || parsed.total == 0.0) {
      print('🔍 FALLBACK: Spatial parsing failed, trying with original text...');
      
      // Create basic OcrLine objects for fallback
      final fallbackLines = <OcrLine>[];
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final box = line.boundingBox;
          fallbackLines.add(OcrLine(
            line.text,
            left: box.left,
            top: box.top,
            width: box.width,
            height: box.height,
          ));
        }
      }
      
      parsed = _parser.parse(recognized.text, fallbackLines);
    }
    
    print('🔍 MAGIC: Parsing results:');
    print('  Vendor: ${parsed.vendor}');
    print('  Total: ${parsed.total}');
    print('  Currency: ${parsed.currency}');
    print('  Date: ${parsed.date}');
    print('  Line items: ${parsed.lineItems.length}');

    // CHANGED: Return enhanced spatial text
    return OcrResult(
      rawText: spatialRawText, // Use enhanced text
      lines: lines,
      vendor: parsed.vendor,
      date: parsed.date,
      total: parsed.total,
      currency: parsed.currency,
      category: parsed.category,
      lineItems: parsed.lineItems,
      totalsBreakdown: parsed.totals,
    );
  }

  @override
  void dispose() {
    _textRecognizer.close();
  }
}

// NEW: Helper class to represent text elements with spatial information
class _TextElement {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double width;
  final double height;
  
  _TextElement({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.width,
    required this.height,
  });
  
  @override
  String toString() => '_TextElement("$text", pos: ($left,$top), size: (${width}x$height))';
}