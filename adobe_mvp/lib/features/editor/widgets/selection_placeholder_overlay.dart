// features/editor/widgets/selection_placeholder_overlay.dart
// Displays grid pattern at original position of selected objects to indicate removal

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/editing_image_manager.dart';
import '../../../models/editing_image.dart';

/// Cached grid image to avoid reloading
ui.Image? _cachedGridImage;
bool _isLoadingGrid = false;

/// Load grid image once and cache it
Future<ui.Image?> _loadGridImage() async {
  if (_cachedGridImage != null) return _cachedGridImage;
  if (_isLoadingGrid) return null;
  
  _isLoadingGrid = true;
  try {
    final data = await rootBundle.load('assets/grid.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _cachedGridImage = frame.image;
    return _cachedGridImage;
  } catch (e) {
    debugPrint('Failed to load grid.png: $e');
    return null;
  } finally {
    _isLoadingGrid = false;
  }
}

/// Overlay showing grid pattern at original positions of selected cutouts
class SelectionPlaceholderOverlay extends ConsumerStatefulWidget {
  final Size imageSize;
  
  const SelectionPlaceholderOverlay({
    super.key,
    required this.imageSize,
  });

  @override
  ConsumerState<SelectionPlaceholderOverlay> createState() => _SelectionPlaceholderOverlayState();
}

class _SelectionPlaceholderOverlayState extends ConsumerState<SelectionPlaceholderOverlay> {
  ui.Image? _gridImage;
  
  @override
  void initState() {
    super.initState();
    _loadGrid();
  }
  
  Future<void> _loadGrid() async {
    final img = await _loadGridImage();
    if (mounted && img != null) {
      setState(() => _gridImage = img);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selections = ref.watch(imageSelectionsProvider);
    
    if (selections.isEmpty || _gridImage == null) return const SizedBox.shrink();
    
    return Stack(
      clipBehavior: Clip.none,
      children: selections.map((selectionState) {
        return _SelectionPlaceholder(
          key: ValueKey('placeholder_${selectionState.id}'),
          selectionState: selectionState,
          imageSize: widget.imageSize,
          gridImage: _gridImage!,
        );
      }).toList(),
    );
  }
}

class _SelectionPlaceholder extends StatelessWidget {
  final SelectionState selectionState;
  final Size imageSize;
  final ui.Image gridImage;
  
  const _SelectionPlaceholder({
    super.key,
    required this.selectionState,
    required this.imageSize,
    required this.gridImage,
  });

  @override
  Widget build(BuildContext context) {
    final selection = selectionState.selection;
    final bbox = selection.boundingBox;
    final mask = selection.mask;
    
    if (mask.isEmpty || mask[0].isEmpty) return const SizedBox.shrink();
    
    final maskWidth = mask[0].length;
    final maskHeight = mask.length;
    
    final scaleX = imageSize.width / maskWidth;
    final scaleY = imageSize.height / maskHeight;
    
    final left = bbox[0] * scaleX;
    final top = bbox[1] * scaleY;
    final width = (bbox[2] - bbox[0] + 1) * scaleX;
    final height = (bbox[3] - bbox[1] + 1) * scaleY;
    
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(width, height),
          painter: _MaskedGridPainter(
            mask: mask,
            bbox: bbox,
            gridImage: gridImage,
          ),
          isComplex: true,
          willChange: false,
        ),
      ),
    );
  }
}

/// Painter that draws grid.png clipped to the mask shape
class _MaskedGridPainter extends CustomPainter {
  final List<List<int>> mask;
  final List<int> bbox;
  final ui.Image gridImage;
  
  _MaskedGridPainter({
    required this.mask,
    required this.bbox,
    required this.gridImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (mask.isEmpty || mask[0].isEmpty) return;
    
    // Create path from mask
    final path = _createMaskPath(size);
    
    // Clip to mask shape
    canvas.save();
    canvas.clipPath(path);
    
    // Tile the grid image to fill the area
    final paint = Paint()..filterQuality = FilterQuality.low;
    final gridWidth = gridImage.width.toDouble();
    final gridHeight = gridImage.height.toDouble();
    
    for (double y = 0; y < size.height; y += gridHeight) {
      for (double x = 0; x < size.width; x += gridWidth) {
        canvas.drawImage(gridImage, Offset(x, y), paint);
      }
    }
    
    canvas.restore();
    
    // Draw subtle border around the mask shape
    final borderPaint = Paint()
      ..color = Colors.grey.shade500.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);
  }
  
  /// Create path from mask - optimized with horizontal run-length encoding
  Path _createMaskPath(Size size) {
    final path = Path();
    final maskHeight = mask.length;
    final maskWidth = mask[0].length;
    
    final bboxWidth = bbox[2] - bbox[0] + 1;
    final bboxHeight = bbox[3] - bbox[1] + 1;
    
    final scaleX = size.width / bboxWidth;
    final scaleY = size.height / bboxHeight;
    
    // Sample at lower resolution for performance
    final step = (bboxWidth / 80).ceil().clamp(1, 8);
    
    for (int my = bbox[1]; my <= bbox[3] && my < maskHeight; my += step) {
      int? runStart;
      
      for (int mx = bbox[0]; mx <= bbox[2] && mx < maskWidth; mx += step) {
        final inMask = my < mask.length && mx < mask[my].length && mask[my][mx] == 1;
        
        if (inMask && runStart == null) {
          runStart = mx;
        } else if (!inMask && runStart != null) {
          final x1 = (runStart - bbox[0]) * scaleX;
          final y1 = (my - bbox[1]) * scaleY;
          final x2 = (mx - bbox[0]) * scaleX;
          final y2 = y1 + scaleY * step;
          path.addRect(Rect.fromLTRB(x1, y1, x2, y2));
          runStart = null;
        }
      }
      
      if (runStart != null) {
        final x1 = (runStart - bbox[0]) * scaleX;
        final y1 = (my - bbox[1]) * scaleY;
        path.addRect(Rect.fromLTRB(x1, y1, size.width, y1 + scaleY * step));
      }
    }
    
    return path;
  }

  @override
  bool shouldRepaint(covariant _MaskedGridPainter oldDelegate) {
    return mask != oldDelegate.mask || 
           gridImage != oldDelegate.gridImage;
  }
}
