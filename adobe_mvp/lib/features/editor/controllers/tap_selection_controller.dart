import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/providers.dart';
import '../../../state/editing_image_manager.dart';
import '../../../models/selection.dart';

class TapSelectionController extends ChangeNotifier {
  bool _isActive = false;
  Offset? _selectedCoordinate;
  List<List<int>>? _bitmask;
  ui.Image? _decodedImage;
  bool _isProcessing = false;

  bool get isActive => _isActive;
  Offset? get selectedCoordinate => _selectedCoordinate;
  List<List<int>>? get bitmask => _bitmask;
  bool get isProcessing => _isProcessing;

  void toggleSelection() {
    _isActive = !_isActive;
    if (!_isActive) {
      clear();
    }
    notifyListeners();
  }

  void clear() {
    _selectedCoordinate = null;
    _bitmask = null;
    _decodedImage = null;
    notifyListeners();
  }

  /// Set the mask directly from a detected object
  void setMask(List<List<int>> mask) {
    _bitmask = mask;
    _selectedCoordinate = null; // Clear tap coordinate since selection is from object list
    notifyListeners();
  }

  Future<void> selectPoint(
      Offset coordinate, Uint8List imageBytes, WidgetRef ref) async {
    _selectedCoordinate = coordinate;
    _isProcessing = true;
    notifyListeners();

    try {
      if (_decodedImage == null) {
        _decodedImage = await decodeImageFromList(imageBytes);
      }

      if (_decodedImage == null) {
        throw Exception('Failed to decode image');
      }

      // ============================================================
      // USING YOLO MODEL (TEMPORARY - FOR TESTING)
      // ============================================================
      final yolo = ref.read(yoloProvider);
      final bitmask = await yolo.detectMaskAtPointFromUIImage(
        _decodedImage!,
        coordinate.dx,
        coordinate.dy,
      );

      _bitmask = bitmask;
      
      // Add selection to EditingImageManager
      if (bitmask != null && bitmask.isNotEmpty) {
        final imageManager = ref.read(editingImageProvider.notifier);
        await imageManager.addSelection(
          mask: bitmask,
          source: SelectionSource.tap,
          className: 'Tap Selection',
        );
      }

      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      _isProcessing = false;
      notifyListeners();
      rethrow;
    }
  }
}

// Provider
final tapSelectionControllerProvider =
    ChangeNotifierProvider<TapSelectionController>(
  (ref) => TapSelectionController(),
);
