// models/detected_object.dart
// Model for storing detected objects with their masks and metadata

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// COCO dataset class names for YOLO
const List<String> cocoClassNames = [
  'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck',
  'boat', 'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench',
  'bird', 'cat', 'dog', 'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra',
  'giraffe', 'backpack', 'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee',
  'skis', 'snowboard', 'sports ball', 'kite', 'baseball bat', 'baseball glove',
  'skateboard', 'surfboard', 'tennis racket', 'bottle', 'wine glass', 'cup',
  'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple', 'sandwich', 'orange',
  'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 'chair', 'couch',
  'potted plant', 'bed', 'dining table', 'toilet', 'tv', 'laptop', 'mouse',
  'remote', 'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink',
  'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear', 'hair drier',
  'toothbrush'
];

/// Represents a detected object from YOLO segmentation
class DetectedObject {
  /// Unique identifier for this detection
  final int index;
  
  /// The binary mask for this object (2D array: height x width)
  final List<List<int>> mask;
  
  /// Bounding box [x, y, width, height, confidence, classId]
  final List<double> box;
  
  /// COCO class ID (0-79)
  final int classId;
  
  /// Detection confidence (0.0 - 1.0)
  final double confidence;
  
  /// Cached preview image bytes (PNG with transparency)
  Uint8List? _previewBytes;
  
  DetectedObject({
    required this.index,
    required this.mask,
    required this.box,
    required this.classId,
    required this.confidence,
  });
  
  /// Get the human-readable class name
  String get className {
    if (classId >= 0 && classId < cocoClassNames.length) {
      return cocoClassNames[classId];
    }
    return 'Object $classId';
  }
  
  /// Get formatted confidence as percentage
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(0)}%';
  
  /// Get the bounding box center in normalized coordinates
  Offset get center => Offset(box[0], box[1]);
  
  /// Get the bounding box size in normalized coordinates
  Size get size => Size(box[2], box[3]);
  
  /// Generate a preview image of the object cutout with transparent/checkered background
  Future<Uint8List> generatePreview(Uint8List sourceImageBytes, {int maxSize = 80}) async {
    if (_previewBytes != null) return _previewBytes!;
    
    // Decode source image
    final sourceImage = img.decodeImage(sourceImageBytes);
    if (sourceImage == null) {
      throw Exception('Failed to decode source image');
    }
    
    final maskHeight = mask.length;
    final maskWidth = mask.isNotEmpty ? mask[0].length : 0;
    
    if (maskWidth == 0 || maskHeight == 0) {
      throw Exception('Invalid mask dimensions');
    }
    
    // Find bounding box of the mask
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
    
    // Add padding
    final padding = 4;
    minX = (minX - padding).clamp(0, maskWidth - 1);
    minY = (minY - padding).clamp(0, maskHeight - 1);
    maxX = (maxX + padding).clamp(0, maskWidth - 1);
    maxY = (maxY + padding).clamp(0, maskHeight - 1);
    
    final cropWidth = maxX - minX + 1;
    final cropHeight = maxY - minY + 1;
    
    // Scale to fit maxSize while maintaining aspect ratio
    double scale = 1.0;
    if (cropWidth > maxSize || cropHeight > maxSize) {
      scale = maxSize / (cropWidth > cropHeight ? cropWidth : cropHeight);
    }
    final outputWidth = (cropWidth * scale).round().clamp(1, maxSize);
    final outputHeight = (cropHeight * scale).round().clamp(1, maxSize);
    
    // Create output image with transparency
    final output = img.Image(width: outputWidth, height: outputHeight, numChannels: 4);
    
    // Fill with checkered pattern (transparency indicator)
    final checkerSize = 8;
    final lightGray = img.ColorRgba8(60, 60, 60, 255);
    final darkGray = img.ColorRgba8(40, 40, 40, 255);
    
    for (int y = 0; y < outputHeight; y++) {
      for (int x = 0; x < outputWidth; x++) {
        final isLight = ((x ~/ checkerSize) + (y ~/ checkerSize)) % 2 == 0;
        output.setPixel(x, y, isLight ? lightGray : darkGray);
      }
    }
    
    // Map source image onto output with mask
    for (int y = 0; y < outputHeight; y++) {
      for (int x = 0; x < outputWidth; x++) {
        // Map back to mask coordinates
        final maskX = minX + (x / scale).round();
        final maskY = minY + (y / scale).round();
        
        if (maskX >= 0 && maskX < maskWidth && maskY >= 0 && maskY < maskHeight) {
          if (mask[maskY][maskX] == 1) {
            // Map to source image coordinates
            final srcX = (maskX * sourceImage.width / maskWidth).round().clamp(0, sourceImage.width - 1);
            final srcY = (maskY * sourceImage.height / maskHeight).round().clamp(0, sourceImage.height - 1);
            
            final pixel = sourceImage.getPixel(srcX, srcY);
            output.setPixelRgba(x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), 255);
          }
        }
      }
    }
    
    _previewBytes = Uint8List.fromList(img.encodePng(output));
    return _previewBytes!;
  }
  
  @override
  String toString() => 'DetectedObject($className, ${confidencePercent})';
}
