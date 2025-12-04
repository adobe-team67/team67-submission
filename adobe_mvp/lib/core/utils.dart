 // core/utils.dart
// Small utility helpers used across the app.
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';

Future<String> saveToTemp(Uint8List bytes, String name) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<void> SaveToGallery(Uint8List bytes, BuildContext context) async {

  final result = await ImageGallerySaverPlus.saveImage(
    bytes,
    quality: 100);
  if (result == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image saved to gallery!')),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to save image to gallery.')),
    );
  }

}
