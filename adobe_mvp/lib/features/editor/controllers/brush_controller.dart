// features/editor/controllers/brush_controller.dart
// Controller for brush selection tool

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/editing_image_manager.dart';
import '../../../models/selection.dart';
import 'selection_mode_controller.dart';

/// State for brush strokes
class BrushState {
  /// All stroke points with their positions and radii
  final List<BrushPoint> points;
  
  /// Current brush size (radius)
  final double brushSize;
  
  /// Whether currently painting
  final bool isPainting;
  
  /// Whether processing the selection
  final bool isProcessing;
  
  const BrushState({
    this.points = const [],
    this.brushSize = 30.0,
    this.isPainting = false,
    this.isProcessing = false,
  });
  
  BrushState copyWith({
    List<BrushPoint>? points,
    double? brushSize,
    bool? isPainting,
    bool? isProcessing,
  }) {
    return BrushState(
      points: points ?? this.points,
      brushSize: brushSize ?? this.brushSize,
      isPainting: isPainting ?? this.isPainting,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
  
  /// Check if there are any brush strokes
  bool get hasStrokes => points.isNotEmpty;
}

/// Single brush point with position and radius
class BrushPoint {
  final Offset position;
  final double radius;
  
  const BrushPoint({
    required this.position,
    required this.radius,
  });
}

/// Controller for brush selection
class BrushController extends StateNotifier<BrushState> {
  final Ref _ref;
  
  BrushController(this._ref) : super(const BrushState());
  
  /// Set brush size
  void setBrushSize(double size) {
    state = state.copyWith(brushSize: size.clamp(10.0, 100.0));
    // Also update in selection mode controller
    _ref.read(selectionModeProvider.notifier).setBrushSize(size);
  }
  
  /// Start painting
  void startPainting(Offset point) {
    final brushSize = _ref.read(brushSizeProvider);
    state = BrushState(
      points: [BrushPoint(position: point, radius: brushSize)],
      brushSize: brushSize,
      isPainting: true,
    );
  }
  
  /// Continue painting
  void continuePainting(Offset point) {
    if (!state.isPainting) return;
    
    // Add point if it's far enough from the last point
    final lastPoint = state.points.last;
    final distance = (point - lastPoint.position).distance;
    
    // Add interpolated points for smooth strokes
    if (distance > 1.0) {
      final newPoints = <BrushPoint>[...state.points];
      
      // Interpolate points for smoother line
      final steps = (distance / 3.0).ceil();
      for (int i = 1; i <= steps; i++) {
        final t = i / steps;
        final interpolated = Offset.lerp(lastPoint.position, point, t)!;
        newPoints.add(BrushPoint(
          position: interpolated,
          radius: state.brushSize,
        ));
      }
      
      state = state.copyWith(points: newPoints);
    }
  }
  
  /// End painting and process selection
  void endPainting() {
    if (!state.isPainting) return;
    
    state = state.copyWith(isPainting: false);
    
    if (state.hasStrokes) {
      _processBrushSelection();
    }
  }
  
  /// Process brush strokes into a mask
  Future<void> _processBrushSelection() async {
    if (!state.hasStrokes) return;
    
    state = state.copyWith(isProcessing: true);
    
    try {
      final editingImage = _ref.read(editingImageProvider);
      if (editingImage == null) {
        throw Exception('No image loaded');
      }
      
      final imageSize = editingImage.imageSize;
      final selectionMode = _ref.read(currentModeProvider);
      
      // Create mask from brush strokes
      final mask = _createMaskFromStrokes(
        state.points,
        imageSize.width.toInt(),
        imageSize.height.toInt(),
      );
      
      if (selectionMode == SelectionMode.add) {
        // Add selection
        await _ref.read(editingImageProvider.notifier).addSelection(
          mask: mask,
          source: SelectionSource.brush,
          className: 'Brush Selection',
        );
      } else {
        // Subtract selection (remove overlapping parts from existing selections)
        await _ref.read(editingImageProvider.notifier).subtractSelection(
          subtractMask: mask,
          source: SelectionSource.brush,
        );
      }
      
      // Clear brush state
      clear();
      
    } catch (e) {
      state = state.copyWith(isProcessing: false);
    }
  }
  
  /// Create binary mask from brush strokes
  List<List<int>> _createMaskFromStrokes(List<BrushPoint> strokes, int width, int height) {
    final mask = List.generate(height, (_) => List.filled(width, 0));
    
    // For each stroke point, fill circle at that position
    for (final stroke in strokes) {
      final cx = stroke.position.dx.round();
      final cy = stroke.position.dy.round();
      final radius = stroke.radius.round();
      
      // Fill circle
      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          final x = cx + dx;
          final y = cy + dy;
          
          // Check bounds
          if (x >= 0 && x < width && y >= 0 && y < height) {
            // Check if inside circle
            if (dx * dx + dy * dy <= radius * radius) {
              mask[y][x] = 1;
            }
          }
        }
      }
    }
    
    return mask;
  }
  
  /// Confirm current brush selection manually
  Future<void> confirmSelection() async {
    if (!state.hasStrokes) return;
    await _processBrushSelection();
  }
  
  /// Clear brush state
  void clear() {
    state = BrushState(brushSize: state.brushSize);
  }
  
  /// Cancel current brush strokes
  void cancel() {
    clear();
  }
  
  /// Add strokes to existing (for multi-stroke selection)
  void addMoreStrokes() {
    // Just mark as not processing, keep existing strokes
    state = state.copyWith(isPainting: false, isProcessing: false);
  }
}

// Provider
final brushControllerProvider = StateNotifierProvider<BrushController, BrushState>(
  (ref) => BrushController(ref),
);

/// Convenience providers
final isBrushPaintingProvider = Provider<bool>((ref) {
  return ref.watch(brushControllerProvider).isPainting;
});

final brushPointsProvider = Provider<List<BrushPoint>>((ref) {
  return ref.watch(brushControllerProvider).points;
});

final brushHasStrokesProvider = Provider<bool>((ref) {
  return ref.watch(brushControllerProvider).hasStrokes;
});
