// workers/mask_worker.dart
// Rasterize a polygon (list of points) to a binary mask image and return PNG bytes.
// This runs inside compute/isolate.
import 'dart:typed_data';
import 'package:image/image.dart' as img;

Uint8List rasterizePolygon(Map<String, dynamic> payload) {
  // payload expects: points: List<List<double>>, width, height, outSize
  final pts = (payload['points'] as List).map<List<int>>((p) {
    final dx = (p[0] as num).toDouble();
    final dy = (p[1] as num).toDouble();
    return [dx.toInt(), dy.toInt()];
  }).toList();
  final outSize = payload['outSize'] as int? ?? 256;
  final mask = img.Image(width: outSize, height: outSize);
  // Simple scaling from source coords to outSize if width/height passed
  final sw = (payload['width'] as num?)?.toDouble() ?? outSize.toDouble();
  final sh = (payload['height'] as num?)?.toDouble() ?? outSize.toDouble();

  for (var y = 0; y < outSize; y++) {
    for (var x = 0; x < outSize; x++) {
      // map to source coords
      final sx = x * sw / outSize;
      final sy = y * sh / outSize;
      // point-in-polygon test
      if (_pointInPolygon(sx, sy, pts)) {
        mask.setPixelRgba(x, y, 255, 255, 255, 200);
      }
    }
  }

  final png = img.encodePng(mask);
  return Uint8List.fromList(png);
}

bool _pointInPolygon(double x, double y, List<List<int>> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final xi = poly[i][0].toDouble(), yi = poly[i][1].toDouble();
    final xj = poly[j][0].toDouble(), yj = poly[j][1].toDouble();

    final intersect = ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi + 0.0000001) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}
