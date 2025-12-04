// lib/models/edit_feature.dart
import 'package:flutter/material.dart';

/// Generic model for an editor feature tile.
class EditFeature {
  final String id;
  final String name;
  final IconData? icon;
  final Widget? iconWidget;

  const EditFeature({
    required this.id,
    required this.name,
    this.icon,    this.iconWidget,
  }) : assert(icon != null || iconWidget != null, 'Either icon or iconWidget must be provided');
}
