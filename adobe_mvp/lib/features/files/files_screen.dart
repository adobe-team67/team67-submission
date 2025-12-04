// lib/features/files/files_screen.dart
import 'package:adobe_mvp/ui/widgets/app_bottom_nav.dart';
import 'package:adobe_mvp/ui/widgets/home_top_nav.dart';
import 'package:flutter/material.dart';
import 'package:adobe_mvp/ui/theme/app_theme.dart';

class FilesScreen extends StatelessWidget {
  const FilesScreen({super.key});

  static const _placeholderImages = [
    'assets/images/tutorial_placeholder_1.png'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.darkTheme;
    final bg = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeTopNav(),
              const SizedBox(height: 8),
              Text('Files',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 18),

              // Grid of file cards (2 columns)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _placeholderImages.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 171 / 137, // image 89 + footer ~137
                ),
                itemBuilder: (ctx, idx) {
                  final img = _placeholderImages[idx];
                  return _FileCard(imageUrl: img, subtitle: 'Move, Remove & Inpaint');
                },
              ),

              const SizedBox(height: 20),

              // // Optional: a second grouped section similar to the design
              // Text('Collections',
              //     style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              // const SizedBox(height: 12),

              // SizedBox(
              //   height: 120,
              //   child: ListView.separated(
              //     scrollDirection: Axis.horizontal,
              //     itemCount: 5,
              //     separatorBuilder: (_, __) => const SizedBox(width: 12),
              //     itemBuilder: (ctx, i) => _CollectionCard(imageUrl: _placeholderImages[i % _placeholderImages.length], label: 'Collection ${i + 1}'),
              //   ),
              // ),
              // const SizedBox(height: 56),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final String imageUrl;
  // final String title;
  final String subtitle;
  const _FileCard({required this.imageUrl, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.darkTheme;
    return GestureDetector(
      onTap: () {
        // open file or editor
        Navigator.of(context).pushNamed('/editor');
      },
      child: Container(
        decoration: ShapeDecoration(
          color: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // image
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
              child: Image.asset(imageUrl, width: double.infinity, height: 89, fit: BoxFit.cover),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Text(tit, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                // const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: AppTheme.darkTheme.colorScheme.onSurface, fontSize: 11, fontFamily: 'Adobe Clean')),
              ]),
            )
          ],
        ),
      ),
    );
  }
}

// class _CollectionCard extends StatelessWidget {
//   final String imageUrl;
//   final String label;
//   const _CollectionCard({required this.imageUrl, required this.label});

//   @override
//   Widget build(BuildContext context) {
//     final theme = AppTheme.darkTheme;
//     return Container(
//       width: 140,
//       decoration: ShapeDecoration(color: theme.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
//       child: Column(
//         children: [
//           ClipRRect(borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)), child: Image.network(imageUrl, width: 140, height: 72, fit: BoxFit.cover)),
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
//           )
//         ],
//       ),
//     );
//   }
// }
