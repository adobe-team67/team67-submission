// state/edit_history_notifier.dart
// StateNotifier that manages EditHistory with clean undo/redo API.

import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/edit_state.dart';
import '../models/edit_history.dart';
import '../models/detected_object.dart';

/// Notifier that manages the edit history stack.
/// Provides clean API for pushing new states, undo, redo.
class EditHistoryNotifier extends StateNotifier<EditHistory> {
  EditHistoryNotifier() : super(const EditHistory());

  static const _uuid = Uuid();

  // ─────────────────────────────────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Current image bytes (null if no image loaded)
  Uint8List? get currentImageBytes => state.current?.imageBytes;

  /// Current mask bytes (null if no mask)
  Uint8List? get currentMaskBytes => state.current?.maskBytes;

  /// Whether undo is available
  bool get canUndo => state.canUndo;

  /// Whether redo is available
  bool get canRedo => state.canRedo;

  /// Current edit state
  EditState? get currentState => state.current;
  
  /// Get detected objects for current state
  List<DetectedObject> get currentDetectedObjects => state.current?.detectedObjects ?? [];
  
  /// Get stored masks for current state
  List<List<List<int>>> get currentStoredMasks => state.current?.storedMasks ?? [];
  
  /// Whether detection is complete for current state
  bool get currentDetectionComplete => state.current?.detectionComplete ?? false;
  
  /// Get backend image name for current state
  String? get currentBackendImageName => state.current?.backendImageName;

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Load initial image (clears history and starts fresh)
  void loadImage(Uint8List imageBytes) {
    final initialState = EditState(
      id: _uuid.v4(),
      imageBytes: imageBytes,
      operation: EditOperation.initial,
      description: 'Original image',
      timestamp: DateTime.now(),
    );
    state = state.clear(initialState);
  }

  /// Push a new edit state after an operation
  void pushEdit({
    required Uint8List imageBytes,
    Uint8List? maskBytes,
    required EditOperation operation,
    required String description,
    Map<String, dynamic>? metadata,
  }) {
    final newState = EditState(
      id: _uuid.v4(),
      imageBytes: imageBytes,
      maskBytes: maskBytes,
      operation: operation,
      description: description,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
    state = state.push(newState);
  }

  /// Update only the mask (doesn't create new history entry)
  /// Useful for live mask drawing before committing
  void updateMask(Uint8List? maskBytes) {
    if (state.current == null) return;
    final updated = state.current!.copyWith(maskBytes: maskBytes);
    state = EditHistory(
      past: state.past,
      current: updated,
      future: state.future,
      maxHistorySize: state.maxHistorySize,
    );
  }
  
  /// Update detected objects for current state (after YOLO detection)
  void updateDetectedObjects({
    required List<DetectedObject> detectedObjects,
    required List<List<List<int>>> storedMasks,
    required String backendImageName,
    required bool detectionComplete,
  }) {
    if (state.current == null) return;
    final updated = state.current!.copyWith(
      detectedObjects: detectedObjects,
      storedMasks: storedMasks,
      backendImageName: backendImageName,
      detectionComplete: detectionComplete,
    );
    state = EditHistory(
      past: state.past,
      current: updated,
      future: state.future,
      maxHistorySize: state.maxHistorySize,
    );
  }
  
  /// Add a manual mask to current state's stored masks
  /// Returns the index of the added mask
  int addManualMask(List<List<int>> mask) {
    if (state.current == null) return -1;
    
    final currentMasks = List<List<List<int>>>.from(state.current!.storedMasks);
    currentMasks.add(mask);
    
    final updated = state.current!.copyWith(storedMasks: currentMasks);
    state = EditHistory(
      past: state.past,
      current: updated,
      future: state.future,
      maxHistorySize: state.maxHistorySize,
    );
    
    return currentMasks.length - 1;
  }
  
  /// Update backend image name for current state (after re-upload on undo/redo)
  void updateBackendImageName(String backendImageName) {
    if (state.current == null) return;
    final updated = state.current!.copyWith(backendImageName: backendImageName);
    state = EditHistory(
      past: state.past,
      current: updated,
      future: state.future,
      maxHistorySize: state.maxHistorySize,
    );
  }

  /// Undo last operation
  void undo() {
    if (!canUndo) return;
    state = state.undo();
  }

  /// Redo last undone operation
  void redo() {
    if (!canRedo) return;
    state = state.redo();
  }

  /// Clear all history
  void clear() {
    state = const EditHistory();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONVENIENCE METHODS FOR COMMON OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Apply inpaint result
  void applyInpaint(Uint8List resultBytes, {String? prompt}) {
    pushEdit(
      imageBytes: resultBytes,
      operation: EditOperation.inpaint,
      description: prompt ?? 'Inpaint / Remove object',
      metadata: prompt != null ? {'prompt': prompt} : null,
    );
  }

  void applyErase(Uint8List resultBytes) {
    pushEdit(
      imageBytes: resultBytes,
      operation: EditOperation.erase,
      description: 'Erase',
    );
  }

  void applyMove(Uint8List resultBytes) {
    pushEdit(
      imageBytes: resultBytes,
      operation: EditOperation.move,
      description: 'Move',
    );
  }

  /// Apply style transfer result
  void applyStylize(Uint8List resultBytes, {String? styleName, String? prompt}) {
    pushEdit(
      imageBytes: resultBytes,
      operation: EditOperation.stylize,
      description: styleName ?? 'Style transfer',
      metadata: {
        if (styleName != null) 'style': styleName,
        if (prompt != null) 'prompt': prompt,
      },
    );
  }

  applyResize(Uint8List resultBytes, String description) {
    pushEdit(
      imageBytes: resultBytes,
      operation: EditOperation.resize,
      description: description,
    );
  }

  /// Apply magic view (perspective) result
  void applyMagicView(Uint8List resultBytes, String direction) {
    pushEdit(
      imageBytes: resultBytes,
      operation: EditOperation.magicView,
      description: 'MagicView: $direction',
      metadata: {'direction': direction},
    );
  }

  /// Apply filter result
  void applyFilter(Uint8List resultBytes, String filterName, {double? value}) {
    pushEdit(
      imageBytes: resultBytes,
      operation: EditOperation.filter,
      description: filterName,
      metadata: {
        'filter': filterName,
        if (value != null) 'value': value,
      },
    );
  }

  /// Apply crop result
  void applyCrop(Uint8List resultBytes) {
    pushEdit(
      imageBytes: resultBytes,
      operation: EditOperation.crop,
      description: 'Crop',
    );
  }

  /// Apply prompt-based edit result
  void applyPromptEdit(Uint8List resultBytes, String prompt) {
    pushEdit(
      imageBytes: resultBytes,
      operation: EditOperation.prompt,
      description: 'Prompt: ${prompt.length > 30 ? '${prompt.substring(0, 30)}...' : prompt}',
      metadata: {'prompt': prompt},
    );
  }

  /// Get history summary for debugging
  List<String> getHistorySummary() => state.historySummary;
}
