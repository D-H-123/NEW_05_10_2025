import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

class DocumentScannerService {
  static Future<String?> scanDocument() async {
    try {
      // Use image picker for now - this is more reliable
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 90,
      );
      
      if (image != null) {
        // Copy to our app's temp directory for consistency
        final Directory tempDir = await getTemporaryDirectory();
        final String imagePath = '${tempDir.path}/scanned_document_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        final File originalFile = File(image.path);
        final File newFile = await originalFile.copy(imagePath);
        
        return newFile.path;
      }
      
      return null;
    } catch (e) {
      print('Document scanning error: $e');
      return null;
    }
  }

  static Future<void> initializeEdgeDetection() async {
    // No initialization needed for this implementation
    print('Document scanner initialized');
  }
}
