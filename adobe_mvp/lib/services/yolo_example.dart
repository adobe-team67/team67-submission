// features/models/yolo_example.dart
// Example usage of YOLO segmentation wrapper

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'yolo_segmentation.dart';

/// Example class demonstrating YOLO segmentation usage
class YoloSegmentationExample {
  late YoloSegmentation yolo;

  /// Initialize the YOLO model
  Future<void> initialize() async {
    yolo = YoloSegmentation();
    await yolo.initialize();
    print('YOLO model ready for inference');
  }

  /// Run detection on ui.Image
  Future<YoloSegmentationResult> detectFromUIImage(ui.Image image) async {
    print('\n=== Running YOLO Detection ===');

    final result = await yolo.detectFromUIImage(image);

    print('Found ${result.detectionCount} objects:');
    for (int i = 0; i < result.detectionCount; i++) {
      final classId = result.classIds[i];
      final confidence = result.confidences[i];
      final box = result.boxes[i];
      final mask = result.masks[i];

      print('  Object $i:');
      print('    Class ID: $classId');
      print('    Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
      print('    Box: [x=${box[0].toInt()}, y=${box[1].toInt()}, '
          'w=${box[2].toInt()}, h=${box[3].toInt()}]');
      print('    Mask size: ${mask.length}x${mask[0].length}');
    }

    return result;
  }

  /// Run detection on image bytes
  Future<YoloSegmentationResult> detectFromBytes(Uint8List imageBytes) async {
    print('\n=== Running YOLO Detection from bytes ===');

    final result = await yolo.detectFromBytes(imageBytes);

    print('Found ${result.detectionCount} objects');
    return result;
  }

  /// Get mask as PNG bytes for visualization
  Future<Uint8List> getMaskAsPng(
      YoloSegmentationResult result, int index) async {
    if (index >= result.detectionCount) {
      throw Exception('Index out of bounds');
    }

    final mask = result.masks[index];
    return await yolo.maskToPngBytes(mask);
  }

  /// Clean up resources
  void dispose() {
    yolo.dispose();
    print('YOLO resources released');
  }
}

/// Widget example showing how to use YOLO in a Flutter app
class YoloDetectionWidget extends StatefulWidget {
  final Uint8List imageBytes;

  const YoloDetectionWidget({
    Key? key,
    required this.imageBytes,
  }) : super(key: key);

  @override
  State<YoloDetectionWidget> createState() => _YoloDetectionWidgetState();
}

class _YoloDetectionWidgetState extends State<YoloDetectionWidget> {
  YoloSegmentation? _yolo;
  YoloSegmentationResult? _result;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAndDetect();
  }

  Future<void> _initializeAndDetect() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      _yolo = YoloSegmentation();
      await _yolo!.initialize();

      final result = await _yolo!.detectFromBytes(widget.imageBytes);

      setState(() {
        _result = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _yolo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isProcessing)
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Running YOLO detection...'),
              ],
            ),
          ),
        if (_errorMessage != null)
          Center(
            child: Text(
              'Error: $_errorMessage',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        if (_result != null) ...[
          Text('Detected ${_result!.detectionCount} objects'),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _result!.detectionCount,
              itemBuilder: (context, index) {
                final classId = _result!.classIds[index];
                final confidence = _result!.confidences[index];
                final box = _result!.boxes[index];

                return Card(
                  child: ListTile(
                    title: Text('Object $index (Class $classId)'),
                    subtitle: Text(
                      'Confidence: ${(confidence * 100).toStringAsFixed(1)}%\n'
                      'Box: [${box[0].toInt()}, ${box[1].toInt()}, '
                      '${box[2].toInt()}, ${box[3].toInt()}]',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.image),
                      onPressed: () async {
                        // Export mask as PNG
                        final maskPng =
                            await _yolo!.maskToPngBytes(_result!.masks[index]);
                        // Show mask or save it
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Mask exported: ${maskPng.length} bytes',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
