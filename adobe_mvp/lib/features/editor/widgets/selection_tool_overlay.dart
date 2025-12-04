// features/editor/widgets/selection_tool_overlay.dart
// Overlay widget for displaying lasso and brush selection visuals

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/selection_mode_controller.dart';
import '../controllers/lasso_controller.dart';
import '../controllers/brush_controller.dart';

/// Overlay that shows visual feedback for selection tools
class SelectionToolOverlay extends ConsumerWidget {
  /// Size of the image in canvas coordinates
  final Size imageSize;
  
  /// Scale factor for the canvas
  final double scale;
  
  /// Offset of the image on the canvas
  final Offset imageOffset;

  const SelectionToolOverlay({
    super.key,
    required this.imageSize,
    this.scale = 1.0,
    this.imageOffset = Offset.zero,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolState = ref.watch(selectionModeProvider);
    final lassoState = ref.watch(lassoControllerProvider);
    final brushState = ref.watch(brushControllerProvider);
    
    return Stack(
      children: [
        // Lasso path visualization
        if (toolState.tool == SelectionTool.lasso && lassoState.points.isNotEmpty)
          Positioned.fill(
            child: CustomPaint(
              painter: _LassoPainter(
                points: lassoState.points,
                isDrawing: lassoState.isDrawing,
                isClosed: lassoState.isClosed,
                scale: scale,
                offset: imageOffset,
                isAddMode: toolState.mode == SelectionMode.add,
              ),
            ),
          ),
        
        // Brush strokes visualization
        if (toolState.tool == SelectionTool.brush && brushState.points.isNotEmpty)
          Positioned.fill(
            child: CustomPaint(
              painter: _BrushPainter(
                points: brushState.points,
                scale: scale,
                offset: imageOffset,
                isAddMode: toolState.mode == SelectionMode.add,
              ),
            ),
          ),
      ],
    );
  }
}

/// Painter for lasso selection path
class _LassoPainter extends CustomPainter {
  final List<Offset> points;
  final bool isDrawing;
  final bool isClosed;
  final double scale;
  final Offset offset;
  final bool isAddMode;
  
  _LassoPainter({
    required this.points,
    required this.isDrawing,
    required this.isClosed,
    required this.scale,
    required this.offset,
    required this.isAddMode,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    
    // Scale and translate points
    final scaledPoints = points.map((p) => Offset(
      p.dx * scale + offset.dx,
      p.dy * scale + offset.dy,
    )).toList();
    
    // Create path
    final path = Path();
    path.moveTo(scaledPoints.first.dx, scaledPoints.first.dy);
    
    for (int i = 1; i < scaledPoints.length; i++) {
      path.lineTo(scaledPoints[i].dx, scaledPoints[i].dy);
    }
    
    if (isClosed) {
      path.close();
    }
    
    // Fill color (semi-transparent)
    final fillColor = isAddMode 
        ? const Color(0x3300A3FF)  // Blue for add
        : const Color(0x33FF4444); // Red for subtract
    
    // Stroke color
    final strokeColor = isAddMode 
        ? const Color(0xFF00A3FF)  // Blue
        : const Color(0xFFFF4444); // Red
    
    // Draw fill if closed
    if (isClosed) {
      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }
    
    // Draw stroke
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    // Dashed line effect for drawing
    if (isDrawing) {
      strokePaint.strokeWidth = 3.0;
    }
    
    canvas.drawPath(path, strokePaint);
    
    // Draw start point indicator
    if (points.isNotEmpty && !isClosed) {
      final startPoint = scaledPoints.first;
      final startPaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(startPoint, 8, startPaint);
      
      // White inner circle
      final innerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(startPoint, 5, innerPaint);
    }
    
    // Draw connecting line to start point if close enough
    if (isDrawing && points.length >= 3) {
      final firstPoint = scaledPoints.first;
      final lastPoint = scaledPoints.last;
      final distance = (firstPoint - lastPoint).distance;
      
      if (distance < 50) {
        // Draw dashed line to start
        final connectPaint = Paint()
          ..color = strokeColor.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        
        canvas.drawLine(lastPoint, firstPoint, connectPaint);
      }
    }
  }
  
  @override
  bool shouldRepaint(_LassoPainter oldDelegate) {
    return points != oldDelegate.points ||
        isDrawing != oldDelegate.isDrawing ||
        isClosed != oldDelegate.isClosed ||
        scale != oldDelegate.scale ||
        offset != oldDelegate.offset ||
        isAddMode != oldDelegate.isAddMode;
  }
}

/// Painter for brush selection strokes
class _BrushPainter extends CustomPainter {
  final List<BrushPoint> points;
  final double scale;
  final Offset offset;
  final bool isAddMode;
  
