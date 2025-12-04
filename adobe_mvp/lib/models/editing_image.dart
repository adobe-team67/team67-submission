// models/editing_image.dart
// Comprehensive model for storing ALL details of the currently editing image.
// This is the single source of truth for the image being edited.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'detected_object.dart';
import 'selection.dart';

/// Represents a detected object with its preview and selection state
class DetectedObjectState {
  /// The detected object from YOLO
  final DetectedObject object;
  
  /// Cached preview image bytes (PNG)
  final Uint8List? previewBytes;
  
  /// Whether the preview is currently being generated
  final bool isPreviewLoading;
  
  /// Whether this object is currently selected
  final bool isSelected;
  
  /// Offset from original position (if selected and moved)
  final Offset offset;
  
  const DetectedObjectState({
    required this.object,
    this.previewBytes,
    this.isPreviewLoading = false,
    this.isSelected = false,
    this.offset = Offset.zero,
  });
  
  DetectedObjectState copyWith({
    DetectedObject? object,
    Uint8List? previewBytes,
    bool? isPreviewLoading,
    bool? isSelected,
    Offset? offset,
  }) {
    return DetectedObjectState(
      object: object ?? this.object,
      previewBytes: previewBytes ?? this.previewBytes,
      isPreviewLoading: isPreviewLoading ?? this.isPreviewLoading,
      isSelected: isSelected ?? this.isSelected,
      offset: offset ?? this.offset,
    );
  }
  
  /// Convenience getters from DetectedObject
  int get index => object.index;
  String get className => object.className;
  double get confidence => object.confidence;
  List<List<int>> get mask => object.mask;
  List<double> get box => object.box;
}

/// Represents a selection from any source (tap, lasso, brush, object list)
class SelectionState {
  /// Unique ID for this selection
  final String id;
  
  /// The selection model
  final Selection selection;
  
  /// Cached cutout image bytes (PNG with transparency)
  final Uint8List? cutoutBytes;
  
  /// Whether cutout is being generated
  final bool isCutoutLoading;
  
  const SelectionState({
    required this.id,
    required this.selection,
    this.cutoutBytes,
    this.isCutoutLoading = false,
  });
  
  SelectionState copyWith({
    String? id,
    Selection? selection,
    Uint8List? cutoutBytes,
    bool? isCutoutLoading,
  }) {
    return SelectionState(
      id: id ?? this.id,
      selection: selection ?? this.selection,
      cutoutBytes: cutoutBytes ?? this.cutoutBytes,
      isCutoutLoading: isCutoutLoading ?? this.isCutoutLoading,
    );
  }
  
  /// Convenience getters
  SelectionSource get source => selection.source;
  List<List<int>> get mask => selection.mask;
  Offset get offset => selection.offset;
  String? get className => selection.className;
  Size get cutoutSize => selection.cutoutSize;
  Offset get renderPosition => selection.renderPosition;
  Offset get currentCenter => selection.currentCenter;
}

/// Main model containing ALL details of the currently editing image
class EditingImage {
  // ========================
  // CORE IMAGE DATA
  // ========================
  
  /// Unique identifier for this image session
  final String id;
  
  /// Original image bytes (unmodified)
  final Uint8List originalImageBytes;
  
  /// Current image bytes (after edits)
  final Uint8List currentImageBytes;
  
  /// Image dimensions
  final Size imageSize;
  
  /// Image path/URI (if loaded from file)
  final String? imagePath;
  
  // ========================
  // YOLO DETECTION STATE
  // ========================
  
  /// Whether YOLO detection is currently running
  final bool isDetecting;
  
  /// Whether detection has completed (objects detected and masks sent to backend)
  final bool detectionComplete;
  
  /// All detected objects with their states
  final List<DetectedObjectState> detectedObjects;
  
  /// IDs of currently selected objects (from object list)
  final Set<int> selectedObjectIds;
  
  // ========================
  // SELECTION STATE
  // ========================
  
  /// All active selections (from tap, lasso, brush, object list)
  final List<SelectionState> selections;
  
  /// Combined mask of all selections
  final List<List<int>>? combinedMask;
  
  // ========================
  // EDIT STATE
  // ========================
  
  /// Current active tool
  final String activeTool;
  
  /// Whether an operation is in progress
  final bool isProcessing;
  
