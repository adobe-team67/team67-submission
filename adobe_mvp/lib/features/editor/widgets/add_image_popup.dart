// features/editor/widgets/add_image_popup.dart
// Popup dialog for adding images with two options:
// 1. Import as Layer - composites the new image onto the canvas
// 2. Converge Images - uses AI to merge/blend two images together

import 'package:flutter/material.dart';

/// Option selected by user for adding an image
enum AddImageOption {
  importAsLayer,
  convergeImages,
}

/// Shows the add image options popup as a dialog.
/// Returns the selected option, or null if dismissed.
Future<AddImageOption?> showAddImagePopup(BuildContext context) {
  return showDialog<AddImageOption>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (ctx) => const _AddImagePopupDialog(),
  );
}

class _AddImagePopupDialog extends StatelessWidget {
  const _AddImagePopupDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
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
                    'Add Image',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurface,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Description
              Text(
                'Choose how you want to add the new image:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 24),

              // Option 1: Import as Layer
              _buildOptionTile(
                context: context,
                icon: Icons.layers_outlined,
                iconColor: const Color(0xFF3B62FB),
                title: 'Import as Layer',
                description: 'Add the image on top of your current canvas. Perfect for compositing and layered edits.',
                onTap: () => Navigator.of(context).pop(AddImageOption.importAsLayer),
              ),
              
              const SizedBox(height: 16),

              // Option 2: Converge Images
              _buildOptionTile(
                context: context,
                icon: Icons.auto_awesome,
                iconColor: const Color(0xFF9C27B0),
                title: 'Converge Images',
                description: 'Use AI to intelligently blend and merge two images together for creative effects.',
                onTap: () => Navigator.of(context).pop(AddImageOption.convergeImages),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.onSurface.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow indicator
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
