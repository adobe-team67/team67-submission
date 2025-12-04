// import 'dart:math' as math;
// import 'dart:typed_data';

// import 'package:flutter/foundation.dart'; // for compute()
// import 'package:image/image.dart' as img;

// /// Auto aspect-ratio + gradient background service.
// ///
// /// Rules:
// /// - If the source image is LARGER than the target canvas in either dimension:
// ///     -> scale with "cover" and center-crop to target size (no borders).
// /// - If the source image fits entirely inside the target:
// ///     -> keep original size and center it,
// ///        and fill remaining space with gradients taken from the image edges.
// class AutoAspectRatioService {
//   /// Main function you call from your UI.
//   ///
//   /// Example:
//   /// ```dart
//   /// final outBytes = await AutoAspectRatioService.processToCanvas(
//   ///   bytes: originalBytes,
//   ///   targetWidth: 1920,
//   ///   targetHeight: 1080,
//   /// );
//   /// ```
//   static Future<Uint8List> processToCanvas({
//     required Uint8List bytes,
//     required int targetWidth,
//     required int targetHeight,
//     bool useIsolate = true,
//   }) async {
//     if (useIsolate) {
//       return compute<_ProcessArgs, Uint8List>(
//         _processEntry,
//         _ProcessArgs(bytes, targetWidth, targetHeight),
//       );
//     } else {
//       return _resizeOrExtendSync(bytes, targetWidth, targetHeight);
//     }
//   }
// }

// /// Arguments for the isolate.
// class _ProcessArgs {
//   final Uint8List bytes;
//   final int targetWidth;
//   final int targetHeight;

//   const _ProcessArgs(this.bytes, this.targetWidth, this.targetHeight);
// }

// /// Entry point for compute().
// Uint8List _processEntry(_ProcessArgs args) {
//   return _resizeOrExtendSync(args.bytes, args.targetWidth, args.targetHeight);
// }

// /// Core logic: crop-if-larger, otherwise gradient-extend.
// Uint8List _resizeOrExtendSync(
//   Uint8List inputBytes,
//   int targetWidth,
//   int targetHeight,
// ) {
//   // Decode
//   img.Image? src = img.decodeImage(inputBytes);
//   if (src == null) {
//     throw Exception('Failed to decode image');
//   }

//   int w = src.width;
//   int h = src.height;

//   // ---------- CASE 1: IMAGE LARGER THAN CANVAS → COVER + CROP ----------
//   if (w > targetWidth || h > targetHeight) {
//     final scale = math.max(targetWidth / w, targetHeight / h);

//     final newW = (w * scale).round();
//     final newH = (h * scale).round();

//     final resized = img.copyResize(
//       src,
//       width: newW,
//       height: newH,
//       interpolation: img.Interpolation.linear,
//     );

//     final xStart = ((newW - targetWidth) / 2).round();
//     final yStart = ((newH - targetHeight) / 2).round();

//     final cropped = img.copyCrop(
//       resized,
//       x: xStart,
//       y: yStart,
//       width: targetWidth,
//       height: targetHeight,
//     );

//     return Uint8List.fromList(img.encodePng(cropped));
//   }

//   // ---------- CASE 2: IMAGE FITS → GRADIENT EXTENSION ----------
//   // Create empty (black) canvas
//   final out = img.Image(width: targetWidth, height: targetHeight);
//   out.clear(); // fills with 0 (black & transparent)

//   final yOffset = ((targetHeight - h) ~/ 2);
//   final xOffset = ((targetWidth - w) ~/ 2);

//   int clamp255(num v) {
//     if (v < 0) return 0;
//     if (v > 255) return 255;
//     return v.toInt();
//   }

//   // Paste original image in center manually (no copyInto)
//   for (int y = 0; y < h; y++) {
//     for (int x = 0; x < w; x++) {
//       final p = src.getPixel(x, y);
//       out.setPixelRgba(xOffset + x, yOffset + y, p.r, p.g, p.b, p.a);
//     }
//   }

//   // ----- TOP GRADIENT -----
//   if (yOffset > 0) {
//     final topRowY = 0;
//     final topEndRowY = math.min(10, h - 1);

//     for (int yy = 0; yy < yOffset; yy++) {
//       final alpha = yOffset == 0 ? 0.0 : yy / yOffset;
//       for (int xx = 0; xx < w; xx++) {
//         final pStart = src.getPixel(xx, topRowY);
//         final pEnd = src.getPixel(xx, topEndRowY);

