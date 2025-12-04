// state/selection_manager.dart
// Unified selection state manager using Riverpod

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/selection.dart';
import '../models/detected_object.dart';

/// State class holding all selections
class SelectionState {
  /// All active selections
  final List<Selection> selections;
  
  /// Whether YOLO detection is running
  final bool isDetecting;
  
  /// All detected objects from YOLO (for object list UI)
  final List<DetectedObject> detectedObjects;
  
  /// Source image bytes (for generating cutouts)
  final Uint8List? sourceImageBytes;
  
  /// Size of the source image
  final Size? imageSize;
  
  const SelectionState({
    this.selections = const [],
    this.isDetecting = false,
    this.detectedObjects = const [],
    this.sourceImageBytes,
    this.imageSize,
  });
  
  /// Check if any selections exist
  bool get hasSelections => selections.isNotEmpty;
  
  /// Get combined mask of all selections
  List<List<int>>? get combinedMask {
    if (selections.isEmpty) return null;
    
    // Use first selection's mask dimensions
    final firstMask = selections.first.mask;
    final height = firstMask.length;
    final width = firstMask.isNotEmpty ? firstMask[0].length : 0;
    
    if (width == 0 || height == 0) return null;
    
    // Create combined mask
    final combined = List.generate(height, (_) => List.filled(width, 0));
    
    for (final sel in selections) {
      for (int y = 0; y < height && y < sel.mask.length; y++) {
        for (int x = 0; x < width && x < sel.mask[y].length; x++) {
          if (sel.mask[y][x] == 1) {
            combined[y][x] = 1;
          }
        }
      }
    }
    
    return combined;
  }
  
  SelectionState copyWith({
    List<Selection>? selections,
    bool? isDetecting,
    List<DetectedObject>? detectedObjects,
    Uint8List? sourceImageBytes,
    Size? imageSize,
  }) {
    return SelectionState(
      selections: selections ?? this.selections,
      isDetecting: isDetecting ?? this.isDetecting,
      detectedObjects: detectedObjects ?? this.detectedObjects,
      sourceImageBytes: sourceImageBytes ?? this.sourceImageBytes,
      imageSize: imageSize ?? this.imageSize,
    );
  }
}

/// SelectionManager handles all selection operations
class SelectionManager extends StateNotifier<SelectionState> {
  SelectionManager() : super(const SelectionState());
  
  int _selectionCounter = 0;
  
  /// Set the source image for selections
  void setSourceImage(Uint8List imageBytes, Size imageSize) {
    state = state.copyWith(
      sourceImageBytes: imageBytes,
      imageSize: imageSize,
    );
  }
  
  /// Set detection loading state
  void setDetecting(bool isDetecting) {
    state = state.copyWith(isDetecting: isDetecting);
  }
  
  /// Set detected objects from YOLO
  void setDetectedObjects(List<DetectedObject> objects) {
    state = state.copyWith(
      detectedObjects: objects,
      isDetecting: false,
    );
  }
  
  /// Add a selection from a mask
  Future<void> addSelection({
    required List<List<int>> mask,
    required SelectionSource source,
    String? className,
    double? confidence,
  }) async {
    final id = 'sel_${_selectionCounter++}_${DateTime.now().millisecondsSinceEpoch}';
    
    final selection = Selection(
      id: id,
      mask: mask,
      source: source,
      className: className,
      confidence: confidence,
    );
    
    // Generate cutout if we have source image
    if (state.sourceImageBytes != null) {
      try {
        await selection.generateCutout(state.sourceImageBytes!);
      } catch (e) {
        // Silently handle cutout generation error
      }
    }
    
    state = state.copyWith(
      selections: [...state.selections, selection],
    );
  }
  
  /// Add selection from a DetectedObject
  Future<void> addFromDetectedObject(DetectedObject obj) async {
    await addSelection(
      mask: obj.mask,
      source: SelectionSource.objectList,
      className: obj.className,
      confidence: obj.confidence,
    );
  }
  
  /// Toggle selection of a detected object
  Future<void> toggleDetectedObject(DetectedObject obj) async {
    // Check if this object is already selected (by matching mask)
    final existingIndex = state.selections.indexWhere(
      (sel) => sel.source == SelectionSource.objectList && 
               sel.className == obj.className &&
               _masksMatch(sel.mask, obj.mask),
    );
    
    if (existingIndex >= 0) {
      // Remove existing selection
      removeSelection(state.selections[existingIndex].id);
    } else {
      // Add new selection
      await addFromDetectedObject(obj);
    }
  }
  
  /// Check if a detected object is currently selected
  bool isObjectSelected(DetectedObject obj) {
    return state.selections.any(
      (sel) => sel.source == SelectionSource.objectList && 
               sel.className == obj.className &&
               _masksMatch(sel.mask, obj.mask),
    );
  }
  
  /// Simple mask comparison (checks if masks have same dimensions and values)
  bool _masksMatch(List<List<int>> mask1, List<List<int>> mask2) {
    if (mask1.length != mask2.length) return false;
    if (mask1.isEmpty) return mask2.isEmpty;
    if (mask1[0].length != mask2[0].length) return false;
    
    // Compare a sample of points for performance
    final sampleRate = 10;
    for (int y = 0; y < mask1.length; y += sampleRate) {
      for (int x = 0; x < mask1[y].length; x += sampleRate) {
        if (mask1[y][x] != mask2[y][x]) return false;
      }
    }
    return true;
  }
  
  /// Remove a selection by ID
  void removeSelection(String id) {
    state = state.copyWith(
      selections: state.selections.where((s) => s.id != id).toList(),
    );
  }
  
  /// Update selection offset (for drag/move)
  void updateSelectionOffset(String id, Offset newOffset) {
    final updatedSelections = state.selections.map((sel) {
      if (sel.id == id) {
        return sel.copyWith(offset: newOffset);
      }
      return sel;
    }).toList();
    
    state = state.copyWith(selections: updatedSelections);
  }
  
  /// Clear all selections
  void clearSelections() {
    state = state.copyWith(selections: []);
  }
  
  /// Clear detected objects and selections
  void clearAll() {
    _selectionCounter = 0;
    state = const SelectionState();
  }
}

/// Provider for SelectionManager
final selectionManagerProvider = StateNotifierProvider<SelectionManager, SelectionState>(
  (ref) => SelectionManager(),
);

/// Convenience providers
final hasSelectionsProvider = Provider<bool>((ref) {
  return ref.watch(selectionManagerProvider).hasSelections;
});

final isDetectingProvider = Provider<bool>((ref) {
  return ref.watch(selectionManagerProvider).isDetecting;
});

final detectedObjectsListProvider = Provider<List<DetectedObject>>((ref) {
  return ref.watch(selectionManagerProvider).detectedObjects;
});

final activeSelectionsProvider = Provider<List<Selection>>((ref) {
  return ref.watch(selectionManagerProvider).selections;
});
