// features/editor/widgets/selection_preview_overlay.dart
// Displays selection preview (grid pattern on selected areas) during Selection Phase
// to help users visualize what they've selected before proceeding to Action Phase.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/editing_image_manager.dart';
import '../../../models/editing_image.dart';

/// Cached grid image to avoid reloading
ui.Image? _cachedPreviewGridImage;
bool _isLoadingPreviewGrid = false;

/// Load grid image once and cache it
Future<ui.Image?> _loadPreviewGridImage() async {
  if (_cachedPreviewGridImage != null) return _cachedPreviewGridImage;
  if (_isLoadingPreviewGrid) return null;
  
  _isLoadingPreviewGrid = true;
  try {
    // Try grid.jpeg first, fallback to grid.png
    ByteData? data;
    try {
      data = await rootBundle.load('assets/grid.jpeg');
    } catch (_) {
      try {
        data = await rootBundle.load('assets/grid.png');
      } catch (_) {
        debugPrint('No grid image found (tried grid.jpeg and grid.png)');
        return null;
      }
    }
    
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _cachedPreviewGridImage = frame.image;
    return _cachedPreviewGridImage;
  } catch (e) {
    debugPrint('Failed to load grid image for preview: $e');
    return null;
  } finally {
    _isLoadingPreviewGrid = false;
  }
}

/// Overlay showing selection preview (grid on selected areas) during Selection Phase
/// This helps users see what they've selected before proceeding to Action Phase
class SelectionPreviewOverlay extends ConsumerStatefulWidget {
  final Size imageSize;
  
  const SelectionPreviewOverlay({
    super.key,
    required this.imageSize,
  });

  @override
  ConsumerState<SelectionPreviewOverlay> createState() => _SelectionPreviewOverlayState();
}

class _SelectionPreviewOverlayState extends ConsumerState<SelectionPreviewOverlay> {
  ui.Image? _gridImage;
  
  @override
  void initState() {
    super.initState();
    _loadGrid();
  }
  
  Future<void> _loadGrid() async {
    final img = await _loadPreviewGridImage();
    if (mounted && img != null) {
      setState(() => _gridImage = img);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selections = ref.watch(imageSelectionsProvider);
    
    if (selections.isEmpty) return const SizedBox.shrink();
    
    // Grid image is optional - overlay will still show without it
    return Stack(
      clipBehavior: Clip.none,
      children: selections.map((selectionState) {
        return _SelectionPreviewItem(
          key: ValueKey('preview_${selectionState.id}'),
          selectionState: selectionState,
          imageSize: widget.imageSize,
          gridImage: _gridImage,
        );
      }).toList(),
    );
  }
}

class _SelectionPreviewItem extends StatelessWidget {
  final SelectionState selectionState;
  final Size imageSize;
  final ui.Image? gridImage;
  
  const _SelectionPreviewItem({
    super.key,
    required this.selectionState,
    required this.imageSize,
    this.gridImage,
  });

  @override
  Widget build(BuildContext context) {
    final selection = selectionState.selection;
    final bbox = selection.boundingBox;
    final mask = selection.mask;
    
    if (mask.isEmpty || mask[0].isEmpty) {
      return const SizedBox.shrink();
    }
    
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
      child: IgnorePointer(
        // Don't intercept gestures - this is just a visual preview
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size(width, height),
            painter: _SelectionPreviewPainter(
              mask: mask,
              bbox: bbox,
              gridImage: gridImage,
            ),
            isComplex: true,
            willChange: false,
          ),
        ),
      ),
    );
  }
}

/// Painter that draws a colored semi-transparent overlay on selected areas
/// This makes selections clearly visible to the user during Selection Phase
class _SelectionPreviewPainter extends CustomPainter {
  final List<List<int>> mask;
  final List<int> bbox;
  final ui.Image? gridImage;
  
  _SelectionPreviewPainter({
    required this.mask,
    required this.bbox,
    this.gridImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (mask.isEmpty || mask[0].isEmpty) return;
    
    // Create path from mask
    final path = _createMaskPath(size);
    
    // Clip to mask shape
    canvas.save();
    canvas.clipPath(path);
    
    // Draw colored semi-transparent overlay to clearly show selected areas
    // Using a blue color that's visible on most images
    final overlayPaint = Paint()
      ..color = const Color(0xFF2196F3).withOpacity(0.4)  // Blue with 40% opacity
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);
    
    // Optionally add a subtle grid pattern for texture if grid image is available
    if (gridImage != null) {
      final paint = Paint()
        ..filterQuality = FilterQuality.low
        ..color = Colors.white.withOpacity(0.3);  // More subtle grid
      
      final gridWidth = gridImage!.width.toDouble();
      final gridHeight = gridImage!.height.toDouble();
      
      // Tile the grid image
      for (double y = 0; y < size.height; y += gridHeight) {
        for (double x = 0; x < size.width; x += gridWidth) {
          canvas.drawImage(gridImage!, Offset(x, y), paint);
        }
      }
    }
    
    canvas.restore();
    
    // Draw a visible animated border around the selection
    // Outer border - darker for contrast
    final outerBorderPaint = Paint()
      ..color = const Color(0xFF1565C0).withOpacity(0.9)  // Dark blue
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, outerBorderPaint);
    
    // Inner border - white dashed for "marching ants" effect
    final innerBorderPaint = Paint()
      ..color = Colors.white.withOpacity(0.95)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, innerBorderPaint);
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
  bool shouldRepaint(covariant _SelectionPreviewPainter oldDelegate) {
    return mask != oldDelegate.mask || 
           gridImage != oldDelegate.gridImage;
  }
}
