// features/editor/widgets/magic_view_popup.dart
import 'package:adobe_mvp/core/constants.dart';
import 'package:flutter/material.dart';

/// Perspective view options for MagicView
enum MagicViewDirection {
  left,
  right,
  back,
}

/// Shows the MagicView popup as a dialog.
/// Returns the selected direction, or null if dismissed.
Future<MagicViewDirection?> showMagicViewPopup(BuildContext context) {
  return showDialog<MagicViewDirection>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (ctx) => const _MagicViewDialog(),
  );
}

class _MagicViewDialog extends StatelessWidget {
  const _MagicViewDialog();
  

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final sx = mq.size.width / refW;
    final sy = mq.size.height / refH;


    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 354 * sx,
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: title + close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MagicView',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(null),
                    child: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurface,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 45),

              // Description
              SizedBox(
                // width: 226,
                child: Text(
                  'You can select from a variety of angles to transform your image into another perspective.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.57,
                  ),
                ),
              ),
              const SizedBox(height: 45),

              // Direction buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _DirectionButton(
                    label: 'LEFT',
                    icon: Icons.view_in_ar_rounded,
                    onTap: () => Navigator.of(context).pop(MagicViewDirection.left),
                  ),
                  _DirectionButton(
                    label: 'BACK',
                    icon: Icons.view_in_ar_rounded,
                    onTap: () => Navigator.of(context).pop(MagicViewDirection.back),
                  ),
                  _DirectionButton(
                    label: 'RIGHT',
                    icon: Icons.view_in_ar_rounded,
                    onTap: () => Navigator.of(context).pop(MagicViewDirection.right),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual direction button widget
class _DirectionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DirectionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Preview placeholder with arrow icon
          Container(
            width: 43,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                icon,
                color: theme.colorScheme.onSurface,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Label
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              
            ),
          ),
        ],
      ),
    );
  }
}
