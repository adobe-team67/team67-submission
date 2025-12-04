// features/editor/controllers/stylize_controller.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/ai_api.dart';
import '../../../state/editing_image_manager.dart';
import '../../../state/providers.dart';
import '../../../models/edit_state.dart';

class StylizeController extends ChangeNotifier {
  final Ref _ref;
  
  StylizeController(this._ref);
  
  bool _isProcessing = false;
  Uint8List? _resultImage;
  String? _errorMessage;

  bool get isProcessing => _isProcessing;
  Uint8List? get resultImage => _resultImage;
  String? get errorMessage => _errorMessage;

  /// Stylize the current image
  /// 
  /// [prompt] - Text description of the desired style (optional if preset is provided)
  /// [style] - Preset style name (e.g., 'Cinematic', 'Vintage', 'Neon', etc.)
  /// [targetImage] - Reference image for custom style transfer (optional)
  Future<void> stylizeImage({
    String prompt = '',
    String? style,
    Uint8List? targetImage,
  }) async {
    // Need either a preset style or reference image
    if (style == null && targetImage == null) {
      _errorMessage = 'Please select a preset style or attach a reference image';
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

      final effectivePrompt = prompt.trim().isEmpty ? (style ?? '') : prompt.trim();

      // Call the stylize API
      final resultPath = await AiApi.stylize(
        imageBytes: imageBytes,
        targetImage: targetImage,
        prompt: effectivePrompt,
        style: style,
      );

      // Read the result image
      final File resultFile = File(resultPath);
      _resultImage = await resultFile.readAsBytes();

      // Update global EditingImageManager state
      if (_resultImage != null) {
        final imageManager = _ref.read(editingImageProvider.notifier);
        imageManager.updateImage(
          _resultImage!,
          operation: EditOperation.stylize,
          description: 'Stylize: ${style ?? 'Custom'}',
          metadata: {
            'prompt': effectivePrompt,
            'style': style ?? 'Custom',
            'hasReferenceImage': targetImage != null,
          },
        );
      }

      // Clean up temporary file
      try {
        await resultFile.delete();
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

final stylizeControllerProvider = ChangeNotifierProvider<StylizeController>((ref) {
  return StylizeController(ref);
});
