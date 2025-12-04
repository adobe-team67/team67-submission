// models/mask.dart
// Simple polygon mask representation and utilities.
import 'dart:ui';
import 'dart:typed_data';

class PolygonMask {
  final List<Offset> points;
  PolygonMask(this.points);

  // Convert to a simple byte rasterization is done in workers/mask_worker.dart
}
