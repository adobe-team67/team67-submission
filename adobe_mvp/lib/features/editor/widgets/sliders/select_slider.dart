import 'dart:typed_data';
import 'package:adobe_mvp/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/tap_selection_controller.dart';
import '../../controllers/inpaint_controller.dart';
import '../../controllers/selection_mode_controller.dart';
import '../../controllers/brush_controller.dart';
import '../../../../state/providers.dart';
import '../../../../state/editing_image_manager.dart';
import '../../../../models/detected_object.dart';
import '../../../../models/editing_image.dart';
import '../../../../ui/widgets/custom_loader.dart';
import '../../../../services/ai_api.dart';
import '../../../../services/speech_to_text_service.dart';

/// SelectSlider: Two-phase selection panel.
/// Phase 1 (Selection): Object list, lasso/brush tools, +/- mode, tick to continue
/// Phase 2 (Action): Prompt bar only (floating buttons for erase/move are separate)
class SelectSlider extends ConsumerStatefulWidget {
  final double sx;
  final double sy;
  final VoidCallback? onClose;
  const SelectSlider({Key? key, this.sx = 1.0, this.sy = 1.0, this.onClose})
      : super(key: key);

  @override
  ConsumerState<SelectSlider> createState() => _SelectSliderState();
}

class _SelectSliderState extends ConsumerState<SelectSlider>
    with TickerProviderStateMixin {
  bool _busy = false;
  final TextEditingController _ctrl = TextEditingController();
  final SpeechToTextService _speechService = SpeechToTextService();
  bool _isListening = false;
  
  // Cached preview images for detected objects
  final Map<int, Uint8List> _previewCache = {};

  @override
  void initState() {
    super.initState();
    // Mark slider as open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectionModeProvider.notifier).setSliderOpen(true);
      _checkAndTriggerDetection();
    });
    
    // Initialize speech service
    _speechService.initialize();
    
    // Sync text controller with provider
    _ctrl.addListener(_onPromptChanged);
  }
  
  void _onPromptChanged() {
    // Update the provider with current text
    ref.read(selectPromptProvider.notifier).state = _ctrl.text;
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onPromptChanged);
    // Clear the prompt when slider closes
    ref.read(selectPromptProvider.notifier).state = '';
    // Mark slider as closed (reset to selection phase)
    ref.read(selectionModeProvider.notifier).setSliderOpen(false);
    _ctrl.dispose();
    _speechService.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speechService.stopListening();
      setState(() => _isListening = false);
    } else {
      final initialized = await _speechService.initialize();
      if (!initialized) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_speechService.lastError),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      setState(() => _isListening = true);
      await _speechService.startListening(
        onResult: (text) {
          setState(() {
            _ctrl.text = text;
            _ctrl.selection = TextSelection.fromPosition(
              TextPosition(offset: text.length),
            );
          });
        },
        onComplete: () {
          setState(() => _isListening = false);
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          }
        },
      );
    }
  }

  /// Check if detection is needed and trigger if not already complete
  void _checkAndTriggerDetection() {
    final detectionComplete = ref.read(detectionCompleteProvider);
    final isDetecting = ref.read(imageIsDetectingProvider);
    
    if (!detectionComplete && !isDetecting) {
      _detectObjectsManually();
    } else if (detectionComplete) {
      _loadExistingPreviews();
    }
  }
  
  /// Load existing previews from detected objects into local cache
  void _loadExistingPreviews() {
    final objects = ref.read(imageDetectedObjectsProvider);
    for (final obj in objects) {
      if (obj.previewBytes != null) {
        _previewCache[obj.index] = obj.previewBytes!;
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// Run YOLO detection manually (only if background detection hasn't completed)
  Future<void> _detectObjectsManually() async {
    final imageBytes = ref.read(currentImageBytesProvider);
    if (imageBytes == null) return;
    
    final imageManager = ref.read(editingImageProvider.notifier);
    imageManager.setDetecting(true);
    
    try {
      final yolo = ref.read(yoloProvider);
      final result = await yolo.detectFromBytes(imageBytes);
      
      if (result.masks.isNotEmpty) {
        final objects = <DetectedObject>[];
        
        for (int i = 0; i < result.masks.length; i++) {
          objects.add(DetectedObject(
            index: i,
            mask: result.masks[i],
            box: result.boxes[i],
            classId: result.classIds[i],
            confidence: result.confidences[i],
          ));
        }
        
        objects.sort((a, b) => b.confidence.compareTo(a.confidence));
        imageManager.setDetectedObjects(objects);
        _sendMasksToBackend(result.masks);
        imageManager.setDetectionComplete(true);
        _generatePreviews(objects, imageBytes);
      } else {
        imageManager.setDetectedObjects([]);
        imageManager.setDetectionComplete(true);
      }
    } catch (e) {
      imageManager.setDetecting(false);
    }
  }
  
  /// Send detected masks to backend API
  Future<void> _sendMasksToBackend(List<List<List<int>>> masks) async {
    try {
      await AiApi.setMasks(masks: masks);
    } catch (e) {
      // Failed to send masks to backend
    }
  }
  
  /// Generate preview images for all detected objects
  Future<void> _generatePreviews(List<DetectedObject> objects, Uint8List imageBytes) async {
    final imageManager = ref.read(editingImageProvider.notifier);
    
    for (final obj in objects) {
      try {
        final preview = await obj.generatePreview(imageBytes);
        imageManager.updateObjectPreview(obj.index, preview);
        if (mounted) {
          setState(() {
            _previewCache[obj.index] = preview;
          });
        }
      } catch (e) {
        // Error generating preview
      }
    }
  }

  /// Handle object selection from the list
  Future<void> _onObjectSelected(DetectedObjectState obj) async {
    final imageManager = ref.read(editingImageProvider.notifier);
    
    await imageManager.toggleObjectSelection(obj.index);
    
    final tapController = ref.read(tapSelectionControllerProvider);
    tapController.setMask(obj.mask);
    
    final isSelected = imageManager.isObjectSelected(obj.index);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSelected 
                ? 'Selected: ${obj.className} (${(obj.confidence * 100).toStringAsFixed(0)}%)'
                : 'Deselected: ${obj.className}',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// Go to action phase - called when user taps tick
  void _goToActionPhase() {
    final selections = ref.read(imageSelectionsProvider);
    if (selections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one object first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    ref.read(selectionModeProvider.notifier).goToActionPhase();
  }
  
  /// Go back to selection phase
  void _goToSelectionPhase() {
    ref.read(selectionModeProvider.notifier).goToSelectionPhase();
  }

  /// Build the horizontal list of detected objects
  Widget _buildDetectedObjectsList() {
    final theme = AppTheme.darkTheme;
    final isDetecting = ref.watch(imageIsDetectingProvider);
    final objects = ref.watch(imageDetectedObjectsProvider);
    
    if (isDetecting) {
      return Container(
        height: 100,
        margin: const EdgeInsets.only(bottom: 16),
        child: LoadingOverlay(
          isLoading: true,
          cellSize: 16,
          lightColor: const Color(0x44FFFFFF),
          darkColor: const Color(0x22FFFFFF),
          overlayOpacity: 0.8,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemBuilder: (context, index) {
              return _PlaceholderCard();
            },
          ),
        ),
      );
    }
    
    if (objects.isEmpty) {
      return Container(
        height: 80,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No objects detected',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ),
      );
    }
    
    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: objects.length,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemBuilder: (context, index) {
          final obj = objects[index];
          final preview = obj.previewBytes ?? _previewCache[obj.index];
          final isPreviewLoading = obj.isPreviewLoading && preview == null;
          
          return _DetectedObjectCard(
            objectState: obj,
            previewBytes: preview,
            isPreviewLoading: isPreviewLoading,
            onTap: () => _onObjectSelected(obj),
          );
        },
      ),
    );
  }

  /// Build horizontal brush size slider (shown when brush tool is active)
  Widget _buildHorizontalBrushSizeSlider() {
    final theme = AppTheme.darkTheme;
    final toolState = ref.watch(selectionModeProvider);
    final brushSize = ref.watch(brushSizeProvider);
    
    // Only show when brush tool is selected
    if (toolState.tool != SelectionTool.brush) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Size preview circle
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.darkTheme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Container(
                width: brushSize * 0.28,
                height: brushSize * 0.28,
                decoration: BoxDecoration(
                  color: AppTheme.darkTheme.colorScheme.onPrimary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Horizontal slider
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                activeTrackColor: AppTheme.darkTheme.colorScheme.onPrimary,
                inactiveTrackColor: Colors.white.withOpacity(0.2),
                thumbColor: AppTheme.darkTheme.colorScheme.onPrimary,
                overlayColor: AppTheme.darkTheme.colorScheme.onPrimary.withOpacity(0.16),
              ),
              child: Slider(
                value: brushSize,
                min: 10,
                max: 100,
                onChanged: (value) {
                  ref.read(brushControllerProvider.notifier).setBrushSize(value);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Size label
          Container(
            width: 36,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${brushSize.round()}',
              style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolChip(String label, SelectionTool tool) {
    final toolState = ref.watch(selectionModeProvider);
    final selected = toolState.tool == tool && toolState.isActive;
    final theme = AppTheme.darkTheme;
    
    String iconAsset;
    switch (tool) {
      case SelectionTool.lasso:
        iconAsset = 'assets/icons/lasso-svgrepo-com 1.png';
        break;
      case SelectionTool.brush:
        iconAsset = 'assets/icons/brush-svgrepo-com 1.png';
        break;
      default:
        iconAsset = 'assets/icons/select-cursor-svgrepo-com 1.png';
    }
    
    return GestureDetector(
      onTap: () {
        final controller = ref.read(selectionModeProvider.notifier);
        controller.toggleTool(tool);
        
        if (!selected && mounted) {
          String message;
          switch (tool) {
            case SelectionTool.lasso:
              message = 'Lasso mode: Draw around objects to select';
              break;
            case SelectionTool.brush:
              message = 'Brush mode: Paint over areas to select';
              break;
            default:
              message = 'Selection tool activated';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: ShapeDecoration(
          color: selected ? theme.colorScheme.onSecondary : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              iconAsset,
              width: 12,
              height: 12,
              color: selected ? Colors.white : theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: selected ? Colors.white : theme.colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _plusMinusToggle() {
    final theme = AppTheme.darkTheme;
    final mode = ref.watch(currentModeProvider);
    final add = mode == SelectionMode.add;
    final green = theme.colorScheme.tertiary;

    return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _busy
                  ? null
                  : () {
                      ref.read(selectionModeProvider.notifier).setMode(SelectionMode.add);
                    },
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: add ? green : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
            GestureDetector(
              onTap: _busy
                  ? null
                  : () {
                      ref.read(selectionModeProvider.notifier).setMode(SelectionMode.subtract);
                    },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: add
                      ? Colors.transparent
                      : theme.colorScheme.inversePrimary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.remove,
                    color: add
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface),
              ),
            ),
          ],
        ));
  }

  /// Build prompt bar (shown only in action phase)
  Widget _buildPromptBar() {
    final theme = AppTheme.darkTheme;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30)),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: _goToSelectionPhase,
            child: Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.3)),
              ),
              child: Image.asset('assets/icons/Chevron left.png', width: 18, height: 18, color: theme.colorScheme.onSurface),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
              decoration: InputDecoration.collapsed(
                hintText: 'Describe what to do with selection...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary.withOpacity(0.7)),
              ),
              onSubmitted: (v) => _handlePromptSubmit(v),
            ),
          ),
          const SizedBox(width: 8),
          // Mic button for voice input
          GestureDetector(
            onTap: _busy ? null : _toggleListening,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isListening 
                    ? Colors.red
                    : theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Colors.white : theme.colorScheme.onSurface,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _busy ? null : () => _handlePromptSubmit(_ctrl.text),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle),
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.send, color: AppTheme.darkTheme.cardColor, size: 18),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Handle prompt submission for inpainting
  Future<void> _handlePromptSubmit(String text) async {
    final v = text.trim();
    if (v.isEmpty) return;
    
    final selections = ref.read(imageSelectionsProvider);
    if (selections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No selection to process'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      final inpaintController = ref.read(inpaintControllerProvider);
      await inpaintController.inpaintSelection(v);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inpaint completed! Check the canvas.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _ctrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Inpaint failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Build tick button to continue to action phase
  Widget _buildTickButton() {
    final theme = AppTheme.darkTheme;
    final selections = ref.watch(imageSelectionsProvider);
    final hasSelections = selections.isNotEmpty;
    
    return GestureDetector(
      onTap: hasSelections ? _goToActionPhase : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: hasSelections 
              ? theme.colorScheme.onSecondary 
              : theme.colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          boxShadow: hasSelections ? [
            BoxShadow(
              color: theme.colorScheme.onSecondary.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ] : null,
        ),
        child: Icon(
          Icons.check,
          size: 24,
          color: hasSelections 
              ? Colors.white 
              : theme.colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.darkTheme;
    final isSelectionPhase = ref.watch(isSelectionPhaseProvider);
    final isActionPhase = ref.watch(isActionPhaseProvider);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 32),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: theme.cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          GestureDetector(
              onTap: widget.onClose,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! > 100) {
                  widget.onClose?.call();
                }
              },
              child: Container(
                  color: Colors.transparent,
                  width: double.infinity,
                  height: 30,
                  child: Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: theme.colorScheme.onPrimary,
                              borderRadius: BorderRadius.circular(4)))))),
          
          // === SELECTION PHASE UI ===
          if (isSelectionPhase) ...[
            // Detected objects horizontal list
            _buildDetectedObjectsList(),
            
            // Horizontal brush size slider (only when brush is active)
            _buildHorizontalBrushSizeSlider(),
            
            // Tools row: Lasso, Brush, +/-, Tick button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: Row(
                    children: [
                      _toolChip('Lasso', SelectionTool.lasso),
                      _toolChip('Brush', SelectionTool.brush),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _plusMinusToggle(),
                    const SizedBox(width: 12),
                    _buildTickButton(),
                  ],
                ),
              ],
            ),
          ],
          
          // === ACTION PHASE UI ===
          if (isActionPhase) ...[
            // Only prompt bar in action phase (floating buttons are separate)
            _buildPromptBar(),
          ],
        ],
      ),
    );
  }
}

