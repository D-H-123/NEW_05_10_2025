import 'package:flutter/material.dart';
import 'dart:io';
import 'edge_detection_preview.dart';

/// Simple, user-friendly edge detection dialog
/// Replaces complex technical edge detection with simple guidance
class SimpleEdgeDetectionDialog extends StatefulWidget {
  final File imageFile;
  final List<Offset> detectedCorners;

  const SimpleEdgeDetectionDialog({
    super.key,
    required this.imageFile,
    required this.detectedCorners,
  });

  @override
  State<SimpleEdgeDetectionDialog> createState() => _SimpleEdgeDetectionDialogState();
}

class _SimpleEdgeDetectionDialogState extends State<SimpleEdgeDetectionDialog> {
  late List<Offset> displayCorners;
  int? draggingCorner;

  @override
  void initState() {
    super.initState();
    // Initialize with empty corners - EdgeDetectionPreview will calculate them
    displayCorners = [];
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85, // Increased height for better receipt visibility
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header - compact for more receipt space
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12), // Reduced padding
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.crop_free,
                    color: Colors.blue,
                    size: 28, // Reduced from 32
                  ),
                  const SizedBox(height: 8), // Reduced from 12
                  const Text(
                    'Adjust Receipt Corners',
                    style: TextStyle(
                      fontSize: 18, // Reduced from 20
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4), // Reduced from 8
                  Text(
                    'Drag the corners to match your receipt edges',
                    style: TextStyle(
                      fontSize: 13, // Reduced from 14
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Enhanced edge detection preview - reduced margins for more space
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 12), // Reduced margins
                child: EdgeDetectionPreview(
                  imageFile: widget.imageFile,
                  detectedCorners: displayCorners,
                  onCornersChanged: (corners) {
                    setState(() {
                      displayCorners = corners;
                    });
                  },
                  showGuides: true,
                  showAccuracy: true,
                ),
              ),
            ),
            
            // Action buttons - made smaller for edge detection priority
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20), // Reduced top padding
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(null);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10), // Reduced from 16
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8), // Reduced from 12
                        ),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 14, // Reduced from 16
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12), // Reduced from 16
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(displayCorners);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10), // Reduced from 16
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8), // Reduced from 12
                        ),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(
                          fontSize: 14, // Reduced from 16
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for drawing corner connections
class CornerConnectionPainter extends CustomPainter {
  final List<Offset> corners;

  CornerConnectionPainter(this.corners);

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;

    // Light connecting lines (diagonal)
    final lightPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Bold horizontal and vertical lines
    final boldPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw light connecting lines (diagonal)
    for (int i = 0; i < 4; i++) {
      final next = (i + 1) % 4;
      canvas.drawLine(corners[i], corners[next], lightPaint);
    }

    // Draw bold horizontal and vertical lines
    // Top horizontal line
    canvas.drawLine(corners[0], corners[1], boldPaint);
    // Right vertical line
    canvas.drawLine(corners[1], corners[2], boldPaint);
    // Bottom horizontal line
    canvas.drawLine(corners[2], corners[3], boldPaint);
    // Left vertical line
    canvas.drawLine(corners[3], corners[0], boldPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
