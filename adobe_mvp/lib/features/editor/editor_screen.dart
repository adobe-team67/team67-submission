// features/editor/editor_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:adobe_mvp/core/constants.dart';
import 'package:adobe_mvp/core/global.dart';
import 'package:adobe_mvp/core/utils.dart';
import 'package:adobe_mvp/features/editor/widgets/edit_top_nav.dart';
import 'package:adobe_mvp/ui/theme/app_theme.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import '../../state/providers.dart';
import '../../state/editing_image_manager.dart';
import '../../models/edit_state.dart';
import '../../models/editing_image.dart';
import 'widgets/image_canvas.dart';
import 'widgets/selection_cutout_overlay.dart';
import 'controllers/selection_mode_controller.dart';
// selection toolbar removed (not used currently)
import 'widgets/floating_bottom_nav.dart';
import 'widgets/sliders/edit_slider.dart';
import 'widgets/sliders/select_slider.dart';
import 'widgets/sliders/prompt_slider.dart';
import 'widgets/sliders/layers_slider.dart';
import 'widgets/sliders/stylize_slider.dart';
import '../../services/auto_enhance.dart';
import '../../services/auto_aspect_ratio.dart';
import '../../services/ai_api.dart';
import 'controllers/tap_selection_controller.dart';
import 'controllers/erase_controller.dart';
import 'controllers/inpaint_controller.dart';
import 'controllers/move_controller.dart';
import 'controllers/img_to_img_controller.dart';
import 'controllers/stylize_controller.dart';
import 'package:adobe_mvp/features/learn/learn_screen.dart'
    show EditorNavigationArgs;
