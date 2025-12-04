// features/editor/controllers/selection_mode_controller.dart
// Controller for managing selection modes and their states

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selection tool type (removed tap - only area selection tools)
enum SelectionTool {
  none,
  lasso,
  brush,
}

/// Selection mode (add or subtract)
enum SelectionMode {
  add,
  subtract,
}

/// Selection phase - two phases of the selection workflow
enum SelectionPhase {
  /// Phase 1: User is selecting areas/objects
  selection,
  /// Phase 2: User can move, erase, or inpaint the selection
  action,
}

/// State class for selection tool
class SelectionToolState {
  final SelectionTool tool;
  final SelectionMode mode;
  final bool isActive;
  final double brushSize;
  final SelectionPhase phase;
  final bool isSliderOpen; // Track if select slider is visible
  
  const SelectionToolState({
    this.tool = SelectionTool.none,
    this.mode = SelectionMode.add,
    this.isActive = false,
    this.brushSize = 30.0,
    this.phase = SelectionPhase.selection,
    this.isSliderOpen = false,
  });
  
  SelectionToolState copyWith({
    SelectionTool? tool,
    SelectionMode? mode,
    bool? isActive,
    double? brushSize,
    SelectionPhase? phase,
    bool? isSliderOpen,
  }) {
    return SelectionToolState(
      tool: tool ?? this.tool,
      mode: mode ?? this.mode,
      isActive: isActive ?? this.isActive,
      brushSize: brushSize ?? this.brushSize,
      phase: phase ?? this.phase,
      isSliderOpen: isSliderOpen ?? this.isSliderOpen,
    );
  }
  
  /// Check if any selection tool is active
  bool get hasActiveTool => tool != SelectionTool.none && isActive;
  
  /// Check if in selection phase
  bool get isSelectionPhase => phase == SelectionPhase.selection;
  
  /// Check if in action phase
  bool get isActionPhase => phase == SelectionPhase.action;
  
  /// Get tool icon
  IconData get toolIcon {
    switch (tool) {
      case SelectionTool.lasso:
        return Icons.timeline;
      case SelectionTool.brush:
        return Icons.brush;
      case SelectionTool.none:
        return Icons.highlight_alt;
    }
  }
  
  /// Get tool name
  String get toolName {
    switch (tool) {
      case SelectionTool.lasso:
        return 'Lasso';
      case SelectionTool.brush:
        return 'Brush';
      case SelectionTool.none:
        return 'Select';
    }
  }
}

/// Controller for selection tool state
class SelectionModeController extends StateNotifier<SelectionToolState> {
  SelectionModeController() : super(const SelectionToolState());
  
  /// Set the active tool
  void setTool(SelectionTool tool) {
    state = state.copyWith(
      tool: tool,
      isActive: tool != SelectionTool.none,
    );
  }
  
  /// Toggle tool (turn off if same tool, turn on if different)
  void toggleTool(SelectionTool tool) {
    if (state.tool == tool && state.isActive) {
      // Turn off current tool
      state = state.copyWith(
        tool: SelectionTool.none,
        isActive: false,
      );
    } else {
      // Switch to new tool
      setTool(tool);
    }
  }
  
  /// Set selection mode (add/subtract)
  void setMode(SelectionMode mode) {
    state = state.copyWith(mode: mode);
  }
  
  /// Toggle mode
  void toggleMode() {
    state = state.copyWith(
      mode: state.mode == SelectionMode.add 
          ? SelectionMode.subtract 
          : SelectionMode.add,
    );
  }
  
  /// Set brush size
  void setBrushSize(double size) {
    state = state.copyWith(brushSize: size.clamp(10.0, 100.0));
  }
  
  /// Deactivate tool (keep tool type but mark as inactive)
  void deactivate() {
    state = state.copyWith(isActive: false);
  }
  
  /// Activate current tool
  void activate() {
    if (state.tool != SelectionTool.none) {
      state = state.copyWith(isActive: true);
    }
  }
  
  /// Move to action phase (after tick in selection phase)
  void goToActionPhase() {
    state = state.copyWith(
      phase: SelectionPhase.action,
      tool: SelectionTool.none,
      isActive: false,
    );
  }
  
  /// Go back to selection phase
  void goToSelectionPhase() {
    state = state.copyWith(
      phase: SelectionPhase.selection,
    );
  }
  
  /// Set slider open state
  void setSliderOpen(bool open) {
    if (open) {
      // When opening, always start in selection phase
      state = state.copyWith(
        isSliderOpen: true,
        phase: SelectionPhase.selection,
      );
    } else {
      // When closing, reset to selection phase but keep state
      state = state.copyWith(
        isSliderOpen: false,
        phase: SelectionPhase.selection,
        tool: SelectionTool.none,
        isActive: false,
      );
    }
  }
  
  /// Clear all (reset to default)
  void clear() {
    state = const SelectionToolState();
  }
}

// ========================
// PROVIDERS
// ========================

/// Main provider for selection mode controller
final selectionModeProvider = StateNotifierProvider<SelectionModeController, SelectionToolState>(
  (ref) => SelectionModeController(),
);

/// Current tool
final currentToolProvider = Provider<SelectionTool>((ref) {
  return ref.watch(selectionModeProvider).tool;
});

/// Current mode (add/subtract)
final currentModeProvider = Provider<SelectionMode>((ref) {
  return ref.watch(selectionModeProvider).mode;
});

/// Is any tool active
final isToolActiveProvider = Provider<bool>((ref) {
  return ref.watch(selectionModeProvider).hasActiveTool;
});

/// Brush size
final brushSizeProvider = Provider<double>((ref) {
  return ref.watch(selectionModeProvider).brushSize;
});

/// Current phase
final selectionPhaseProvider = Provider<SelectionPhase>((ref) {
  return ref.watch(selectionModeProvider).phase;
});

/// Is in selection phase
final isSelectionPhaseProvider = Provider<bool>((ref) {
  return ref.watch(selectionModeProvider).isSelectionPhase;
});

/// Is in action phase
final isActionPhaseProvider = Provider<bool>((ref) {
  return ref.watch(selectionModeProvider).isActionPhase;
});

/// Is slider open
final isSelectSliderOpenProvider = Provider<bool>((ref) {
  return ref.watch(selectionModeProvider).isSliderOpen;
});
