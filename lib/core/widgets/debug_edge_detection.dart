import 'package:flutter/material.dart';
import 'dart:io';
import '../services/simple_edge_detection_service.dart';

/// Debug widget to test edge detection
/// Shows the detected corners and allows testing
class DebugEdgeDetection extends StatefulWidget {
  final File imageFile;

  const DebugEdgeDetection({
    super.key,
    required this.imageFile,
  });

  @override
  State<DebugEdgeDetection> createState() => _DebugEdgeDetectionState();
}

class _DebugEdgeDetectionState extends State<DebugEdgeDetection> {
  List<Offset>? _detectedCorners;
  bool _isLoading = false;
  String _status = 'Ready to detect edges';

  @override
  void initState() {
    super.initState();
    _detectEdges();
  }

  Future<void> _detectEdges() async {
    setState(() {
      _isLoading = true;
      _status = 'Detecting edges...';
    });

    try {
      final corners = await SimpleEdgeDetectionService.detectDocumentEdges(widget.imageFile);
      
      setState(() {
        _detectedCorners = corners;
        _isLoading = false;
        _status = 'Found ${corners.length} corners';
      });
      
      print('🔍 DEBUG: Detected corners: $corners');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error: $e';
      });
      print('❌ DEBUG: Edge detection failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Edge Detection'),
        actions: [
          IconButton(
            onPressed: _detectEdges,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.withOpacity(0.1),
            child: Text(
              _status,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Image with corners
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Detecting edges...'),
                        ],
                      ),
                    )
                  : _detectedCorners != null
                      ? _buildImageWithCorners()
                      : const Center(
                          child: Text('No corners detected'),
                        ),
            ),
          ),
          
          // Corner details
          if (_detectedCorners != null)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Detected Corners:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._detectedCorners!.asMap().entries.map((entry) {
                    final index = entry.key;
                    final corner = entry.value;
                    return Text(
                      'Corner ${index + 1}: (${corner.dx.toInt()}, ${corner.dy.toInt()})',
                      style: const TextStyle(fontSize: 14),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageWithCorners() {
    return Stack(
      children: [
        // Image
        Positioned.fill(
          child: Image.file(
            widget.imageFile,
            fit: BoxFit.contain,
          ),
        ),
        
        // Corner markers
        ..._detectedCorners!.asMap().entries.map((entry) {
          final index = entry.key;
          final corner = entry.value;
          
          return Positioned(
            left: corner.dx - 20,
            top: corner.dy - 20,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
        
        // Corner connections
        CustomPaint(
          size: Size.infinite,
          painter: CornerConnectionPainter(_detectedCorners!),
        ),
      ],
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

    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw the quadrilateral
    final path = Path();
    path.moveTo(corners[0].dx, corners[0].dy);
    path.lineTo(corners[1].dx, corners[1].dy);
    path.lineTo(corners[2].dx, corners[2].dy);
    path.lineTo(corners[3].dx, corners[3].dy);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
