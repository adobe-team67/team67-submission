// ui/widgets/app_scaffold.dart
// Small scaffold wrapper used by screens for consistent paddings and actions.
import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;

  const AppScaffold({super.key, required this.body, this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Adobe MVP'), actions: actions),
      body: body,
    );
  }
}
