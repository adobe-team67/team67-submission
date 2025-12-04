// services/ai_api_mock.dart
// Mock AiApi implementation that simulates latency and returns demo masks/images.
import 'dart:async';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../services/ai_api.dart';

class AiApiMock implements AiApi {
  AiApiMock();

  @override
  Future<Uint8List> segment(Uint8List imageBytes) async {
    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 800));
    // Generate a simple circular mask as 256x256 PNG
  final mask = img.Image(width: 256, height: 256);
    final cx = 128, cy = 128, r = 80;
    for (var y = 0; y < 256; y++) {
      for (var x = 0; x < 256; x++) {
        final dx = x - cx;
        final dy = y - cy;
        if (dx * dx + dy * dy <= r * r) {
          mask.setPixelRgba(x, y, 255, 255, 255, 180);
        }
      }
    }
    final png = img.encodePng(mask);
    return Uint8List.fromList(png);
  }

  @override
  Future<Uint8List> inpaint(Uint8List imageBytes, Uint8List maskBytes) async {
    // Simulate longer latency
    await Future.delayed(const Duration(milliseconds: 1800));
    // Simple mock: blur the original image using `image` package, ignoring mask for simplicity
    final original = img.decodeImage(imageBytes);
    if (original == null) return imageBytes;
    final out = img.copyResize(original, width: original.width, height: original.height);
  img.gaussianBlur(out, radius: 8);
    final jpg = img.encodeJpg(out, quality: 85);
    return Uint8List.fromList(jpg);
  }
}
