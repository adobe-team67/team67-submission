// features/editor/widgets/image_canvas.dart
// Canvas placeholder using PhotoView for pinch/zoom and a CustomPainter overlay for mask.
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'selection_cutout_overlay.dart';
import 'selection_placeholder_overlay.dart';
import 'selection_tool_overlay.dart';
import 'selection_preview_overlay.dart';
import '../controllers/selection_mode_controller.dart';
import '../controllers/lasso_controller.dart';
import '../controllers/brush_controller.dart';
import '../../../state/editing_image_manager.dart';

/// Provider to track if image zooming/panning should be disabled
final disableImageGesturesProvider = Provider<bool>((ref) {
  final toolState = ref.watch(selectionModeProvider);
  final isCutoutDragging = ref.watch(isCutoutDraggingProvider);
  
  // Disable gestures when using lasso/brush tools OR when dragging a cutout
  return isCutoutDragging || 
      (toolState.hasActiveTool && 
       (toolState.tool == SelectionTool.lasso || toolState.tool == SelectionTool.brush));
});

class ImageCanvas extends ConsumerStatefulWidget {
  final Uint8List imageBytes;
  final Uint8List? maskBytes;
  final void Function(Offset imagePixelCoordinate)? onTap;
  final Offset? selectedPixelCoordinate;
  final Rect? binZone;
  final VoidCallback? onEraseRequested;

  const ImageCanvas({
    super.key,
    required this.imageBytes,
    this.maskBytes,
    this.onTap,
    this.selectedPixelCoordinate,
    this.binZone,
    this.onEraseRequested,
  });

  @override
  ConsumerState<ImageCanvas> createState() => _ImageCanvasState();
}

class _ImageCanvasState extends ConsumerState<ImageCanvas> {
  ui.Image? _decodedImage;
  bool _isDecoding = false;
  
  @override
  void initState() {
    super.initState();
    _decodeImage();
  }
  
