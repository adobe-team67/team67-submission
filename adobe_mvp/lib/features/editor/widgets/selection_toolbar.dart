// features/editor/widgets/selection_toolbar.dart
// Bottom toolbar with selection tools (Selection, Lasso, Brush, Remove, NLP)
import 'package:flutter/material.dart';
import 'package:adobe_mvp/ui/theme/app_theme.dart';

class SelectionToolbar extends StatelessWidget {
  final void Function()? onSelect;
  final void Function()? onRemove;
  const SelectionToolbar({super.key, this.onSelect, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.darkTheme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(onPressed: onSelect, icon: const Icon(Icons.select_all)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.brush)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.crop_square)),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_forever)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.text_fields)),
        ],
      ),
    );
  }
}