  /// Last operation description
  final String? lastOperation;
  
  /// Timestamp of last modification
  final DateTime lastModified;
  
  const EditingImage({
    required this.id,
    required this.originalImageBytes,
    required this.currentImageBytes,
    required this.imageSize,
    this.imagePath,
    this.isDetecting = false,
    this.detectionComplete = false,
    this.detectedObjects = const [],
    this.selectedObjectIds = const {},
    this.selections = const [],
    this.combinedMask,
    this.activeTool = 'Tap',
    this.isProcessing = false,
    this.lastOperation,
    required this.lastModified,
  });
  
  // ========================
  // COMPUTED PROPERTIES
  // ========================
  
  /// Check if any objects are detected
  bool get hasDetectedObjects => detectedObjects.isNotEmpty;
  
  /// Check if any objects are selected
  bool get hasSelectedObjects => selectedObjectIds.isNotEmpty;
  
  /// Check if any selections exist
  bool get hasSelections => selections.isNotEmpty;
  
  /// Get selected objects only
  List<DetectedObjectState> get selectedObjects =>
      detectedObjects.where((o) => selectedObjectIds.contains(o.index)).toList();
  
  /// Get unselected objects
  List<DetectedObjectState> get unselectedObjects =>
      detectedObjects.where((o) => !selectedObjectIds.contains(o.index)).toList();
  
  /// Get selections from object list only
  List<SelectionState> get objectListSelections =>
      selections.where((s) => s.source == SelectionSource.objectList).toList();
  
  /// Get selections from manual tools (tap, lasso, brush)
  List<SelectionState> get manualSelections =>
      selections.where((s) => s.source != SelectionSource.objectList).toList();
  
  /// Check if image has been modified
  bool get isModified => originalImageBytes != currentImageBytes;
  
  /// Get number of detected objects
  int get objectCount => detectedObjects.length;
  
  /// Get number of selected objects
  int get selectedCount => selectedObjectIds.length;
  
  /// Get number of active selections
  int get selectionCount => selections.length;
  
  // ========================
  // COPY WITH
  // ========================
  
  EditingImage copyWith({
    String? id,
    Uint8List? originalImageBytes,
    Uint8List? currentImageBytes,
    Size? imageSize,
    String? imagePath,
    bool? isDetecting,
    bool? detectionComplete,
    List<DetectedObjectState>? detectedObjects,
    Set<int>? selectedObjectIds,
    List<SelectionState>? selections,
    List<List<int>>? combinedMask,
    String? activeTool,
    bool? isProcessing,
    String? lastOperation,
    DateTime? lastModified,
  }) {
    return EditingImage(
      id: id ?? this.id,
      originalImageBytes: originalImageBytes ?? this.originalImageBytes,
      currentImageBytes: currentImageBytes ?? this.currentImageBytes,
      imageSize: imageSize ?? this.imageSize,
      imagePath: imagePath ?? this.imagePath,
      isDetecting: isDetecting ?? this.isDetecting,
      detectionComplete: detectionComplete ?? this.detectionComplete,
      detectedObjects: detectedObjects ?? this.detectedObjects,
      selectedObjectIds: selectedObjectIds ?? this.selectedObjectIds,
      selections: selections ?? this.selections,
      combinedMask: combinedMask ?? this.combinedMask,
      activeTool: activeTool ?? this.activeTool,
      isProcessing: isProcessing ?? this.isProcessing,
      lastOperation: lastOperation ?? this.lastOperation,
      lastModified: lastModified ?? this.lastModified,
    );
  }
  
  // ========================
  // FACTORY CONSTRUCTORS
  // ========================
  
  /// Create new EditingImage from image bytes
  factory EditingImage.fromBytes({
    required Uint8List imageBytes,
    required Size imageSize,
    String? imagePath,
  }) {
    return EditingImage(
      id: 'img_${DateTime.now().millisecondsSinceEpoch}',
      originalImageBytes: imageBytes,
      currentImageBytes: imageBytes,
      imageSize: imageSize,
      imagePath: imagePath,
      lastModified: DateTime.now(),
    );
  }
  
  @override
  String toString() => 'EditingImage($id, ${imageSize.width}x${imageSize.height}, '
      'objects: $objectCount, selected: $selectedCount, selections: $selectionCount)';
}
