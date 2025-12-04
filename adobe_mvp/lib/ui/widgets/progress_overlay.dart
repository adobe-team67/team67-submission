// ui/widgets/progress_overlay.dart
// Simple overlay to show a loading indicator with message.
import 'package:flutter/material.dart';

class ProgressOverlay extends StatelessWidget {
  final String message;
  const ProgressOverlay({super.key, this.message = 'Please wait...'});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withOpacity(0.3),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
