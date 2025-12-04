// features/editor/widgets/selection_cutout_overlay.dart
// Overlay widget that displays selected objects as movable cutouts

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/editing_image.dart';
import '../../../state/editing_image_manager.dart';

/// Provider to track if a cutout is being dragged over the bin
final isDraggingOverBinProvider = StateProvider<bool>((ref) => false);

/// Provider to track which selection is currently being dragged
final draggingSelectionIdProvider = StateProvider<String?>((ref) => null);

/// Provider to track if any cutout is being dragged (for disabling PhotoView gestures)
final isCutoutDraggingProvider = StateProvider<bool>((ref) => false);

/// Overlay that shows all selected objects as movable cutouts
class SelectionCutoutOverlay extends ConsumerWidget {
  /// Size of the image in canvas coordinates
  final Size imageSize;
  
  /// Scale factor for the canvas (to convert between image and screen coords)
  final double scale;
  
  /// Offset of the image on the canvas
  final Offset imageOffset;
  
  /// Elevation offset for cutouts (lifted above original position)
  final double elevationOffset;
  
  /// Callback when a cutout is dropped on the bin
  final VoidCallback? onEraseRequested;
  
  /// The bin zone rect in screen coordinates (for drop detection)
  final Rect? binZone;

  const SelectionCutoutOverlay({
    super.key,
    required this.imageSize,
    this.scale = 1.0,
    this.imageOffset = Offset.zero,
    this.elevationOffset = 2.0,
    this.onEraseRequested,
    this.binZone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selections = ref.watch(imageSelectionsProvider);
    
    if (selections.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Stack(
      clipBehavior: Clip.none, // Allow cutouts to render outside bounds
      children: selections.map((selectionState) {
        return _DraggableCutout(
          key: ValueKey(selectionState.id),
          selectionState: selectionState,
          imageSize: imageSize,
          scale: scale,
          imageOffset: imageOffset,
          elevationOffset: elevationOffset,
          binZone: binZone,
          onOffsetChanged: (newOffset) {
            ref.read(editingImageProvider.notifier)
                .updateSelectionOffset(selectionState.id, newOffset);
          },
          onRemove: () {
            ref.read(editingImageProvider.notifier)
                .removeSelection(selectionState.id);
          },
          onDragStart: () {
            ref.read(draggingSelectionIdProvider.notifier).state = selectionState.id;
          },
          onDragEnd: () {
            ref.read(draggingSelectionIdProvider.notifier).state = null;
            ref.read(isDraggingOverBinProvider.notifier).state = false;
          },
          onOverBinChanged: (isOver) {
            ref.read(isDraggingOverBinProvider.notifier).state = isOver;
          },
          onDropOnBin: () {
            onEraseRequested?.call();
          },
        );
      }).toList(),
    );
  }
}

/// Individual draggable cutout widget
class _DraggableCutout extends ConsumerStatefulWidget {
  final SelectionState selectionState;
  final Size imageSize;
  final double scale;
  final Offset imageOffset;
  final double elevationOffset;
  final ValueChanged<Offset> onOffsetChanged;
  final VoidCallback onRemove;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final ValueChanged<bool> onOverBinChanged;
  final VoidCallback onDropOnBin;
  final Rect? binZone;

  const _DraggableCutout({
    super.key,
    required this.selectionState,
    required this.imageSize,
    required this.scale,
    required this.imageOffset,
    required this.elevationOffset,
    required this.onOffsetChanged,
    required this.onRemove,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onOverBinChanged,
    required this.onDropOnBin,
    this.binZone,
  });

  @override
  ConsumerState<_DraggableCutout> createState() => _DraggableCutoutState();
}

class _DraggableCutoutState extends ConsumerState<_DraggableCutout> {
  bool _isDragging = false;
  Offset _dragOffset = Offset.zero;
  bool _isOverBin = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }
  
  void _checkBinCollision(Offset globalPosition) {
    if (widget.binZone == null) return;
    
    final wasOverBin = _isOverBin;
    _isOverBin = widget.binZone!.contains(globalPosition);
    
    if (wasOverBin != _isOverBin) {
      widget.onOverBinChanged(_isOverBin);
    }
  }
  
  void _startDrag(Offset globalPosition) {
    setState(() => _isDragging = true);
    ref.read(isCutoutDraggingProvider.notifier).state = true;
    widget.onDragStart();
  }
  
  void _updateDrag(Offset delta, Offset globalPosition) {
    setState(() {
      _dragOffset += delta;
    });
    _checkBinCollision(globalPosition);
  }
  
  void _endDrag() {
    final sel = widget.selectionState;
    final maskWidth = sel.mask.isNotEmpty ? sel.mask[0].length : 1;
    final maskHeight = sel.mask.length;
    
    final scaleX = widget.imageSize.width / maskWidth;
    final scaleY = widget.imageSize.height / maskHeight;
    
    if (_isOverBin) {
      // Drop on bin - trigger erase
      widget.onDropOnBin();
    } else {
      // Normal drop - update position
      final newOffset = Offset(
        sel.offset.dx + (_dragOffset.dx / (scaleX * widget.scale)),
        sel.offset.dy + (_dragOffset.dy / (scaleY * widget.scale)),
      );
      widget.onOffsetChanged(newOffset);
    }
    
    setState(() {
      _isDragging = false;
      _isOverBin = false;
    });
    _dragOffset = Offset.zero;
    ref.read(isCutoutDraggingProvider.notifier).state = false;
    widget.onDragEnd();
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.selectionState;
    
    if (sel.cutoutBytes == null) {
      return const SizedBox.shrink();
    }
    
    // Calculate position in screen coordinates
    // The render position is in mask/image coordinates, scale to screen
    final maskWidth = sel.mask.isNotEmpty ? sel.mask[0].length : 1;
    final maskHeight = sel.mask.length;
    
    final scaleX = widget.imageSize.width / maskWidth;
    final scaleY = widget.imageSize.height / maskHeight;
    
    final screenX = (sel.renderPosition.dx * scaleX * widget.scale) + widget.imageOffset.dx;
    final screenY = (sel.renderPosition.dy * scaleY * widget.scale) + widget.imageOffset.dy;
    
    final cutoutWidth = sel.cutoutSize.width * scaleX * widget.scale;
    final cutoutHeight = sel.cutoutSize.height * scaleY * widget.scale;
    
    // Simple positioned widget without floating animation
    return Positioned(
      left: screenX + _dragOffset.dx,
      top: screenY - widget.elevationOffset + _dragOffset.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          _startDrag(details.globalPosition);
        },
        onPanUpdate: (details) {
          _updateDrag(details.delta, details.globalPosition);
        },
        onPanEnd: (_) {
          _endDrag();
        },
        onLongPress: widget.onRemove,
        child: _buildCutoutWidget(cutoutWidth, cutoutHeight),
      ),
    );
  }
  
  Widget _buildCutoutWidget(double width, double height) {
    final sel = widget.selectionState;
    
    // Scale down when over bin
    final displayScale = _isOverBin ? 0.8 : 1.0;
    
    return AnimatedScale(
      scale: displayScale,
      duration: const Duration(milliseconds: 150),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: _isOverBin
                  ? Colors.red.withValues(alpha: 0.5)
                  : (_isDragging 
                      ? Colors.blue.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.3)),
              blurRadius: _isDragging ? 16 : 8,
              spreadRadius: _isDragging ? 2 : 0,
              offset: Offset(0, _isDragging ? 8 : 4),
            ),
          ],
        ),
        // Just the cutout image - no text, no icons, no labels
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isOverBin ? 0.6 : 1.0,
          child: Image.memory(
            sel.cutoutBytes!,
            width: width,
            height: height,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