//         final r = clamp255((1 - alpha) * pStart.r + alpha * pEnd.r);
//         final g = clamp255((1 - alpha) * pStart.g + alpha * pEnd.g);
//         final b = clamp255((1 - alpha) * pStart.b + alpha * pEnd.b);
//         final a = clamp255((1 - alpha) * pStart.a + alpha * pEnd.a);

//         out.setPixelRgba(xOffset + xx, yy, r, g, b, a);
//       }
//     }
//   }

//   // ----- BOTTOM GRADIENT -----
//   final bottomPad = targetHeight - (yOffset + h);
//   if (bottomPad > 0) {
//     final bottomRowY = h - 1;
//     final bottomEndRowY = math.max(h - 11, 0);

//     for (int yy = 0; yy < bottomPad; yy++) {
//       final alpha = bottomPad == 0 ? 0.0 : yy / bottomPad;
//       for (int xx = 0; xx < w; xx++) {
//         final pStart = src.getPixel(xx, bottomRowY);
//         final pEnd = src.getPixel(xx, bottomEndRowY);

//         final r = clamp255((1 - alpha) * pStart.r + alpha * pEnd.r);
//         final g = clamp255((1 - alpha) * pStart.g + alpha * pEnd.g);
//         final b = clamp255((1 - alpha) * pStart.b + alpha * pEnd.b);
//         final a = clamp255((1 - alpha) * pStart.a + alpha * pEnd.a);

//         out.setPixelRgba(xOffset + xx, yOffset + h + yy, r, g, b, a);
//       }
//     }
//   }

//   // ----- LEFT GRADIENT -----
//   if (xOffset > 0) {
//     final leftColX = 0;
//     final leftEndColX = math.min(10, w - 1);

//     for (int xx = 0; xx < xOffset; xx++) {
//       final alpha = xOffset == 0 ? 0.0 : xx / xOffset;
//       for (int yy = 0; yy < h; yy++) {
//         final pStart = src.getPixel(leftColX, yy);
//         final pEnd = src.getPixel(leftEndColX, yy);

//         final r = clamp255((1 - alpha) * pStart.r + alpha * pEnd.r);
//         final g = clamp255((1 - alpha) * pStart.g + alpha * pEnd.g);
//         final b = clamp255((1 - alpha) * pStart.b + alpha * pEnd.b);
//         final a = clamp255((1 - alpha) * pStart.a + alpha * pEnd.a);

//         out.setPixelRgba(xx, yOffset + yy, r, g, b, a);
//       }
//     }
//   }

//   // ----- RIGHT GRADIENT -----
//   final rightPad = targetWidth - (xOffset + w);
//   if (rightPad > 0) {
//     final rightColX = w - 1;
//     final rightEndColX = math.max(w - 11, 0);

//     for (int xx = 0; xx < rightPad; xx++) {
//       final alpha = rightPad == 0 ? 0.0 : xx / rightPad;
//       for (int yy = 0; yy < h; yy++) {
//         final pStart = src.getPixel(rightColX, yy);
//         final pEnd = src.getPixel(rightEndColX, yy);

//         final r = clamp255((1 - alpha) * pStart.r + alpha * pEnd.r);
//         final g = clamp255((1 - alpha) * pStart.g + alpha * pEnd.g);
//         final b = clamp255((1 - alpha) * pStart.b + alpha * pEnd.b);
//         final a = clamp255((1 - alpha) * pStart.a + alpha * pEnd.a);

//         out.setPixelRgba(xOffset + w + xx, yOffset + yy, r, g, b, a);
//       }
//     }
//   }

//   return Uint8List.fromList(img.encodePng(out));
// }



