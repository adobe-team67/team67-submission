import 'dart:ui' as ui;
import 'package:adobe_mvp/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';

class FloatingNavItem {
  final IconData? icon;
  final String? iconAsset;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  FloatingNavItem({this.icon, this.iconAsset, required this.label, this.onTap, this.color})
      : assert(icon != null || iconAsset != null, 'Either icon or iconAsset must be provided');
}

class FloatingBottomNav extends StatelessWidget {
  final List<FloatingNavItem> items;
  final double sx;
  final double sy;
  final bool compact;
  final Color? backgroundColor;
  final Duration duration;
  final double horizontalPadding;
  final double itemSpacing;

  const FloatingBottomNav({
    Key? key,
    required this.items,
    this.sx = 1.0,
    this.sy = 1.0,
    this.compact = false,
    this.backgroundColor,
    this.duration = const Duration(milliseconds: 300),
    this.horizontalPadding = 32,
    this.itemSpacing = 26,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = (backgroundColor ?? AppTheme.darkTheme.cardColor).withOpacity(compact ? 0.85 : 1.0);

    // Compact transforms: slightly up (-12*sy), right (+20*sx) and scaled to 0.92
    final translateX = compact ? 10.0  : 0.0;
    final translateY = compact ? 10.0  : 0.0;
    final scale = compact ? 0.9 : 1.0;
    final opacity = compact ? 0.6 : 1.0;
    final height = compact ? 60.0 * sy : 80.0 * sy;

    final showLabels = !compact; // initial expanded shows labels, compact hides

    return AnimatedContainer(
      // height: height,
      duration: duration,
      transform: Matrix4.identity()
        ..translate(translateX, translateY)
        ..scale(scale, scale),
      child: AnimatedOpacity(
        duration: duration,
        opacity: opacity,
        child: Material(
          color: Colors.transparent,
          // child: ClipRRect(
          //   borderRadius: BorderRadius.circular(60 * sx),
          //   child : BackdropFilter(
          //     filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: 
            Container(
              margin: EdgeInsets.all(20),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8 ),
              decoration: ShapeDecoration(
                color: bg.withOpacity(.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(60 * sx)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: items.map((it) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: (itemSpacing) / 2),
                    child: GestureDetector(
                      onTap: it.onTap,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 36),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (it.iconAsset != null)
                                Image.asset(
                                  it.iconAsset!,
                                  width: 24 * sx,
                                  height: 24 * sx,
                                  color: it.color ?? Colors.white,
                                )
                              else
                                Icon(it.icon, color: it.color ?? Colors.white, size: 24 * sx),
                              SizedBox(height: 6 * sy),
                              if (showLabels)
                                Text(
                                  it.label,
                                  textAlign: TextAlign.center,
                                  style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontFamily: 'Adobe Clean',
                                        fontWeight: FontWeight.w500,
                                        height: 1.83,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ) ;
  }
}
