import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import '../models/editing_image.dart';
import '../models/detected_object.dart';
import '../models/selection.dart';
import '../models/edit_state.dart';
import '../services/ai_api.dart';
import '../features/editor/controllers/selection_mode_controller.dart';
import 'providers.dart';
import 'edit_history_notifier.dart';

/// Manages image editing state including selections, YOLO detection, and history
class EditingImageManager extends StateNotifier<EditingImage?> {
  final Ref _ref;
  
  EditingImageManager(this._ref) : super(null);
  
  int _selectionCounter = 0;
  
  EditHistoryNotifier get _historyNotifier => _ref.read(editHistoryProvider.notifier);
  
  /// Load a new image for editing (resets all state)
  Future<void> loadImage({
    required Uint8List imageBytes,
    String? imagePath,
  }) async {
    // Decode to get dimensions
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw Exception('Failed to decode image');
    }
    
    final imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
    
    // Reset counter
    _selectionCounter = 0;
    
    // Clear previous API state
    AiApi.clearState();
    
    // Clear selection mode UI state
    _ref.read(selectionModeProvider.notifier).clear();
    
    // Create new EditingImage
    state = EditingImage.fromBytes(
      imageBytes: imageBytes,
      imageSize: imageSize,
      imagePath: imagePath,
    );
    
    // Also load into history system (clears all previous states)
    _historyNotifier.loadImage(imageBytes);
    
