// features/editor/controllers/lasso_controller.dart
// Controller for lasso selection tool

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/editing_image_manager.dart';
import '../../../models/selection.dart';
import 'selection_mode_controller.dart';

/// State for lasso drawing
class LassoState {
  /// Points of the lasso path (in image coordinates)
  final List<Offset> points;
  
  /// Whether lasso is currently being drawn
  final bool isDrawing;
  
  /// Whether lasso is closed (ready to select)
  final bool isClosed;
  
  /// Whether processing the selection
  final bool isProcessing;
  
  const LassoState({
    this.points = const [],
    this.isDrawing = false,
    this.isClosed = false,
    this.isProcessing = false,
  });
  
  LassoState copyWith({
    List<Offset>? points,
    bool? isDrawing,
    bool? isClosed,
    bool? isProcessing,
  }) {
    return LassoState(
      points: points ?? this.points,
      isDrawing: isDrawing ?? this.isDrawing,
      isClosed: isClosed ?? this.isClosed,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
  
  /// Check if lasso has enough points to form a valid selection
  bool get isValid => points.length >= 3;
  
  /// Get path for drawing
  Path? get path {
    if (points.length < 2) return null;
    
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    
    if (isClosed) {
      path.close();
    }
    
    return path;
  }
}

/// Controller for lasso selection
class LassoController extends StateNotifier<LassoState> {
  final Ref _ref;
  
  LassoController(this._ref) : super(const LassoState());
  
  /// Start drawing lasso
  void startDrawing(Offset point) {
    state = LassoState(
      points: [point],
      isDrawing: true,
      isClosed: false,
    );
  }
  
  /// Continue drawing lasso
  void continueDrawing(Offset point) {
    if (!state.isDrawing) return;
    
    // Add point if it's far enough from the last point (avoid duplicates)
    final lastPoint = state.points.last;
    final distance = (point - lastPoint).distance;
    
    if (distance > 2.0) { // Minimum distance threshold
      state = state.copyWith(
        points: [...state.points, point],
      );
    }
  }
  
  /// End drawing lasso
  void endDrawing() {
    if (!state.isDrawing) return;
    
    // Check if we have enough points for a valid selection
    if (state.points.length >= 3) {
      // Always close the lasso when drawing ends (connect back to start)
      state = state.copyWith(
        isDrawing: false,
        isClosed: true,
      );
      
      // Process the selection
      _processLassoSelection();
    } else {
      // Not enough points, cancel
      clear();
    }
  }
  
  /// Process the lasso selection into a mask
  Future<void> _processLassoSelection() async {
    if (!state.isValid || !state.isClosed) return;
    
    state = state.copyWith(isProcessing: true);
    
    try {
      final editingImage = _ref.read(editingImageProvider);
      if (editingImage == null) {
        throw Exception('No image loaded');
      }
      
      final imageSize = editingImage.imageSize;
      final selectionMode = _ref.read(currentModeProvider);
      
      // Create mask from lasso path
      final mask = _createMaskFromPath(
        state.path!,
        imageSize.width.toInt(),
        imageSize.height.toInt(),
      );
      
      if (selectionMode == SelectionMode.add) {
        // Add selection
        await _ref.read(editingImageProvider.notifier).addSelection(
          mask: mask,
          source: SelectionSource.lasso,
          className: 'Lasso Selection',
        );
      } else {
        // Subtract selection (remove overlapping parts from existing selections)
        await _ref.read(editingImageProvider.notifier).subtractSelection(
          subtractMask: mask,
          source: SelectionSource.lasso,
        );
      }
      
      // Clear lasso state
      clear();
      
    } catch (e) {
      state = state.copyWith(isProcessing: false);
    }
  }
  
  /// Create binary mask from path
  List<List<int>> _createMaskFromPath(Path path, int width, int height) {
    final mask = List.generate(height, (_) => List.filled(width, 0));
    
    // Check each pixel if it's inside the path
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (path.contains(Offset(x.toDouble(), y.toDouble()))) {
          mask[y][x] = 1;
        }
      }
    }
    
    return mask;
  }
  
  /// Confirm current lasso selection manually
  Future<void> confirmSelection() async {
    if (!state.isValid) return;
    
    // Close the path if not already
    if (!state.isClosed) {
      state = state.copyWith(isClosed: true);
    }
    
    await _processLassoSelection();
  }
  
  /// Clear lasso state
  void clear() {
    state = const LassoState();
  }
  
  /// Cancel current lasso
  void cancel() {
    clear();
  }
}

// Provider
final lassoControllerProvider = StateNotifierProvider<LassoController, LassoState>(
  (ref) => LassoController(ref),
);

/// Convenience providers
final isLassoDrawingProvider = Provider<bool>((ref) {
  return ref.watch(lassoControllerProvider).isDrawing;
});

final lassoPointsProvider = Provider<List<Offset>>((ref) {
  return ref.watch(lassoControllerProvider).points;
});

final lassoPathProvider = Provider<Path?>((ref) {
  return ref.watch(lassoControllerProvider).path;
});
