import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/providers.dart';

class EditController {
  final WidgetRef ref;
  EditController(this.ref);

  Future<Uint8List?> segment(Uint8List imageBytes) async {
    final api = ref.read(apiProvider);
    return await api.segment(imageBytes);
  }

  Future<Uint8List?> inpaint(Uint8List imageBytes, Uint8List maskBytes) async {
    final api = ref.read(apiProvider);
    return await api.inpaint(imageBytes, maskBytes);
  }
}
