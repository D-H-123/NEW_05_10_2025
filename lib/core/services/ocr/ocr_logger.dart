import 'package:flutter/foundation.dart';

class OcrLogger {
  static bool debugEnabled = false;

  static void debug(String message) {
    if (!debugEnabled) return;
    debugPrint('[OCR][DEBUG] $message');
  }

  static void info(String message) {
    debugPrint('[OCR][INFO] $message');
  }

  static void warn(String message) {
    debugPrint('[OCR][WARN] $message');
  }

  static void error(String message) {
    debugPrint('[OCR][ERROR] $message');
  }
}