    _initializeBackendAndDetection(imageBytes, imageSize);
  }
  
  Future<void> _initializeBackendAndDetection(Uint8List imageBytes, Size imageSize) async {
    await _sendImageToBackend(imageBytes, imageSize);
    _runBackgroundDetection(imageBytes);
  }
  
  Future<void> _sendImageToBackend(Uint8List imageBytes, Size imageSize) async {
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final uiImage = frame.image;
      await AiApi.setImage(image: uiImage);
    } catch (e) {
      // Silently fail - background operation
    }
  }
  
  /// Runs YOLO object detection and syncs results with backend
  Future<void> _runBackgroundDetection(Uint8List imageBytes) async {
    if (state == null) return;
    state = state!.copyWith(isDetecting: true);
    
    try {
      final yolo = _ref.read(yoloProvider);
      final result = await yolo.detectFromBytes(imageBytes);
      
      if (result.masks.isNotEmpty) {
        final objects = <DetectedObject>[];
        
        for (int i = 0; i < result.masks.length; i++) {
          objects.add(DetectedObject(
            index: i,
            mask: result.masks[i],
            box: result.boxes[i],
            classId: result.classIds[i],
            confidence: result.confidences[i],
          ));
        }
        
        objects.sort((a, b) => b.confidence.compareTo(a.confidence));
        setDetectedObjects(objects);
        await _sendMasksToBackend(result.masks);
        
        final backendImageName = AiApi.getCurrentImageName();
        _historyNotifier.updateDetectedObjects(
          detectedObjects: objects,
          storedMasks: result.masks,
          backendImageName: backendImageName ?? '',
          detectionComplete: true,
        );
        
        if (state != null) {
          state = state!.copyWith(
            isDetecting: false,
            detectionComplete: true,
          );
        }
        _generatePreviewsInBackground(objects, imageBytes);
      } else {
        final backendImageName = AiApi.getCurrentImageName();
        _historyNotifier.updateDetectedObjects(
          detectedObjects: [],
          storedMasks: [],
          backendImageName: backendImageName ?? '',
          detectionComplete: true,
        );
        
        if (state != null) {
          state = state!.copyWith(
            isDetecting: false,
            detectionComplete: true,
            detectedObjects: [],
          );
        }
      }
    } catch (e) {
      if (state != null) {
        state = state!.copyWith(isDetecting: false);
      }
    }
  }
  
  Future<void> _sendMasksToBackend(List<List<List<int>>> masks) async {
    try {
      await AiApi.setMasks(masks: masks);
    } catch (e) {
      // Silently fail - background operation
    }
  }
  
  Future<void> _generatePreviewsInBackground(List<DetectedObject> objects, Uint8List imageBytes) async {
    for (final obj in objects) {
      try {
        final preview = await obj.generatePreview(imageBytes);
        updateObjectPreview(obj.index, preview);
      } catch (_) {}
    }
  }
  
  /// Update the current image bytes (after edit operation)
  /// This also pushes to undo/redo history and runs background detection
  void updateImage(
    Uint8List newImageBytes, {
    required EditOperation operation,
    required String description,
    Map<String, dynamic>? metadata,
  }) {
    if (state == null) return;
    
    final imageSize = state!.imageSize;
    
    state = state!.copyWith(
      currentImageBytes: newImageBytes,
      lastOperation: description,
      lastModified: DateTime.now(),
      // Reset detected objects - will be repopulated by detection
      detectedObjects: [],
      detectionComplete: false,
      isDetecting: true,
    );
    
    // Push to history for undo/redo (this creates new state without objects yet)
    _historyNotifier.pushEdit(
      imageBytes: newImageBytes,
      operation: operation,
      description: description,
      metadata: metadata,
    );
    
    // For new edits (not undo/redo), run detection in background
    // This will update the new history state with detected objects
    _initializeBackendAndDetection(newImageBytes, imageSize);
  }
  
  /// Sync image from history (after undo/redo)
  /// Restores frontend state from history and re-uploads to backend
  void syncFromHistory() {
    final currentState = _historyNotifier.currentState;
    if (currentState == null || state == null) return;
    
    final historyBytes = currentState.imageBytes;
    final detectedObjects = currentState.detectedObjects;
    final detectionComplete = currentState.detectionComplete;
    final backendImageName = currentState.backendImageName;
    final storedMasks = currentState.storedMasks;
    
    // Convert DetectedObject to DetectedObjectState
    final objectStates = detectedObjects.map((obj) => DetectedObjectState(
      object: obj,
      isPreviewLoading: false,
    )).toList();
    
    state = state!.copyWith(
      currentImageBytes: historyBytes,
      lastModified: DateTime.now(),
      detectedObjects: objectStates,
      detectionComplete: detectionComplete,
      isDetecting: false,
    );
    
    clearSelections();
    
    if (backendImageName != null && backendImageName.isNotEmpty) {
      AiApi.setImageName(backendImageName);
    } else {
      _reuploadImageToBackend(historyBytes, storedMasks);
    }
  }
  
  Future<void> _reuploadImageToBackend(Uint8List imageBytes, List<List<List<int>>> masks) async {
    try {
      final imageSize = state?.imageSize ?? const Size(0, 0);
      await _sendImageToBackend(imageBytes, imageSize);
      if (masks.isNotEmpty) {
        await _sendMasksToBackend(masks);
      }
    } catch (_) {}
  }
  
  /// Undo last operation
  bool undo() {
    if (!_historyNotifier.canUndo) return false;
    _historyNotifier.undo();
    syncFromHistory();
    return true;
  }
  
  /// Redo last undone operation
  bool redo() {
    if (!_historyNotifier.canRedo) return false;
    _historyNotifier.redo();
    syncFromHistory();
    return true;
  }
  
  /// Check if undo is available
  bool get canUndo => _historyNotifier.canUndo;
  
  /// Check if redo is available
  bool get canRedo => _historyNotifier.canRedo;
  
  void clearImage() {
    _selectionCounter = 0;
    state = null;
    _historyNotifier.clear();
  }
  
  void setDetecting(bool isDetecting) {
    if (state == null) return;
    state = state!.copyWith(isDetecting: isDetecting);
  }
  
  void setDetectionComplete(bool complete) {
    if (state == null) return;
    state = state!.copyWith(detectionComplete: complete);
  }
  
  void setDetectedObjects(List<DetectedObject> objects) {
    if (state == null) return;
    
    // Convert to DetectedObjectState list
    final objectStates = objects.map((obj) => DetectedObjectState(
      object: obj,
      isPreviewLoading: true, // Mark as loading initially
    )).toList();
    
    state = state!.copyWith(
      detectedObjects: objectStates,
      isDetecting: false,
    );
  }
  
  /// Update preview for a specific object
  void updateObjectPreview(int objectIndex, Uint8List previewBytes) {
    if (state == null) return;
    
    final updatedObjects = state!.detectedObjects.map((obj) {
      if (obj.index == objectIndex) {
        return obj.copyWith(
          previewBytes: previewBytes,
          isPreviewLoading: false,
        );
      }
      return obj;
    }).toList();
    
    state = state!.copyWith(detectedObjects: updatedObjects);
  }
  
  /// Mark object preview as loading
  void setObjectPreviewLoading(int objectIndex, bool isLoading) {
    if (state == null) return;
    
    final updatedObjects = state!.detectedObjects.map((obj) {
      if (obj.index == objectIndex) {
        return obj.copyWith(isPreviewLoading: isLoading);
      }
      return obj;
    }).toList();
    
    state = state!.copyWith(detectedObjects: updatedObjects);
  }
  
  /// Clear all detected objects
  void clearDetectedObjects() {
    if (state == null) return;
    state = state!.copyWith(
      detectedObjects: [],
      selectedObjectIds: {},
    );
  }
  
  Future<void> toggleObjectSelection(int objectIndex) async {
    if (state == null) return;
    
    final currentSelected = Set<int>.from(state!.selectedObjectIds);
    final wasSelected = currentSelected.contains(objectIndex);
    
    if (wasSelected) {
      // Deselect: remove from selected IDs and remove from selections
      currentSelected.remove(objectIndex);
      
      final objState = state!.detectedObjects.firstWhere((o) => o.index == objectIndex);
      
      // Remove selection that matches this object's mask
      final updatedSelections = state!.selections
          .where((s) => !_masksOverlap(s.mask, objState.mask, threshold: 0.7))
          .toList();
      
      // Update object state
      final updatedObjects = state!.detectedObjects.map((obj) {
        if (obj.index == objectIndex) {
          return obj.copyWith(isSelected: false, offset: Offset.zero);
        }
        return obj;
      }).toList();
      
      state = state!.copyWith(
        selectedObjectIds: currentSelected,
        selections: updatedSelections,
        detectedObjects: updatedObjects,
      );
      
      _updateCombinedMask();
    } else {
      // Check if this object's mask already exists in selections (from tap or other source)
      final objState = state!.detectedObjects.firstWhere((o) => o.index == objectIndex);
      
      for (final existingSel in state!.selections) {
        if (_masksOverlap(existingSel.mask, objState.mask, threshold: 0.7)) {
          // Already selected via another method, just mark the object as selected
          currentSelected.add(objectIndex);
          
          final updatedObjects = state!.detectedObjects.map((obj) {
            if (obj.index == objectIndex) {
              return obj.copyWith(isSelected: true);
            }
            return obj;
          }).toList();
          
          state = state!.copyWith(
            selectedObjectIds: currentSelected,
            detectedObjects: updatedObjects,
          );
          return;
        }
      }
      
      // Select: add to selected IDs and add to selections
      currentSelected.add(objectIndex);
      
      // Create selection from object
      final selection = Selection(
        id: 'sel_obj_${_selectionCounter++}',
        mask: objState.mask,
        source: SelectionSource.objectList,
        className: objState.className,
        confidence: objState.confidence,
      );
      
      Uint8List? cutoutBytes;
      try {
        cutoutBytes = await selection.generateCutout(state!.currentImageBytes);
      } catch (_) {}
      
      final selectionState = SelectionState(
        id: selection.id,
        selection: selection,
        cutoutBytes: cutoutBytes,
      );
      
      // Update object state
      final updatedObjects = state!.detectedObjects.map((obj) {
        if (obj.index == objectIndex) {
          return obj.copyWith(isSelected: true);
        }
        return obj;
      }).toList();
      
      state = state!.copyWith(
        selectedObjectIds: currentSelected,
        selections: [...state!.selections, selectionState],
        detectedObjects: updatedObjects,
      );
      
      _updateCombinedMask();
    }
  }
  
  bool isObjectSelected(int objectIndex) {
    return state?.selectedObjectIds.contains(objectIndex) ?? false;
  }
  
  /// Select all objects
  Future<void> selectAllObjects() async {
    if (state == null || state!.detectedObjects.isEmpty) return;
    
    for (final obj in state!.detectedObjects) {
      if (!state!.selectedObjectIds.contains(obj.index)) {
        await toggleObjectSelection(obj.index);
      }
    }
  }
  
  /// Deselect all objects
  void deselectAllObjects() {
    if (state == null) return;
    
    final objectListSelections = state!.selections
        .where((s) => s.source != SelectionSource.objectList)
        .toList();
    
    final updatedObjects = state!.detectedObjects
        .map((obj) => obj.copyWith(isSelected: false, offset: Offset.zero))
        .toList();
    
    state = state!.copyWith(
      selectedObjectIds: {},
      selections: objectListSelections,
      detectedObjects: updatedObjects,
    );
    
    _updateCombinedMask();
  }
  
  /// Add selection from mask (tap, lasso, brush)
  Future<bool> addSelection({
    required List<List<int>> mask,
    required SelectionSource source,
    String? className,
    double? confidence,
  }) async {
    if (state == null) return false;
    
    // Validate mask
    if (mask.isEmpty || (mask.isNotEmpty && mask[0].isEmpty)) return false;
    
    int nonZeroCount = 0;
    for (final row in mask) {
      for (final val in row) {
        if (val != 0) nonZeroCount++;
      }
    }
    if (nonZeroCount == 0) return false;
    
    // Check for overlapping selections
    final selectionsToRemove = <String>[];
    for (final existingSel in state!.selections) {
      if (_masksOverlap(existingSel.mask, mask, threshold: 0.2)) {
        if (source != SelectionSource.objectList && existingSel.source == SelectionSource.objectList) {
          selectionsToRemove.add(existingSel.id);
        } else if (source == existingSel.source) {
          return false; // Skip duplicate
        }
      }
    }
    
    // Remove objectList selections that are being replaced by manual selections
    if (selectionsToRemove.isNotEmpty) {
      final filteredSelections = state!.selections
          .where((s) => !selectionsToRemove.contains(s.id))
          .toList();
      
      // Also update selectedObjectIds if we removed objectList selections
      final newSelectedIds = Set<int>.from(state!.selectedObjectIds);
      for (final id in selectionsToRemove) {
        // Find the object index for this selection
        for (final obj in state!.detectedObjects) {
          final sel = state!.selections.firstWhere((s) => s.id == id);
          if (_masksOverlap(obj.mask, sel.mask, threshold: 0.7)) {
            newSelectedIds.remove(obj.index);
            break;
          }
        }
      }
      
      final updatedObjects = state!.detectedObjects.map((obj) {
        if (!newSelectedIds.contains(obj.index)) {
          return obj.copyWith(isSelected: false);
        }
        return obj;
      }).toList();
      
      state = state!.copyWith(
        selections: filteredSelections,
        selectedObjectIds: newSelectedIds,
        detectedObjects: updatedObjects,
      );
    }
    
    // Check if this mask matches any detected object and mark it as selected
    int? matchingObjectIndex;
    for (final obj in state!.detectedObjects) {
      if (_masksOverlap(obj.mask, mask, threshold: 0.7)) {
        matchingObjectIndex = obj.index;
        className ??= obj.className;
        confidence ??= obj.confidence;
        break;
      }
    }
    
    final selection = Selection(
      id: 'sel_${source.name}_${_selectionCounter++}',
      mask: mask,
      source: source,
      className: className,
      confidence: confidence,
    );
    
    Uint8List? cutoutBytes;
    try {
      cutoutBytes = await selection.generateCutout(state!.currentImageBytes);
    } catch (_) {}
    
    final selectionState = SelectionState(
      id: selection.id,
      selection: selection,
      cutoutBytes: cutoutBytes,
    );
    
    // Update detected object selection state if matching
    if (matchingObjectIndex != null) {
      final currentSelected = Set<int>.from(state!.selectedObjectIds);
      currentSelected.add(matchingObjectIndex);
      
      final updatedObjects = state!.detectedObjects.map((obj) {
        if (obj.index == matchingObjectIndex) {
          return obj.copyWith(isSelected: true);
        }
        return obj;
      }).toList();
      
      state = state!.copyWith(
        selections: [...state!.selections, selectionState],
        selectedObjectIds: currentSelected,
        detectedObjects: updatedObjects,
      );
    } else {
      state = state!.copyWith(
        selections: [...state!.selections, selectionState],
      );
    }
    
    _updateCombinedMask();
    return true;
  }
  
  /// Check if two masks overlap using IoU
  bool _masksOverlap(List<List<int>> mask1, List<List<int>> mask2, {double threshold = 0.5}) {
    if (mask1.isEmpty || mask2.isEmpty) return false;
    
    final height1 = mask1.length;
    final width1 = mask1.isNotEmpty ? mask1[0].length : 0;
    final height2 = mask2.length;
    final width2 = mask2.isNotEmpty ? mask2[0].length : 0;
    
    // If dimensions don't match, can't compare directly
    if (height1 != height2 || width1 != width2) return false;
    
    int mask1Count = 0;
    int mask2Count = 0;
    int overlapCount = 0;
    
    for (int y = 0; y < height1; y++) {
      for (int x = 0; x < width1; x++) {
        final val1 = mask1[y][x] == 1;
        final val2 = mask2[y][x] == 1;
        
        if (val1) mask1Count++;
        if (val2) mask2Count++;
        if (val1 && val2) overlapCount++;
      }
    }
    
    if (mask1Count == 0 || mask2Count == 0) return false;
    
    // IoU (Intersection over Union) style check
    final union = mask1Count + mask2Count - overlapCount;
    final iou = union > 0 ? overlapCount / union : 0.0;
    
    return iou >= threshold;
  }
  
  /// Subtract mask from existing selections
  Future<void> subtractSelection({
    required List<List<int>> subtractMask,
    required SelectionSource source,
  }) async {
    if (state == null || state!.selections.isEmpty) return;
    
    final maskHeight = subtractMask.length;
    final maskWidth = subtractMask.isNotEmpty ? subtractMask[0].length : 0;
    if (maskWidth == 0 || maskHeight == 0) return;
    
    final updatedSelections = <SelectionState>[];
    final selectionsToRemove = <String>[];
    
    for (final selState in state!.selections) {
      final existingMask = selState.mask;
      final existingHeight = existingMask.length;
      final existingWidth = existingMask.isNotEmpty ? existingMask[0].length : 0;
      
      // Check if dimensions match
      if (existingHeight != maskHeight || existingWidth != maskWidth) {
        // Keep as is if dimensions don't match
        updatedSelections.add(selState);
        continue;
      }
      
      // Create new mask by subtracting the subtractMask from existing mask
      final newMask = List.generate(existingHeight, (y) => 
        List.generate(existingWidth, (x) => 
          existingMask[y][x] == 1 && subtractMask[y][x] != 1 ? 1 : 0
        )
      );
      
      // Check if the new mask is empty (completely subtracted)
      int pixelCount = 0;
      for (final row in newMask) {
        for (final val in row) {
          if (val == 1) pixelCount++;
        }
      }
      
      if (pixelCount == 0) {
        selectionsToRemove.add(selState.id);
      } else {
        // Create updated selection with new mask
        final updatedSelection = Selection(
          id: selState.id,
          mask: newMask,
          source: selState.source,
          className: selState.className,
          confidence: selState.selection.confidence,
          offset: selState.offset,
        );
        
        Uint8List? cutoutBytes;
        try {
          cutoutBytes = await updatedSelection.generateCutout(state!.currentImageBytes);
        } catch (_) {}
        
        updatedSelections.add(SelectionState(
          id: selState.id,
          selection: updatedSelection,
          cutoutBytes: cutoutBytes,
        ));
      }
    }
    
    // Update state with modified selections
    state = state!.copyWith(selections: updatedSelections);
    
    // Also update object selection state if any detected objects were affected
    for (final _ in selectionsToRemove) {
      // Find if this was an object list selection
      for (final obj in state!.detectedObjects) {
        if (obj.isSelected) {
          // Check if this object's mask now has no overlap with any remaining selection
          bool stillSelected = false;
          for (final sel in state!.selections) {
            if (_masksOverlap(sel.mask, obj.mask, threshold: 0.5)) {
              stillSelected = true;
              break;
            }
          }
          if (!stillSelected) {
            // Deselect the object
            final currentSelected = Set<int>.from(state!.selectedObjectIds);
            currentSelected.remove(obj.index);
            final updatedObjects = state!.detectedObjects.map((o) {
              if (o.index == obj.index) {
                return o.copyWith(isSelected: false, offset: Offset.zero);
              }
              return o;
            }).toList();
            state = state!.copyWith(
              selectedObjectIds: currentSelected,
              detectedObjects: updatedObjects,
            );
          }
        }
      }
    }
    
    _updateCombinedMask();
  }
  
  void removeSelection(String selectionId) {
    if (state == null) return;
    
    // Check if this is an object list selection
    final selection = state!.selections.firstWhere(
      (s) => s.id == selectionId,
      orElse: () => throw Exception('Selection not found'),
    );
    
    // If from object list, also update selectedObjectIds
    if (selection.source == SelectionSource.objectList) {
      final objIndex = state!.detectedObjects
          .indexWhere((o) => o.className == selection.className);
      if (objIndex >= 0) {
        final currentSelected = Set<int>.from(state!.selectedObjectIds);
        currentSelected.remove(state!.detectedObjects[objIndex].index);
        
        final updatedObjects = state!.detectedObjects.map((obj) {
          if (obj.className == selection.className) {
            return obj.copyWith(isSelected: false, offset: Offset.zero);
          }
          return obj;
        }).toList();
        
        state = state!.copyWith(
          selectedObjectIds: currentSelected,
          detectedObjects: updatedObjects,
        );
      }
    }
    
    state = state!.copyWith(
      selections: state!.selections.where((s) => s.id != selectionId).toList(),
    );
    
    _updateCombinedMask();
  }
  
  /// Clear all selections
  void clearSelections() {
    if (state == null) return;
    
    final updatedObjects = state!.detectedObjects
        .map((obj) => obj.copyWith(isSelected: false, offset: Offset.zero))
        .toList();
    
    state = state!.copyWith(
      selections: [],
      selectedObjectIds: {},
      combinedMask: null,
      detectedObjects: updatedObjects,
    );
  }
  
  // ========================
  // SELECTION MOVEMENT
  // ========================
  
  /// Update selection offset (for drag/move)
  void updateSelectionOffset(String selectionId, Offset newOffset) {
    if (state == null) return;
    
    final updatedSelections = state!.selections.map((s) {
      if (s.id == selectionId) {
        return s.copyWith(
          selection: s.selection.copyWith(offset: newOffset),
        );
      }
      return s;
    }).toList();
    
    // Also update object offset if from object list
    final selection = state!.selections.firstWhere((s) => s.id == selectionId);
    if (selection.source == SelectionSource.objectList) {
      final updatedObjects = state!.detectedObjects.map((obj) {
        if (obj.className == selection.className && obj.isSelected) {
          return obj.copyWith(offset: newOffset);
        }
        return obj;
      }).toList();
      
      state = state!.copyWith(
        selections: updatedSelections,
        detectedObjects: updatedObjects,
      );
    } else {
      state = state!.copyWith(selections: updatedSelections);
    }
  }
  
  // ========================
  // TOOL STATE
  // ========================
  
  /// Set active tool
  void setActiveTool(String tool) {
    if (state == null) return;
    state = state!.copyWith(activeTool: tool);
  }
  
  /// Set processing state
  void setProcessing(bool isProcessing) {
    if (state == null) return;
    state = state!.copyWith(isProcessing: isProcessing);
  }
  
  // ========================
  // HELPERS
  // ========================
  
  /// Update combined mask from all selections
  void _updateCombinedMask() {
    if (state == null || state!.selections.isEmpty) {
      if (state != null) {
        state = state!.copyWith(combinedMask: null);
      }
      return;
    }
    
    // Use first selection's mask dimensions
    final firstMask = state!.selections.first.mask;
    final height = firstMask.length;
    final width = firstMask.isNotEmpty ? firstMask[0].length : 0;
    
    if (width == 0 || height == 0) {
      state = state!.copyWith(combinedMask: null);
      return;
    }
    
    // Create combined mask
    final combined = List.generate(height, (_) => List.filled(width, 0));
    
    for (final sel in state!.selections) {
      for (int y = 0; y < height && y < sel.mask.length; y++) {
        for (int x = 0; x < width && x < sel.mask[y].length; x++) {
          if (sel.mask[y][x] == 1) {
            combined[y][x] = 1;
          }
        }
      }
    }
    
    state = state!.copyWith(combinedMask: combined);
  }
  
  /// Get DetectedObjectState by index
  DetectedObjectState? getObjectByIndex(int index) {
    return state?.detectedObjects
        .where((o) => o.index == index)
        .firstOrNull;
  }
  
  /// Get SelectionState by ID
  SelectionState? getSelectionById(String id) {
    return state?.selections
        .where((s) => s.id == id)
        .firstOrNull;
  }
  
  /// Get manual selection masks (tap/lasso/brush - not from object list)
  List<List<List<int>>> getManualSelectionMasks() {
    if (state == null) return [];
    
    final manualMasks = <List<List<int>>>[];
    for (final sel in state!.selections) {
      // Only include manual selections - objectList handled by selectedIndices
      if (sel.source == SelectionSource.objectList) continue;
      manualMasks.add(sel.mask);
    }
    return manualMasks;
  }
  
  /// Get all selection masks (for manual edit operations)
  List<List<List<int>>> getAllSelectionMasks() {
    if (state == null) return [];
    return state!.selections.map((s) => s.mask).toList();
  }
  
  /// Get the combined mask for all current selections
  List<List<int>>? getCombinedMask() {
    return state?.combinedMask;
  }
}

