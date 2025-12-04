// state/image_document_notifier.dart
// Legacy ImageDocument notifier that stores current image path (temp) and undo stack.
// NOTE: Consider using EditHistoryNotifier for new code - it has full undo/redo support.
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../core/utils.dart';

class ImageDocumentNotifier extends StateNotifier<String?> {
  ImageDocumentNotifier() : super(null);

  final List<String> _undoStack = [];

  Future<void> loadFromBytes(Uint8List bytes) async {
    final id = const Uuid().v4();
    final path = await saveToTemp(bytes, 'image_$id.jpg');
    _pushUndo(path);
    state = path;
  }

  void _pushUndo(String path) {
    _undoStack.insert(0, path);
    if (_undoStack.length > kUndoStackLimit) _undoStack.removeLast();
  }

  Future<void> applyNewImage(Uint8List bytes) async {
    final id = const Uuid().v4();
    final path = await saveToTemp(bytes, 'image_$id.jpg');
    _pushUndo(path);
    state = path;
  }

  Future<void> undo() async {
    if (_undoStack.length < 2) return;
    // remove current
    _undoStack.removeAt(0);
    final prev = _undoStack.first;
    state = prev;
  }
}
