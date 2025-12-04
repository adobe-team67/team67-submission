// features/editor/controllers/move_controller.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/ai_api.dart';
import '../../../state/editing_image_manager.dart';
import '../../../models/edit_state.dart';

class MoveController extends ChangeNotifier {
  final Ref _ref;
  
  MoveController(this._ref);
  
  bool _isProcessing = false;
  Uint8List? _resultImage;
  String? _errorMessage;

  bool get isProcessing => _isProcessing;
  Uint8List? get resultImage => _resultImage;
  String? get errorMessage => _errorMessage;

  /// Move the current selection using the new convenience API
  /// Uses stored image name and selected mask IDs from AiApi
  /// Also supports manual masks for non-object selections
  /// 
  /// [startX], [startY] - Original position of the object (from originalCenter)
  /// [endX], [endY] - Target position after move
  /// [prompt] - Optional prompt for background fill
  Future<void> moveSelection({
    required int startX,
    required int startY,
    required int endX,
    required int endY,
    String? prompt,
  }) async {
    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Get the selected mask indices from EditingImageManager
      final imageManager = _ref.read(editingImageProvider.notifier);
      final state = _ref.read(editingImageProvider);
      
      if (state == null) {
        throw Exception('No image loaded');
      }
      
      // Get selected object indices
      final selectedIndices = state.selectedObjectIds.toList();
      
      // Get manual masks (selections not from object list)
      final manualMasks = imageManager.getManualSelectionMasks();
      
      if (selectedIndices.isEmpty && manualMasks.isEmpty) {
        throw Exception('No objects or areas selected');
      }
      
      // Update AiApi with the selected mask IDs
      AiApi.setMaskIds(selectedIndices);

      // Call the move API using convenience method
      final resultPath = await AiApi.moveCurrentSelection(
        startX: startX,
        startY: startY,
        endX: endX,
        endY: endY,
        prompt: prompt,
        manualMasks: manualMasks.isNotEmpty ? manualMasks : null,
      );

      // Read the result image
      final File resultFile = File(resultPath);
      _resultImage = await resultFile.readAsBytes();

      // Update global EditingImageManager state
      if (_resultImage != null) {
        imageManager.updateImage(
          _resultImage!,
          operation: EditOperation.move,
          description: 'Move selection from ($startX, $startY) to ($endX, $endY)',
          metadata: {
            'startX': startX,
            'startY': startY,
            'endX': endX,
            'endY': endY,
            if (prompt != null) 'prompt': prompt,
          },
        );
        
        // Clear selections after successful move
        imageManager.clearSelections();
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

final moveControllerProvider = ChangeNotifierProvider<MoveController>((ref) {
  return MoveController(ref);
});
