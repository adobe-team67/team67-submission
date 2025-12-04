import 'package:adobe_mvp/core/global.dart';
import 'package:adobe_mvp/features/learn/learn_screen.dart';
import 'package:adobe_mvp/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';

class TutorialCard extends StatelessWidget {
  final String title;
  final String? description;
  final double sx;
  final bool isVideo;
  final bool isOnHomepage;
  final FeatureTutorial? tutorial; // New: optional tutorial model
  final int index; // New: index for placeholder image selection

  const TutorialCard({
    required this.title, 
    this.description, 
    required this.sx, 
    this.isVideo = false, 
    this.isOnHomepage = false,
    this.tutorial,
    this.index = 0,
    super.key,
  });
  
  /// Factory constructor from FeatureTutorial
  factory TutorialCard.fromTutorial({
    required FeatureTutorial tutorial,
    required double sx,
    bool isOnHomepage = false,
    required int index,
  }) {
    return TutorialCard(
      title: tutorial.title,
      description: tutorial.description,
      sx: sx,
      isVideo: tutorial.videoAsset != null,
      isOnHomepage: isOnHomepage,
      tutorial: tutorial,
      index: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.darkTheme;
    return SizedBox(
      width: !isOnHomepage ? 191 * sx : 130 * sx,

      child: GestureDetector(
        onTap: () {
          isVideo ? _showVideoDialog(context) : null;
        },
        child: Container(
          decoration: ShapeDecoration(color: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
                    child: Image.asset(TutorialCard._placeholderUrls[index % 6], width: double.infinity, height: 122, fit: BoxFit.cover),
                  ),
                  isVideo ? Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ) : const SizedBox.shrink(),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: const BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Adobe Clean')),
                  if (description != null) const SizedBox(height: 8),
                  if (description != null) Text(description!, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500, fontFamily: 'Adobe Clean')),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVideoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => VideoPlayerDialog(
        title: title, 
        tutorial: tutorial,
      ),
    );
  }

  static const List<String> _placeholderUrls = [
    'assets/images/tutorial_placeholder_1.png',
    'assets/images/tutorial_placeholder_2.png',
    'assets/images/tutorial_placeholder_3.png',
    'assets/images/try_trends_1.png',
    'assets/images/try_trends_2.png',
    'assets/images/try_trends_3.png',
  ];
}
