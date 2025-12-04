// models/edit_state.dart
// Represents a single state in the edit history (immutable snapshot).

import 'dart:typed_data';
import 'detected_object.dart';

/// Type of edit operation performed
enum EditOperation {
  initial,       // Original image loaded
  inpaint,       // Object removal / fill
  stylize,       // Style transfer
  magicView,     // Perspective change
  crop,          // Crop operation
  filter,        // Filter applied (hue, saturation, etc.)
  prompt,        // Text prompt edit
  segment,       // Segmentation mask created
  custom,        // Custom/other operation
  erase,         // Erase operation
  move,          // Move operation
  resize         // Resize operation
}

/// Immutable snapshot of the editor state at a point in time.
/// Each edit creates a new EditState that gets pushed to history.
class EditState {
  /// Unique identifier for this state
  final String id;

  /// The image bytes at this state
  final Uint8List imageBytes;

  /// Optional mask bytes (for selection-based operations)
  final Uint8List? maskBytes;

  /// What operation created this state
  final EditOperation operation;

  /// Human-readable description of the operation
  final String description;

  /// When this state was created
  final DateTime timestamp;

  /// Optional metadata (prompt text, filter values, etc.)
  final Map<String, dynamic>? metadata;
  
  /// Detected objects for this state (from YOLO detection)
  /// Each edit state has its own set of detected objects
  final List<DetectedObject> detectedObjects;
  
  /// Raw masks data from backend (indexed by mask ID)
  /// These are the masks stored in the backend for this image state
  final List<List<List<int>>> storedMasks;
  
  /// Whether detection has been completed for this state
  final bool detectionComplete;
  
  /// Backend image name for this state
  final String? backendImageName;

  const EditState({
    required this.id,
    required this.imageBytes,
    this.maskBytes,
    required this.operation,
    required this.description,
    required this.timestamp,
    this.metadata,
    this.detectedObjects = const [],
    this.storedMasks = const [],
    this.detectionComplete = false,
    this.backendImageName,
  });

  /// Create a copy with optional overrides
  EditState copyWith({
    String? id,
    Uint8List? imageBytes,
    Uint8List? maskBytes,
    EditOperation? operation,
    String? description,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    List<DetectedObject>? detectedObjects,
    List<List<List<int>>>? storedMasks,
    bool? detectionComplete,
    String? backendImageName,
  }) {
    return EditState(
      id: id ?? this.id,
      imageBytes: imageBytes ?? this.imageBytes,
      maskBytes: maskBytes ?? this.maskBytes,
      operation: operation ?? this.operation,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      detectedObjects: detectedObjects ?? this.detectedObjects,
      storedMasks: storedMasks ?? this.storedMasks,
      detectionComplete: detectionComplete ?? this.detectionComplete,
      backendImageName: backendImageName ?? this.backendImageName,
    );
  }

  @override
  String toString() => 'EditState($operation: $description, objects: ${detectedObjects.length})';
}
