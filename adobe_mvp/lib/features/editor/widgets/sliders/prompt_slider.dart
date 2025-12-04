// features/editor/widgets/sliders/prompt_slider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:adobe_mvp/features/editor/controllers/img_to_img_controller.dart';
import 'package:adobe_mvp/services/speech_to_text_service.dart';

/// Prompt slider panel for text-based editing prompts.
/// Shows suggestion chips and a text input field.
/// Calls /imgtoimg API on submit via ImgToImgController.
class PromptSlider extends ConsumerStatefulWidget {
  final double sx;
  final double sy;
  final VoidCallback? onClose;
  final void Function(String prompt)? onSubmit;

  const PromptSlider({
    super.key,
    this.sx = 1.0,
    this.sy = 1.0,
    this.onClose,
    this.onSubmit,
  });

  @override
  ConsumerState<PromptSlider> createState() => _PromptSliderState();
}

class _PromptSliderState extends ConsumerState<PromptSlider> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final SpeechToTextService _speechService = SpeechToTextService();
  bool _isListening = false;

  // Suggestion chip texts
  static const List<String> _suggestions = [
    'Change the scene to night',
    'Change Car\'s Color to Red',
  ];

  @override
  void initState() {
    super.initState();
    _speechService.initialize();
  }

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

  void _onChipTap(String suggestion) {
    _controller.text = suggestion;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    _focusNode.requestFocus();
  }

  Future<void> _onSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final controller = ref.read(imgToImgControllerProvider);
    if (controller.isProcessing) return;

    try {
      await ref.read(imgToImgControllerProvider).transformImage(text);
      
      if (mounted) {
        widget.onSubmit?.call(text);
        _controller.clear();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Applied: \$text')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: \$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ref.watch(imgToImgControllerProvider);
    final isLoading = controller.isProcessing;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 32),
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
        children: [
          // Handle bar
          GestureDetector(
              onTap: widget.onClose,
              onVerticalDragEnd: (details) {
                // Swipe down to close
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
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )))),
          const SizedBox(height: 16),

          // Suggestion chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _suggestions.asMap().entries.map((entry) {
                final idx = entry.key;
                final text = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                      right: idx < _suggestions.length - 1 ? 8 : 0),
                  child: _SuggestionChip(
                    text: text,
                    onTap: () => _onChipTap(text),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Input field pill
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(60),
            ),
            child: Row(
              children: [
                Expanded(
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
                      hintText: 'Type out the edit you want to perform',
                      hintStyle: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w400,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: (_) => _onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                // Mic button for voice input
                GestureDetector(
                  onTap: isLoading ? null : _toggleListening,
                  child: Container(
                    width: 36,
                    height: 36,
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
                // Send button with loading state
                GestureDetector(
                  onTap: isLoading ? null : _onSend,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isLoading 
                          ? theme.colorScheme.primary.withValues(alpha: 0.5)
                          : theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            Icons.auto_awesome,
                            color: theme.cardColor,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual suggestion chip widget.
class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const _SuggestionChip({
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(60),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sparkle/AI icon
            Icon(
              Icons.auto_awesome,
              size: 14,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
