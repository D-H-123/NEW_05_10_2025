import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/services/document_scanner_service.dart';
import '../../core/services/ocr/mlkit_ocr_service.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isScanning = false;
  String? _scannedImagePath;
  String? _detectedTitle;
  double? _detectedTotal;
  String? _detectedCurrency;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Failed to initialize camera: $e');
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      setState(() {
        _isScanning = true;
      });

      final image = await _controller!.takePicture();
      
      if (image != null) {
        setState(() {
          _scannedImagePath = image.path;
        });
        
        // Analyze the scanned document for basic info using OCR
        await _analyzeDocument();
        
        setState(() {
          _isScanning = false;
        });
      }
    } catch (e) {
      print('Error taking picture: $e');
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _analyzeDocument() async {
    if (_scannedImagePath == null) return;

    try {
      print('DEBUG: Starting OCR analysis for image: $_scannedImagePath');
      final ocrService = MlKitOcrService();
      final file = File(_scannedImagePath!);
      final result = await ocrService.processImage(file);
      
      print('DEBUG: OCR result: $result');
      
      if (result != null) {
        setState(() {
          _detectedTitle = result.vendor ?? 'Receipt';
          _detectedTotal = result.total;
          _detectedCurrency = result.currency;
        });
        
        print('DEBUG: Detected vendor: $_detectedTitle');
        print('DEBUG: Detected total: $_detectedTotal');
        print('DEBUG: Detected currency: $_detectedCurrency');
        print('DEBUG: Raw OCR text: ${result.rawText.substring(0, result.rawText.length > 200 ? 200 : result.rawText.length)}...');
      } else {
        print('DEBUG: OCR result is null');
        setState(() {
          _detectedTitle = 'Receipt';
          _detectedTotal = null;
          _detectedCurrency = null;
        });
      }
    } catch (e) {
      print('Error analyzing document: $e');
      setState(() {
        _detectedTitle = 'Receipt';
        _detectedTotal = null;
        _detectedCurrency = null;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        setState(() {
          _scannedImagePath = image.path;
        });
        
        // Analyze the scanned document for basic info using OCR
        await _analyzeDocument();
      }
    } catch (e) {
      print('Error picking from gallery: $e');
    }
  }

  Future<bool> _isEmulator() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.isPhysicalDevice == false;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.isPhysicalDevice == false;
    }
    return false;
  }

  Future<void> _onDonePressed() async {
    if (_scannedImagePath != null) {
      print('🔍 MAGIC CAMERA: Done button pressed');
      print('🔍 MAGIC CAMERA: Passing to post-capture:');
      print('  Image path: $_scannedImagePath');
      print('  Detected title: "$_detectedTitle"');
      print('  Detected total: $_detectedTotal');
      print('  Detected currency: "$_detectedCurrency"');
      
      // Ensure we have the latest OCR data before navigating
      if (_detectedTitle == null || _detectedTitle!.isEmpty || _detectedTotal == null) {
        print('🔍 MAGIC CAMERA: Re-running OCR before navigation...');
        await _analyzeDocument();
      }
      
      print('🔍 MAGIC CAMERA: Final data before navigation:');
      print('  Image path: $_scannedImagePath');
      print('  Detected title: "$_detectedTitle"');
      print('  Detected total: $_detectedTotal');
      print('  Detected currency: "$_detectedCurrency"');
      
      context.push('/post-capture', extra: {
        'imagePath': _scannedImagePath,
        'detectedTitle': _detectedTitle,
        'detectedTotal': _detectedTotal,
        'detectedCurrency': _detectedCurrency,
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_detectedTitle ?? 'Scan Receipt'),
        actions: [
          if (_scannedImagePath != null) ...[
            IconButton(
              onPressed: () {
                setState(() {
                  _scannedImagePath = null;
                  _detectedTitle = null;
                  _detectedTotal = null;
                  _detectedCurrency = null;
                });
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset',
            ),
            IconButton(
              onPressed: _onDonePressed,
              icon: const Icon(Icons.check),
              tooltip: 'Done',
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          CameraPreview(_controller!),
          
          // Overlay UI
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
              ),
              child: Column(
                children: [
                  // Top section
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.document_scanner,
                            size: 64,
                            color: Colors.white,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Position your receipt within the frame',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Make sure all edges are visible',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Center section with scan area
                  Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                  
                  // Bottom section with controls
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Take Picture button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isScanning ? null : _takePicture,
                              icon: _isScanning 
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.camera_alt),
                              label: Text(_isScanning ? 'Capturing...' : 'Take Picture'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Gallery picker
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickFromGallery,
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('Gallery'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
