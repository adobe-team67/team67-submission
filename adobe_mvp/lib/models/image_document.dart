// models/image_document.dart
// Simple model for an image document. Freezed-style comments included for future expansion.
import 'dart:typed_data';

class ImageDocument {
  final String id;
  final Uint8List imageBytes;
  final Uint8List? maskBytes;

  ImageDocument({required this.id, required this.imageBytes, this.maskBytes});

  ImageDocument copyWith({Uint8List? imageBytes, Uint8List? maskBytes}) {
    return ImageDocument(id: id, imageBytes: imageBytes ?? this.imageBytes, maskBytes: maskBytes ?? this.maskBytes);
  }
}
