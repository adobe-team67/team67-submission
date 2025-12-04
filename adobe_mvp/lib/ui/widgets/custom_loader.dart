import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// LoadingOverlay
/// - Wrap any subtree with this widget. When [isLoading] is true it paints an
///   animated translucent checkerboard overlay (wavy animation).
/// - It blocks pointer events while loading (AbsorbPointer).
class LoadingOverlay extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final double cellSize; // size of checker tile in logical px
  final Color lightColor; // lighter check color
  final Color darkColor; // darker check color
  final double overlayOpacity; // overall overlay alpha (0..1)
  final Duration period; // animation cycle length
  final bool absorbPointer; // whether to block input

  const LoadingOverlay({
    Key? key,
    required this.child,
    required this.isLoading,
    this.cellSize = 24.0,
    this.lightColor = const Color(0x66FFFFFF),
    this.darkColor = const Color(0x33FFFFFF),
    this.overlayOpacity = 0.6,
    this.period = const Duration(milliseconds: 1000),
    this.absorbPointer = true,
  }) : super(key: key);

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant LoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _ctrl.duration = widget.period;
      if (_ctrl.isAnimating) _ctrl.repeat();
    }
    // Keep animation running only while loading (optional)
    if (widget.isLoading && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.isLoading && _ctrl.isAnimating) {
      // Let animation continue for a fraction to complete smooth fade-out or stop immediately:
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The overlay sits above the child inside a Stack.
    final overlay = AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _CheckerWavePainter(
            phase: _ctrl.value, // 0..1
            cellSize: widget.cellSize,
            lightColor: widget.lightColor.withOpacity(widget.overlayOpacity),
            darkColor: widget.darkColor.withOpacity(widget.overlayOpacity),
          ),
        );
      },
    );

    // only show overlay when loading
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // When loading show overlay; otherwise nothing
        if (widget.isLoading)
          AbsorbPointer(
            absorbing: widget.absorbPointer,
            child: FadeTransition(
              // Smooth fade-in/out so enabling/disabling looks nice
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
              child: overlay,
            ),
          ),
      ],
    );
  }
}

/// Painter draws a checkerboard and computes a "wave" brightness per cell.
/// The wave is produced by sampling sin(row*freq + col*freq - phase*TAU).
class _CheckerWavePainter extends CustomPainter {
  final double phase; // 0..1
  final double cellSize;
  final Color lightColor;
  final Color darkColor;

  _CheckerWavePainter({
    required this.phase,
    required this.cellSize,
    required this.lightColor,
    required this.darkColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final int cols = (size.width / cellSize).ceil();
    final int rows = (size.height / cellSize).ceil();

    // Wave settings
    final double t = phase * 2 * pi; // map phase to radians
    final double freq = 1.2; // wave frequency (affects wavelength)
    final double speed = 1.0; // speed multiplier (already in phase)
    final double amp = 0.55; // amplitude of brightness variation (0..1)

    // Precompute cell rect size to avoid recreating
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final double left = c * cellSize;
        final double top = r * cellSize;
        final Rect cellRect = Rect.fromLTWH(left, top, cellSize + 0.5, cellSize + 0.5);
        // base checker alternation (classic chessboard)
        final bool base = ((r + c) % 2 == 0);

        // compute wave factor for this cell
        // Using a 2D travelling wave: sin(kx * c + ky * r - t)
        final double phaseForCell = (freq * (c + r) * 0.6) - (t * speed);
        final double s = (sin(phaseForCell) + 1) / 2; // 0..1
        // brightness modulation bias so wave moves between slightly darker and lighter
        final double mod = (1 - amp) + amp * s; // in [1-amp,1]

        // pick base color
        final Color baseColor = base ? lightColor : darkColor;

        // apply modulation by lerping towards white (for "lit" cells) or towards black (for "dim" cells)
        // we choose lerp to white to increase brightness subtly
        final Color finalColor = Color.lerp(baseColor, Colors.white.withOpacity(baseColor.opacity), (mod - 1 + amp) / (2 * amp)) ?? baseColor;

        paint.color = finalColor;
        canvas.drawRect(cellRect, paint);
      }
    }

    // Overlay an overall subtle dark scrim to contrast the checks a bit (so it looks translucent)
    final overlay = Paint()..color = Colors.black.withOpacity(0.06);
    canvas.drawRect(Offset.zero & size, overlay);
  }

  @override
  bool shouldRepaint(covariant _CheckerWavePainter old) {
    return old.phase != phase || old.cellSize != cellSize || old.lightColor != lightColor || old.darkColor != darkColor;
  }
}
