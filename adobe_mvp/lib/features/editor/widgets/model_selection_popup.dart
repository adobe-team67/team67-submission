// features/editor/widgets/model_selection_popup.dart
import 'package:flutter/material.dart';
import 'package:adobe_mvp/core/global.dart';

/// Model data: name, badge text, badge color, description
class ModelInfo {
  final String name;
  final String badge;
  final Color badgeColor;
  final String description;

  const ModelInfo({
    required this.name,
    required this.badge,
    required this.badgeColor,
    required this.description,
  });
}

const _models = [
  ModelInfo(
    name: 'Atom',
    badge: 'FREE',
    badgeColor: Color(0xFF3B62FB),
    description:
        'On-device intelligence. Unlimited, private, and runs offline. Best for rapid iterations and quick edits.',
  ),
  ModelInfo(
    name: 'PhotoFlux V30',
    badge: 'PRO',
    badgeColor: Color(0xFF937204),
    description:
        'The creative powerhouse. Specialized in high-fidelity textures, cinematic lighting, and artistic stylization.',
  ),
  ModelInfo(
    name: 'PhotoQwen V30',
    badge: 'PRO',
    badgeColor: Color(0xFF937204),
    description:
        'Precision instruction follower. Best for complex prompts, spatial reasoning, and rendering accurate text.',
  ),
];

/// Shows the model selection popup as a dialog.
/// Returns true if a model was selected, false/null otherwise.
Future<bool?> showModelSelectionPopup(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (ctx) => const _ModelSelectionDialog(),
  );
}

class _ModelSelectionDialog extends StatefulWidget {
  const _ModelSelectionDialog();

  @override
  State<_ModelSelectionDialog> createState() => _ModelSelectionDialogState();
}

class _ModelSelectionDialogState extends State<_ModelSelectionDialog> {
  String _selected = GlobalConfig.selectedModelName;

  void _selectModel(ModelInfo m) {
    setState(() => _selected = m.name);
    GlobalConfig.setModelType(m.name, m.badge);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 333,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
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
                    'Models',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Icon(Icons.close,
                        color: theme.colorScheme.onSurface, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Description
              Text(
                'You can select from a variety of models based on your usecase and preferences.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.57,
                ),
              ),
              const SizedBox(height: 24),

              // Model list
              ..._models.map((m) => _buildModelTile(m)).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelTile(ModelInfo m) {
    final theme = Theme.of(context);
    final isSelected = _selected == m.name;

    return GestureDetector(
      onTap: () => _selectModel(m),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name row with badge and optional checkmark
            Row(
              children: [
                Text(
                  m.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: ShapeDecoration(
                    color: m.badgeColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  child: Text(
                    m.badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'Adobe Clean',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle,
                      color: theme.colorScheme.primary, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              m.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.72),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