// ========================
// RIVERPOD PROVIDERS
// ========================

/// Main provider for EditingImageManager
final editingImageProvider = StateNotifierProvider<EditingImageManager, EditingImage?>(
  (ref) => EditingImageManager(ref),
);

// ========================
// CONVENIENCE PROVIDERS
// ========================

/// Whether an image is currently loaded
final hasImageProvider = Provider<bool>((ref) {
  return ref.watch(editingImageProvider) != null;
});

/// Current image bytes
final currentImageProvider = Provider<Uint8List?>((ref) {
  return ref.watch(editingImageProvider)?.currentImageBytes;
});

/// Original image bytes
final originalImageProvider = Provider<Uint8List?>((ref) {
  return ref.watch(editingImageProvider)?.originalImageBytes;
});

/// Image size
final imageSizeProvider = Provider<Size?>((ref) {
  return ref.watch(editingImageProvider)?.imageSize;
});

/// Whether YOLO detection is running
final imageIsDetectingProvider = Provider<bool>((ref) {
  return ref.watch(editingImageProvider)?.isDetecting ?? false;
});

/// Whether YOLO detection has completed (objects detected and masks sent to backend)
final detectionCompleteProvider = Provider<bool>((ref) {
  return ref.watch(editingImageProvider)?.detectionComplete ?? false;
});

