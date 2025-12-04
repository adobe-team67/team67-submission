// lib/features/learn/learn_screen.dart
import 'dart:typed_data';
import 'package:adobe_mvp/core/constants.dart';
import 'package:adobe_mvp/core/global.dart';
import 'package:adobe_mvp/features/learn/widgets/tutorial_card.dart';
import 'package:adobe_mvp/ui/widgets/app_bottom_nav.dart';
import 'package:adobe_mvp/ui/widgets/home_top_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:adobe_mvp/ui/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.darkTheme;
    final bg = theme.scaffoldBackgroundColor;
    final mq = MediaQuery.of(context);
    final sx = mq.size.width / refW;
    final sy = mq.size.height / refH;


    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: SingleChildScrollView(
          // scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            HomeTopNav(),
            const SizedBox(height: 8),
            Text('Learn', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            Text('Feature Tutorials', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            // tutorial cards - using AppTutorials data
            SizedBox(
              height: 246 * sy,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: AppTutorials.learnTutorials.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) => TutorialCard.fromTutorial(
                  tutorial: AppTutorials.learnTutorials[i],
                  sx: sx,
                  index: i,
                ),
              ),
            ),

            const SizedBox(height: 20),
            Text('Try Trends with Stylize', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            // stylize cards (horizontal) - using AppTutorials.stylizeTrends
            SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: AppTutorials.stylizeTrends.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) => TutorialCard.fromTutorial(
                  tutorial: AppTutorials.stylizeTrends[i],
                  sx: sx,
                  index: i + 3,
                ),
              ),
            ),

            const SizedBox(height: 20),
            Text('What’s New', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            SizedBox(
              height: 170,
              child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (ctx, i) => TutorialCard(title: 'Adobe MAX Concluded', sx: sx),
              ),
            ),

            const SizedBox(height: 56),
          ]),
        ),
      ),
    );
  }
}


class VideoPlayerDialog extends StatefulWidget {
  final String title;
  final FeatureTutorial? tutorial;

  const VideoPlayerDialog({
    required this.title,
    this.tutorial,
    super.key,
  });

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    final videoAsset = widget.tutorial?.videoAsset ?? 'assets/sample_video.mp4';
    _controller = VideoPlayerController.asset(videoAsset)
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Handle the "Use this feature" button tap
  /// Opens image picker and navigates to editor with the target feature
  /// For Stylize: downloads thumbnail as style reference first
  Future<void> _handleFeatureAction() async {
    if (_isPickingImage) return;
    
    final tutorial = widget.tutorial;
    if (tutorial == null || !tutorial.hasFeatureAction) return;
    
    setState(() => _isPickingImage = true);
    
    try {
      Uint8List? styleReferenceBytes;
      
      // For Stylize feature, load the thumbnail as style reference
      if (tutorial.targetFeature == EditorFeature.stylize && 
          tutorial.thumbnailAsset != null) {
        try {
          // Load the thumbnail asset as style reference
          final ByteData data = await rootBundle.load(tutorial.thumbnailAsset!);
          styleReferenceBytes = data.buffer.asUint8List();
          
          if (mounted) {
            // Show snackbar that style reference is ready
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text('"${tutorial.title}" style loaded!'),
                  ],
                ),
                backgroundColor: Colors.green.shade700,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          // Silently handle thumbnail load error
        }
      }
      
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);
      
      if (file == null) {
        setState(() => _isPickingImage = false);
        return;
      }
      
      // Set image mode
      GlobalConfig.setImageMode();
      
      final Uint8List bytes = await file.readAsBytes();
      
      if (mounted) {
        // Close the dialog
        Navigator.of(context).pop();
        
        // Navigate to editor with feature info
        Navigator.of(context).pushNamed(
          '/editor',
          arguments: EditorNavigationArgs(
            imageBytes: bytes,
            initialFeature: tutorial.targetFeature,
            stylizeReferenceImage: styleReferenceBytes,
            stylizePresetName: tutorial.title,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPickingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tutorial = widget.tutorial;
    final hasFeatureAction = tutorial?.hasFeatureAction ?? false;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500, 
          maxHeight: hasFeatureAction ? 480 : 400,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with title and close button
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title, 
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 16, 
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Adobe Clean',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Video player
            Expanded(
              child: ClipRRect(
                borderRadius: hasFeatureAction 
                    ? BorderRadius.zero 
                    : const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                child: _isInitialized
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _controller.value.isPlaying 
                                    ? _controller.pause() 
                                    : _controller.play();
                              });
                            },
                            child: AnimatedOpacity(
                              opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(12),
                                child: const Icon(
                                  Icons.play_arrow, 
                                  color: Colors.white, 
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: VideoProgressIndicator(
                              _controller,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: Colors.red,
                                bufferedColor: Colors.white24,
                                backgroundColor: Colors.white12,
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
              ),
            ),
            
            // CTA Button for feature action
            if (hasFeatureAction)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isPickingImage ? null : _handleFeatureAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B62FB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      disabledBackgroundColor: const Color(0xFF3B62FB).withOpacity(0.5),
                    ),
                    child: _isPickingImage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.auto_awesome, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                tutorial!.buttonText,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Arguments for navigating to editor with a specific feature
class EditorNavigationArgs {
  final Uint8List imageBytes;
  final EditorFeature initialFeature;
  final Uint8List? stylizeReferenceImage;
  final String? stylizePresetName;
  
  const EditorNavigationArgs({
    required this.imageBytes,
    this.initialFeature = EditorFeature.none,
    this.stylizeReferenceImage,
    this.stylizePresetName,
  });
}
