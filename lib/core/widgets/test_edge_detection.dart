import 'package:flutter/material.dart';
import 'dart:io';
import '../services/simple_edge_detection_service.dart';

/// Test widget to verify edge detection is working
class TestEdgeDetection extends StatefulWidget {
  const TestEdgeDetection({super.key});

  @override
  State<TestEdgeDetection> createState() => _TestEdgeDetectionState();
}

class _TestEdgeDetectionState extends State<TestEdgeDetection> {
  List<Offset>? _corners;
  bool _isLoading = false;
  String _status = 'Ready to test';

  Future<void> _testEdgeDetection() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing edge detection...';
    });

    try {
      // Create a test image file (you can replace this with an actual image)
      // For now, we'll test with a dummy file path
      final testFile = File('/path/to/test/image.jpg');
      
      if (!await testFile.exists()) {
        setState(() {
          _isLoading = false;
          _status = 'Test image not found. Please provide a real image file.';
        });
        return;
      }

      final corners = await SimpleEdgeDetectionService.detectDocumentEdges(testFile);
      
      setState(() {
        _corners = corners;
        _isLoading = false;
        _status = 'Found ${corners.length} corners: $corners';
      });
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Edge Detection'),
        actions: [
          IconButton(
            onPressed: _testEdgeDetection,
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
          
          // Test button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _testEdgeDetection,
              child: _isLoading 
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Testing...'),
                    ],
                  )
                : const Text('Test Edge Detection'),
            ),
          ),
          
          // Results
          if (_corners != null)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detected Corners:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._corners!.asMap().entries.map((entry) {
                      final index = entry.key;
                      final corner = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Corner ${index + 1}: (${corner.dx.toInt()}, ${corner.dy.toInt()})',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Text(
                      'Total corners: ${_corners!.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
