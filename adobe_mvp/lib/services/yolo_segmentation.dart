// features/models/yolo_segmentation.dart
// Flutter wrapper for YOLO11 segmentation model
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Result of YOLO segmentation containing detected objects and their masks
class YoloSegmentationResult {
  /// List of detected object masks
  /// Each mask is a 2D list where 1 indicates object pixel, 0 indicates background
  final List<List<List<int>>> masks;

  /// Bounding boxes for each detected object [x, y, width, height, confidence, class]
  final List<List<double>> boxes;

  /// Class IDs for each detected object
  final List<int> classIds;

  /// Confidence scores for each detection
  final List<double> confidences;

  YoloSegmentationResult({
    required this.masks,
    required this.boxes,
    required this.classIds,
    required this.confidences,
  });

  /// Returns the number of detected objects
  int get detectionCount => masks.length;

  /// Returns true if any objects were detected
  bool get hasDetections => masks.isNotEmpty;
}

/// YOLO Segmentation Model Wrapper
///
/// Usage:
/// ```dart
/// final yolo = YoloSegmentation();
/// await yolo.initialize();
///
/// // From ui.Image
/// final result = await yolo.detectFromUIImage(image);
///
/// // From Uint8List
/// final result = await yolo.detectFromBytes(imageBytes);
///
/// // Access results
/// for (int i = 0; i < result.detectionCount; i++) {
///   final mask = result.masks[i];
///   final confidence = result.confidences[i];
///   print('Object $i: confidence ${confidence.toStringAsFixed(2)}');
/// }
///
/// yolo.dispose();
/// ```
class YoloSegmentation {
  static const String _modelPath = 'lib/ai-models/yolo11n-seg_float32.tflite';
  static const int _inputSize = 640; // YOLO11 default input size
  static const double _confidenceThreshold = 0.25;
  static const double _iouThreshold = 0.45;

  late Interpreter _interpreter;
  bool _isInitialized = false;

  /// Initialize the YOLO model
  /// Must be called before running any detection
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load the model with options
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(_modelPath, options: options);
      _interpreter.allocateTensors();

