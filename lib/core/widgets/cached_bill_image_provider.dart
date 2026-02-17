import 'dart:io';
import 'package:flutter/material.dart';

/// ✅ Optimized: ImageProvider for DecorationImage that supports caching
/// Uses FileImage with resize optimization for memory efficiency
/// This is a simple wrapper that applies ResizeImage for memory optimization
class CachedBillImageProvider extends FileImage {
  final int? cacheWidth;
  final int? cacheHeight;

  CachedBillImageProvider({
    required String imagePath,
    this.cacheWidth = 200,
    this.cacheHeight = 200,
  }) : super(File(imagePath));

  /// Get the resized image provider for use in DecorationImage
  ImageProvider get resized {
    if (cacheWidth != null || cacheHeight != null) {
      return ResizeImage(
        this,
        width: cacheWidth,
        height: cacheHeight,
      );
    }
    return this;
  }
}

