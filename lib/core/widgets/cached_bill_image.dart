import 'dart:io';
import 'package:flutter/material.dart';

/// ✅ Optimized: Cached image widget for bill receipts
/// Handles both local files with memory caching
class CachedBillImage extends StatelessWidget {
  final String imagePath;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;

  const CachedBillImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth = 200,
    this.cacheHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    // Local file - use FileImage with caching
    final file = File(imagePath);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Icon(Icons.error_outline, color: Colors.grey),
        ),
      );
    } else {
      // File doesn't exist - show placeholder
      return Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }
  }
}