/// All detected objects
final imageDetectedObjectsProvider = Provider<List<DetectedObjectState>>((ref) {
  return ref.watch(editingImageProvider)?.detectedObjects ?? [];
});

/// Selected object IDs
final selectedObjectIdsProvider = Provider<Set<int>>((ref) {
  return ref.watch(editingImageProvider)?.selectedObjectIds ?? {};
});

/// All selections
final imageSelectionsProvider = Provider<List<SelectionState>>((ref) {
  return ref.watch(editingImageProvider)?.selections ?? [];
});

/// Combined mask
final combinedMaskProvider = Provider<List<List<int>>?>((ref) {
  return ref.watch(editingImageProvider)?.combinedMask;
});

/// Has any selections
final hasImageSelectionsProvider = Provider<bool>((ref) {
  return ref.watch(editingImageProvider)?.hasSelections ?? false;
});

/// Has any moved selections (objects that have been dragged)
final hasMovedSelectionsProvider = Provider<bool>((ref) {
  final selections = ref.watch(editingImageProvider)?.selections ?? [];
  return selections.any((s) => s.offset != Offset.zero);
});

/// Get moved selections
final movedSelectionsProvider = Provider<List<SelectionState>>((ref) {
  final selections = ref.watch(editingImageProvider)?.selections ?? [];
  return selections.where((s) => s.offset != Offset.zero).toList();
});

