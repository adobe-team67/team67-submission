// features/editor/widgets/sliders/layers_slider.dart
import 'package:adobe_mvp/features/editor/widgets/sliders/layers/layer_card.dart';
import 'package:adobe_mvp/state/editing_image_manager.dart';
import 'package:adobe_mvp/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LayersSlider extends ConsumerStatefulWidget {
  final double sx;
  final double sy;
    final VoidCallback? onClose;
  const LayersSlider({Key? key, this.sx = 1.0, this.sy = 1.0, this.onClose}) : super(key: key);

  @override
  ConsumerState<LayersSlider> createState() => _LayersSliderState();
}

class _LayersSliderState extends ConsumerState<LayersSlider> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.darkTheme;
    final currentImageBytes = ref.watch(currentImageProvider);
    
    // design constants
    const double baseCardHeight = 68.0;
    const double baseCardVerticalMargin = 12.0;
    final double perCardTotal = (baseCardHeight + baseCardVerticalMargin) * widget.sy;
    final double visibleAreaHeight = perCardTotal * 1.5;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 32),
      // valid decoration present so clipBehavior is OK here
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: theme.cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // handle
                    GestureDetector(
            onTap: widget.onClose,
            onVerticalDragEnd: (details) {
              // Swipe down to close
              if (details.primaryVelocity != null && details.primaryVelocity! > 100) {
                widget.onClose?.call();
              }
            },
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: 30,
              child: Center(
                child:Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: theme.colorScheme.onPrimary, borderRadius: BorderRadius.circular(4)),
          )))),
          const SizedBox(height: 12),
          // title row - remove clipBehavior since no decoration here
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text('Layers', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500, height: .92, fontFamily: 'Adobe Clean')),
          ),

          // Single layer card showing current image
          SizedBox(
            height: visibleAreaHeight,
            child: currentImageBytes != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: LayerCard(
                      label: 'Image',
                      thumbnailBytes: currentImageBytes,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Selected Background layer')),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Text(
                      'No image loaded',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white54),
                    ),
                  ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