import 'widgets/add_image_popup.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with TickerProviderStateMixin {
  Uint8List? imageBytes;
  Uint8List? maskBytes;
  bool busy = false;
  String activeTool = 'None';
  bool sheetOpen = false;
  Widget? sheetContent;

  // Key for tracking bin icon position
  final GlobalKey _binKey = GlobalKey();
  Rect? _binZone;

  // Track if erase is in progress
  bool _isErasing = false;

  // Draggable bin position (null = default position, otherwise custom offset)
  Offset? _binCustomOffset;
  bool _isDraggingBin = false;

  // Track initial feature to open (from navigation args)
  EditorFeature? _pendingFeature;

  // Store stylize reference image from navigation (for stylize tutorials)
  Uint8List? _stylizeReferenceImage;
  // ignore: unused_field
  String? _stylizePresetName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (imageBytes != null) return;
    final arg = ModalRoute.of(context)?.settings.arguments;

    if (arg is EditorNavigationArgs) {
      // Handle EditorNavigationArgs with image bytes and optional feature
      imageBytes = arg.imageBytes;
      _pendingFeature = arg.initialFeature;
      _stylizeReferenceImage = arg.stylizeReferenceImage;
      _stylizePresetName = arg.stylizePresetName;

      // Delay provider modifications to avoid modifying during build
      Future.microtask(() {
        if (!mounted) return;
        ref.read(imageDocumentProvider.notifier).loadFromBytes(imageBytes!);
        ref
            .read(editingImageProvider.notifier)
            .loadImage(imageBytes: imageBytes!);

        // Auto-open the feature slider if specified
        if (_pendingFeature != null && _pendingFeature != EditorFeature.none) {
          _openFeatureSlider(_pendingFeature!);
          _pendingFeature = null;
        }
      });
    } else if (arg is String) {
      // assume asset path
      rootBundle.load(arg).then((bd) {
        if (!mounted) return;
        setState(() {
          imageBytes = bd.buffer.asUint8List();
        });
        // Delay provider modifications to avoid modifying during build
        Future.microtask(() {
          if (!mounted) return;
          ref.read(imageDocumentProvider.notifier).loadFromBytes(imageBytes!);
          // Load into EditingImageManager (single source of truth)
          ref
              .read(editingImageProvider.notifier)
              .loadImage(imageBytes: imageBytes!);
        });
      });
    } else if (arg is Uint8List) {
      imageBytes = arg;
      // Delay provider modifications to avoid modifying during build
      Future.microtask(() {
        if (!mounted) return;
        ref.read(imageDocumentProvider.notifier).loadFromBytes(imageBytes!);
        // Load into EditingImageManager (single source of truth)
        ref
            .read(editingImageProvider.notifier)
            .loadImage(imageBytes: imageBytes!);
      });
    }
  }

  /// Opens the appropriate slider for a given EditorFeature
  void _openFeatureSlider(EditorFeature feature) {
    String toolLabel;
    switch (feature) {
      case EditorFeature.edit:
        toolLabel = 'Edit';
        break;
      case EditorFeature.select:
        toolLabel = 'Select';
        break;
      case EditorFeature.prompt:
        toolLabel = 'Prompt';
        break;
      case EditorFeature.layers:
        toolLabel = 'Layers';
        break;
      case EditorFeature.stylize:
        toolLabel = 'Stylize';
        break;
      case EditorFeature.none:
        return;
    }
    _openSheetFor(toolLabel);
  }

  // ignore: unused_element
  Future<void> _doSegment() async {
    if (imageBytes == null) return;
    setState(() => busy = true);
    final api = ref.read(apiProvider);
    final m = await api.segment(imageBytes!);
    setState(() {
      maskBytes = m;
      busy = false;
    });
  }

  // ignore: unused_element
  Future<void> _doRemove() async {
    if (imageBytes == null || maskBytes == null) return;
    setState(() => busy = true);
    final api = ref.read(apiProvider);
    final out = await api.inpaint(imageBytes!, maskBytes!);
    setState(() {
      imageBytes = out;
      maskBytes = null;
      busy = false;
    });
    // Update via EditingImageManager (handles history)
    await ref.read(imageDocumentProvider.notifier).applyNewImage(out);
    ref.read(editingImageProvider.notifier).updateImage(
          out,
          operation: EditOperation.inpaint,
          description: 'Inpaint / Remove object',
        );
  }

  /// Undo last edit operation
  void _undo() {
    final historyNotifier = ref.read(editHistoryProvider.notifier);
    if (!historyNotifier.canUndo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to undo')),
      );
      return;
    }
    historyNotifier.undo();

    // Sync EditingImageManager from history
    final editingImageManager = ref.read(editingImageProvider.notifier);
    editingImageManager.syncFromHistory();

    // Update local state from history
    final newBytes = historyNotifier.currentImageBytes;
    if (newBytes != null) {
      setState(() {
        imageBytes = newBytes;
        maskBytes = historyNotifier.currentMaskBytes;
      });
      // Also update imageDocumentProvider
      ref.read(imageDocumentProvider.notifier).loadFromBytes(newBytes);
    }
  }

  /// Redo last undone operation
  void _redo() {
    final historyNotifier = ref.read(editHistoryProvider.notifier);
    if (!historyNotifier.canRedo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to redo')),
      );
      return;
    }
    historyNotifier.redo();

    // Sync EditingImageManager from history
    final editingImageManager = ref.read(editingImageProvider.notifier);
    editingImageManager.syncFromHistory();

    // Update local state from history
    final newBytes = historyNotifier.currentImageBytes;
    if (newBytes != null) {
      setState(() {
        imageBytes = newBytes;
        maskBytes = historyNotifier.currentMaskBytes;
      });
      // Also update imageDocumentProvider
      ref.read(imageDocumentProvider.notifier).loadFromBytes(newBytes);
    }
  }

  /// Show popup with options to add image as layer or converge images
  Future<void> _showAddImagePopup() async {
    final option = await showAddImagePopup(context);
    if (option == null || !mounted) return;
    
    switch (option) {
      case AddImageOption.importAsLayer:
        await _pickAndAddImageAsLayer();
        break;
      case AddImageOption.convergeImages:
        await _pickAndConvergeImages();
        break;
    }
  }

  /// Pick an image from gallery and add it to the canvas as a layer
  /// If in canvas mode, the image will be fitted and composited onto the canvas
  /// If not in canvas mode, the image replaces the current one
  Future<void> _pickAndAddImageAsLayer() async {
    final picker = ImagePicker();
    try {
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;

      final pickedBytes = await file.readAsBytes();

      Uint8List finalBytes;

      if (GlobalConfig.isCanvasMode && imageBytes != null) {
        // Composite the picked image onto the existing canvas
        setState(() => busy = true);
        finalBytes = await _compositeImageOnCanvas(pickedBytes);
        setState(() => busy = false);
      } else {
        // Not in canvas mode or no existing canvas - just use the picked image
        finalBytes = pickedBytes;
      }

      // Update state
      setState(() {
        imageBytes = finalBytes;
      });

      // Update providers
      ref.read(imageDocumentProvider.notifier).loadFromBytes(finalBytes);
      ref.read(editingImageProvider.notifier).loadImage(imageBytes: finalBytes);
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add image: $e')),
        );
      }
    }
  }

  /// Pick a second image and converge it with the current image using AI
  Future<void> _pickAndConvergeImages() async {
    if (imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please load an image first')),
      );
      return;
    }

    final picker = ImagePicker();
    try {
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;

      final pickedBytes = await file.readAsBytes();

      setState(() => busy = true);

      // Call the converge API
      final resultPath = await AiApi.convergeImages(
        image1Bytes: imageBytes!,
        image2Bytes: pickedBytes,
      );

      // Read the result image
      final resultFile = File(resultPath);
      final resultBytes = await resultFile.readAsBytes();

      if (!mounted) return;

      setState(() {
        imageBytes = resultBytes;
        busy = false;
      });

      // Update providers
      ref.read(imageDocumentProvider.notifier).loadFromBytes(resultBytes);
      ref.read(editingImageProvider.notifier).updateImage(
        resultBytes,
        operation: EditOperation.custom,
        description: 'Converged two images',
      );

      // Clean up temp file
      try {
        await resultFile.delete();
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to converge images: $e')),
        );
      }
    }
  }

  /// Composite the picked image onto the current canvas, fitting it appropriately
  Future<Uint8List> _compositeImageOnCanvas(Uint8List pickedImageBytes) async {
    if (imageBytes == null) return pickedImageBytes;

    // Decode both images
    final canvasCodec = await ui.instantiateImageCodec(imageBytes!);
    final canvasFrame = await canvasCodec.getNextFrame();
    final canvasImage = canvasFrame.image;

    final pickedCodec = await ui.instantiateImageCodec(pickedImageBytes);
    final pickedFrame = await pickedCodec.getNextFrame();
    final pickedImage = pickedFrame.image;

    final canvasWidth = canvasImage.width.toDouble();
    final canvasHeight = canvasImage.height.toDouble();
    final pickedWidth = pickedImage.width.toDouble();
    final pickedHeight = pickedImage.height.toDouble();

    // Calculate the scale to fit the picked image within the canvas (contain)
    final scaleX = canvasWidth / pickedWidth;
    final scaleY = canvasHeight / pickedHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate the scaled dimensions
    final scaledWidth = pickedWidth * scale;
    final scaledHeight = pickedHeight * scale;

    // Store the original image size on canvas for region fill
    GlobalConfig.originalImageSizeOnCanvas = Size(scaledWidth, scaledHeight);

    // Calculate offset to center the image
    final offsetX = (canvasWidth - scaledWidth) / 2;
    final offsetY = (canvasHeight - scaledHeight) / 2;

    // Create a new picture with the composite
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw the canvas background first
    canvas.drawImage(canvasImage, Offset.zero, Paint());

    // Draw the picked image scaled and centered
    final srcRect = Rect.fromLTWH(0, 0, pickedWidth, pickedHeight);
    final dstRect = Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight);
    canvas.drawImageRect(pickedImage, srcRect, dstRect, Paint());

    final picture = recorder.endRecording();

    // Convert to image
    final compositeImage = await picture.toImage(
      canvasWidth.toInt(),
      canvasHeight.toInt(),
    );

    // Convert to PNG bytes
    final byteData =
        await compositeImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to encode composite image');
    }

    // Cleanup
    canvasImage.dispose();
    pickedImage.dispose();
    compositeImage.dispose();

    return byteData.buffer.asUint8List();
  }

  /// Opens the Auto Enhance popup and processes the image based on user selection.
  /// For canvas images: Shows 2 options (Enhance and Extend)
  /// For non-canvas images: Shows only Enhance option
  Future<void> _openMagicViewPopup() async {
    if (imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No image to enhance'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final isCanvasMode = GlobalConfig.isCanvasMode;

    // Show selection dialog
    final selectedOption = await showDialog<AutoEnhanceOption>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => _AutoEnhanceDialog(isCanvasMode: isCanvasMode),
    );

    if (selectedOption != null && mounted) {
      setState(() => busy = true);

      try {
        Uint8List processedBytes = imageBytes!;

        switch (selectedOption) {
          case AutoEnhanceOption.enhance:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Auto enhancing image...'),
                duration: Duration(seconds: 1),
              ),
            );
            processedBytes = autoEnhanceImage(processedBytes);
            break;

          case AutoEnhanceOption.extend:
            if (isCanvasMode && GlobalConfig.currentCanvasSize != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Extending canvas background...'),
                  duration: Duration(seconds: 1),
                ),
              );

              final canvasSize = GlobalConfig.currentCanvasSize!;
              final originalSize = GlobalConfig.originalImageSizeOnCanvas;

              if (originalSize != null) {
                processedBytes = await extractAndFillCanvasBackground(
                  processedBytes,
                  canvasSize.width.toInt(),
                  canvasSize.height.toInt(),
                  originalSize.width.toInt(),
                  originalSize.height.toInt(),
                  blurRadius: 2,
                );
              } else {
                processedBytes = await extendGradientBackground(
                  processedBytes,
                  canvasSize.width.toInt(),
                  canvasSize.height.toInt(),
                  blurRadius: 2,
                );
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Extend only works in canvas mode'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
              return;
            }
            break;
        }

        setState(() {
          imageBytes = processedBytes;
        });

        ref.read(imageDocumentProvider.notifier).loadFromBytes(processedBytes);
        ref.read(editingImageProvider.notifier).updateImage(
              processedBytes,
              operation: EditOperation.filter,
              description: selectedOption == AutoEnhanceOption.enhance
                  ? 'Auto enhance'
                  : 'Canvas extend',
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(selectedOption == AutoEnhanceOption.enhance
                  ? 'Image enhanced!'
                  : 'Canvas extended!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Operation failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => busy = false);
        }
      }
    }
  }

  /// Update bin zone from GlobalKey
  void _updateBinZone() {
    final box = _binKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final position = box.localToGlobal(Offset.zero);
      _binZone = Rect.fromLTWH(
        position.dx - 20, // Add some padding
        position.dy - 20,
        box.size.width + 40,
        box.size.height + 40,
      );
    }
  }

  /// Handle erase when cutout is dropped on bin
  Future<void> _handleEraseFromBin() async {
    if (_isErasing || imageBytes == null) return;

    setState(() => _isErasing = true);

    try {
      final eraseController = ref.read(eraseControllerProvider);
      await eraseController.eraseSelection();

      // Update image from erase result
      if (eraseController.resultImage != null && mounted) {
        setState(() {
          imageBytes = eraseController.resultImage;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Object erased successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erase failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isErasing = false);
      }
    }
  }

  /// Handle tick button press for Select tool
  /// Note: This is now unused as SelectSlider handles its own tick/action flow
  /// Keeping for potential future use
  // ignore: unused_element
  Future<void> _handleSelectToolTick() async {
    final editingImage = ref.read(editingImageProvider);
    if (editingImage == null || imageBytes == null) {
      _closeSheetAndReset();
      return;
    }

    final prompt = ref.read(selectPromptProvider).trim();
    final selections = editingImage.selections;
    final imageSize = editingImage.imageSize;
    final detectedObjects = editingImage.detectedObjects;

    if (prompt.isNotEmpty) {
      await _processSelectPrompt(
          prompt, selections, detectedObjects, imageSize);
      return;
    }

    await _handleMovedSelections(selections, imageSize);
  }

  /// Process the prompt from select tool
  Future<void> _processSelectPrompt(
    String prompt,
    List<SelectionState> selections,
    List<DetectedObjectState> detectedObjects,
    Size imageSize,
  ) async {
    // Classify the prompt
    final action = classifyPrompt(prompt);

    // Show processing feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Processing: "${prompt}" → ${action.name.toUpperCase()}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    switch (action) {
      case PromptAction.select:
        await _handleSelectAction(prompt, detectedObjects);
        break;

      case PromptAction.erase:
        await _handleEraseAction(prompt, selections);
        break;

      case PromptAction.move:
        await _handleMoveAction(prompt, selections, imageSize);
        break;

      case PromptAction.inpaint:
        await _handleInpaintAction(prompt, selections);
        break;
    }
  }

  /// Handle select action from prompt
  Future<void> _handleSelectAction(
      String prompt, List<DetectedObjectState> objects) async {
    if (objects.isEmpty) {
      _showErrorDialog('No Objects Detected',
          'No objects were detected in the image. Please wait for detection to complete.');
      return;
    }

    // Use stub matcher to find matching object
    final matchedIndex = matchPromptToObject(prompt, objects);

    if (matchedIndex == null) {
      // No match found - show available objects
      final objectNames = objects.map((o) => o.className).toSet().join(', ');
      _showErrorDialog(
        'No Match Found',
        'Could not find an object matching "$prompt".\n\nAvailable objects: $objectNames',
      );
      return;
    }

    // Select the matched object
    final imageManager = ref.read(editingImageProvider.notifier);
    await imageManager.toggleObjectSelection(matchedIndex);

    final matchedObject = objects.firstWhere((o) => o.index == matchedIndex);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected: ${matchedObject.className}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Clear prompt after selection
    ref.read(selectPromptProvider.notifier).state = '';
  }

  /// Handle erase action from prompt
  Future<void> _handleEraseAction(
      String prompt, List<SelectionState> selections) async {
    if (selections.isEmpty) {
      _showErrorDialog(
          'No Selection', 'Please select an object first before erasing.');
      return;
    }

    setState(() => busy = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erasing selected object...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    try {
      final eraseController = ref.read(eraseControllerProvider);

      await eraseController.eraseSelection();

      if (eraseController.resultImage != null && mounted) {
        setState(() {
          imageBytes = eraseController.resultImage;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Object erased successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        _closeSheetAndReset();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erase failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  /// Handle move action from prompt
  Future<void> _handleMoveAction(
      String prompt, List<SelectionState> selections, Size imageSize) async {
    if (selections.isEmpty) {
      _showErrorDialog(
          'No Selection', 'Please select an object first before moving.');
      return;
    }

    // Check for moved selections
    final movedSelections =
        selections.where((s) => s.offset != Offset.zero).toList();

    if (movedSelections.isEmpty) {
      _showErrorDialog('Object Not Moved',
          'Please drag the selected object to its new position first.');
      return;
    }

    // Use the existing move handling logic
    await _handleMovedSelections(selections, imageSize);
  }

  /// Handle inpaint action from prompt
  Future<void> _handleInpaintAction(
      String prompt, List<SelectionState> selections) async {
    if (selections.isEmpty) {
      _showErrorDialog('No Selection',
          'Please select a region first before applying edits.');
      return;
    }

    setState(() => busy = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Applying edit: "$prompt"...'),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    try {
      final inpaintController = ref.read(inpaintControllerProvider);

      await inpaintController.inpaintSelection(prompt);

      if (inpaintController.resultImage != null && mounted) {
        setState(() {
          imageBytes = inpaintController.resultImage;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Edit applied successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        _closeSheetAndReset();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Edit failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  /// Handle moved selections (original move logic)
  Future<void> _handleMovedSelections(
      List<SelectionState> selections, Size imageSize) async {
    // Find selections with non-zero offset (moved objects)
    final movedSelections =
        selections.where((s) => s.offset != Offset.zero).toList();

    if (movedSelections.isEmpty) {
      // No objects moved, just close the sheet
      _closeSheetAndReset();
      return;
    }

    if (movedSelections.length > 1) {
      // More than one object moved - prompt user to select only one
      _showErrorDialog(
        'Multiple Objects Moved',
        'You have moved multiple objects. Please move only one object at a time for the move operation.',
      );
      return;
    }

    // Exactly one object moved - check if it's outside the image
    final movedSelection = movedSelections.first;
    final currentCenter = movedSelection.currentCenter;
    final originalCenter = movedSelection.selection.originalCenter;

    // Check if the center point is outside image bounds
    // final isOutsideImage = currentCenter.dx < 0 ||
    //     currentCenter.dy < 0 ||
    //     currentCenter.dx > imageSize.width ||
    //     currentCenter.dy > imageSize.height;

    // if (isOutsideImage) {
    //   _showErrorDialog(
    //     'Object Outside Image',
    //     'The selected object has been moved outside the image boundaries. Please move it back inside the image to apply the move operation.',
    //   );
    //   return;
    // }

    // Object moved within image bounds - call move API
    setState(() => busy = true);

    // if (mounted) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(
    //       content: Text('Moving object to new position...'),
    //       duration: Duration(seconds: 1),
    //     ),
    //   );
    // }

    try {
      final moveController = ref.read(moveControllerProvider);

      await moveController.moveSelection(
        startX: originalCenter.dx.round(),
        startY: originalCenter.dy.round(),
        endX: currentCenter.dx.round(),
        endY: currentCenter.dy.round(),
      );

      // Update image from move result
      if (moveController.resultImage != null && mounted) {
        setState(() {
          imageBytes = moveController.resultImage;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Object moved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      _closeSheetAndReset();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Move failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  /// Show error dialog helper
  Future<void> _showErrorDialog(String title, String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(
          title,
          style: AppTheme.darkTheme.textTheme.bodyMedium
              ?.copyWith(color: Colors.white),
        ),
        content: Text(
          message,
          style: AppTheme.darkTheme.textTheme.bodyMedium
              ?.copyWith(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Close sheet and reset state
  void _closeSheetAndReset() {
    if (imageBytes != null) {
      ref.read(imageDocumentProvider.notifier).applyNewImage(imageBytes!);
    }
    setState(() {
      sheetOpen = false;
      activeTool = 'None';
      sheetContent = null;
    });
  }

  /// Build the draggable and clickable bin button
  Widget _buildBinButton(bool hasSelections, bool isDraggingOverBin) {
    return GestureDetector(
      onTap: () {
        // Click to delete all selections
        if (!_isErasing) {
          _handleEraseFromBin();
        }
      },
      onDoubleTap: () {
        // Double-tap to reset bin position to default
        setState(() {
          _binCustomOffset = null;
        });
      },
      onPanStart: (details) {
        // Get the actual current position of the bin from its RenderBox
        final box = _binKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          final position = box.localToGlobal(Offset.zero);
          setState(() {
            _isDraggingBin = true;
            _binCustomOffset = position;
          });
        } else {
          // Fallback to calculated position
          final screenSize = MediaQuery.of(context).size;
          final defaultBottom = sheetOpen ? 320.0 : 140.0;
          final defaultCenterX = screenSize.width / 2 - 32;
          final defaultY = screenSize.height - defaultBottom - 64;
          setState(() {
            _isDraggingBin = true;
            _binCustomOffset ??= Offset(defaultCenterX, defaultY);
          });
        }
      },
      onPanUpdate: (details) {
        setState(() {
          _binCustomOffset = Offset(
            (_binCustomOffset?.dx ?? 0) + details.delta.dx,
            (_binCustomOffset?.dy ?? 0) + details.delta.dy,
          );
        });
        // Update bin zone as it moves
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateBinZone();
        });
      },
      onPanEnd: (details) {
        setState(() {
          _isDraggingBin = false;
        });
        // Ensure bin zone is updated after drag ends
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateBinZone();
        });
      },
      child: AnimatedScale(
        scale: hasSelections ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          key: _binKey,
          duration: const Duration(milliseconds: 150),
          width: isDraggingOverBin ? 80 : 64,
          height: isDraggingOverBin ? 80 : 64,
          decoration: BoxDecoration(
            color: isDraggingOverBin
                ? Colors.red.withValues(alpha: 0.9)
                : const Color(0xFF2A2A2A).withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDraggingOverBin
                  ? Colors.red
                  : Colors.white.withValues(alpha: 0.3),
              width: isDraggingOverBin ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDraggingOverBin
                    ? Colors.red.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.4),
                blurRadius: isDraggingOverBin ? 20 : 12,
                spreadRadius: isDraggingOverBin ? 4 : 2,
              ),
            ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _isErasing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isDraggingOverBin
                          ? Icons.delete_forever
                          : Icons.delete_outline,
                      key: ValueKey(isDraggingOverBin),
                      color: Colors.white,
                      size: isDraggingOverBin ? 36 : 28,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the move button (shown when an object has been moved)
  Widget _buildMoveButton(bool isVisible) {
    return GestureDetector(
      onTap: () {
        if (!busy) {
          _handleMoveFromButton();
        }
      },
      child: AnimatedScale(
        scale: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.open_with,
                    color: Colors.white,
                    size: 28,
                  ),
          ),
        ),
      ),
    );
  }

  /// Handle move when move button is tapped
  Future<void> _handleMoveFromButton() async {
    final editingImage = ref.read(editingImageProvider);
    if (editingImage == null || imageBytes == null) {
      return;
    }

    final selections = editingImage.selections;
    final imageSize = editingImage.imageSize;

    await _handleMovedSelections(selections, imageSize);
  }

  void _openSheetFor(String label) {
    final mq = MediaQuery.of(context);
    final sx = mq.size.width / refW;
    final sy = mq.size.height / refH;

    Widget content;
    switch (label) {
      case 'Edit':
        content = EditSlider(
          sx: sx,
          sy: sy,
          onClose: () {
            setState(() {
              sheetOpen = false;
              activeTool = 'None';
              sheetContent = null;
            });
          },
        );
        // inside _openSheetFor when label == 'Prompt'
        break;
      case 'Select':
        content = SelectSlider(
          sx: sx,
          sy: sy,
          onClose: () {
            setState(() {
              sheetOpen = false;
              activeTool = 'None';
              sheetContent = null;
            });
          },
        );
        break;
      case 'Prompt':
        content = PromptSlider(
          sx: sx,
          sy: sy,
          onClose: () {
            setState(() {
              sheetOpen = false;
              activeTool = 'None';
              sheetContent = null;
            });
          },
          onSubmit: (String prompt) {
            // handle submit if you want (call API, close sheet, etc.)
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Prompt: $prompt')));
            }
          },
        );
        break;
      case 'Layers':
        content = LayersSlider(
          sx: sx,
          sy: sy,
          onClose: () {
            setState(() {
              sheetOpen = false;
              activeTool = 'None';
              sheetContent = null;
            });
          },
        );
        break;
      case 'Stylize':
        content = StylizeSlider(
          sx: sx,
          sy: sy,
          initialReferenceImage: _stylizeReferenceImage,
          onClose: () {
            setState(() {
              sheetOpen = false;
              activeTool = 'None';
              sheetContent = null;
              // Clear the reference image after use
              _stylizeReferenceImage = null;
              _stylizePresetName = null;
            });
          },
          onSubmit: ({
            required String prompt,
            String? selectedPreset,
            Uint8List? referenceImage,
          }) {
            setState(() {
              sheetOpen = false;
              activeTool = 'None';
              sheetContent = null;
            });
            // Stub API call - show snackbar with details
            if (context.mounted) {
              final details = <String>[];
              if (prompt.isNotEmpty) details.add('Prompt: $prompt');
              if (selectedPreset != null)
                details.add('Preset: $selectedPreset');
              if (referenceImage != null)
                details.add('Reference image attached');

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(details.isEmpty
                      ? 'Stylize: No input provided'
                      : 'Stylize: ${details.join(", ")}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            // TODO: Implement actual stylize API call here
          },
        );
        break;
      default:
        content = EditSlider(sx: sx, sy: sy);
    }

    setState(() {
      if (sheetOpen && activeTool == label) {
        sheetOpen = false;
        // when closing the currently open tool, reset to 'None' (no tool selected)
        activeTool = 'None';
        sheetContent = null;
      } else {
        sheetOpen = true;
        activeTool = label;
        sheetContent = content;
      }
    });
  }

  void _onNavTap(String label) => _openSheetFor(label);

  Future<void> _handleImageTap(Offset coordinate) async {
    if (imageBytes == null) return;

    final tapController = ref.read(tapSelectionControllerProvider);
    if (!tapController.isActive) return;

    try {
      await tapController.selectPoint(coordinate, imageBytes!, ref);

      if (context.mounted) {
        final bitmask = tapController.bitmask;

        // Send selection to backend
        if (bitmask != null && bitmask.isNotEmpty) {
          try {
            // Send the tap selection mask to backend using setMasks
            await AiApi.setMasks(masks: [bitmask]);
          } catch (e) {
            // Silently handle backend errors
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Point selected at: (${coordinate.dx.toInt()}, ${coordinate.dy.toInt()})\n'
              'Bitmask received: ${bitmask?.length ?? 0} x ${bitmask != null && bitmask.isNotEmpty ? bitmask[0].length : 0}',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refine selection: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(imageDocumentProvider);
    final tapController = ref.watch(tapSelectionControllerProvider);
    // ============================================================
    // TEST ERASE BUTTON STATE - START (CAN BE SAFELY DELETED)
    // ============================================================
    final eraseController = ref.watch(eraseControllerProvider);
    // ============================================================
    // TEST ERASE BUTTON STATE - END
    // ============================================================

    final inpaintController = ref.watch(inpaintControllerProvider);
    final moveController = ref.watch(moveControllerProvider);
    final imgToImgController = ref.watch(imgToImgControllerProvider);
    final stylizeController = ref.watch(stylizeControllerProvider);

    // Replace image when inpaint completes
    if (inpaintController.resultImage != null &&
        imageBytes != inpaintController.resultImage) {
      final newImage = inpaintController.resultImage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          imageBytes = newImage;
        });
        // Clear result to prevent infinite loop
        ref.read(inpaintControllerProvider).clear();
      });
    }

    // Replace image when move completes
    if (moveController.resultImage != null &&
        imageBytes != moveController.resultImage) {
      final newImage = moveController.resultImage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          imageBytes = newImage;
        });
        // Clear result to prevent infinite loop
        ref.read(moveControllerProvider).clearResult();
      });
    }

    // Replace image when img-to-img completes
    if (imgToImgController.resultImage != null &&
        imageBytes != imgToImgController.resultImage) {
      final newImage = imgToImgController.resultImage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          imageBytes = newImage;
        });
        // Clear result to prevent infinite loop
        ref.read(imgToImgControllerProvider).clearResult();
      });
    }

    // Replace image when stylize completes
    if (stylizeController.resultImage != null &&
        imageBytes != stylizeController.resultImage) {
      final newImage = stylizeController.resultImage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          imageBytes = newImage;
        });
        // Clear result to prevent infinite loop
        ref.read(stylizeControllerProvider).clearResult();
      });
    }

    final mq = MediaQuery.of(context);
    final sx = mq.size.width / refW;
    final sy = mq.size.height / refH;

    // sheet sizing is computed by child panels; no fixed height needed here

    final bg = AppTheme.darkTheme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Plain white canvas with centered image. Tapping the canvas opens Edit sheet.
          Center(
            // color: Color(0x393737),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // maxWidth: 288 * sx,
                maxHeight: 500 * sy,
              ),
              child: Container(
                decoration: BoxDecoration(
                  // use theme card color so panels/backgrounds keep exact 0xFF1E1E1E
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.none, // Allow cutouts to be dragged outside
                child: imageBytes != null
                    ? ImageCanvas(
                        imageBytes: imageBytes!,
                        maskBytes: maskBytes,
                        onTap: tapController.isActive ? _handleImageTap : null,
                        selectedPixelCoordinate:
                            tapController.selectedCoordinate,
                        binZone: _binZone,
                        onEraseRequested: _handleEraseFromBin,
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'Tap to add or edit image',
                            style: AppTheme.darkTheme.textTheme.bodyMedium
                                ?.copyWith(
                                    color: AppTheme
                                        .darkTheme.colorScheme.onSurface
                                        .withOpacity(0.7)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
              ),
            ),
          ),

          if (busy ||
              tapController.isProcessing ||
              eraseController.isProcessing ||
              inpaintController.isProcessing ||
              moveController.isProcessing ||
              imgToImgController.isProcessing ||
              stylizeController.isProcessing)
            const Positioned.fill(
                child: ColoredBox(color: Color.fromRGBO(0, 0, 0, 0.2))),
          if (busy ||
              tapController.isProcessing ||
              eraseController.isProcessing ||
              inpaintController.isProcessing ||
              moveController.isProcessing ||
              imgToImgController.isProcessing ||
              stylizeController.isProcessing)
            const Center(child: CircularProgressIndicator()),

          // TopNav (modular)
          Positioned(
            left: 0,
            right: 0,
            top: mq.padding.top + 6,
            child: TopNav(
              onBack: () => Navigator.of(context).pop(),
              onUndo: _undo,
              onRedo: _redo,
              onShare: () async {
                if (imageBytes != null) {
                  await SaveToGallery(imageBytes!, context);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved to gallery')));
                }
              },
            ),
          ),

          // Left side tool buttons (Stylize + MagicView stacked)
          Positioned(
            left: 18 * sx,
            top: 133 * sy,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(200),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  width: 150,
                  height: 72,
                  padding: const EdgeInsets.all(10),
                  decoration: ShapeDecoration(
                    color: AppTheme.darkTheme.cardColor.withOpacity(0.5),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(200))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      GestureDetector(
                        onTap: () => _openSheetFor('Stylize'),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/icons/Vector.png',
                                width: 24,
                                height: 24,
                                color: AppTheme.darkTheme.colorScheme.onSurface),
                            Text('Stylize',
                                textAlign: TextAlign.center,
                                style: AppTheme.darkTheme.textTheme.bodySmall
                                    ?.copyWith(
                                        color: AppTheme
                                            .darkTheme.colorScheme.onSurface,
                                        fontSize: 8,
                                        height: 2.20)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // MagicView button
                      GestureDetector(
                        onTap: () => _openMagicViewPopup(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                                'assets/icons/auto_enhancer.png',
                                width: 30,
                                height: 30,
                                color: AppTheme
                                    .darkTheme.colorScheme.onSurface),
                            Text('Auto Enhance',
                                textAlign: TextAlign.center,
                                style: AppTheme
                                    .darkTheme.textTheme.bodySmall
                                    ?.copyWith(
                                        color: AppTheme.darkTheme
                                            .colorScheme.onSurface,
                                        fontSize: 8,
                                        height: 2.20)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            right: 0,
            top: 133 * sy,
            // right: 0,
            child: Image.asset(
              'assets/images/ai_ass.png',
              width: 72,
              height: 72,
            ),
          ),
          // Floating add image button (hidden when sheet open)
          (!sheetOpen)
              ? Positioned(
                  right: 18 * sx,
                  top: 649 * sy,
                  child: GestureDetector(
                    onTap: _showAddImagePopup,
                    child: Container(
                      width: 56,
                      height: 56,
                      // padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                      clipBehavior: Clip.antiAlias,
                      decoration: ShapeDecoration(
                        color: AppTheme.darkTheme.colorScheme.onSecondary,
                        shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(200))),
                      ),
                      child: Center(
                        child: Icon(Icons.add,
                            color: AppTheme.darkTheme.colorScheme.onSurface,
                            size: 35),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),

          // Selection tool indicator (shown when slider is closed but tool is active)
          // if (!sheetOpen)
          //   Positioned(
          //     left: 16,
          //     bottom: 90,
          //     child: SelectionToolIndicator(
          //       onTap: () => _openSheetFor('Select'),
          //     ),
          //   ),

          // Bin icon for deleting selected objects
          // Only show in Action Phase (Phase 2) when slider is open
          // Now clickable to delete and draggable to reposition
          Consumer(
            builder: (context, ref, child) {
              final hasSelections = ref.watch(hasImageSelectionsProvider);
              final hasMovedSelections = ref.watch(hasMovedSelectionsProvider);
              final isDraggingOverBin = ref.watch(isDraggingOverBinProvider);
              final toolState = ref.watch(selectionModeProvider);
              final screenSize = MediaQuery.of(context).size;

              // Only show floating buttons in Action Phase when slider is open
              final showFloatingButtons = toolState.isSliderOpen &&
                  toolState.isActionPhase &&
                  hasSelections;

              // Calculate default position (center-bottom above nav)
              final defaultBottom = sheetOpen ? 320.0 : 140.0;
              final defaultX = screenSize.width / 2 -
                  32; // Center horizontally (32 = half of 64)
              final defaultY =
                  screenSize.height - defaultBottom - 64; // Position from top

              // Update bin zone after layout
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _updateBinZone();
              });

              // Build the buttons row (bin + move if moved)
              Widget buildButtonsRow() {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bin button (delete)
                    Opacity(
                      opacity: showFloatingButtons ? 1.0 : 0.0,
                      child: _buildBinButton(
                          showFloatingButtons, isDraggingOverBin),
                    ),
                    // Move button (shown when object is moved)
                    if (hasMovedSelections && showFloatingButtons) ...[
                      const SizedBox(width: 16),
                      _buildMoveButton(hasMovedSelections),
                    ],
                  ],
                );
              }

              // If we have a custom offset, use Positioned; otherwise use AnimatedPositioned
              if (_binCustomOffset != null || _isDraggingBin) {
                final currentOffset =
                    _binCustomOffset ?? Offset(defaultX, defaultY);

                return Positioned(
                  left: currentOffset.dx,
                  top: currentOffset.dy,
                  child: buildButtonsRow(),
                );
              }

              // Default animated position (before any drag)
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                left: 0,
                right: 0,
                bottom: showFloatingButtons ? (sheetOpen ? 320 : 140) : -100,
                child: Center(
                  child: buildButtonsRow(),
                ),
              );
            },
          ),

          // Floating bottom nav: positioned ABOVE the sheet (dynamic)
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              (activeTool != 'Stylize')
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Builder(builder: (ctx) {
                            final compact = sheetOpen;
                            return FloatingBottomNav(
                              key: ValueKey(compact),
                              sx: sx,
                              sy: sy,
                              compact: compact,
                              backgroundColor: AppTheme.darkTheme.cardColor,
                              horizontalPadding: compact ? 12 : 24,
                              itemSpacing: compact ? 10 : 26,
                              items: [
                                FloatingNavItem(
                                    iconAsset: 'assets/icons/Crop.png',
                                    label: 'Edit',
                                    onTap: () => _onNavTap('Edit'),
                                    color: activeTool == 'Edit'
                                        ? AppTheme
                                            .darkTheme.colorScheme.onSecondary
                                        : AppTheme
                                            .darkTheme.colorScheme.onSurface),
                                FloatingNavItem(
                                    iconAsset:
                                        'assets/icons/select-cursor-svgrepo-com.png',
                                    label: 'Select',
                                    onTap: () => _onNavTap('Select'),
                                    color: activeTool == 'Select'
                                        ? AppTheme
                                            .darkTheme.colorScheme.onSecondary
                                        : AppTheme
                                            .darkTheme.colorScheme.onSurface),
                                FloatingNavItem(
                                    iconAsset: 'assets/icons/Vector.png',
                                    label: 'Prompt',
                                    onTap: () => _onNavTap('Prompt'),
                                    color: activeTool == 'Prompt'
                                        ? AppTheme
                                            .darkTheme.colorScheme.onSecondary
                                        : AppTheme
                                            .darkTheme.colorScheme.onSurface),
                                FloatingNavItem(
                                    iconAsset: 'assets/icons/Layers.png',
                                    label: 'Layers',
                                    onTap: () => _onNavTap('Layers'),
                                    color: activeTool == 'Layers'
                                        ? AppTheme
                                            .darkTheme.colorScheme.onSecondary
                                        : AppTheme
                                            .darkTheme.colorScheme.onSurface),
                              ],
                            );
                          }),
                        ),
                        // Tick button: moves together with nav and hides when sheet closed.
                        // HIDE for Select tool - SelectSlider has its own tick/action buttons
                        (sheetOpen && activeTool != 'Select')
                            ? AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeInOut,
                                switchOutCurve: Curves.easeInOut,
                                // right: 30,
                                // left: 60,
                                // bottom: defaultNavBottom,
                                child: AnimatedScale(
                                  scale: (sheetOpen && activeTool != 'Select')
                                      ? 1.0
                                      : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: GestureDetector(
                                    onTap: () async {
                                      // Default behavior for other tools
                                      if (imageBytes != null)
                                        await ref
                                            .read(
                                                imageDocumentProvider.notifier)
                                            .applyNewImage(imageBytes!);
                                      setState(() {
                                        sheetOpen = false;
                                        // finalize edit and clear selection
                                        activeTool = 'None';
                                        sheetContent = null;
                                      });
                                    },
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      margin: EdgeInsets.only(right: 20),
                                      padding: const EdgeInsets.all(8),
                                      clipBehavior: Clip.antiAlias,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF3B62FB),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 8,
                                              offset: Offset(0, 4))
                                        ],
                                      ),
                                      child: const Center(
                                          child: Icon(Icons.check,
                                              color: Colors.white, size: 24)),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ],
                    )
                  : const SizedBox.shrink(),
              // Bottom sheet content: render as a normal child at the end of this Column
              sheetOpen
                  ? AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: double.infinity,
                      child: sheetContent ?? const SizedBox.shrink(),
                    )
                  : const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Options for Auto Enhance popup