/// Is processing
final isProcessingProvider = Provider<bool>((ref) {
  return ref.watch(editingImageProvider)?.isProcessing ?? false;
});

/// Active tool
final activeToolProvider = Provider<String>((ref) {
  return ref.watch(editingImageProvider)?.activeTool ?? 'Tap';
});

/// Count providers
final objectCountProvider = Provider<int>((ref) {
  return ref.watch(editingImageProvider)?.objectCount ?? 0;
});

final selectedCountProvider = Provider<int>((ref) {
  return ref.watch(editingImageProvider)?.selectedCount ?? 0;
});

final selectionCountProvider = Provider<int>((ref) {
  return ref.watch(editingImageProvider)?.selectionCount ?? 0;
});

/// Provider for select tool prompt text (shared between SelectSlider and EditorScreen)
final selectPromptProvider = StateProvider<String>((ref) => '');

/// Enum for classified prompt action
enum PromptAction {
  select,
  erase,
  move,
  inpaint,
}

/// Stub for prompt classification (will be replaced with TFLite model)
PromptAction classifyPrompt(String prompt) {
  final lower = prompt.toLowerCase().trim();
  
  // Simple keyword-based classification (stub)
  if (lower.contains('select') || 
      lower.contains('choose') || 
      lower.contains('pick') ||
      lower.contains('find')) {
    return PromptAction.select;
  }
  
  if (lower.contains('erase') || 
      lower.contains('remove') || 
      lower.contains('delete') ||
      lower.contains('get rid')) {
    return PromptAction.erase;
  }
  
  if (lower.contains('move') || 
      lower.contains('shift') || 
      lower.contains('relocate') ||
      lower.contains('put') ||
      lower.contains('place')) {
    return PromptAction.move;
  }
  
  // Default to inpaint for any other edit request
  return PromptAction.inpaint;
}

/// Stub for matching prompt to object labels (will be replaced with TFLite model)
/// Returns the index of the best matching object, or null if no match
int? matchPromptToObject(String prompt, List<DetectedObjectState> objects) {
  if (objects.isEmpty) return null;
  
  final lower = prompt.toLowerCase();
  
  // Simple keyword matching (stub)
  for (final obj in objects) {
    final className = obj.className.toLowerCase();
    if (lower.contains(className)) {
      return obj.index;
    }
  }
  
  // No match found
  return null;
}
