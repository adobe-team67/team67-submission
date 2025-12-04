// models/edit_history.dart
// Manages the undo/redo stacks with a simple and clean API.

import 'edit_state.dart';

/// Immutable container for edit history.
/// Contains past states, current state, and future states (for redo).
class EditHistory {
  /// States before current (oldest first, most recent last)
  final List<EditState> past;

  /// Current state being displayed
  final EditState? current;

  /// States after current for redo (oldest first)
  final List<EditState> future;

  /// Maximum number of states to keep in history
  final int maxHistorySize;

  const EditHistory({
    this.past = const [],
    this.current,
    this.future = const [],
    this.maxHistorySize = 20,
  });

  /// Whether undo is available
  bool get canUndo => past.isNotEmpty;

  /// Whether redo is available
  bool get canRedo => future.isNotEmpty;

  /// Total states in history (past + current + future)
  int get totalStates => past.length + (current != null ? 1 : 0) + future.length;

  /// Current position in history (0-indexed from start)
  int get currentIndex => past.length;

  /// Get current image bytes (convenience getter)
  // Uint8List? get currentImageBytes => current?.imageBytes;

  /// Push a new state (clears redo stack)
  EditHistory push(EditState newState) {
    final newPast = current != null ? [...past, current!] : [...past];

    // Trim history if exceeds max size
    final trimmedPast = newPast.length > maxHistorySize
        ? newPast.sublist(newPast.length - maxHistorySize)
        : newPast;

    return EditHistory(
      past: trimmedPast,
      current: newState,
      future: const [], // Clear redo stack on new edit
      maxHistorySize: maxHistorySize,
    );
  }

  /// Undo: move current to future, pop from past to current
  EditHistory undo() {
    if (!canUndo) return this;

    final newFuture = current != null ? [current!, ...future] : [...future];
    final newPast = [...past];
    final newCurrent = newPast.removeLast();

    return EditHistory(
      past: newPast,
      current: newCurrent,
      future: newFuture,
      maxHistorySize: maxHistorySize,
    );
  }

  /// Redo: move current to past, pop from future to current
  EditHistory redo() {
    if (!canRedo) return this;

    final newPast = current != null ? [...past, current!] : [...past];
    final newFuture = [...future];
    final newCurrent = newFuture.removeAt(0);

    return EditHistory(
      past: newPast,
      current: newCurrent,
      future: newFuture,
      maxHistorySize: maxHistorySize,
    );
  }

  /// Clear all history and start fresh with optional initial state
  EditHistory clear([EditState? initialState]) {
    return EditHistory(
      past: const [],
      current: initialState,
      future: const [],
      maxHistorySize: maxHistorySize,
    );
  }

  /// Get a summary of the history for debugging
  List<String> get historySummary {
    final result = <String>[];
    for (var i = 0; i < past.length; i++) {
      result.add('[$i] ${past[i].description}');
    }
    if (current != null) {
      result.add('[${past.length}] ${current!.description} ← CURRENT');
    }
    for (var i = 0; i < future.length; i++) {
      result.add('[${past.length + 1 + i}] ${future[i].description} (redo)');
    }
    return result;
  }

  @override
  String toString() =>
      'EditHistory(past: ${past.length}, current: ${current != null}, future: ${future.length})';
}
