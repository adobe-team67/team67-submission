import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/ai_api.dart';
import '../../../state/editing_image_manager.dart';
import '../../../models/edit_state.dart';

class InpaintController extends ChangeNotifier {
  final Ref _ref;
  
  InpaintController(this._ref);
  
  bool _isProcessing = false;
  Uint8List? _resultImage;
  String? _errorMessage;

  bool get isProcessing => _isProcessing;
  Uint8List? get resultImage => _resultImage;
  String? get errorMessage => _errorMessage;

  void clear() {
    _resultImage = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Inpaint the current selection using the new convenience API
  /// Uses stored image name and selected mask IDs from AiApi
  /// Also supports manual masks for non-object selections
  Future<void> inpaintSelection(String prompt) async {
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

      // Call the inpaint API using convenience method
      final String resultPath = await AiApi.inpaintCurrentSelection(
        prompt: prompt,
        manualMasks: manualMasks.isNotEmpty ? manualMasks : null,
      );

      // Read result image
      final File resultFile = File(resultPath);
      _resultImage = await resultFile.readAsBytes();

      // Clean up temporary file
      try {
        await resultFile.delete();
      } catch (e) {
        // Could not clean up temp file
      }

      // Update global EditingImageManager state
      if (_resultImage != null) {
        imageManager.updateImage(
          _resultImage!,
          operation: EditOperation.inpaint,
          description: 'Inpaint: ${prompt.length > 30 ? '${prompt.substring(0, 30)}...' : prompt}',
          metadata: {'prompt': prompt},
        );
        
        // Clear selections after successful inpaint
        imageManager.clearSelections();
      }

      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isProcessing = false;
      notifyListeners();
      rethrow;
    }
  }
}

// Provider
final inpaintControllerProvider = ChangeNotifierProvider<InpaintController>(
  (ref) => InpaintController(ref),
);