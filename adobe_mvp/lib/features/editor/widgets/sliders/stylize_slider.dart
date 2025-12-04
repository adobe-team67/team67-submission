// features/editor/widgets/sliders/stylize_slider.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:adobe_mvp/features/editor/controllers/stylize_controller.dart';
import 'package:adobe_mvp/ui/theme/app_theme.dart';
import 'package:adobe_mvp/services/speech_to_text_service.dart';

/// Preset style data model
class StylePreset {
  final String name;
  final String imageUrl;

  const StylePreset({required this.name, required this.imageUrl});
}

/// StylizeSlider: Custom style reference panel with file attachment, prompt input, and preset styles.
/// Calls /stylize API on submit via StylizeController.
class StylizeSlider extends ConsumerStatefulWidget {
  final double sx;
  final double sy;
  final VoidCallback? onClose;
  final void Function({
    required String prompt,
    String? selectedPreset,
    Uint8List? referenceImage,
  })? onSubmit;
  final Uint8List? initialReferenceImage;

  const StylizeSlider({
    super.key,
    this.sx = 1.0,
    this.sy = 1.0,
    this.onClose,
    this.onSubmit,
    this.initialReferenceImage,
  });

  @override
  ConsumerState<StylizeSlider> createState() => _StylizeSliderState();
}

class _StylizeSliderState extends ConsumerState<StylizeSlider> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  final SpeechToTextService _speechService = SpeechToTextService();
  bool _isListening = false;

  Uint8List? _attachedImage;
  String? _selectedPreset;

  @override
  void initState() {
    super.initState();
    // Initialize with reference image if provided
    _attachedImage = widget.initialReferenceImage;
    // Initialize speech service
    _speechService.initialize();
  }

  // Sample preset styles - replace with actual assets/URLs
  static const List<StylePreset> _presets = [
    StylePreset(name: 'Cinematic', imageUrl: 'assets/style_sample.png'),
    StylePreset(name: 'Vintage', imageUrl: 'assets/style_sample.png'),
    StylePreset(name: 'Neon', imageUrl: 'assets/style_sample.png'),
    StylePreset(name: 'Watercolor', imageUrl: 'assets/style_sample.png'),
    StylePreset(name: 'Oil Paint', imageUrl: 'assets/style_sample.png'),
    StylePreset(name: 'Sketch', imageUrl: 'assets/style_sample.png'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
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
            _controller.text = text;
            _controller.selection = TextSelection.fromPosition(
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

  Future<void> _pickImage() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() => _attachedImage = bytes);
    }
  }

  void _removeAttachedImage() {
    setState(() => _attachedImage = null);
  }

  void _selectPreset(String presetName) {
    setState(() {
      _selectedPreset = _selectedPreset == presetName ? null : presetName;
    });
    
    // If a preset is selected, show confirmation dialog
    if (_selectedPreset != null) {
      _showPresetConfirmationDialog(presetName);
    }
  }

  /// Shows confirmation dialog when a preset is selected
  Future<void> _showPresetConfirmationDialog(String presetName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Apply \$presetName Style?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'This will apply the \$presetName style to your image.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              setState(() => _selectedPreset = null);
            },
            child: Text(
              'Cancel',
              style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.darkTheme.colorScheme.onSurface,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: Text('Apply', style: TextStyle(color: AppTheme.darkTheme.scaffoldBackgroundColor, fontFamily: 'Adobe Clean')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _applyStyle();
    } else {
      setState(() => _selectedPreset = null);
    }
  }

  /// Applies the stylize API with current settings using StylizeController
  Future<void> _applyStyle() async {
    final controller = ref.read(stylizeControllerProvider);
    if (controller.isProcessing) return;

    // Need either a preset or reference image
    if (_selectedPreset == null && _attachedImage == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a preset or attach a reference image')),
        );
      }
      return;
    }

    final text = _controller.text.trim();

    try {
      await ref.read(stylizeControllerProvider).stylizeImage(
        prompt: text,
        style: _selectedPreset,
        targetImage: _attachedImage,
      );
      
      if (mounted) {
        widget.onSubmit?.call(
          prompt: text,
          selectedPreset: _selectedPreset,
          referenceImage: _attachedImage,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Applied style: ${_selectedPreset ?? "Custom"}')),
        );
        
        // Close slider after successful apply
        widget.onClose?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: \$e')),
        );
      }
    }
  }

  void _onSend() {
    // If reference image is attached or preset selected, apply style
    if (_attachedImage != null || _selectedPreset != null) {
      _applyStyle();
    } else {
      // Just callback with text only
      final text = _controller.text.trim();
      widget.onSubmit?.call(
        prompt: text,
        selectedPreset: _selectedPreset,
        referenceImage: _attachedImage,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ref.watch(stylizeControllerProvider);
    final isLoading = controller.isProcessing;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 32),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: theme.cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar - swipe down to close
          GestureDetector(
            onTap: widget.onClose,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! > 100) {
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
                    color: theme.colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),

          // Title
          Text(
            'Custom Style Reference',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // Input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAttachmentButton(theme),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: !isLoading,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: 'Describe the style you want',
                      hintStyle: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _onSend(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Mic button for voice input
              GestureDetector(
                onTap: isLoading ? null : _toggleListening,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isListening 
                        ? Colors.red
                        : theme.colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.white : theme.colorScheme.onSurface,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isLoading ? null : _onSend,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isLoading 
                        ? theme.colorScheme.onSecondary.withValues(alpha: 0.5)
                        : theme.colorScheme.onSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.auto_awesome_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Presets title
          Text(
            'Presets',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // Presets horizontal scroll
          SizedBox(
            height: 120,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _presets.map((preset) {
                  final isSelected = _selectedPreset == preset.name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _PresetCard(
                      preset: preset,
                      isSelected: isSelected,
                      onTap: () => _selectPreset(preset.name),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentButton(ThemeData theme) {
    if (_attachedImage != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: MemoryImage(_attachedImage!),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: _removeAttachedImage,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 12),
              ),
            ),
          ),
        ],
      );
    } else {
      return GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.asset(
            'assets/icons/Paperclip.png',
            width: 24,
            height: 24,
            color: theme.colorScheme.onSurface,
          ),
        ),
      );
    }
  }
}

/// Preset style card widget
class _PresetCard extends StatelessWidget {
  final StylePreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetCard({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary, width: 1)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image(
              image: AssetImage(preset.imageUrl),
              width: 101,
              height: 68,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 101,
                  height: 68,
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.style_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      size: 32,
                    ),
                  ),
                );
              },
            ),
            Container(
              width: 101,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: const ShapeDecoration(
                color: Color(0xFF383737),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                  ),
                ),
              ),
              child: Text(
                preset.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