  _BrushPainter({
    required this.points,
    required this.scale,
    required this.offset,
    required this.isAddMode,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    
    // Fill color (semi-transparent)
    final fillColor = isAddMode 
        ? const Color(0x5500A3FF)  // Blue for add
        : const Color(0x55FF4444); // Red for subtract
    
    // Stroke color
    final strokeColor = isAddMode 
        ? const Color(0xFF00A3FF)  // Blue
        : const Color(0xFFFF4444); // Red
    
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    // Draw each brush point as a circle
    for (final point in points) {
      final scaledPosition = Offset(
        point.position.dx * scale + offset.dx,
        point.position.dy * scale + offset.dy,
      );
      final scaledRadius = point.radius * scale;
      
      // Draw filled circle
      canvas.drawCircle(scaledPosition, scaledRadius, fillPaint);
      
      // Draw stroke only for last few points for performance
      if (points.indexOf(point) >= points.length - 10) {
        canvas.drawCircle(scaledPosition, scaledRadius, strokePaint);
      }
    }
  }
  
  @override
  bool shouldRepaint(_BrushPainter oldDelegate) {
    return points != oldDelegate.points ||
        scale != oldDelegate.scale ||
        offset != oldDelegate.offset ||
        isAddMode != oldDelegate.isAddMode;
  }
}

/// Brush size slider overlay (shown when brush tool is active)
class BrushSizeSlider extends ConsumerWidget {
  const BrushSizeSlider({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brushSize = ref.watch(brushSizeProvider);
    final toolState = ref.watch(selectionModeProvider);
    
    if (toolState.tool != SelectionTool.brush) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      right: 16,
      top: 100,
      bottom: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Size indicator
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Container(
                width: brushSize * 0.4,
                height: brushSize * 0.4,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A3FF),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Vertical slider
          SizedBox(
            height: 200,
            child: RotatedBox(
              quarterTurns: -1,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  activeTrackColor: const Color(0xFF00A3FF),
                  inactiveTrackColor: Colors.white.withOpacity(0.3),
                  thumbColor: const Color(0xFF00A3FF),
                  overlayColor: const Color(0x2900A3FF),
                ),
                child: Slider(
                  value: brushSize,
                  min: 10,
                  max: 100,
                  onChanged: (value) {
                    ref.read(brushControllerProvider.notifier).setBrushSize(value);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Size label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${brushSize.round()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'Adobe Clean',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini indicator for showing active selection tool when slider is closed
class SelectionToolIndicator extends ConsumerWidget {
  final VoidCallback? onTap;
  
  const SelectionToolIndicator({super.key, this.onTap});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolState = ref.watch(selectionModeProvider);
    
    if (!toolState.hasActiveTool) {
      return const SizedBox.shrink();
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: toolState.mode == SelectionMode.add
                ? const Color(0xFF00A3FF)
                : const Color(0xFFFF4444),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              toolState.toolIcon,
              color: toolState.mode == SelectionMode.add
                  ? const Color(0xFF00A3FF)
                  : const Color(0xFFFF4444),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              '${toolState.toolName} ${toolState.mode == SelectionMode.add ? '+' : '-'}',
              style: TextStyle(
                fontFamily: 'Adobe Clean',
                color: toolState.mode == SelectionMode.add
                    ? const Color(0xFF00A3FF)
                    : const Color(0xFFFF4444),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