import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Extends or crops an image to match the target aspect ratio with gradient backgrounds
/// 
/// [imageBytes] - The input image as Uint8List (may be a composited canvas image)
/// [targetWidth] - Desired output width (canvas width)
/// [targetHeight] - Desired output height (canvas height)
/// [originalWidth] - Optional: width of the original image before compositing
/// [originalHeight] - Optional: height of the original image before compositing
/// [blurRadius] - Blur intensity for extended areas (default: 5)
/// 
/// If originalWidth/originalHeight are provided, the function will extract the
/// centered original image from the canvas and use it for gradient generation.
/// 
/// Returns the processed image as Uint8List (PNG encoded)
Future<Uint8List> extendGradientBackground(
  Uint8List imageBytes,
  int targetWidth,
  int targetHeight, {
  int? originalWidth,
  int? originalHeight,
  int blurRadius = 0,
}) async {
  // Decode the input image
  img.Image? canvasImage = img.decodeImage(imageBytes);
  if (canvasImage == null) {
    throw Exception('Failed to decode image');
  }

  img.Image image;
  int xOffset;
  int yOffset;
  int w;
  int h;

  // If original dimensions are provided, extract the centered original image
  if (originalWidth != null && originalHeight != null) {
    // The original image is centered on the canvas
    // Calculate where the original image is located
    xOffset = (canvasImage.width - originalWidth) ~/ 2;
    yOffset = (canvasImage.height - originalHeight) ~/ 2;
    w = originalWidth;
    h = originalHeight;
    
    // Extract the original image from the canvas
    image = img.copyCrop(
      canvasImage,
      x: xOffset.clamp(0, canvasImage.width - 1),
      y: yOffset.clamp(0, canvasImage.height - 1),
      width: w.clamp(1, canvasImage.width - xOffset),
      height: h.clamp(1, canvasImage.height - yOffset),
    );
    
    // Update w and h to actual cropped dimensions
    w = image.width;
    h = image.height;
    
    // Recalculate offsets for the target canvas
    xOffset = (targetWidth - w) ~/ 2;
    yOffset = (targetHeight - h) ~/ 2;
  } else {
    // No original dimensions - use the input image as-is
    image = canvasImage;
    h = image.height;
    w = image.width;

    // Calculate scale factor
    double scale = (targetWidth / w).clamp(0.0, 1.0) < (targetHeight / h).clamp(0.0, 1.0)
        ? targetWidth / w
        : targetHeight / h;

    // Resize if the image is larger than target
    if (scale < 1) {
      int newW = (w * scale).round();
      int newH = (h * scale).round();
      image = img.copyResize(
        image,
        width: newW,
        height: newH,
        interpolation: img.Interpolation.average,
      );
      h = image.height;
      w = image.width;
    }

    // Calculate offsets for centering
    xOffset = (targetWidth - w) ~/ 2;
    yOffset = (targetHeight - h) ~/ 2;
  }

  // Create new canvas
  img.Image newImg = img.Image(width: targetWidth, height: targetHeight);

  // Helper function to get pixel color safely
  img.Pixel getPixelSafe(img.Image sourceImg, int x, int y) {
    x = x.clamp(0, sourceImg.width - 1);
    y = y.clamp(0, sourceImg.height - 1);
    return sourceImg.getPixel(x, y);
  }

  // Helper function to sample and blend colors from edge
  List<int> sampleEdgeColor(img.Image sourceImg, int x, int y, int sampleDepth) {
    x = x.clamp(0, sourceImg.width - 1);
    y = y.clamp(0, sourceImg.height - 1);
    
    img.Pixel start = sourceImg.getPixel(x, y);
    int endX = x;
    int endY = y;
    
    // Determine sampling direction based on position
    if (x == 0) endX = sampleDepth.clamp(0, sourceImg.width - 1);
    if (x == sourceImg.width - 1) endX = (sourceImg.width - 1 - sampleDepth).clamp(0, sourceImg.width - 1);
    if (y == 0) endY = sampleDepth.clamp(0, sourceImg.height - 1);
    if (y == sourceImg.height - 1) endY = (sourceImg.height - 1 - sampleDepth).clamp(0, sourceImg.height - 1);
    
    img.Pixel end = sourceImg.getPixel(endX, endY);
    
    return [
      ((start.r + end.r) / 2).round(),
      ((start.g + end.g) / 2).round(),
      ((start.b + end.b) / 2).round(),
    ];
  }

  // Fill the entire canvas with gradient colors
  for (int y = 0; y < targetHeight; y++) {
    for (int x = 0; x < targetWidth; x++) {
      // Check if this pixel is in the original image area
      if (x >= xOffset && x < xOffset + w && y >= yOffset && y < yOffset + h) {
        continue; // Will be filled with original image later
      }

      // Determine which region this pixel belongs to
      bool isLeft = x < xOffset;
      bool isRight = x >= xOffset + w;
      bool isTop = y < yOffset;
      bool isBottom = y >= yOffset + h;

      int r, g, b;

      if (isTop && isLeft) {
        // Top-left corner
        double distX = (xOffset - x) / (xOffset + 1.0);
        double distY = (yOffset - y) / (yOffset + 1.0);
        
        List<int> topColor = sampleEdgeColor(image, 0, 0, 10);
        List<int> leftColor = sampleEdgeColor(image, 0, 0, 10);
        
        r = ((topColor[0] + leftColor[0]) / 2).round();
        g = ((topColor[1] + leftColor[1]) / 2).round();
        b = ((topColor[2] + leftColor[2]) / 2).round();
        
      } else if (isTop && isRight) {
        // Top-right corner
        double distX = (x - (xOffset + w)) / (targetWidth - (xOffset + w) + 1.0);
        double distY = (yOffset - y) / (yOffset + 1.0);
        
        List<int> topColor = sampleEdgeColor(image, w - 1, 0, 10);
        List<int> rightColor = sampleEdgeColor(image, w - 1, 0, 10);
        
        r = ((topColor[0] + rightColor[0]) / 2).round();
        g = ((topColor[1] + rightColor[1]) / 2).round();
        b = ((topColor[2] + rightColor[2]) / 2).round();
        
      } else if (isBottom && isLeft) {
        // Bottom-left corner
        double distX = (xOffset - x) / (xOffset + 1.0);
        double distY = (y - (yOffset + h)) / (targetHeight - (yOffset + h) + 1.0);
        
        List<int> bottomColor = sampleEdgeColor(image, 0, h - 1, 10);
        List<int> leftColor = sampleEdgeColor(image, 0, h - 1, 10);
        
        r = ((bottomColor[0] + leftColor[0]) / 2).round();
        g = ((bottomColor[1] + leftColor[1]) / 2).round();
        b = ((bottomColor[2] + leftColor[2]) / 2).round();
        
      } else if (isBottom && isRight) {
        // Bottom-right corner
        double distX = (x - (xOffset + w)) / (targetWidth - (xOffset + w) + 1.0);
        double distY = (y - (yOffset + h)) / (targetHeight - (yOffset + h) + 1.0);
        
        List<int> bottomColor = sampleEdgeColor(image, w - 1, h - 1, 10);
        List<int> rightColor = sampleEdgeColor(image, w - 1, h - 1, 10);
        
        r = ((bottomColor[0] + rightColor[0]) / 2).round();
        g = ((bottomColor[1] + rightColor[1]) / 2).round();
        b = ((bottomColor[2] + rightColor[2]) / 2).round();
        
      } else if (isTop) {
        // Top edge
        int imgX = x - xOffset;
        double alpha = y / (yOffset + 1.0);
        
        img.Pixel start = getPixelSafe(image, imgX, 0);
        img.Pixel end = getPixelSafe(image, imgX, 10.clamp(0, h - 1));
        
        r = ((1 - alpha) * start.r + alpha * end.r).round();
        g = ((1 - alpha) * start.g + alpha * end.g).round();
        b = ((1 - alpha) * start.b + alpha * end.b).round();
        
      } else if (isBottom) {
        // Bottom edge
        int imgX = x - xOffset;
        double alpha = (y - (yOffset + h)) / (targetHeight - (yOffset + h) + 1.0);
        
        img.Pixel start = getPixelSafe(image, imgX, h - 1);
        img.Pixel end = getPixelSafe(image, imgX, (h - 11).clamp(0, h - 1));
        
        r = ((1 - alpha) * start.r + alpha * end.r).round();
        g = ((1 - alpha) * start.g + alpha * end.g).round();
        b = ((1 - alpha) * start.b + alpha * end.b).round();
        
      } else if (isLeft) {
        // Left edge
        int imgY = y - yOffset;
        double alpha = x / (xOffset + 1.0);
        
        img.Pixel start = getPixelSafe(image, 0, imgY);
        img.Pixel end = getPixelSafe(image, 10.clamp(0, w - 1), imgY);
        
        r = ((1 - alpha) * start.r + alpha * end.r).round();
        g = ((1 - alpha) * start.g + alpha * end.g).round();
        b = ((1 - alpha) * start.b + alpha * end.b).round();
        
      } else {
        // Right edge
        int imgY = y - yOffset;
        double alpha = (x - (xOffset + w)) / (targetWidth - (xOffset + w) + 1.0);
        
        img.Pixel start = getPixelSafe(image, w - 1, imgY);
        img.Pixel end = getPixelSafe(image, (w - 11).clamp(0, w - 1), imgY);
        
        r = ((1 - alpha) * start.r + alpha * end.r).round();
        g = ((1 - alpha) * start.g + alpha * end.g).round();
        b = ((1 - alpha) * start.b + alpha * end.b).round();
      }

      newImg.setPixelRgb(x, y, r, g, b);
    }
  }

  // Place the original image in the center (this will overwrite the center area)
  img.compositeImage(newImg, image, dstX: xOffset, dstY: yOffset);

  // Apply blur only to the extended areas
  if (blurRadius > 0) {
    // Create a mask for the extended areas
    img.Image mask = img.Image(width: targetWidth, height: targetHeight);
    img.fill(mask, color: img.ColorRgb8(0, 0, 0));
    
    // Mark extended areas as white in the mask
    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        if (x < xOffset || x >= xOffset + w || y < yOffset || y >= yOffset + h) {
          mask.setPixelRgb(x, y, 255, 255, 255);
        }
      }
    }

    // Apply Gaussian blur to the entire image
    img.Image blurred = img.gaussianBlur(newImg, radius: blurRadius);

    // Blend blurred and original based on mask
    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        img.Pixel maskPixel = mask.getPixel(x, y);
        
        if (maskPixel.r > 0) {
          // Extended area - use blurred version
          img.Pixel blurredPixel = blurred.getPixel(x, y);
          newImg.setPixelRgb(x, y, blurredPixel.r.toInt(), blurredPixel.g.toInt(), blurredPixel.b.toInt());
        }
      }
    }
  }

  // Encode to PNG and return
  return Uint8List.fromList(img.encodePng(newImg));
}