enum AutoEnhanceOption {
  enhance, // Auto enhance (color, brightness, sharpness)
  extend,  // Extend canvas background (canvas mode only)
}

/// Auto Enhance dialog with options
/// For canvas mode: Shows 2 options (Enhance and Extend)
/// For non-canvas mode: Shows only Enhance option (with confirmation)
class _AutoEnhanceDialog extends StatelessWidget {
  final bool isCanvasMode;

  const _AutoEnhanceDialog({required this.isCanvasMode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final sx = mq.size.width / refW;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 340 * sx,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: title + close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Auto Enhance',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurface,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Description
              Text(
                isCanvasMode
                    ? 'Choose an enhancement option for your canvas:'
                    : 'Enhance your image with AI-powered adjustments:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              // Option 1: Enhance
              _buildOptionTile(
                context: context,
                icon: Icons.auto_fix_high,
                iconColor: const Color(0xFF4CAF50),
                title: 'Enhance',
                description: 'Improve colors, brightness, contrast and sharpness automatically.',
                features: const [
                  'Auto exposure & brightness',
                  'Color balance correction',
                  'Image sharpening',
                ],
                onTap: () => Navigator.of(context).pop(AutoEnhanceOption.enhance),
              ),

              // Option 2: Extend (only for canvas mode)
              if (isCanvasMode) ...[
                const SizedBox(height: 16),
                _buildOptionTile(
                  context: context,
                  icon: Icons.crop_free,
                  iconColor: const Color(0xFF2196F3),
                  title: 'Extend',
                  description: 'Fill canvas borders with mirrored content from the image edges.',
                  features: const [
                    'Smart edge detection',
                    'Mirror reflection fill',
                    'Smooth blending',
                  ],
                  onTap: () => Navigator.of(context).pop(AutoEnhanceOption.extend),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required List<String> features,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.onSurface.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Title and description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow indicator
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Features list
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: iconColor.withOpacity(0.7),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    feature,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
