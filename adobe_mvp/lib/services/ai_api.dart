// services/ai_api.dart
// Defines the AiApi interface for segmentation and inpainting.
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:adobe_mvp/config/env.dart';
import 'package:adobe_mvp/core/global.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

abstract class AiApi {
  Future<Uint8List> segment(Uint8List imageBytes);
  Future<Uint8List> inpaint(Uint8List imageBytes, Uint8List maskBytes);

  /// API base URL loaded from environment
  static String get baseUrl => Env.apiBaseUrl;

  // Global state to track current image name and mask IDs
  static String? _currentImageName;
  static List<int> _currentMaskIds = [];

// ==========================================================================================
// =====================================Set Image API========================================
// ==========================================================================================

  static Future<Map<String, dynamic>> setImage({
    required ui.Image image,
  }) async {
    try {
      // Convert ui.Image to bytes
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }
      final Uint8List imageBytes = byteData.buffer.asUint8List();
      final String base64Image = base64Encode(imageBytes);

      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'image': base64Image,
      };

      // Make POST request to backend
      final response = await http
          .post(
            Uri.parse('$baseUrl/set-image'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        // Store the image name for future operations
        _currentImageName = responseData['image_name'];
        
        return responseData;
      } else {
        throw Exception(
          'Backend returned status ${response.statusCode}: ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      throw Exception('Failed to set image: $e');
    }
  }

// ==========================================================================================
// =====================================Set Masks API========================================
// ==========================================================================================

  static Future<Map<String, dynamic>> setMasks({
    required List<List<List<int>>> masks,
  }) async {
    try {
      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'image_name': _currentImageName,
        'masks': masks,
      };

      // Make POST request to backend
      final response = await http
          .post(
            Uri.parse('$baseUrl/set-masks'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Store mask IDs for future operations
        final List<dynamic> masksList = responseData['masks'];
        _currentMaskIds = masksList.map((m) {
          final String maskStr = m as String;
          final RegExp regex = RegExp(r'_(\d+)_set');
          final match = regex.firstMatch(maskStr);
          if (match != null) {
            return int.parse(match.group(1)!);
          }
          throw Exception('Invalid mask format: $maskStr');
        }).toList();
        
        return responseData;
      } else {
        throw Exception(
          'Backend returned status ${response.statusCode}: ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      throw Exception('Failed to set masks: $e');
    }
  }

// ==========================================================================================
// =====================================Tap Select API=======================================
// ==========================================================================================

  static Future<Map<String, dynamic>> refineSelectionWithUIImage({
    required ui.Image image,
    required Offset tapPoint,
  }) async {
    try {
      // Convert ui.Image to bytes
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }
      final Uint8List imageBytes = byteData.buffer.asUint8List();
      final String base64Image = base64Encode(imageBytes);

      final int pixelX = (tapPoint.dx).round();
      final int pixelY = (tapPoint.dy).round();

      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'image': base64Image,
        'imageWidth': image.width,
        'imageHeight': image.height,
        'selectionPoint': {'x': pixelX, 'y': pixelY},
      };

      // Make POST request to backend
      final response = await http
          .post(
            Uri.parse('$baseUrl/refine-selection'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 300));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Parse bitmask from response
        final List<dynamic> bitmaskData = responseData['bitmask'];
        final List<List<int>> bitmask = bitmaskData
            .map((row) => (row as List).map((val) => val as int).toList())
            .toList();

        return {
          'bitmask': bitmask,
          'width': responseData['width'],
          'height': responseData['height'],
          'message': responseData['message'],
        };
      } else {
        throw Exception(
          'Backend returned status ${response.statusCode}: ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      throw Exception('Failed to refine selection: $e');
    }
  }

// ==========================================================================================
// =======================================Erase API==========================================
// ==========================================================================================

  static Future<String> eraseSelection({
    required String imageName,
    required List<int> maskIds,
    List<List<List<int>>>? manualMasks,
  }) async {
    try {
      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'image_name': imageName,
        'masks_ids': maskIds,
      };
      
      // Add manual masks if provided
      if (manualMasks != null && manualMasks.isNotEmpty) {
        requestBody['manual_masks'] = manualMasks;
      }

      // Make POST request to backend
      final response = await http
          .post(
            Uri.parse('$baseUrl/erase'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 300));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Get base64 encoded result image
        final String base64ResultImage = responseData['image'];
        final Uint8List resultBytes = base64Decode(base64ResultImage);

        // Save to temporary file
        final Directory tempDir = Directory.systemTemp;
        final String tempPath =
            '${tempDir.path}/erased_${DateTime.now().millisecondsSinceEpoch}.png';
        final File tempFile = File(tempPath);
        await tempFile.writeAsBytes(resultBytes);

        return tempPath;
      } else {
        throw Exception(
          'Backend returned status ${response.statusCode}: ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      throw Exception('Failed to erase selection: $e');
    }
  }

  // Convenience method using stored state
  static Future<String> eraseCurrentSelection({
    List<List<List<int>>>? manualMasks,
  }) async {
    if (_currentImageName == null) {
      throw Exception('No image set. Call setImage first.');
    }
    if (_currentMaskIds.isEmpty && (manualMasks == null || manualMasks.isEmpty)) {
      throw Exception('No masks selected.');
    }
    return eraseSelection(
      imageName: _currentImageName!,
      maskIds: _currentMaskIds,
      manualMasks: manualMasks,
    );
  }

// ==========================================================================================
// ========================================Inpaint API=======================================
// ==========================================================================================

  static Future<String> inpaintSelection({
    required String imageName,
    required List<int> maskIds,
    required String prompt,
    List<List<List<int>>>? manualMasks,
  }) async {
    try {
      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'image_name': imageName,
        'masks_ids': maskIds,
        'prompt': prompt,
        'model_type': GlobalConfig.selectedModelType
      };
      
      // Add manual masks if provided
      if (manualMasks != null && manualMasks.isNotEmpty) {
        requestBody['manual_masks'] = manualMasks;
      }
      
      // Make POST request to backend
      final response = await http
          .post(
            Uri.parse('$baseUrl/inpaint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 300));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Get base64 encoded result image
        final String base64ResultImage = responseData['image'];
        final Uint8List resultBytes = base64Decode(base64ResultImage);

        // Save to temporary file
        final Directory tempDir = Directory.systemTemp;
        final String tempPath =
            '${tempDir.path}/inpainted_${DateTime.now().millisecondsSinceEpoch}.png';
        final File tempFile = File(tempPath);
        await tempFile.writeAsBytes(resultBytes);

        return tempPath;
      } else {
        throw Exception(
          'Backend returned status ${response.statusCode}: ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      throw Exception('Failed to inpaint selection: $e');
    }
  }

  // Convenience method using stored state
  static Future<String> inpaintCurrentSelection({
    required String prompt,
    List<List<List<int>>>? manualMasks,
  }) async {
    if (_currentImageName == null) {
      throw Exception('No image set. Call setImage first.');
    }
    if (_currentMaskIds.isEmpty && (manualMasks == null || manualMasks.isEmpty)) {
      throw Exception('No masks selected.');
    }
    return inpaintSelection(
      imageName: _currentImageName!,
      maskIds: _currentMaskIds,
      prompt: prompt,
      manualMasks: manualMasks,
    );
  }

// ==========================================================================================
// ==========================================Move API========================================
// ==========================================================================================

  static Future<String> moveSelection({
    required String imageName,
    required List<int> maskIds,
    required int startX,
    required int startY,
    required int endX,
    required int endY,
    String? prompt,
    List<List<List<int>>>? manualMasks,
  }) async {
    try {
      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'image_name': imageName,
        'masks_ids': maskIds,
        'startx': startX,
        'starty': startY,
        'endx': endX,
        'endy': endY,
      };

      if (prompt != null && prompt.isNotEmpty) {
        requestBody['prompt'] = prompt;
      }
      
      // Add manual masks if provided
      if (manualMasks != null && manualMasks.isNotEmpty) {
        requestBody['manual_masks'] = manualMasks;
      }

      // Make POST request to backend
      final response = await http
          .post(
            Uri.parse('$baseUrl/move'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(
            const Duration(seconds: 300),
          ); // Longer timeout for move operation

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Get base64 encoded result image
        final String base64ResultImage = responseData['image'];
        final Uint8List resultBytes = base64Decode(base64ResultImage);

        // Save to temporary file
        final Directory tempDir = Directory.systemTemp;
        final String tempPath =
            '${tempDir.path}/moved_${DateTime.now().millisecondsSinceEpoch}.png';
        final File tempFile = File(tempPath);
        await tempFile.writeAsBytes(resultBytes);

        return tempPath;
      } else {
        throw Exception(
          'Backend returned status ${response.statusCode}: ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      throw Exception('Failed to move selection: $e');
    }
  }

  // Convenience method using stored state
  static Future<String> moveCurrentSelection({
    required int startX,
    required int startY,
    required int endX,
    required int endY,
    String? prompt,
    List<List<List<int>>>? manualMasks,
  }) async {
    if (_currentImageName == null) {
      throw Exception('No image set. Call setImage first.');
    }
    if (_currentMaskIds.isEmpty && (manualMasks == null || manualMasks.isEmpty)) {
      throw Exception('No masks selected.');
    }
    return moveSelection(
      imageName: _currentImageName!,
      maskIds: _currentMaskIds,
      startX: startX,
      startY: startY,
      endX: endX,
      endY: endY,
      prompt: prompt,
      manualMasks: manualMasks,
    );
  }


  static Future<void> resetBackend() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/reset'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Clear local state as well
        clearState();
      } else {
        throw Exception(
          'Backend returned status ${response.statusCode}: ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      throw Exception('Failed to reset backend: $e');
    }
  }
// ===========================================================================================
// ==================================flux inpaint api=========================================
// ===========================================================================================
static Future<String> fluxInpaint({
    required String imageName,
    required List<int> maskIds,
    required String prompt,
  }) async {
    try {
      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'image_name': imageName,
        'masks_ids': maskIds,
        'prompt': prompt,
      };

      // Make POST request to backend
      final response = await http
          .post(
            Uri.parse('$baseUrl/flux-inpaint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 300));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Get base64 encoded result image
        final String base64ResultImage = responseData['image'];
        final Uint8List resultBytes = base64Decode(base64ResultImage);

        // Save to temporary file
        final Directory tempDir = Directory.systemTemp;
        final String tempPath =
            '${tempDir.path}/inpainted_${DateTime.now().millisecondsSinceEpoch}.png';
        final File tempFile = File(tempPath);
        await tempFile.writeAsBytes(resultBytes);

        return tempPath;
      } else {
        throw Exception(
          'Backend returned status ${response.statusCode}: ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      throw Exception('Failed to inpaint selection: $e');
    }
  }

  // Convenience method using stored state
  static Future<String> fluxInpaintCurrent({
    required String prompt,
  }) async {
    if (_currentImageName == null) {
      throw Exception('No image set. Call setImage first.');
    }
    if (_currentMaskIds.isEmpty) {
      throw Exception('No masks selected.');
    }
    return inpaintSelection(
      imageName: _currentImageName!,
      maskIds: _currentMaskIds,
      prompt: prompt,
    );
  }

// ==========================================================================================
// ====================================Health Check API======================================
// ==========================================================================================

  static Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/health'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Backend returned status ${response.statusCode}: ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      throw Exception('Health check failed: $e');
    }
  }

// ==========================================================================================
// ====================================State Management======================================
// ==========================================================================================

  // Get current image name
  static String? getCurrentImageName() => _currentImageName;

  // Get current mask IDs
  static List<int> getCurrentMaskIds() => List.from(_currentMaskIds);

  // Set mask IDs manually if needed
  static void setMaskIds(List<int> maskIds) {
    _currentMaskIds = maskIds;
  }
  
  // Set image name manually (for undo/redo restore)
  static void setImageName(String? imageName) {
    _currentImageName = imageName;
  }

  // Clear all state
  static void clearState() {
    _currentImageName = null;
    _currentMaskIds.clear();
  }

// ==========================================================================================
// ======================================Image to Image API==================================
// ==========================================================================================

  /// Transforms an image based on a text prompt.
  /// Returns the path to the transformed image file.
  static Future<String> imgToImg({
    required Uint8List imageBytes,
    required String prompt,
  }) async {
    try {
      final String base64Image = base64Encode(imageBytes);

      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'image': base64Image,
        'prompt': prompt,
      };

      // Make POST request to backend
      final response = await http
          .post(
            Uri.parse('$baseUrl/imgtoimg'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 300));

      if (response.statusCode == 200) {
        // Handle response - could be JSON with 'image' key or raw base64 string
        String base64ResultImage;
        try {
          final dynamic responseData = jsonDecode(response.body);
          if (responseData is Map<String, dynamic>) {
            base64ResultImage = responseData['image'];
          } else if (responseData is String) {
            // JSON-encoded string (double serialization)
            base64ResultImage = responseData;
          } else {
            throw FormatException('Unexpected response type');
          }
        } catch (e) {
          // Response is raw base64 string, not JSON
          base64ResultImage = response.body;
          // Remove quotes if present (in case it's a quoted string)
          if (base64ResultImage.startsWith('"') && base64ResultImage.endsWith('"')) {
            base64ResultImage = base64ResultImage.substring(1, base64ResultImage.length - 1);
          }
        }
        
        final Uint8List resultBytes = base64Decode(base64ResultImage);

        // Save to temporary file
        final Directory tempDir = Directory.systemTemp;
        final String tempPath =
            '${tempDir.path}/imgtoimg_${DateTime.now().millisecondsSinceEpoch}.png';
        final File tempFile = File(tempPath);
        await tempFile.writeAsBytes(resultBytes);

        return tempPath;
      } else {
        throw Exception(
          'Backend returned status ${response.statusCode}: ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      throw Exception('Failed to transform image: $e');
    }
  }

// ==========================================================================================
// =========================================Stylize API======================================
// ==========================================================================================

  /// Stylizes an image based on a target style image, prompt, and style name.
  /// Returns the path to the stylized image file.
  static Future<String> stylize({
    required Uint8List imageBytes,
    Uint8List? targetImage,
    required String prompt,
    String? style,
  }) async {
    try {
      final String base64Image = base64Encode(imageBytes);

      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'image': base64Image,
        'prompt': prompt,
      };

      // Add style if provided
      if (style != null && style.isNotEmpty) {
        requestBody['style'] = style;
      }

      // Add target_image if provided
      if (targetImage != null) {
        requestBody['target_image'] = base64Encode(targetImage);
      }

      // Make POST request to backend
      final response = await http
          .post(
            Uri.parse('$baseUrl/stylize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 300));

      if (response.statusCode == 200) {
        // Handle response - could be JSON with 'image' key or raw base64 string
        String base64ResultImage;
        try {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          base64ResultImage = responseData['image'];
        } catch (e) {
          // Response is raw base64 string, not JSON
          base64ResultImage = response.body;
        }
        
        final Uint8List resultBytes = base64Decode(base64ResultImage);

        // Save to temporary file
        final Directory tempDir = Directory.systemTemp;
        final String tempPath =
            '${tempDir.path}/stylized_${DateTime.now().millisecondsSinceEpoch}.png';
        final File tempFile = File(tempPath);
        await tempFile.writeAsBytes(resultBytes);
        return tempPath;
      } else {
        throw Exception(
          'Backend returned status ${response.statusCode}: ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      throw Exception('Failed to stylize image: $e');
    }
  }

// ==========================================================================================
// =========================================Converge API=====================================
// ==========================================================================================

  /// Converges (merges/blends) two images using AI.
  /// Takes the current image and a second image, intelligently blending them together.
  /// Returns the path to the converged image file.
  static Future<String> convergeImages({
    required Uint8List image1Bytes,
    required Uint8List image2Bytes,
    String? prompt,
  }) async {
    try {
      final String base64Image1 = base64Encode(image1Bytes);
      final String base64Image2 = base64Encode(image2Bytes);

      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'image1': base64Image1,
        'image2': base64Image2,
      };

      // Add prompt if provided
      if (prompt != null && prompt.isNotEmpty) {
        requestBody['prompt'] = prompt;
      }

      // Make POST request to backend
      final response = await http
          .post(
            Uri.parse('$baseUrl/converge'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 300));

      if (response.statusCode == 200) {
        // Handle response - could be JSON with 'image' key or raw base64 string
        String base64ResultImage;
        try {
          final dynamic responseData = jsonDecode(response.body);
          if (responseData is Map<String, dynamic>) {
            base64ResultImage = responseData['image'];
          } else if (responseData is String) {
            base64ResultImage = responseData;
          } else {
            throw FormatException('Unexpected response type');
          }
        } catch (e) {
          // Response is raw base64 string, not JSON
          base64ResultImage = response.body;
          // Remove quotes if present
          if (base64ResultImage.startsWith('"') && base64ResultImage.endsWith('"')) {
            base64ResultImage = base64ResultImage.substring(1, base64ResultImage.length - 1);
          }
        }
        
        final Uint8List resultBytes = base64Decode(base64ResultImage);

        // Save to temporary file
        final Directory tempDir = Directory.systemTemp;
        final String tempPath =
            '${tempDir.path}/converge_${DateTime.now().millisecondsSinceEpoch}.png';
        final File tempFile = File(tempPath);
        await tempFile.writeAsBytes(resultBytes);

        return tempPath;
      } else {
        throw Exception(
          'Backend returned status ${response.statusCode}: ${response.body}',
        );
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: $e');
    } catch (e) {
      throw Exception('Failed to converge images: $e');
    }
  }
}