/// Card widget for displaying a detected object preview
class _DetectedObjectCard extends StatelessWidget {
  final DetectedObjectState objectState;
  final Uint8List? previewBytes;
  final bool isPreviewLoading;
  final VoidCallback onTap;

  const _DetectedObjectCard({
    required this.objectState,
    required this.previewBytes,
    required this.isPreviewLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.darkTheme;
    final isSelected = objectState.isSelected;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.tertiary 
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.tertiary.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF2A2A2A),
              ),
              clipBehavior: Clip.antiAlias,
              child: isPreviewLoading
                  ? LoadingOverlay(
                      isLoading: true,
                      cellSize: 8,
                      lightColor: const Color(0x44FFFFFF),
                      darkColor: const Color(0x22FFFFFF),
                      overlayOpacity: 0.9,
                      child: Container(
                        color: const Color(0xFF2A2A2A),
                      ),
                    )
                  : previewBytes != null
                      ? Image.memory(
                          previewBytes!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
                        )
                      : _buildPlaceholder(theme),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                objectState.className,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected 
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.onSurface.withOpacity(0.9),
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 24,
        color: theme.colorScheme.onSurface.withOpacity(0.3),
      ),
    );
  }
}

/// Placeholder card shown while detecting objects
class _PlaceholderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF2A2A2A),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 48,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: const Color(0xFF3A3A3A),
            ),
          ),
        ],
      ),
    );
  }
}
