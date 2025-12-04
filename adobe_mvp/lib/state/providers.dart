// state/providers.dart
// Riverpod providers wiring api, document and selection state.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';
import '../services/ai_api.dart';
import '../services/ai_api_mock.dart';
import '../config/env.dart';
import '../models/edit_history.dart';
import '../models/detected_object.dart';
import 'image_document_notifier.dart';
import 'edit_history_notifier.dart';
import '../services/yolo_segmentation.dart';

final apiProvider = Provider<AiApi>((ref) {
  if (Env.useMockApi) return AiApiMock();
  // TODO: return real api implementation when available
  return AiApiMock();
});

/// Legacy image document provider (kept for backward compatibility)
final imageDocumentProvider = StateNotifierProvider<ImageDocumentNotifier, String?>((ref) {
  return ImageDocumentNotifier();
});

/// NEW: Edit history provider with full undo/redo support
final editHistoryProvider = StateNotifierProvider<EditHistoryNotifier, EditHistory>((ref) {
  return EditHistoryNotifier();
});

/// Convenience provider for current image bytes
final currentImageBytesProvider = Provider<Uint8List?>((ref) {
  final history = ref.watch(editHistoryProvider);
  return history.current?.imageBytes;
});

/// Convenience provider for current mask bytes
final currentMaskBytesProvider = Provider<Uint8List?>((ref) {
  final history = ref.watch(editHistoryProvider);
  return history.current?.maskBytes;
});

/// Convenience provider for undo availability
final canUndoProvider = Provider<bool>((ref) {
  return ref.watch(editHistoryProvider).canUndo;
});

/// Convenience provider for redo availability
final canRedoProvider = Provider<bool>((ref) {
  return ref.watch(editHistoryProvider).canRedo;
});

final selectionProvider = StateProvider<bool>((ref) => false);

/// Provider for storing detected objects from YOLO
final detectedObjectsProvider = StateProvider<List<DetectedObject>>((ref) => []);

/// Provider for currently selected object index (-1 means none)
final selectedObjectIndexProvider = StateProvider<int>((ref) => -1);

/// YOLO Segmentation Model Provider
/// Automatically initializes when first accessed
final yoloProvider = Provider<YoloSegmentation>((ref) {
  final yolo = YoloSegmentation();

  // Initialize in background - fire and forget
  yolo.initialize().catchError((error) {
    // YOLO model initialization failed silently
  });

  // Dispose when provider is destroyed
  ref.onDispose(() {
    yolo.dispose();
  });

  return yolo;
});
