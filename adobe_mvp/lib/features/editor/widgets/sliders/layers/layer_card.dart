// features/editor/widgets/layer_card.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// A single Layer card matching the Figma layout.
/// - height: 68
/// - rounded corners
/// - small left drag handle (2x3 dots)
/// - thumbnail (29x20), label, right-side 3-dot indicator
class LayerCard extends StatelessWidget {
  final String label;
  final ImageProvider? thumbnail; // preferred
  final Uint8List? thumbnailBytes; // fallback
  final double opacity; // 0.0 - 1.0 (not used for rendering image; informative)
  final bool visible;
  final bool locked;
  final VoidCallback? onTap;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onToggleLock;

  const LayerCard({
    Key? key,
    required this.label,
    this.thumbnail,
    this.thumbnailBytes,
    this.opacity = 1.0,
    this.visible = true,
    this.locked = false,
    this.onTap,
    this.onToggleVisibility,
    this.onToggleLock,
  })  : assert(thumbnail != null || thumbnailBytes != null, 'Provide thumbnail or thumbnailBytes'),
        super(key: key);

  ImageProvider _resolveImage() {
    if (thumbnail != null) return thumbnail!;
    return MemoryImage(thumbnailBytes!);
  }

  Widget _buildDots({double spacing = 6.0}) {
    // 2x3 dots like the design
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _smallDot(),
            SizedBox(width: spacing / 3),
            _smallDot(),
          ],
        ),
        SizedBox(height: spacing / 4),
        Row(
          children: [
            _smallDot(),
            SizedBox(width: spacing / 3),
            _smallDot(),
          ],
        ),
        SizedBox(height: spacing / 4),
        Row(
          children: [
            _smallDot(),
            SizedBox(width: spacing / 3),
            _smallDot(),
          ],
        ),
      ],
    );
  }

  Widget _smallDot() => Container(
        width: 4,
        height: 4,
        decoration: const BoxDecoration(
          color: Color(0xFFD9D9D9),
          shape: BoxShape.circle,
        ),
      );

  Widget _rightIndicator() => Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(width: 4),
          _IndicatorDot(),
          SizedBox(width: 4),
          _IndicatorDot(),
          SizedBox(width: 4),
          _IndicatorDot(),
        ],
      );

  @override
  Widget build(BuildContext context) {
    // Keep exact height from design
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 68,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        // clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Material(
          color: Colors.transparent, // subtle base, parent sheet supplies background
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // Main row content
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      // left handle (fixed width area)
                      SizedBox(
                        width: 48,
                        child: Center(child: _buildDots(spacing: 6)),
                      ),

                      // thumbnail
                      Container(
                        width: 29,
                        height: 20,
                        decoration: ShapeDecoration(
                          image: DecorationImage(
                            image: _resolveImage(),
                            fit: BoxFit.cover,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // label + optional meta
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'Adobe Clean',
                                fontWeight: FontWeight.w500,
                                height: 1.38,
                              ),
                            ),
                            // const SizedBox(height: 4),
                            // Row(
                            //   children: [
                            //     Opacity(
                            //       opacity: 0.8,
                            //       child: Text(
                            //         'Opacity ${ (opacity * 100).round() }%',
                            //         style: const TextStyle(color: Colors.white70, fontSize: 12),
                            //       ),
                            //     ),
                            //     const SizedBox(width: 12),
                            //     if (!visible)
                            //       const Icon(Icons.visibility_off, size: 14, color: Colors.white54),
                            //     if (locked)
                            //       const Padding(
                            //         padding: EdgeInsets.only(left: 8),
                            //         child: Icon(Icons.lock, size: 14, color: Colors.white54),
                            //       ),
                            //   ],
                            // ),
                          ],
                        ),
                      ),

                      // right indicator (three small dots)
                      _rightIndicator(),
                    ],
                  ),
                ),
              ),

              // invisible touch targets for visibility/lock if provided
              // right-side small buttons positioned similarly to design (approx)
              // Positioned(
              //   right: 8,
              //   top: 18,
              //   child: Row(
              //     children: [
              //       // Visibility toggle
              //       GestureDetector(
              //         onTap: onToggleVisibility,
              //         child: Container(
              //           width: 36,
              //           height: 36,
              //           alignment: Alignment.center,
              //           decoration: const BoxDecoration(shape: BoxShape.circle),
              //           child: Icon(
              //             visible ? Icons.visibility : Icons.visibility_off,
              //             size: 18,
              //             color: Colors.white70,
              //           ),
              //         ),
              //       ),
              //       // Lock toggle
              //       GestureDetector(
              //         onTap: onToggleLock,
              //         child: Container(
              //           width: 36,
              //           height: 36,
              //           alignment: Alignment.center,
              //           decoration: const BoxDecoration(shape: BoxShape.circle),
              //           child: Icon(
              //             locked ? Icons.lock : Icons.lock_open,
              //             size: 18,
              //             color: Colors.white70,
              //           ),
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

/// tiny reusable indicator dot used on right side
class _IndicatorDot extends StatelessWidget {
  const _IndicatorDot();

  @override
  Widget build(BuildContext context) {
    return Container(width: 3, height: 3, decoration: const BoxDecoration(color: Color(0xFFD9D9D9), shape: BoxShape.circle));
  }
}
