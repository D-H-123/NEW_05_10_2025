import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../core/services/image_preprocessing_service.dart';
import '../../core/services/document_scanner_service.dart';
import '../../core/services/ocr/mlkit_ocr_service.dart';
import 'pre_scan_instruction_modal.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with TickerProviderStateMixin {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isScanning = false;
  String? _scannedImagePath;
  String? _detectedTitle;
  double? _detectedTotal;
  String? _detectedCurrency;
  
  // New state variables for edge detection and cropping
  bool _isProcessingImage = false;
  bool _isPreprocessing = false;
  bool _isRunningOCR = false; // Prevent multiple OCR runs
  File? _processedImage;
  final ImagePreprocessingService _preprocessor = ImagePreprocessingService();

  // Edge detection state
  List<Offset>? _detectedCorners;
  bool _isDetectingEdges = false;
  
  // Document scanner state
  String? _scanMode; // 'scan_document' or 'import_gallery'
  bool _isDocumentDetected = false;
  bool _isEdgeStable = false;
  DateTime? _lastEdgeDetection;
  Timer? _stabilityTimer;
  Timer? _documentDetectionTimer; // Add timer reference for proper cleanup
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  // ML Kit Document Scanner
  final MLKitDocumentService _mlKitService = MLKitDocumentService();
  
  // OCR Service for text extraction (using legacy system)
  final MlKitOcrService _ocrService = MlKitOcrService();
  
  // OCR completion tracking
  bool _isOcrCompleted = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeAnimations();
    _initializeMLKit();
    _showPreScanInstructions();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController!,
      curve: Curves.easeInOut,
    ));
  }

  /// Initialize ML Kit Document Scanner
  Future<void> _initializeMLKit() async {
    try {
      await _mlKitService.initialize();
      print('✅ ML Kit Document Scanner ready');
    } catch (e) {
      print('❌ ML Kit initialization failed: $e');
    }
  }

  /// Show pre-scan instruction modal
  void _showPreScanInstructions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const PreScanInstructionModal(),
        ).then((_) {
          // After OK is pressed, show simple options for camera or gallery
          _showSimpleScanOptions();
        });
      }
    });
  }

  /// Show simple scan options after pre-scan instructions (previous UI)
  void _showSimpleScanOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose how to capture your receipt',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Camera Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _scanMode = 'scan_document';
                  });
                  _initializeCamera();
                },
                icon: const Icon(Icons.camera_alt),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                label: const Text(
                  'Take Photo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Import from Gallery Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _scanMode = 'import_gallery';
                  });
                  _pickFromGallery();
                },
                icon: const Icon(Icons.photo_library),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                label: const Text(
                  'Import from Gallery',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
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
        
        // Start document detection if in scan_document mode
        if (_scanMode == 'scan_document') {
          _startDocumentDetection();
        }
      }
    } catch (e) {
      print('Failed to initialize camera: $e');
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isScanning || _isProcessingImage) {
      print('🛑 TAKE PICTURE: Blocked - controller: ${_controller != null}, initialized: ${_controller?.value.isInitialized}, scanning: $_isScanning, processing: $_isProcessingImage');
      return;
    }

    try {
      setState(() {
        _isScanning = true;
      });
      
      print('📸 TAKE PICTURE: Starting capture...');

      final image = await _controller!.takePicture();
      
      setState(() {
        _scannedImagePath = image.path;
      });
        
      // Check aspect ratio for tall receipts
      final aspectRatio = await _getImageAspectRatio(File(image.path));
      if (aspectRatio > 2.0) {
        _showAspectRatioWarning(aspectRatio);
        setState(() {
          _isScanning = false;
        });
        return;
      }
      
      // Process the captured image with edge detection and preprocessing
      await _processCapturedImage(File(image.path));
      
      setState(() {
        _isScanning = false;
      });
    } catch (e) {
      print('Error taking picture: $e');
      setState(() {
        _isScanning = false;
      });
    }
  }

  /// Get image aspect ratio (width/height)
  Future<double> _getImageAspectRatio(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        return image.width / image.height;
      }
    } catch (e) {
      print('Error reading image dimensions: $e');
    }
    return 1.0; // Default aspect ratio
  }

  /// Show aspect ratio warning for very tall images
  void _showAspectRatioWarning(double aspectRatio) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tall Receipt Detected'),
        content: Text(
          'This receipt looks longer than your screen (aspect ratio: ${aspectRatio.toStringAsFixed(1)}:1).\n\n'
          'For best OCR accuracy, we recommend scanning in parts.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _retakePhoto();
            },
            child: const Text('Scan in Parts'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _processCapturedImage(File(_scannedImagePath ?? ''));
            },
            child: const Text('Attempt Single Capture'),
          ),
        ],
      ),
    );
  }

  /// Pick image from gallery with edge detection control
  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        print('🔍 GALLERY: Image selected from gallery: ${imageFile.path}');
        
        setState(() {
          _scannedImagePath = imageFile.path;
        });
        
        // Check aspect ratio for tall receipts
        final aspectRatio = await _getImageAspectRatio(imageFile);
        if (aspectRatio > 2.0) {
          _showAspectRatioWarning(aspectRatio);
          return;
        }
        
        // Use enhanced edge detection with ML Kit integration
        await _showEdgeAdjustmentForGalleryEnhanced(imageFile);
      }
    } catch (e) {
      print('❌ Error picking from gallery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Enhanced gallery edge adjustment with ML Kit
  Future<void> _showEdgeAdjustmentForGalleryEnhanced(File imageFile) async {
    print('🔍 GALLERY ENHANCED: Starting enhanced edge adjustment...');
    
    setState(() {
      _isProcessingImage = true;
      _scannedImagePath = imageFile.path;
    });
    
    try {
      // Use enhanced edge detection that tries ML Kit first
      print('🔍 GALLERY ENHANCED: Using enhanced edge detection...');
      final detectedCorners = await _mlKitService.detectDocumentCorners(imageFile);
      
      // Get image dimensions for proper corner scaling
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }
      
      List<Offset> cornersToUse;
      
      if (detectedCorners != null && detectedCorners.length == 4) {
        print('✅ GALLERY ENHANCED: Enhanced detection found ${detectedCorners.length} corners');
        cornersToUse = detectedCorners;
      } else {
        print('⚠️ GALLERY ENHANCED: Enhanced detection failed, using smart defaults');
        final imageWidth = image.width.toDouble();
        final imageHeight = image.height.toDouble();
        cornersToUse = [
          Offset(imageWidth * 0.05, imageHeight * 0.05),
          Offset(imageWidth * 0.95, imageHeight * 0.05),
          Offset(imageWidth * 0.95, imageHeight * 0.95),
          Offset(imageWidth * 0.05, imageHeight * 0.95),
        ];
      }
      
      setState(() {
        _isProcessingImage = false;
      });
      
      // Give UI time to update
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Show edge adjustment dialog
      List<Offset>? userAdjustedCorners;
      
      try {
        print('🔍 GALLERY ENHANCED: Showing edge adjustment dialog...');
        userAdjustedCorners = await _showEdgeDetectionControl(
          imageFile, 
          cornersToUse,
        );
        print('🔍 GALLERY ENHANCED: Dialog returned: $userAdjustedCorners');
      } catch (dialogError) {
        print('❌ GALLERY ENHANCED: Dialog error: $dialogError');
        // Show error dialog and ask if user wants to continue
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Edge Detection Failed'),
            content: const Text('Failed to show edge adjustment dialog. Would you like to continue with basic processing?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        
        if (shouldProceed != true) {
          setState(() {
            _isProcessingImage = false;
            _scannedImagePath = null;
          });
          return;
        }
        userAdjustedCorners = null;
      }
      
      // Process the image
      setState(() {
        _isProcessingImage = true;
        _isPreprocessing = true;
      });
      
      File processedImage;
      
      if (userAdjustedCorners != null && userAdjustedCorners.length == 4) {
        print('✅ GALLERY ENHANCED: Processing with user-adjusted corners');
        
        setState(() {
          _detectedCorners = userAdjustedCorners;
        });
        
        final correctedImage = await _preprocessor.applyPerspectiveCorrection(
          imageFile, 
          userAdjustedCorners
        );
        processedImage = await _preprocessor.preprocessForMaximumOCRAccuracySmart(correctedImage);
        
      } else {
        print('⚠️ GALLERY ENHANCED: Processing with basic preprocessing');
        processedImage = await _preprocessor.preprocessForMaximumOCRAccuracySmart(imageFile);
      }
      
      setState(() {
        _processedImage = processedImage;
        _scannedImagePath = processedImage.path;
        _isPreprocessing = false;
        _isOcrCompleted = false; // Reset OCR completion flag for new image
      });
      
      print('✅ GALLERY ENHANCED: Processing complete');
      
      // Automatically trigger OCR after preprocessing completes
      print('🔍 GALLERY ENHANCED: Auto-triggering OCR after preprocessing...');
      await _performAutomaticOCR();
      // No automatic OCR here - user must apply corner adjustments first
      
    } catch (e) {
      print('❌ GALLERY ENHANCED: Processing failed: $e');
      setState(() {
        _isProcessingImage = false;
        _isPreprocessing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing gallery image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Test method to verify edge adjustment dialog works
  Future<void> _testEdgeDialog() async {
    print('🔍 TEST: Testing edge adjustment dialog...');
    
    if (_scannedImagePath == null) {
      print('❌ TEST: No image selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No image selected for testing'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final imageFile = File(_scannedImagePath!);
    if (!await imageFile.exists()) {
      print('❌ TEST: Image file does not exist');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image file does not exist'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Create test corners
    final testCorners = [
      const Offset(50, 50),   // Top-left
      const Offset(300, 50),  // Top-right
      const Offset(300, 400), // Bottom-right
      const Offset(50, 400),  // Bottom-left
    ];
    
    print('🔍 TEST: About to show edge adjustment dialog...');
    print('🔍 TEST: Context mounted: $mounted');
    print('🔍 TEST: Context: $context');
    
    try {
      final result = await _showEdgeDetectionControl(imageFile, testCorners);
      print('🔍 TEST: Edge adjustment dialog returned: $result');
      
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Edge adjustment dialog worked!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Edge adjustment was skipped'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ TEST: Edge adjustment dialog failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Edge adjustment dialog failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Process captured/imported image with automatic edge detection
  Future<void> _processCapturedImage(File imageFile) async {
    // Stop document detection immediately when processing starts
    _stopDocumentDetection();
    
    setState(() {
      _isProcessingImage = true;
      _isPreprocessing = true;
      _detectedCorners = null; // Reset detected corners
    });
    
    print('🛑 PROCESSING: Stopped document detection, starting image processing...');
    
    try {
      print('🔍 STEP 1: Starting edge detection...');
      print('🔍 DEBUG: Image file path: ${imageFile.path}');
      print('🔍 DEBUG: Image file exists: ${await imageFile.exists()}');
      
      // Try multiple edge detection methods with timeout protection
      List<Offset>? corners;
      
      // Method 1: Try enhanced detection with timeout
      try {
        corners = await Future.any([
          _mlKitService.detectDocumentCorners(imageFile),
          Future.delayed(const Duration(seconds: 10), () {
            throw TimeoutException('Edge detection timed out after 10 seconds', const Duration(seconds: 10));
          }),
        ]);
        print('🔍 DEBUG: Enhanced edge detection result: $corners');
      } catch (e) {
        print('❌ Enhanced detection failed: $e');
      }
      
      // Method 2: Try fast detection if enhanced failed
      if (corners == null || corners.length != 4) {
        try {
          corners = await Future.any([
            _mlKitService.detectDocumentCorners(imageFile),
            Future.delayed(const Duration(seconds: 5), () {
              throw TimeoutException('Fast edge detection timed out after 5 seconds', const Duration(seconds: 5));
            }),
          ]);
          print('🔍 DEBUG: Fast edge detection result: $corners');
        } catch (e) {
          print('❌ Fast detection failed: $e');
        }
      }
      
      File processedImage;
      String processingMessage = '';

      if (corners != null && corners.length == 4) {
        print('✅ STEP 1 COMPLETE: Found ${corners.length} corners');
        print('🔍 DEBUG: Corners found: $corners');
        
        // Update preprocessing state to show edge detection is complete
        setState(() {
          _isPreprocessing = false;
        });
        
        // Show user control for edge detection
        print('🔍 STEP 1.5: Showing user control for edge detection...');
        print('🔍 DEBUG: About to show edge detection dialog...');
        
        // Ensure we have a valid context before showing dialog
        if (!mounted) {
          print('❌ ERROR: Widget not mounted, cannot show dialog');
          return;
        }
        
        // Add a small delay to ensure UI is ready
        await Future.delayed(const Duration(milliseconds: 200));
        
        print('🔍 DEBUG: Context is valid, showing edge detection dialog...');
        final userAdjustedCorners = await _showEdgeDetectionControl(imageFile, corners);
        print('🔍 DEBUG: Edge detection dialog returned: $userAdjustedCorners');
        
        if (userAdjustedCorners != null && userAdjustedCorners.length == 4) {
          print('✅ STEP 1.5 COMPLETE: User adjusted corners - USING ADJUSTED CORNERS');
          print('🔍 DEBUG: Adjusted corners: $userAdjustedCorners');
          
          // Store corners for visual feedback
          setState(() {
            _detectedCorners = userAdjustedCorners;
            _isPreprocessing = true; // Show processing again
          });
          
          print('🔍 STEP 2: Applying perspective correction with ADJUSTED corners...');
          final correctedImage = await Future.any([
            _preprocessor.applyPerspectiveCorrection(imageFile, userAdjustedCorners),
            Future.delayed(const Duration(seconds: 15), () {
              throw TimeoutException('Perspective correction timed out after 15 seconds', const Duration(seconds: 15));
            }),
          ]);
          print('✅ STEP 2 COMPLETE: Perspective correction completed with adjusted corners');
          
          print('🔍 STEP 3: Starting OPTIMIZED OCR preprocessing for adjusted corner document...');
          processedImage = await Future.any([
            _preprocessor.preprocessForMaximumOCRAccuracySmart(correctedImage),
            Future.delayed(const Duration(seconds: 15), () {
              throw TimeoutException('OCR preprocessing timed out after 15 seconds', const Duration(seconds: 15));
            }),
          ]);
          print('✅ STEP 3 COMPLETE: OPTIMIZED OCR preprocessing completed for adjusted corners');
          
          processingMessage = '✅ ADJUSTED CORNERS USED: Edge Detection → User Adjustment → Perspective Correction → OCR Preprocessing';
          
        } else {
          print('⚠️ STEP 1.5: User skipped edge detection, using basic preprocessing...');
          // User chose to skip edge detection
          setState(() {
            _isPreprocessing = true; // Show processing again
          });
          processedImage = await Future.any([
            _preprocessor.preprocessForMaximumOCRAccuracySmart(imageFile),
            Future.delayed(const Duration(seconds: 15), () {
              throw TimeoutException('Basic preprocessing timed out after 15 seconds', const Duration(seconds: 15));
            }),
          ]);
          processingMessage = '⚠️ Basic preprocessing completed (edge detection skipped)';
        }
        
      } else {
        print('⚠️ STEP 1 FAILED: No corners found, offering manual edge detection...');
        
        // Even if automatic edge detection fails, offer manual edge detection
        if (mounted) {
          setState(() {
            _isPreprocessing = false;
          });
          
          // Show a dialog asking if user wants to try manual edge detection
          final shouldTryManual = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Edge Detection'),
              content: const Text(
                'Automatic edge detection could not find document edges.\n\n'
                'Would you like to manually adjust the corners or proceed with basic processing?'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Skip Edge Detection'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Manual Adjustment'),
                ),
              ],
            ),
          );
          
          if (shouldTryManual == true) {
            // Create default corners for manual adjustment based on image size
            final bytes = await imageFile.readAsBytes();
            final image = img.decodeImage(bytes);
            if (image != null) {
              final imageWidth = image.width.toDouble();
              final imageHeight = image.height.toDouble();
              
              final defaultCorners = [
                Offset(imageWidth * 0.1, imageHeight * 0.1),   // Top-left
                Offset(imageWidth * 0.9, imageHeight * 0.1),  // Top-right
                Offset(imageWidth * 0.9, imageHeight * 0.9), // Bottom-right
                Offset(imageWidth * 0.1, imageHeight * 0.9),  // Bottom-left
              ];
              
              final userAdjustedCorners = await _showEdgeDetectionControl(imageFile, defaultCorners);
              
              if (userAdjustedCorners != null && userAdjustedCorners.length == 4) {
                setState(() {
                  _detectedCorners = userAdjustedCorners;
                  _isPreprocessing = true;
                });
                
                final correctedImage = await _preprocessor.applyPerspectiveCorrection(imageFile, userAdjustedCorners);
                processedImage = await _preprocessor.preprocessForMaximumOCRAccuracySmart(correctedImage);
                processingMessage = '✅ Manual Edge Detection → Perspective Correction → OCR Preprocessing';
              } else {
                processedImage = await _preprocessor.preprocessForMaximumOCRAccuracySmart(imageFile);
                processingMessage = '⚠️ Basic preprocessing completed (manual edge detection skipped)';
              }
            } else {
              processedImage = await _preprocessor.preprocessForMaximumOCRAccuracySmart(imageFile);
              processingMessage = '⚠️ Basic preprocessing completed (image decode failed)';
            }
          } else {
            processedImage = await _preprocessor.preprocessForMaximumOCRAccuracySmart(imageFile);
            processingMessage = '⚠️ Basic preprocessing completed (edge detection skipped)';
          }
        } else {
          processedImage = await _preprocessor.preprocessForMaximumOCRAccuracySmart(imageFile);
          processingMessage = '⚠️ Basic preprocessing completed (edge detection failed)';
        }
      }
      
      setState(() {
        _processedImage = processedImage;
        _scannedImagePath = processedImage.path;
        _isPreprocessing = false;
        _isOcrCompleted = false; // Reset OCR completion flag for new image
      });
      
      print('✅ PROCESSING: $processingMessage');
      
      // Automatically trigger OCR after preprocessing completes
      print('🔍 PROCESSING: Auto-triggering OCR after preprocessing...');
      await _performAutomaticOCR();
      
      // OCR will only run after corner adjustment is applied
      // No automatic OCR here - user must apply corner adjustments first
      
    } catch (e) {
      print('❌ PROCESSING: Failed: $e');
      setState(() {
        _isProcessingImage = false;
        _isPreprocessing = false;
      });
      
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Processing Failed'),
            content: Text('Error: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }


  /// Automatically perform OCR after preprocessing completes
  Future<void> _performAutomaticOCR() async {
    if (_processedImage == null) {
      print('🔍 AUTO OCR: No processed image available');
      return;
    }
    
    if (_isRunningOCR) {
      print('🔍 AUTO OCR: OCR already running, skipping');
      return;
    }
    
    print('🔍 AUTO OCR: Starting automatic OCR extraction...');
    
    setState(() {
      _isRunningOCR = true;
    });
    
    try {
      final ocrResult = await _ocrService.processImage(_processedImage!);
      
      print('🔍 AUTO OCR: Automatic OCR completed successfully');
      print('  Vendor: "${ocrResult.vendor}"');
      print('  Amount: ${ocrResult.total}');
      print('  Currency: "${ocrResult.currency}"');
      print('  Date: ${ocrResult.date}');
      
      setState(() {
        _detectedTitle = ocrResult.vendor;
        _detectedTotal = ocrResult.total;
        _detectedCurrency = ocrResult.currency;
        _isRunningOCR = false;
        _isOcrCompleted = true; // Enable Done button
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR completed automatically! Found: ${ocrResult.vendor ?? "Unknown vendor"}, ${ocrResult.total != null ? "\$${ocrResult.total!.toStringAsFixed(2)}" : "No amount"}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ AUTO OCR: Automatic OCR failed: $e');
      setState(() {
        _isRunningOCR = false;
        _isOcrCompleted = false; // Keep Done button disabled
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Automatic OCR failed: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Retake photo - reset to camera view
  void _retakePhoto() {
    setState(() {
      _processedImage = null;
      _scannedImagePath = null;
      _detectedCorners = null;
      _isProcessingImage = false;
      _isOcrCompleted = false; // Reset OCR completion flag
      _isPreprocessing = false;
      _isRunningOCR = false; // Reset OCR state
      _isDocumentDetected = false;
      _isEdgeStable = false;
    });
    _stopStabilityTimer();
    _stopDocumentDetection();
    
    // Restart document detection if in scan mode
    if (_scanMode == 'scan_document') {
      _startDocumentDetection();
    }
  }

  /// Start document detection for auto-capture
  void _startDocumentDetection() {
    if (_scanMode != 'scan_document') return;
    
    // Stop any existing timer first
    _stopDocumentDetection();
    
    // Start periodic edge detection
    _documentDetectionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted || _isScanning || _isProcessingImage) {
        print('🛑 DOCUMENT DETECTION: Stopping timer - mounted: $mounted, scanning: $_isScanning, processing: $_isProcessingImage');
        timer.cancel();
        _documentDetectionTimer = null;
        return;
      }
      _detectDocumentEdges();
    });
    
    print('🔄 DOCUMENT DETECTION: Started periodic edge detection timer');
  }
  
  /// Stop document detection timer
  void _stopDocumentDetection() {
    if (_documentDetectionTimer != null) {
      print('🛑 DOCUMENT DETECTION: Stopping document detection timer');
      _documentDetectionTimer!.cancel();
      _documentDetectionTimer = null;
    }
  }

  /// Detect document edges in real-time
  Future<void> _detectDocumentEdges() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    try {
      // Take a quick preview frame for edge detection
      final image = await _controller!.takePicture();
      
        final corners = await _mlKitService.detectDocumentCorners(File(image.path));
      
      if (corners != null && corners.length == 4) {
        setState(() {
          _detectedCorners = corners;
          _isDocumentDetected = true;
          _lastEdgeDetection = DateTime.now();
        });
        
        // Check if edges are stable
        _checkEdgeStability();
      } else {
        setState(() {
          _isDocumentDetected = false;
          _isEdgeStable = false;
        });
        _stopStabilityTimer();
      }
      
      // Clean up temporary file
      try {
        await File(image.path).delete();
      } catch (e) {
        // Ignore cleanup errors
      }
    } catch (e) {
      print('Error detecting document edges: $e');
    }
  }

  /// Check if edges are stable for auto-capture
  void _checkEdgeStability() {
    if (_lastEdgeDetection == null) return;
    
    final now = DateTime.now();
    final timeSinceLastDetection = now.difference(_lastEdgeDetection!);
    
    if (timeSinceLastDetection.inMilliseconds > 500) {
      // Edges have been stable for 0.5 seconds
      if (!_isEdgeStable) {
        setState(() {
          _isEdgeStable = true;
        });
        _pulseController?.repeat(reverse: true);
        
        // Auto-capture after a short delay
        _stabilityTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted && _isEdgeStable && !_isScanning && !_isProcessingImage) {
            print('📸 AUTO-CAPTURE: Triggering automatic capture...');
            _takePicture();
          } else {
            print('🛑 AUTO-CAPTURE: Blocked - mounted: $mounted, stable: $_isEdgeStable, scanning: $_isScanning, processing: $_isProcessingImage');
          }
        });
      }
    } else {
      // Edges are not stable yet
      if (_isEdgeStable) {
        setState(() {
          _isEdgeStable = false;
        });
        _pulseController?.stop();
        _stopStabilityTimer();
      }
    }
  }

  /// Stop stability timer
  void _stopStabilityTimer() {
    _stabilityTimer?.cancel();
    _stabilityTimer = null;
  }

  // REMOVED: _showProcessingDialog method to prevent duplicate processing
  
  // REMOVED: Unused processing dialog methods to prevent duplicate processing

  // REMOVED: _navigateToResults method (unused)

  /// Show edge detection results with user control
  /// Show edge detection results with user control - FIXED VERSION
  /// Show edge detection results with user control - COMPLETE FIXED VERSION
Future<List<Offset>?> _showEdgeDetectionControl(File imageFile, List<Offset> detectedCorners) async {
  print('🔍 EDGE CONTROL: Showing edge detection control dialog...');
  print('🔍 EDGE CONTROL: Image file: ${imageFile.path}');
  print('🔍 EDGE CONTROL: Detected corners: $detectedCorners');
  
  try {
    // Get image dimensions for coordinate scaling
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      print('❌ EDGE CONTROL: Failed to decode image');
      return null;
    }
    
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();
    print('🔍 EDGE CONTROL: Image dimensions: ${imageWidth}x${imageHeight}');
    
    return await showDialog<List<Offset>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Initialize corner positions OUTSIDE of StatefulBuilder
        const double containerHeight = 350.0;
        final double containerWidth = MediaQuery.of(context).size.width - 80;
        
        // Calculate display size maintaining aspect ratio
        double displayWidth, displayHeight;
        final imageAspectRatio = imageWidth / imageHeight;
        final containerAspectRatio = containerWidth / containerHeight;
        
        if (imageAspectRatio > containerAspectRatio) {
          displayWidth = containerWidth;
          displayHeight = containerWidth / imageAspectRatio;
        } else {
          displayHeight = containerHeight;
          displayWidth = containerHeight * imageAspectRatio;
        }
        
        // Calculate offsets to center the image
        final offsetX = (containerWidth - displayWidth) / 2;
        final offsetY = (containerHeight - displayHeight) / 2;
        
        // Scale corners from image to display coordinates ONCE
        List<Offset> displayCorners = detectedCorners.map((corner) {
          final scaleX = displayWidth / imageWidth;
          final scaleY = displayHeight / imageHeight;
          
          return Offset(
            (corner.dx * scaleX) + offsetX,
            (corner.dy * scaleY) + offsetY,
          );
        }).toList();
        
        // Store original corners for reset functionality
        final List<Offset> originalDisplayCorners = List.from(displayCorners);
        
        print('🔍 EDGE CONTROL: Display size: ${displayWidth}x${displayHeight}');
        print('🔍 EDGE CONTROL: Offset: ${offsetX}, ${offsetY}');
        print('🔍 EDGE CONTROL: Initial display corners: $displayCorners');
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            int? draggingCorner;
            
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.crop_square, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Adjust Document Edges'),
                ],
              ),
              contentPadding: const EdgeInsets.all(20),
              content: SizedBox(
                width: containerWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.touch_app, color: Colors.blue, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Drag Corner Points',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Drag the numbered red circles to adjust document corners.\n'
                            'Blue lines show the detected document boundary.',
                            style: TextStyle(fontSize: 13, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Image preview with adjustable corners
                    Container(
                      width: containerWidth,
                      height: containerHeight,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400, width: 2),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade100,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          children: [
                            // Background image positioned exactly
                            Positioned(
                              left: offsetX,
                              top: offsetY,
                              width: displayWidth,
                              height: displayHeight,
                              child: Image.file(
                                imageFile,
                                fit: BoxFit.fill,
                                errorBuilder: (context, error, stackTrace) {
                                  print('❌ EDGE CONTROL: Image load error: $error');
                                  return Container(
                                    color: Colors.grey.shade300,
                                    child: const Center(
                                      child: Icon(Icons.error, size: 48),
                                    ),
                                  );
                                },
                              ),
                            ),
                            
                            // Semi-transparent overlay for better visibility
                            Container(
                              width: containerWidth,
                              height: containerHeight,
                              color: Colors.black.withOpacity(0.1),
                            ),
                            
                            // Draw corner connections using the FIXED CustomPainter
                            CustomPaint(
                              size: Size(containerWidth, containerHeight),
                              painter: CornerConnectionPainter(displayCorners),
                            ),
                            
                            // Draggable corner handles
                            ...displayCorners.asMap().entries.map((entry) {
                              final index = entry.key;
                              final corner = entry.value;
                              
                              final handleSize = draggingCorner == index ? 40.0 : 32.0;
                              final handleRadius = handleSize / 2;
                              
                              return Positioned(
                                left: corner.dx - handleRadius,
                                top: corner.dy - handleRadius,
                                child: GestureDetector(
                                  onPanStart: (details) {
                                    setDialogState(() {
                                      draggingCorner = index;
                                    });
                                    print('🔍 HANDLE: Started dragging corner $index');
                                  },
                                  onPanUpdate: (details) {
                                    setDialogState(() {
                                      // Calculate new position
                                      double newX = displayCorners[index].dx + details.delta.dx;
                                      double newY = displayCorners[index].dy + details.delta.dy;
                                      
                                      // Constrain within container bounds
                                      newX = newX.clamp(handleRadius, containerWidth - handleRadius);
                                      newY = newY.clamp(handleRadius, containerHeight - handleRadius);
                                      
                                      // Update corner position directly
                                      displayCorners[index] = Offset(newX, newY);
                                      
                                      print('🔍 HANDLE: Moving corner $index to ($newX, $newY)');
                                    });
                                  },
                                  onPanEnd: (details) {
                                    setDialogState(() {
                                      draggingCorner = null;
                                    });
                                    print('🔍 HANDLE: Finished dragging corner $index');
                                  },
                                  child: Container(
                                    width: handleSize,
                                    height: handleSize,
                                    decoration: BoxDecoration(
                                      color: draggingCorner == index 
                                        ? Colors.orange.shade600 
                                        : Colors.red.shade600,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white, 
                                        width: draggingCorner == index ? 4 : 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.4),
                                          blurRadius: draggingCorner == index ? 12 : 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: draggingCorner == index ? 16 : 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Control buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                // Reset to original positions
                                displayCorners = List.from(originalDisplayCorners);
                              });
                              print('🔍 EDGE CONTROL: Corners reset');
                            },
                            icon: const Icon(Icons.refresh, size: 20),
                            label: const Text('Reset'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                print('🔍 EDGE CONTROL: Generating preview...');
                                
                                // Convert back to image coordinates
                                final scaleX = imageWidth / displayWidth;
                                final scaleY = imageHeight / displayHeight;
                                
                                final imageCorners = displayCorners.map((corner) {
                                  return Offset(
                                    (corner.dx - offsetX) * scaleX,
                                    (corner.dy - offsetY) * scaleY,
                                  );
                                }).toList();
                                
                                print('🔍 EDGE CONTROL: Image corners: $imageCorners');
                                
                                // Generate preview
                                final previewImage = await _preprocessor.applyPerspectiveCorrection(
                                  imageFile, 
                                  imageCorners
                                );
                                
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (previewContext) => AlertDialog(
                                      title: const Text('Perspective Preview'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('Preview with adjusted corners:'),
                                          const SizedBox(height: 12),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.file(
                                              previewImage,
                                              height: 250,
                                              width: double.infinity,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  height: 250,
                                                  color: Colors.grey.shade200,
                                                  child: const Center(
                                                    child: Text('Preview failed'),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Does this look correct?',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(previewContext).pop(),
                                          child: const Text('Continue Adjusting'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.of(previewContext).pop(),
                                          child: const Text('Looks Good'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              } catch (e) {
                                print('❌ EDGE CONTROL: Preview failed: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Preview failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.preview, size: 20),
                            label: const Text('Preview'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Tip
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: Colors.green.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Position corners at document edges for best results',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    print('🔍 EDGE CONTROL: User skipped edge detection');
                    Navigator.of(context).pop(null);
                  },
                  child: const Text('Skip Edge Detection'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Convert final display coordinates back to image coordinates
                    final scaleX = imageWidth / displayWidth;
                    final scaleY = imageHeight / displayHeight;
                    
                    final finalImageCorners = displayCorners.map((corner) {
                      return Offset(
                        (corner.dx - offsetX) * scaleX,
                        (corner.dy - offsetY) * scaleY,
                      );
                    }).toList();
                    
                    print('🔍 EDGE CONTROL: Final corners: $finalImageCorners');
                    
                    // Return the adjusted corners instead of processing immediately
                    print('🔍 EDGE CONTROL: Returning adjusted corners: $finalImageCorners');
                    Navigator.of(context).pop(finalImageCorners);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply Adjustments'),
                ),
              ],
            );
          },
        );
      },
    );
  } catch (e) {
    print('❌ EDGE CONTROL: Dialog failed: $e');
    return null;
  }
}

/// Custom painter for drawing corner connections


  Future<void> _onDonePressed() async {
    if (_scannedImagePath != null) {
      print('🔍 MAGIC CAMERA: Done button pressed');
      print('🔍 MAGIC CAMERA: Passing to post-capture:');
      print('  Image path: $_scannedImagePath');
      print('  Detected title: "$_detectedTitle"');
      print('  Detected total: $_detectedTotal');
      print('  Detected currency: "$_detectedCurrency"');
      
      // OCR data should already be available from previous extraction
      // No need to re-run OCR here - it was already done when user clicked "Extract Text"
      print('🔍 MAGIC CAMERA: Using existing OCR data for navigation:');
      print('  Vendor: "$_detectedTitle"');
      print('  Amount: $_detectedTotal');
      print('  Currency: "$_detectedCurrency"');
      
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
    _stabilityTimer?.cancel();
    _documentDetectionTimer?.cancel(); // Clean up document detection timer
    _pulseController?.dispose();
    _mlKitService.dispose();
    _ocrService.dispose();
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
        title: Text(_scanMode == 'scan_document' ? 'Document Scanner' : 'Import from Gallery'),
        actions: [
          if (_scannedImagePath != null) ...[
            IconButton(
              onPressed: () {
                setState(() {
                  _scannedImagePath = null;
                  _detectedTitle = null;
                  _detectedTotal = null;
                  _detectedCurrency = null;
                  _processedImage = null;
                  _detectedCorners = null;
                  _isDocumentDetected = false;
                  _isEdgeStable = false;
                });
                _stopStabilityTimer();
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset',
            ),
            IconButton(
              onPressed: _isOcrCompleted ? _onDonePressed : null,
              icon: Icon(
                Icons.check,
                color: _isOcrCompleted ? Colors.green : Colors.grey,
              ),
              tooltip: _isOcrCompleted ? 'Done' : 'Complete OCR first',
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _scanMode == 'scan_document' ? Icons.document_scanner : Icons.photo_library,
                            size: 64,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _scanMode == 'scan_document' 
                              ? 'Position your document within the frame'
                              : 'Gallery Image Selected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _scanMode == 'scan_document'
                              ? 'Auto-capture when edges are stable\nor tap to capture manually'
                              : _isProcessingImage 
                                ? 'Detecting edges - you can adjust them\nfor better OCR accuracy'
                                : _scannedImagePath != null && _processedImage != null
                                  ? _isRunningOCR 
                                    ? 'Running OCR automatically...'
                                    : _isOcrCompleted
                                      ? 'OCR completed! Click "Done" to continue'
                                      : 'Image ready - OCR will start automatically'
                                  : 'Image ready for processing',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Center section with scan area and edge detection
                  Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.transparent,
                            ),
                          ),
                          // Document edge overlay for scanner mode
                          if (_scanMode == 'scan_document' && _detectedCorners != null && _detectedCorners!.length == 4)
                            CustomPaint(
                              painter: DocumentEdgePainter(_detectedCorners!, _isEdgeStable),
                              child: Container(),
                            ),
                          // Edge detection indicator
                          if (_isDetectingEdges)
                            const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Detecting edges...',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Auto-capture indicator
                          if (_scanMode == 'scan_document' && _isEdgeStable)
                            AnimatedBuilder(
                              animation: _pulseAnimation ?? const AlwaysStoppedAnimation(1.0),
                              builder: (context, child) {
                                return Center(
                                  child: Transform.scale(
                                    scale: _pulseAnimation!.value,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Document Detected!\nAuto-capturing...',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
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
                          // Show different controls based on scan mode
                          if (_scanMode == 'scan_document') ...[
                            // Document scanner controls
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isScanning || _isProcessingImage ? null : _takePicture,
                                icon: _isScanning 
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(_isEdgeStable ? Icons.auto_awesome : Icons.camera_alt),
                                label: Text(_isScanning 
                                  ? 'Capturing...' 
                                  : _isEdgeStable 
                                    ? 'Auto-Capture Ready' 
                                    : 'Tap to Capture'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isEdgeStable ? Colors.green : Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Status indicator
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _isDocumentDetected 
                                  ? (_isEdgeStable ? 'Edges Stable - Auto-capture Ready' : 'Document Detected - Stabilizing...')
                                  : 'Looking for document...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                                                      ] else ...[
                            // Debug button to test edge adjustment dialog
                            if (_scannedImagePath != null && !_isProcessingImage) ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _testEdgeDialog(),
                                  icon: const Icon(Icons.crop_square),
                                  label: const Text('Test Edge Dialog'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Gallery import - show processing status
                            if (_isProcessingImage) ...[
                              // Processing gallery image
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                ),
                                child: Column(
                                  children: [
                                    const SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Processing Gallery Image',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isPreprocessing 
                                        ? 'Detecting edges and preparing for adjustment...'
                                        : 'Running OCR analysis...',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              // Gallery import completed
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 32,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Gallery Import Complete',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Image processed with edge detection',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Processing overlay
          if (_isProcessingImage)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _isPreprocessing 
                          ? '🔍 Processing Image...\n\nStep 1: Edge Detection\nStep 2: Perspective Correction\nStep 3: Image Preprocessing'
                          : '🔍 Running OCR...\n\nExtracting text from processed image',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Image preview before OCR (when processing is complete)
          if (_scannedImagePath != null && !_isProcessingImage && _processedImage != null)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _detectedCorners != null && _detectedCorners!.length == 4 
                            ? Icons.crop_square 
                            : Icons.image, 
                          color: _detectedCorners != null && _detectedCorners!.length == 4 
                            ? Colors.green 
                            : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _detectedCorners != null && _detectedCorners!.length == 4
                            ? 'Image Ready for OCR (Edge Corrected)'
                            : 'Image Ready for OCR',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _detectedCorners != null && _detectedCorners!.length == 4 
                              ? Colors.green 
                              : Colors.blue,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _scannedImagePath = null;
                              _detectedTitle = null;
                              _detectedTotal = null;
                              _detectedCurrency = null;
                              _processedImage = null;
                              _detectedCorners = null;
                            });
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _processedImage!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Edge detection status
                    if (_detectedCorners != null && _detectedCorners!.length == 4) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '✅ 3-Step Pipeline Completed Successfully!\n'
                                '• Edge Detection: Found ${_detectedCorners!.length} corners\n'
                                '• Perspective Correction: Applied\n'
                                '• Image Preprocessing: Enhanced for OCR',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '⚠️ Edge Detection Failed\n'
                                '• Using basic preprocessing\n'
                                '• OCR may be less accurate',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      _isOcrCompleted
                        ? 'OCR completed automatically! Data extracted successfully.'
                        : _isRunningOCR
                          ? 'OCR is running automatically...'
                          : _detectedCorners != null && _detectedCorners!.length == 4
                            ? 'Edge detection completed! OCR will start automatically.\nTap "Extract Text" to re-run if needed.'
                            : 'Image is ready for OCR processing.\nOCR will start automatically.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _detectedCorners != null && _detectedCorners!.length == 4 
                          ? Colors.green 
                          : Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isRunningOCR ? null : () async {
                              if (_processedImage != null) {
                                setState(() {
                                  _isRunningOCR = true;
                                });
                                
                                try {
                                  print('🔍 OCR EXTRACTION: Starting legacy OCR extraction...');
                                  final ocrResult = await _ocrService.processImage(_processedImage!);
                                  
                                  print('🔍 OCR EXTRACTION: Legacy OCR completed successfully');
                                  print('  Vendor: "${ocrResult.vendor}"');
                                  print('  Amount: ${ocrResult.total}');
                                  print('  Currency: "${ocrResult.currency}"');
                                  print('  Date: ${ocrResult.date}');
                                  
                                  setState(() {
                                    _detectedTitle = ocrResult.vendor;
                                    _detectedTotal = ocrResult.total;
                                    _detectedCurrency = ocrResult.currency;
                                    _isRunningOCR = false;
                                    _isOcrCompleted = true; // Enable Done button
                                  });
                                  
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('OCR completed! Found: ${ocrResult.vendor ?? "Unknown vendor"}, ${ocrResult.total != null ? "\$${ocrResult.total!.toStringAsFixed(2)}" : "No amount"}'),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  print('❌ OCR EXTRACTION: Failed: $e');
                                  setState(() {
                                    _isRunningOCR = false;
                                    _isOcrCompleted = false; // Keep Done button disabled
                                  });
                                  
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('OCR extraction failed: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            icon: _isRunningOCR 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.text_fields),
                            label: Text(_isRunningOCR ? 'Extracting...' : 'Re-run OCR'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRunningOCR ? Colors.grey : Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _retakePhoto(),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Retake'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }
}

/// Custom painter for drawing adjustable document corners
class AdjustableCornerPainter extends CustomPainter {
  final List<Offset> corners;
  final double containerWidth;
  final double containerHeight;
  
  AdjustableCornerPainter(this.corners, this.containerWidth, this.containerHeight);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;
    
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    
    // Draw the document boundary
    final path = Path();
    path.moveTo(corners[0].dx, corners[0].dy);
    for (int i = 1; i < corners.length; i++) {
      path.lineTo(corners[i].dx, corners[i].dy);
    }
    path.close();
    
    canvas.drawPath(path, paint);
    
    // Draw corner connection lines for better visibility
    final linePaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    // Draw dashed lines between corners
    for (int i = 0; i < corners.length; i++) {
      final start = corners[i];
      final end = corners[(i + 1) % corners.length];
      
      // Draw dashed line
      final distance = (end - start).distance;
      final dashLength = 8.0;
      final dashSpace = 4.0;
      final dashCount = (distance / (dashLength + dashSpace)).floor();
      
      for (int j = 0; j < dashCount; j++) {
        final startRatio = j * (dashLength + dashSpace) / distance;
        final endRatio = (j * (dashLength + dashSpace) + dashLength) / distance;
        
        final dashStart = Offset.lerp(start, end, startRatio)!;
        final dashEnd = Offset.lerp(start, end, endRatio)!;
        
        canvas.drawLine(dashStart, dashEnd, linePaint);
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Custom painter for drawing document edges with stability indication
class DocumentEdgePainter extends CustomPainter {
  final List<Offset> corners;
  final bool isStable;
  
  DocumentEdgePainter(this.corners, this.isStable);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;
    
    final paint = Paint()
      ..color = isStable ? Colors.green : Colors.orange
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    
    // Draw the document boundary
    final path = Path();
    path.moveTo(corners[0].dx, corners[0].dy);
    for (int i = 1; i < corners.length; i++) {
      path.lineTo(corners[i].dx, corners[i].dy);
    }
    path.close();
    
    canvas.drawPath(path, paint);
    
    // Draw corner points
    final cornerPaint = Paint()
      ..color = isStable ? Colors.green : Colors.orange
      ..style = PaintingStyle.fill;
    
    for (final corner in corners) {
      canvas.drawCircle(corner, 6.0, cornerPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
class CornerConnectionPainter extends CustomPainter {
  final List<Offset> corners;
  
  CornerConnectionPainter(this.corners);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;
    
    // Draw connecting lines between corners
    final linePaint = Paint()
      ..color = Colors.blue.withOpacity(0.8)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    
    // Draw the document boundary path
    final path = Path();
    path.moveTo(corners[0].dx, corners[0].dy);
    for (int i = 1; i < corners.length; i++) {
      path.lineTo(corners[i].dx, corners[i].dy);
    }
    path.close();
    
    canvas.drawPath(path, linePaint);
    
    // Draw corner indicators (small circles at each corner)
    final cornerPaint = Paint()
      ..color = Colors.blue.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    
    for (final corner in corners) {
      canvas.drawCircle(corner, 8.0, cornerPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}