  @override
  void didUpdateWidget(ImageCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageBytes != widget.imageBytes) {
      _decodeImage();
    }
  }
  
  Future<void> _decodeImage() async {
    if (_isDecoding) return;
    _isDecoding = true;
    
    try {
      final image = await decodeImageFromList(widget.imageBytes);
      if (mounted) {
        setState(() {
          _decodedImage = image;
          _isDecoding = false;
        });
        
        // Load into EditingImageManager if not already
        final currentImage = ref.read(editingImageProvider);
        if (currentImage == null || currentImage.currentImageBytes != widget.imageBytes) {
          ref.read(editingImageProvider.notifier).loadImage(
            imageBytes: widget.imageBytes,
          );
        }
      }
    } catch (e) {
      _isDecoding = false;
    }
  }
  
  /// Handle pan start with pre-calculated image position
  void _handlePanStartWithOffset(Offset imagePos) {
    final toolState = ref.read(selectionModeProvider);
    if (!toolState.hasActiveTool || !toolState.isSelectionPhase) return;
    
    switch (toolState.tool) {
      case SelectionTool.lasso:
        ref.read(lassoControllerProvider.notifier).startDrawing(imagePos);
        break;
      case SelectionTool.brush:
        ref.read(brushControllerProvider.notifier).startPainting(imagePos);
        break;
      default:
        break;
    }
  }
  
  /// Handle pan update with pre-calculated image position
  void _handlePanUpdateWithOffset(Offset imagePos) {
    final toolState = ref.read(selectionModeProvider);
    if (!toolState.hasActiveTool || !toolState.isSelectionPhase) return;
    
    switch (toolState.tool) {
      case SelectionTool.lasso:
        ref.read(lassoControllerProvider.notifier).continueDrawing(imagePos);
        break;
      case SelectionTool.brush:
        ref.read(brushControllerProvider.notifier).continuePainting(imagePos);
        break;
      default:
        break;
    }
  }
  
  void _handlePanEnd(DragEndDetails details) {
    final toolState = ref.read(selectionModeProvider);
    if (!toolState.hasActiveTool || !toolState.isSelectionPhase) return;
    
    switch (toolState.tool) {
      case SelectionTool.lasso:
        ref.read(lassoControllerProvider.notifier).endDrawing();
        break;
      case SelectionTool.brush:
        ref.read(brushControllerProvider.notifier).endPainting();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch selections for overlays
    final selections = ref.watch(imageSelectionsProvider);
    final toolState = ref.watch(selectionModeProvider);
    final disableGestures = ref.watch(disableImageGesturesProvider);
    final isSliderOpen = toolState.isSliderOpen;
    final isActionPhase = toolState.isActionPhase;
    final isSelectionPhase = toolState.isSelectionPhase;
    
    if (_decodedImage == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final img = _decodedImage!;
    final imageWidth = img.width.toDouble();
    final imageHeight = img.height.toDouble();
    
    // Build the image with overlays
    Widget buildImageWithOverlays() {
      return SizedBox(
        width: imageWidth,
        height: imageHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Base image (blur in action phase to emphasize cutout)
            if (isSliderOpen && isActionPhase && selections.isNotEmpty)
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.3),
                    BlendMode.darken,
                  ),
                  child: RawImage(image: img, fit: BoxFit.contain),
                ),
              )
            else
              RawImage(image: img, fit: BoxFit.contain),
            
            // Selection preview overlay (shows grid on selected areas in SELECTION phase)
            // This helps user visualize what they've selected
            if (isSliderOpen && isSelectionPhase && selections.isNotEmpty)
              SelectionPreviewOverlay(
                imageSize: Size(imageWidth, imageHeight),
              ),
            
            // Grid placeholder at original position (only in ACTION phase when slider is open)
            if (isSliderOpen && isActionPhase && selections.isNotEmpty)
              SelectionPlaceholderOverlay(
                imageSize: Size(imageWidth, imageHeight),
              ),
            
            // Selection tool overlay (lasso/brush visualization) - only in selection phase
            if (isSliderOpen && isSelectionPhase)
              SelectionToolOverlay(
                imageSize: Size(imageWidth, imageHeight),
                scale: 1.0,
                imageOffset: Offset.zero,
              ),
          ],
        ),
      );
    }
    
    // Determine if we should intercept gestures for selection tools (only in selection phase)
    final shouldInterceptGestures = isSliderOpen && isSelectionPhase && 
        toolState.hasActiveTool && 
        (toolState.tool == SelectionTool.lasso || toolState.tool == SelectionTool.brush);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the position of the image within the canvas
        final canvasWidth = constraints.maxWidth;
        final canvasHeight = constraints.maxHeight;
        
        // Calculate scale to fit image within canvas (contained fit)
        final scaleX = canvasWidth / imageWidth;
        final scaleY = canvasHeight / imageHeight;
        final scale = scaleX < scaleY ? scaleX : scaleY;
        
        // Calculate the offset to center the image
        final scaledImageWidth = imageWidth * scale;
        final scaledImageHeight = imageHeight * scale;
        final offsetX = (canvasWidth - scaledImageWidth) / 2;
        final offsetY = (canvasHeight - scaledImageHeight) / 2;
        
        return Stack(
          fit: StackFit.expand,
          children: [
            // PhotoView with centered image
            Center(
              child: PhotoView.customChild(
                childSize: Size(imageWidth, imageHeight),
                // Disable pan/zoom when using lasso, brush, OR when dragging cutout
                disableGestures: disableGestures,
                child: buildImageWithOverlays(),
                backgroundDecoration: const BoxDecoration(color: Colors.transparent),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.contained * 4.0,
                initialScale: PhotoViewComputedScale.contained,
              ),
            ),
            
            // Gesture layer for lasso/brush - OUTSIDE PhotoView for proper gesture capture
            if (shouldInterceptGestures)
              Positioned(
                left: offsetX,
                top: offsetY,
                width: scaledImageWidth,
                height: scaledImageHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) {
                    // Convert from scaled position to image coordinates
                    final localX = details.localPosition.dx / scale;
                    final localY = details.localPosition.dy / scale;
                    final imagePos = Offset(
                      localX.clamp(0.0, imageWidth),
                      localY.clamp(0.0, imageHeight),
                    );
                    _handlePanStartWithOffset(imagePos);
                  },
                  onPanUpdate: (details) {
                    final localX = details.localPosition.dx / scale;
                    final localY = details.localPosition.dy / scale;
                    final imagePos = Offset(
                      localX.clamp(0.0, imageWidth),
                      localY.clamp(0.0, imageHeight),
                    );
                    _handlePanUpdateWithOffset(imagePos);
                  },
                  onPanEnd: (_) => _handlePanEnd(DragEndDetails()),
                  child: Container(color: Colors.transparent),
                ),
              ),
            
            // Selection cutout overlay - ONLY in action phase when slider is open
            if (isSliderOpen && isActionPhase && selections.isNotEmpty)
              Positioned(
                left: offsetX,
                top: offsetY,
                width: scaledImageWidth,
                height: scaledImageHeight,
                child: SelectionCutoutOverlay(
                  imageSize: Size(imageWidth, imageHeight),
                  scale: scale,
                  imageOffset: Offset.zero,
                  elevationOffset: 4.0,
                  binZone: widget.binZone,
                  onEraseRequested: widget.onEraseRequested,
                ),
              ),
          ],
        );
      },
    );
  }
}