      _isInitialized = true;
    } catch (e) {
      rethrow;
    }
  }

  /// Detect objects from ui.Image
  Future<YoloSegmentationResult> detectFromUIImage(ui.Image image) async {
    if (!_isInitialized) {
      throw Exception('Model not initialized. Call initialize() first.');
    }

    // Convert ui.Image to bytes
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      throw Exception('Failed to convert image to bytes');
    }

    final Uint8List imageBytes = byteData.buffer.asUint8List();
    return detectFromBytes(imageBytes);
  }

  /// Detect objects from image bytes (PNG/JPEG)
  Future<YoloSegmentationResult> detectFromBytes(Uint8List imageBytes) async {
    if (!_isInitialized) {
      throw Exception('Model not initialized. Call initialize() first.');
    }

    try {
      // Decode image
      final img.Image? decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }

      // Preprocess image
      final input = _preprocessImage(decodedImage);

      // Run inference
      final outputs = _runInference(input);

      // Post-process outputs
      final result = _postProcessOutputs(
        outputs,
        decodedImage.width,
        decodedImage.height,
      );

      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Preprocess image for YOLO model
  /// Resize to 640x640 and normalize to [0, 1]
  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    // Resize image to model input size
    final resized = img.copyResize(
      image,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    // Create input tensor [1, 640, 640, 3]
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(
          _inputSize,
          (x) {
            final pixel = resized.getPixel(x, y);
            // Normalize to [0, 1] and convert to RGB
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );

    return input;
  }

  /// Run inference on preprocessed image
  Map<String, dynamic> _runInference(List<List<List<List<double>>>> input) {
    // YOLO11-seg outputs:
// output0: [1, 116, 8400] - detections
// output1: [1, 160, 160, 32] - mask prototypes (H, W, C)

    var output0 = List.generate(
      1,
      (_) => List.generate(
        116,
        (_) => List.filled(8400, 0.0),
      ),
    );

    var output1 = List.generate(
      1,
      (_) => List.generate(
        160, // height
        (_) => List.generate(
          160, // width
          (_) => List.filled(32, 0.0), // channels
        ),
      ),
    );

    _interpreter.runForMultipleInputs([
      input
    ], {
      0: output0,
      1: output1,
    });

    return {
      'detections': output0,
      'proto_masks': output1,
    };
  }

  /// Post-process model outputs to extract masks and boxes
  YoloSegmentationResult _postProcessOutputs(
    Map<String, dynamic> outputs,
    int originalWidth,
    int originalHeight,
  ) {
    final detections = outputs['detections'] as List;
    final protoMasks = outputs['proto_masks'] as List;

    final masks = <List<List<int>>>[];
    final boxes = <List<double>>[];
    final classIds = <int>[];
    final confidences = <double>[];

    // Parse detections [1, 116, 8400]
    // Format: [x, y, w, h, class0_conf, ..., class79_conf, mask_coeff0, ..., mask_coeff31]
    for (int i = 0; i < 8400; i++) {
      double maxConf = 0;
      int maxClassId = -1;

      // Find class with highest confidence (indices 4-83)
      for (int c = 0; c < 80; c++) {
        final conf = detections[0][4 + c][i] as double;
        if (conf > maxConf) {
          maxConf = conf;
          maxClassId = c;
        }
      }

      if (maxConf < _confidenceThreshold) continue;

      final x = detections[0][0][i] as double;
      final y = detections[0][1][i] as double;
      final w = detections[0][2][i] as double;
      final h = detections[0][3][i] as double;

      // Extract mask coefficients (indices 84-115)
      final maskCoeffs = List.generate(
        32,
        (j) => detections[0][84 + j][i] as double,
      );

      // Generate mask from prototypes and coefficients
      final mask = _generateMask(
        protoMasks,
        maskCoeffs,
        originalWidth,
        originalHeight,
      );

      masks.add(mask);
      boxes.add([x, y, w, h, maxConf, maxClassId.toDouble()]);
      classIds.add(maxClassId);
      confidences.add(maxConf);
    }

    // Apply NMS to remove duplicate detections
    final nmsIndices = _nonMaxSuppression(boxes, confidences);

    return YoloSegmentationResult(
      masks: nmsIndices.map((i) => masks[i]).toList(),
      boxes: nmsIndices.map((i) => boxes[i]).toList(),
      classIds: nmsIndices.map((i) => classIds[i]).toList(),
      confidences: nmsIndices.map((i) => confidences[i]).toList(),
    );
  }

  /// Generate mask from proto masks and coefficients
  List<List<int>> _generateMask(
    List protoMasks,
    List<double> coeffs,
    int width,
    int height,
  ) {
    // protoMasks shape: [1, 160, 160, 32]
    final maskProto = List.generate(
      160,
      (y) => List.generate(
        160,
        (x) {
          double sum = 0;
          for (int i = 0; i < 32; i++) {
            // [batch][y][x][channel]
            sum += coeffs[i] * (protoMasks[0][y][x][i] as double);
          }
          return _sigmoid(sum) > 0.5 ? 1 : 0;
        },
      ),
    );

    // Resize mask from 160x160 to original image size
    return _resizeMask(maskProto, width, height);
  }

  /// Resize mask to target dimensions using nearest neighbor
  List<List<int>> _resizeMask(
      List<List<int>> mask, int newWidth, int newHeight) {
    final oldHeight = mask.length;
    final oldWidth = mask[0].length;

    return List.generate(
      newHeight,
      (y) => List.generate(
        newWidth,
        (x) {
          final srcY = (y * oldHeight / newHeight).floor();
          final srcX = (x * oldWidth / newWidth).floor();
          return mask[srcY.clamp(0, oldHeight - 1)]
              [srcX.clamp(0, oldWidth - 1)];
        },
      ),
    );
  }

  /// Apply Non-Maximum Suppression to remove duplicate detections
  List<int> _nonMaxSuppression(List<List<double>> boxes, List<double> scores) {
    final indices = List.generate(scores.length, (i) => i);
    indices.sort((a, b) => scores[b].compareTo(scores[a]));

    final keep = <int>[];
    final suppressed = List.filled(indices.length, false);

    for (int i = 0; i < indices.length; i++) {
      if (suppressed[i]) continue;
      keep.add(indices[i]);

      for (int j = i + 1; j < indices.length; j++) {
        if (suppressed[j]) continue;
        if (_iou(boxes[indices[i]], boxes[indices[j]]) > _iouThreshold) {
          suppressed[j] = true;
        }
      }
    }

    return keep;
  }

  /// Calculate Intersection over Union between two boxes
  double _iou(List<double> box1, List<double> box2) {
    final x1 = box1[0] - box1[2] / 2;
    final y1 = box1[1] - box1[3] / 2;
    final x2 = box1[0] + box1[2] / 2;
    final y2 = box1[1] + box1[3] / 2;

    final x3 = box2[0] - box2[2] / 2;
    final y3 = box2[1] - box2[3] / 2;
    final x4 = box2[0] + box2[2] / 2;
    final y4 = box2[1] + box2[3] / 2;

    final xi1 = math.max(x1, x3);
    final yi1 = math.max(y1, y3);
    final xi2 = math.min(x2, x4);
    final yi2 = math.min(y2, y4);

    final inter = math.max(0.0, xi2 - xi1) * math.max(0.0, yi2 - yi1);
    final area1 = (x2 - x1) * (y2 - y1);
    final area2 = (x4 - x3) * (y4 - y3);

    return inter / (area1 + area2 - inter);
  }

  /// Sigmoid activation function
  double _sigmoid(double x) => 1 / (1 + math.exp(-x));

  /// Convert a single mask to PNG bytes for visualization
  /// The mask is a 2D list of integers (0 or 1)
  Future<Uint8List> maskToPngBytes(List<List<int>> mask) async {
    if (mask.isEmpty || mask.first.isEmpty) {
      throw Exception('Mask is empty');
    }

    final int height = mask.length;
    final int width = mask.first.length;

    // Create image from mask
    final maskImage = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final value = mask[y][x];
        final intensity = value == 0 ? 0 : 255;
        maskImage.setPixelRgb(x, y, intensity, intensity, intensity);
      }
    }

    return Uint8List.fromList(img.encodePng(maskImage));
  }

  Future<List<List<int>>?> detectMaskAtPointFromBytes(
    Uint8List imageBytes,
    double x,
    double y,
  ) async {
    if (!_isInitialized) {
      throw Exception('Model not initialized. Call initialize() first.');
    }

    // 1. Decode once to get original width/height for coordinate mapping
    final img.Image? decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) {
      throw Exception('Failed to decode image');
    }

    final int originalWidth = decodedImage.width;
    final int originalHeight = decodedImage.height;

    // Guard: tap outside image → no mask
    if (x < 0 ||
        y < 0 ||
        x >= originalWidth.toDouble() ||
        y >= originalHeight.toDouble()) {
      return null;
    }

    // 2. Run normal detection (this will decode + run TFLite + postprocess)
    final YoloSegmentationResult result = await detectFromBytes(imageBytes);

    if (!result.hasDetections) {
      return null;
    }

    // 3. Map tap point from original image space → model input space (640x640)
    // because boxes are currently in model coordinates.
    final double pxModel = x * _inputSize / originalWidth;
    final double pyModel = y * _inputSize / originalHeight;

    int? bestIndex;
    double bestDist2 = double.infinity;

    // 4. Find all boxes that contain the point, choose one whose center is closest
    for (int i = 0; i < result.boxes.length; i++) {
      final box = result.boxes[i];
      // Denormalize box coordinates (YOLO outputs normalized [0-1] coordinates)
      final double cx = box[0] * _inputSize; // center x in model space
      final double cy = box[1] * _inputSize; // center y
      final double w = box[2] * _inputSize;
      final double h = box[3] * _inputSize;

      final double left = cx - w / 2.0;
      final double top = cy - h / 2.0;
      final double right = cx + w / 2.0;
      final double bottom = cy + h / 2.0;

      final bool inside = pxModel >= left &&
          pxModel <= right &&
          pyModel >= top &&
          pyModel <= bottom;

      if (!inside) continue;

      // Distance from tap point to box center in model space
      final double dx = pxModel - cx;
      final double dy = pyModel - cy;
      final double dist2 = dx * dx + dy * dy;

      if (dist2 < bestDist2) {
        bestDist2 = dist2;
        bestIndex = i;
      }
    }

    // 5. No box contains the point
    if (bestIndex == null) {
      return null;
    }

    // 6. Return ONLY that detection's mask (already in original image size)
    return result.masks[bestIndex];
  }

  Future<List<List<int>>?> detectMaskAtPointFromUIImage(
    ui.Image image,
    double x,
    double y,
  ) async {
    if (!_isInitialized) {
      throw Exception('Model not initialized. Call initialize() first.');
    }

    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to convert ui.Image to bytes');
    }

    final Uint8List imageBytes = byteData.buffer.asUint8List();
    return detectMaskAtPointFromBytes(imageBytes, x, y);
  }

  /// Clean up resources
  void dispose() {
    if (!_isInitialized) return;

    _interpreter.close();
    _isInitialized = false;
  }
}

/// Extension to reshape lists for TFLite tensors
extension ListReshape on List {
  List reshape(List<int> shape) {
    // For TFLite, this is handled internally
    // This is a placeholder for the expected shape
    return this;
  }
}
