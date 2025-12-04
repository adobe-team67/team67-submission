// features/home/home_screen.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:adobe_mvp/core/constants.dart';
import 'package:adobe_mvp/core/global.dart';
import 'package:adobe_mvp/features/learn/widgets/tutorial_card.dart';
import 'package:adobe_mvp/ui/widgets/home_top_nav.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:adobe_mvp/ui/theme/app_theme.dart';
import 'package:adobe_mvp/ui/widgets/app_bottom_nav.dart' as _nav;
import 'widgets/create_canvas_slider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  
  Future<void> _pickAndOpen() async {
    final picker = ImagePicker();
    try {
      // Set image mode in global config
      GlobalConfig.setImageMode();
      
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) {
        Navigator.of(context).pushNamed('/editor', arguments: bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to open image: \$e')));
      }
    }
  }

  void _showCanvasSlider() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateCanvasSlider(
        onClose: () => Navigator.of(ctx).pop(),
        onCanvasSelected: (preset) async {
          Navigator.of(ctx).pop(); // Close the slider
          
          // Set global canvas mode
          GlobalConfig.setCanvasMode(preset);
          
          // Create a blank canvas image with the selected size
          final canvasBytes = await _createBlankCanvas(
            preset.width,
            preset.height,
            GlobalConfig.canvasBackgroundColor,
          );
          
          if (mounted && canvasBytes != null) {
            // Navigate to editor with the canvas bytes
            Navigator.of(context).pushNamed('/editor', arguments: canvasBytes);
          }
        },
      ),
    );
  }
  
  /// Creates a blank canvas image as Uint8List (PNG format)
  Future<Uint8List?> _createBlankCanvas(int width, int height, Color color) async {
    try {
      // Create the image using ui.Image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = color;
      canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paint);
      final picture = recorder.endRecording();
      
      // Convert to image
      final image = await picture.toImage(width, height);
      
      // Convert to PNG bytes
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      
      return byteData.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sx = mq.size.width / refW;
    final sy = mq.size.height / refH;

    final bg = AppTheme.darkTheme.scaffoldBackgroundColor;

    return Scaffold(
        backgroundColor: bg,
        bottomNavigationBar: const _nav.AppBottomNav(),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                HomeTopNav(),
                
                // Let's get started card
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: 362 * sx,
                    height: 157 * sy,
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(
                      color: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Let\'s get started',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'Adobe Clean',
                              fontWeight: FontWeight.w700,
                              height: 1.38,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // From your photos
                              GestureDetector(
                                onTap: _pickAndOpen,
                                child: SizedBox(
                                  width: 100,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: ShapeDecoration(
                                          color: const Color(0xFF383737),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                        ),
                                        child: Image.asset('assets/icons/Image.png',),
                                            // color: Colors.white, size: 30),
                                      ),
                                      const SizedBox(height: 8),
                                      const SizedBox(
                                        width: 100,
                                        child: Text(
                                          'From your\nphotos',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontFamily: 'Adobe Clean',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // New blank canvas
                              GestureDetector(
                                onTap: _showCanvasSlider,
                                child: SizedBox(
                                  width: 100,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: ShapeDecoration(
                                          color: const Color(0xFF383737),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                        ),
                                        child: Image.asset('assets/icons/File.png',)
                                      ),
                                      const SizedBox(height: 8),
                                      const SizedBox(
                                        width: 80,
                                        child: Text(
                                          'New blank canvas',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontFamily: 'Adobe Clean',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Adobe Stock
                              GestureDetector(
                                onTap: () => ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                        content: Text('Adobe Stock coming soon'))),
                                child: SizedBox(
                                  width: 100,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: ShapeDecoration(
                                          color: const Color(0xFF383737),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                        ),
                                        child: Image.asset('assets/icons/adobe-stock.png'),
                                      ),
                                      const SizedBox(height: 8),
                                      const SizedBox(
                                        width: 100,
                                        child: Text(
                                          'From\nAdobe Stock',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontFamily: 'Adobe Clean',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                const SizedBox(height: 10),

                // Header row with title and explore button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Things you can do',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontFamily: 'Adobe Clean',
                          fontWeight: FontWeight.w700,
                          height: 1.10,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pushNamed('/learn'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: ShapeDecoration(
                            color: const Color(0xFF3B62FB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(60),
                            ),
                          ),
                          child: const Text(
                            'Explore More',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Adobe Clean',
                              fontWeight: FontWeight.w700,
                              height: 1.57,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Horizontal scrollable cards - using AppTutorials data
                SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: AppTutorials.homeFeatures.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (ctx, idx) {
                      return TutorialCard.fromTutorial(
                        tutorial: AppTutorials.homeFeatures[idx],
                        sx: sx,
                        isOnHomepage: true,
                        index: idx,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                
                // Recents Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recents',
                        textAlign: TextAlign.center,
                        style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: 4,
                    itemBuilder: (ctx, idx) {
                      final titles = [
                        'Getting Started',
                        'Basic Editing',
                        'Advanced Tools',
                        'Pro Tips',
                      ];
                      return TutorialCard(
                        title: titles[idx],
                        sx: sx,
                        isOnHomepage: true,
                        isVideo: false,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ));
  }
}