/// Extracts the original image from a canvas composite and fills the canvas borders.
/// 
/// This function is used when an image has been composited onto a canvas (centered).
/// It extracts the original image region from the center and uses it to generate
/// gradient backgrounds for the canvas borders.
/// 
/// [imageBytes] - The full canvas image bytes (with original image centered)
/// [canvasWidth] - The width of the canvas
/// [canvasHeight] - The height of the canvas  
/// [originalWidth] - The width of the original image as placed on canvas (after scaling)
/// [originalHeight] - The height of the original image as placed on canvas (after scaling)
/// [blurRadius] - Blur intensity for gradient areas (default: 5)
Future<Uint8List> extractAndFillCanvasBackground(
  Uint8List imageBytes,
  int canvasWidth,
  int canvasHeight,
  int originalWidth,
  int originalHeight, {
  int blurRadius = 5,
}) async {
  return compute(_extractAndFillSync, _ExtractAndFillArgs(
    imageBytes: imageBytes,
    canvasWidth: canvasWidth,
    canvasHeight: canvasHeight,
    originalWidth: originalWidth,
    originalHeight: originalHeight,
    blurRadius: blurRadius,
  ));
}

class _ExtractAndFillArgs {
  final Uint8List imageBytes;
  final int canvasWidth;
  final int canvasHeight;
  final int originalWidth;
  final int originalHeight;
  final int blurRadius;

