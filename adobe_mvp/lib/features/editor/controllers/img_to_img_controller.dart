// features/editor/controllers/img_to_img_controller.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/ai_api.dart';
import '../../../state/editing_image_manager.dart';
import '../../../state/providers.dart';
import '../../../models/edit_state.dart';

class ImgToImgController extends ChangeNotifier {
  final Ref _ref;
  
  ImgToImgController(this._ref);
  
  bool _isProcessing = false;
  Uint8List? _resultImage;
  String? _errorMessage;

  bool get isProcessing => _isProcessing;
  Uint8List? get resultImage => _resultImage;
  String? get errorMessage => _errorMessage;

  /// Transform the current image using a text prompt
  /// 
  /// [prompt] - Text description of the desired transformation
  Future<void> transformImage(String prompt) async {
    if (prompt.trim().isEmpty) {
      _errorMessage = 'Prompt cannot be empty';
      notifyListeners();
      return;
    }

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Get current image bytes
      final imageBytes = _ref.read(currentImageBytesProvider);
      
      if (imageBytes == null) {
        throw Exception('No image loaded');
      }

      // Call the imgToImg API
      final resultPath = await AiApi.imgToImg(
        imageBytes: imageBytes,
        prompt: prompt,
      );

      // Read the result image
      final File resultFile = File(resultPath);
      _resultImage = await resultFile.readAsBytes();

      // Update global EditingImageManager state
      if (_resultImage != null) {
        final imageManager = _ref.read(editingImageProvider.notifier);
        imageManager.updateImage(
          _resultImage!,
          operation: EditOperation.prompt,
          description: 'Prompt: ${prompt.length > 30 ? '${prompt.substring(0, 30)}...' : prompt}',
          metadata: {'prompt': prompt},
        );
      }

      // Clean up temporary file
      try {
        // await resultFile.delete();
      } catch (e) {
        // Could not delete temporary file
      }
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void clearResult() {
    _resultImage = null;
    _errorMessage = null;
    notifyListeners();
  }
}

final imgToImgControllerProvider = ChangeNotifierProvider<ImgToImgController>((ref) {
  return ImgToImgController(ref);
});
