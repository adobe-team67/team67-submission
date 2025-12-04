// features/editor/controllers/selection_controller.dart
// Controls a lasso-style selection and rasterizes it using compute() via mask_worker.
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../../../models/mask.dart';
import '../../../workers/mask_worker.dart';

class SelectionController {
  final List<Offset> points = [];

  void startLasso() => points.clear();
  void addPoint(Offset p) => points.add(p);

  Future<Uint8List> finishLasso(Size size, {int outSize = 256}) async {
    final poly = points.map((p) => [p.dx, p.dy]).toList();
    // call compute to rasterize
    final res = await compute(rasterizePolygon, {'points': poly, 'width': size.width, 'height': size.height, 'outSize': outSize});
    return res as Uint8List;
  }
}