  _ExtractAndFillArgs({
    required this.imageBytes,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.originalWidth,
    required this.originalHeight,
    required this.blurRadius,
  });
}

Uint8List _extractAndFillSync(_ExtractAndFillArgs args) {
  // Decode the full canvas image
  img.Image? fullCanvas = img.decodeImage(args.imageBytes);
  if (fullCanvas == null) {
    throw Exception('Failed to decode canvas image');
  }

  // Calculate the offset where original image is placed (centered)
  int xOffset = (args.canvasWidth - args.originalWidth) ~/ 2;
  int yOffset = (args.canvasHeight - args.originalHeight) ~/ 2;

  // Crop the original image from the center of the canvas
  img.Image originalImage = img.copyCrop(
    fullCanvas,
    x: xOffset,
    y: yOffset,
    width: args.originalWidth,
    height: args.originalHeight,
  );

  // Create new image with canvas size
  img.Image newImg = img.Image(width: args.canvasWidth, height: args.canvasHeight);

  final w = args.originalWidth;
  final h = args.originalHeight;
  final targetWidth = args.canvasWidth;
  final targetHeight = args.canvasHeight;

  // Fill extended areas using mirror reflection of the original image
  for (int y = 0; y < targetHeight; y++) {
    for (int x = 0; x < targetWidth; x++) {
      int srcX, srcY;
      
      // Calculate mirrored source coordinates
      if (x < xOffset) {
        // Left extension - mirror from left edge
        srcX = xOffset - x - 1;
        srcX = srcX.clamp(0, w - 1);
      } else if (x >= xOffset + w) {
        // Right extension - mirror from right edge
        srcX = w - 1 - (x - xOffset - w);
        srcX = srcX.clamp(0, w - 1);
      } else {
        // Inside original image width
        srcX = x - xOffset;
      }
      
      if (y < yOffset) {
        // Top extension - mirror from top edge
        srcY = yOffset - y - 1;
        srcY = srcY.clamp(0, h - 1);
      } else if (y >= yOffset + h) {
        // Bottom extension - mirror from bottom edge
        srcY = h - 1 - (y - yOffset - h);
        srcY = srcY.clamp(0, h - 1);
      } else {
        // Inside original image height
        srcY = y - yOffset;
      }
      
      // Get pixel from original image
      img.Pixel srcPixel = originalImage.getPixel(srcX, srcY);
      newImg.setPixelRgba(x, y, srcPixel.r.toInt(), srcPixel.g.toInt(), srcPixel.b.toInt(), srcPixel.a.toInt());
    }
  }

  // Place the original image in the center (to ensure it's crisp and not affected)
  img.compositeImage(newImg, originalImage, dstX: xOffset, dstY: yOffset);

  // Apply subtle blur only to extended areas for smoother blending
  if (args.blurRadius > 0) {
    // Create a blurred version of the entire image
    img.Image blurred = img.gaussianBlur(newImg, radius: args.blurRadius);
    
    // Apply blurred version only to extended areas, with feathering at edges
    int featherSize = 10; // Pixels to blend at the boundary
    
    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        // Skip if inside the original image area (with some margin)
        bool isInOriginal = x >= xOffset && x < xOffset + w && y >= yOffset && y < yOffset + h;
        
        if (!isInOriginal) {
          // Calculate distance to original image boundary
          int distToOriginal = 0;
          if (x < xOffset) distToOriginal = xOffset - x;
          else if (x >= xOffset + w) distToOriginal = x - xOffset - w + 1;
          
          int distY = 0;
          if (y < yOffset) distY = yOffset - y;
          else if (y >= yOffset + h) distY = y - yOffset - h + 1;
          
          distToOriginal = distToOriginal > distY ? distToOriginal : distY;
          
          // Only apply blur after some distance from the edge for smoother transition
          if (distToOriginal > featherSize) {
            img.Pixel blurredPixel = blurred.getPixel(x, y);
            newImg.setPixelRgba(x, y, blurredPixel.r.toInt(), blurredPixel.g.toInt(), blurredPixel.b.toInt(), blurredPixel.a.toInt());
          } else if (distToOriginal > 0) {
            // Blend between original mirrored and blurred based on distance
            double blendFactor = distToOriginal / featherSize.toDouble();
            img.Pixel origPixel = newImg.getPixel(x, y);
            img.Pixel blurredPixel = blurred.getPixel(x, y);
            
            int r = ((1 - blendFactor) * origPixel.r + blendFactor * blurredPixel.r).toInt();
            int g = ((1 - blendFactor) * origPixel.g + blendFactor * blurredPixel.g).toInt();
            int b = ((1 - blendFactor) * origPixel.b + blendFactor * blurredPixel.b).toInt();
            
            newImg.setPixelRgb(x, y, r, g, b);
          }
        }
      }
    }
    
    // Re-place the original image to ensure it stays crisp
    img.compositeImage(newImg, originalImage, dstX: xOffset, dstY: yOffset);
  }

  return Uint8List.fromList(img.encodePng(newImg));
}

// Example usage:
// 
// import 'dart:io';
// 
// void main() async {
//   // Read image file
//   File imageFile = File('input.png');
//   Uint8List imageBytes = await imageFile.readAsBytes();
//   
//   // Process image with custom blur
//   Uint8List result = await extendGradientBackground(
//     imageBytes,
//     1920,  // target width
//     1080,  // target height
//     blurRadius: 5,  // Optional: adjust blur intensity (default: 5)
//   );
//   
//   // Save result
//   File outputFile = File('output.png');
//   await outputFile.writeAsBytes(result);
// }