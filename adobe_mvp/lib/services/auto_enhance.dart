import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Auto-enhance an image (non-ML, fully algorithmic).
///
/// - [inputBytes]: encoded image bytes (JPEG/PNG/etc.)
/// - Returns: enhanced image bytes (JPEG)
///
/// Usage:
///   final enhanced = autoEnhanceImage(originalBytes);
Uint8List autoEnhanceImage(Uint8List inputBytes) {
  // 1. Decode image
  final decoded = img.decodeImage(inputBytes);
  if (decoded == null) {
    throw Exception('Unsupported or corrupted image data');
  }

  // Make a mutable copy in the current image format
  final image = img.Image.from(decoded);

  // 2. Auto white balance (gray-world)
  _applyGrayWorldWhiteBalance(image);

  // 3. Auto exposure + gamma
  _autoExposureAndGamma(image);

  // 4. Sharpen (unsharp mask)
  _unsharpMask(image, amount: 0.6, radius: 1);

  // 5. Encode result as JPEG (change to encodePng if you prefer)
  final outputJpg = img.encodeJpg(image, quality: 90);
  return Uint8List.fromList(outputJpg);
}

/// Apply Gray-World white balance (in-place).
void _applyGrayWorldWhiteBalance(img.Image image) {
  double sumR = 0;
  double sumG = 0;
  double sumB = 0;
  int numPixels = 0;

  // First pass: compute average R, G, B
  for (final p in image) {
    sumR += p.r;
    sumG += p.g;
    sumB += p.b;
    numPixels++;
  }

  if (numPixels == 0) return;

  final avgR = sumR / numPixels;
  final avgG = sumG / numPixels;
  final avgB = sumB / numPixels;
  final gray = (avgR + avgG + avgB) / 3.0;

  // Gains to push each channel’s mean towards gray
  double gainR = gray / (avgR + 1e-6);
  double gainG = gray / (avgG + 1e-6);
  double gainB = gray / (avgB + 1e-6);

  // Clamp gains to avoid crazy corrections
  gainR = gainR.clamp(0.5, 2.0);
  gainG = gainG.clamp(0.5, 2.0);
  gainB = gainB.clamp(0.5, 2.0);

  // Second pass: apply gains
  for (final p in image) {
    p
      ..r = (p.r * gainR).clamp(0.0, 255.0).round()
      ..g = (p.g * gainG).clamp(0.0, 255.0).round()
      ..b = (p.b * gainB).clamp(0.0, 255.0).round();
  }
}

/// Auto exposure (brightness) and gamma based on luminance statistics.
void _autoExposureAndGamma(img.Image image) {
  double sumY = 0.0;
  double sumY2 = 0.0;
  int numPixels = 0;

  // Compute luminance stats
  for (final p in image) {
    final r = p.r.toDouble();
    final g = p.g.toDouble();
    final b = p.b.toDouble();

    // sRGB luminance approximation
    final yVal = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    sumY += yVal;
    sumY2 += yVal * yVal;
    numPixels++;
  }

  if (numPixels == 0) return;

  final meanY = sumY / numPixels;
  final varY = (sumY2 / numPixels) - meanY * meanY;
  final stdY = math.sqrt(math.max(varY, 0.0));

  final meanYNorm = meanY / 255.0;
  final stdYNorm = stdY / 255.0;

  // Target average brightness (0..1)
  const targetMean = 0.5;
  double exposureGain = targetMean / (meanYNorm + 1e-6);
  exposureGain = exposureGain.clamp(0.5, 1.8);

  // Decide gamma based on contrast
  double gamma;
  if (stdYNorm < 0.07) {
    // Very flat image → boost midtones
    gamma = 0.85;
  } else if (stdYNorm > 0.20) {
    // Already quite contrasty
    gamma = 1.05;
  } else {
    gamma = 1.0;
  }

  // Apply exposure + gamma
  for (final p in image) {
    double r = p.r.toDouble();
    double g = p.g.toDouble();
    double b = p.b.toDouble();

    // Exposure (linear gain)
    r = (r * exposureGain).clamp(0.0, 255.0);
    g = (g * exposureGain).clamp(0.0, 255.0);
    b = (b * exposureGain).clamp(0.0, 255.0);

    // Gamma on [0,1]
    r = math.pow(r / 255.0, gamma) * 255.0;
    g = math.pow(g / 255.0, gamma) * 255.0;
    b = math.pow(b / 255.0, gamma) * 255.0;

    p
      ..r = r.clamp(0.0, 255.0).round()
      ..g = g.clamp(0.0, 255.0).round()
      ..b = b.clamp(0.0, 255.0).round();
  }
}

/// Simple unsharp mask using gaussianBlur from `image` 4.x
void _unsharpMask(
  img.Image image, {
  double amount = 0.6, // sharpening strength
  int radius = 1,      // blur radius for mask
}) {
  if (amount <= 0 || radius <= 0) return;

  final width = image.width;
  final height = image.height;

  // Create a blurred copy
  final blurred = img.gaussianBlur(img.Image.from(image), radius: radius);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final origPix = image.getPixel(x, y);
      final blurPix = blurred.getPixel(x, y);

      double or = origPix.r.toDouble();
      double og = origPix.g.toDouble();
      double ob = origPix.b.toDouble();

      final br = blurPix.r.toDouble();
      final bg = blurPix.g.toDouble();
      final bb = blurPix.b.toDouble();

      // Unsharp mask: orig + amount * (orig - blur)
      double nr = or + amount * (or - br);
      double ng = og + amount * (og - bg);
      double nb = ob + amount * (ob - bb);

      nr = nr.clamp(0.0, 255.0);
      ng = ng.clamp(0.0, 255.0);
      nb = nb.clamp(0.0, 255.0);

      image.setPixelRgba(x, y, nr.round(), ng.round(), nb.round(), origPix.a);
    }
  }
}
