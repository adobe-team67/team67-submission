import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// TODO: set this to your backend URL (same as in your Flutter app's AiApi)
const String baseUrl = 'http://10.36.16.96:8000';

/// Change these if needed
const String inputImagePath =
    r'H:\adobe-inter-iit\adobe_mvp\lib\testing\input\testimg1.jpg';
const String outputDirPath =
    r'H:\adobe-inter-iit\adobe_mvp\lib\testing\output';

const double tapDx = 0.17625;
const double tapDy = 0.5612;

Future<void> main() async {
  try {
    print('Loading image from: $inputImagePath');
    final file = File(inputImagePath);
    if (!await file.exists()) {
      throw Exception('Input image file does not exist: $inputImagePath');
    }

    final Uint8List imageBytes = await file.readAsBytes();
    final img.Image? decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw Exception('Failed to decode input image');
    }

    final int width = decoded.width;
    final int height = decoded.height;
    print('Loaded image: ${width} x ${height}');

    // Compute pixel coordinates from normalized tap point
    final int pixelX = (tapDx * width).round();
    final int pixelY = (tapDy * height).round();
    print('Tap point -> pixel: ($pixelX, $pixelY)');

    // Ensure output directory exists
    final outputDir = Directory(outputDirPath);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    // ============================================================
    // 1) REFINE SELECTION (BITMASK)
    // ============================================================
    print('\n=== 1) Calling /refine-selection ===');

    final String base64Image = base64Encode(imageBytes);
    final Map<String, dynamic> refineBody = {
      'image': base64Image,
      'imageWidth': width,
      'imageHeight': height,
      'selectionPoint': {'x': pixelX, 'y': pixelY},
    };

    final refineRes = await http
        .post(
          Uri.parse('$baseUrl/refine-selection'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(refineBody),
        )
        .timeout(const Duration(seconds: 300));

    if (refineRes.statusCode != 200) {
      throw Exception(
        'Refine-selection failed (${refineRes.statusCode}): ${refineRes.body}',
      );
    }

    final Map<String, dynamic> refineData =
        jsonDecode(refineRes.body) as Map<String, dynamic>;
    final List<dynamic> bitmaskData = refineData['bitmask'] as List<dynamic>;

    final List<List<int>> bitmask = bitmaskData
        .map((row) =>
            (row as List).map((val) => (val as num).toInt()).toList())
        .toList();

    final maskOutputPath = '$outputDirPath/testimg1_mask.png';
    print('Saving mask PNG to: $maskOutputPath');
    await _saveMaskAsPng(bitmask, maskOutputPath);
    print('✅ Mask saved!');

    // ============================================================
    // 2) ERASE SELECTION
    // ============================================================
    print('\n=== 2) Calling /erase ===');

    final Map<String, dynamic> eraseBody = {
      'image': base64Image,
    };

    final eraseRes = await http
        .post(
          Uri.parse('$baseUrl/erase'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(eraseBody),
        )
        .timeout(const Duration(seconds: 300));
        print("response recieved");

    if (eraseRes.statusCode != 200) {
      throw Exception(
        'Erase failed (${eraseRes.statusCode}): ${eraseRes.body}',
      );
    }

    final Map<String, dynamic> eraseData =
        jsonDecode(eraseRes.body) as Map<String, dynamic>;
    final String base64Erased = eraseData['image'] as String;
    final Uint8List erasedBytes = base64Decode(base64Erased);

    final erasedOutputPath = '$outputDirPath/testimg1_erased.png';
    await File(erasedOutputPath).writeAsBytes(erasedBytes);
    print('✅ Erased image saved at: $erasedOutputPath');

    // ============================================================
    // 3) INPAINT SELECTION
    // ============================================================
    print('\n=== 3) Calling /inpaint ===');

    final Map<String, dynamic> inpaintBody = {
      'prompt': 'change the person to a joker',
    };

    final inpaintRes = await http
        .post(
          Uri.parse('$baseUrl/inpaint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(inpaintBody),
        )
        .timeout(const Duration(seconds: 300));

    if (inpaintRes.statusCode != 200) {
      throw Exception(
        'Inpaint failed (${inpaintRes.statusCode}): ${inpaintRes.body}',
      );
    }

    final Map<String, dynamic> inpaintData =
        jsonDecode(inpaintRes.body) as Map<String, dynamic>;
    final String base64Inpaint = inpaintData['image'] as String;
    final Uint8List inpaintBytes = base64Decode(base64Inpaint);

    final inpaintOutputPath = '$outputDirPath/testimg1_inpainted.png';
    await File(inpaintOutputPath).writeAsBytes(inpaintBytes);
    print('✅ Inpainted image saved at: $inpaintOutputPath');

    // ============================================================
    // 4) MOVE SELECTION
    // ============================================================
    print('\n=== 4) Calling /move ===');

    final Map<String, dynamic> moveBody = {
      'endx': 800,
      'endy': 600,
      // 'prompt': 'optional prompt here',
    };

    final moveRes = await http
        .post(
          Uri.parse('$baseUrl/move'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(moveBody),
        )
        .timeout(const Duration(seconds: 300));

    if (moveRes.statusCode != 200) {
      throw Exception(
        'Move failed (${moveRes.statusCode}): ${moveRes.body}',
      );
    }

    final Map<String, dynamic> moveData =
        jsonDecode(moveRes.body) as Map<String, dynamic>;
    final String base64Move = moveData['image'] as String;
    final Uint8List moveBytes = base64Decode(base64Move);

    final movedOutputPath = '$outputDirPath/testimg1_moved.png';
    await File(movedOutputPath).writeAsBytes(moveBytes);
    print('✅ Moved image saved at: $movedOutputPath');

    // ============================================================
    // DONE
    // ============================================================
    print('\n🎉 ALL DONE! CHECK OUTPUT FILES BELOW:\n');
    print('  Mask:      $maskOutputPath');
    print('  Erased:    $erasedOutputPath');
    print('  Inpainted: $inpaintOutputPath');
    print('  Moved:     $movedOutputPath');
  } on http.ClientException catch (e, st) {
    print('❌ Network error: $e');
    print(st);
  } on FormatException catch (e, st) {
    print('❌ Invalid response format: $e');
    print(st);
  } catch (e, st) {
    print('❌ Error while running full pipeline test: $e');
    print(st);
  }
}

/// Convert a 2D bitmask (0/1 or 0/255) to PNG and save it.
/// Uses image 4.x API (setPixelRgb).
Future<void> _saveMaskAsPng(List<List<int>> bitmask, String path) async {
  if (bitmask.isEmpty || bitmask.first.isEmpty) {
    throw Exception('Bitmask is empty');
  }

  final int height = bitmask.length;
  final int width = bitmask.first.length;

  // image 4.x style constructor
  final img.Image mask = img.Image(width: width, height: height);

  for (int y = 0; y < height; y++) {
    final row = bitmask[y];
    if (row.length != width) {
      throw Exception('Inconsistent bitmask row width at row $y');
    }

    for (int x = 0; x < width; x++) {
      final int value = row[x];
      final int intensity = value == 0 ? 0 : 255;

      // New API: directly set RGB (alpha defaults to 255 for 8-bit images)
      mask.setPixelRgb(x, y, intensity, intensity, intensity);
    }
  }

  final Uint8List pngBytes = Uint8List.fromList(img.encodePng(mask));
  await File(path).writeAsBytes(pngBytes);
}
