// models/selection.dart
// Unified selection model for managing multiple selected objects

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Source of selection (how the object was selected)
enum SelectionSource {
  tap,
  lasso,
  brush,
  objectList,
}

/// Represents a single selected object with its mask and cutout data
class Selection {
  /// Unique identifier for this selection
  final String id;
  
  /// The binary mask for this selection (2D array: height x width)
  final List<List<int>> mask;
  
  /// How this selection was created
  final SelectionSource source;
  
  /// Optional class name (from YOLO detection)
  final String? className;
  
  /// Optional confidence score (from YOLO detection)
  final double? confidence;
  
  /// Cached cutout image bytes (PNG with transparency)
  Uint8List? _cutoutBytes;
  
  /// Current offset from original position (for drag/move)
  Offset offset;
  
  /// Bounding box in mask coordinates [minX, minY, maxX, maxY]
  late final List<int> boundingBox;
  
  /// Size of the cutout
  late final Size cutoutSize;
  
  /// Original position of the cutout center in image space
  late final Offset originalCenter;
  
  Selection({
    required this.id,
    required this.mask,
    required this.source,
    this.className,
    this.confidence,
    this.offset = Offset.zero,
  }) {
    _computeBoundingBox();
  }
  
  /// Compute bounding box of the mask
  void _computeBoundingBox() {
    final maskHeight = mask.length;
    final maskWidth = mask.isNotEmpty ? mask[0].length : 0;
    
    int minX = maskWidth, minY = maskHeight, maxX = 0, maxY = 0;
    
    for (int y = 0; y < maskHeight; y++) {
      for (int x = 0; x < maskWidth; x++) {
        if (mask[y][x] == 1) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    
    // Handle empty mask
    if (minX > maxX || minY > maxY) {
      boundingBox = [0, 0, 0, 0];
      cutoutSize = Size.zero;
      originalCenter = Offset.zero;
      return;
    }
    
    boundingBox = [minX, minY, maxX, maxY];
    cutoutSize = Size(
      (maxX - minX + 1).toDouble(),
      (maxY - minY + 1).toDouble(),
    );
    originalCenter = Offset(
      (minX + maxX) / 2.0,
      (minY + maxY) / 2.0,
    );
  }
  
  /// Get current center position (original + offset)
  Offset get currentCenter => originalCenter + offset;
  
  /// Get top-left position for rendering
  Offset get renderPosition => Offset(
    boundingBox[0].toDouble() + offset.dx,
    boundingBox[1].toDouble() + offset.dy,
  );
  
  /// Check if this selection has valid cutout data
  bool get hasCutout => _cutoutBytes != null;
  
  /// Get cached cutout bytes
  Uint8List? get cutoutBytes => _cutoutBytes;
  
  /// Generate cutout image from source image
  Future<Uint8List> generateCutout(Uint8List sourceImageBytes) async {
    if (_cutoutBytes != null) return _cutoutBytes!;
    
    final sourceImage = img.decodeImage(sourceImageBytes);
    if (sourceImage == null) {
      throw Exception('Failed to decode source image');
    }
    
    final maskHeight = mask.length;
    final maskWidth = mask.isNotEmpty ? mask[0].length : 0;
    
    if (maskWidth == 0 || maskHeight == 0) {
      throw Exception('Invalid mask dimensions');
    }
    
    final minX = boundingBox[0];
    final minY = boundingBox[1];
    final maxX = boundingBox[2];
    final maxY = boundingBox[3];
    
    final cropWidth = maxX - minX + 1;
    final cropHeight = maxY - minY + 1;
    
    // Create output image with transparency
    final output = img.Image(
      width: cropWidth,
      height: cropHeight,
      numChannels: 4,
    );
    
    // Fill with transparent
    for (int y = 0; y < cropHeight; y++) {
      for (int x = 0; x < cropWidth; x++) {
        output.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
    
    // Copy pixels from source where mask is 1
    for (int y = 0; y < cropHeight; y++) {
      for (int x = 0; x < cropWidth; x++) {
        final maskX = minX + x;
        final maskY = minY + y;
        
        if (maskX >= 0 && maskX < maskWidth && maskY >= 0 && maskY < maskHeight) {
          if (mask[maskY][maskX] == 1) {
            // Map mask coords to source image coords
            final srcX = (maskX * sourceImage.width / maskWidth).round().clamp(0, sourceImage.width - 1);
            final srcY = (maskY * sourceImage.height / maskHeight).round().clamp(0, sourceImage.height - 1);
            
            final pixel = sourceImage.getPixel(srcX, srcY);
            output.setPixelRgba(x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), 255);
          }
        }
      }
    }
    
    _cutoutBytes = Uint8List.fromList(img.encodePng(output));
    return _cutoutBytes!;
  }
  
  /// Create a copy with updated offset
  Selection copyWith({Offset? offset}) {
    final copy = Selection(
      id: id,
      mask: mask,
      source: source,
      className: className,
      confidence: confidence,
      offset: offset ?? this.offset,
    );
    copy._cutoutBytes = _cutoutBytes;
    return copy;
  }
  
  @override
  String toString() => 'Selection($id, $source, ${className ?? "unknown"})';
}
