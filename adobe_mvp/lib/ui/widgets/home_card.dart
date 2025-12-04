import 'package:flutter/material.dart';
import 'package:adobe_mvp/ui/theme/app_theme.dart';

class HomeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String asset;
  final Color cardBgColor;
  final double sx;
  final double sy;
  final double imageHeight;

  const HomeCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.asset,
    this.cardBgColor = const Color(0xFF1E1E1E),
    this.sx = 1.0,
    this.sy = 1.0,
    this.imageHeight = 122.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use Theme text as base then apply the explicit sizes/families requested
    final titleStyle = AppTheme.darkTheme.textTheme.titleSmall?.copyWith(
          color: Colors.white,
          fontSize: 15,
          fontFamily: 'Adobe Clean',
          fontWeight: FontWeight.w700,
          height: 1.47,
        ) ?? TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontFamily: 'Adobe Clean',
          fontWeight: FontWeight.w700,
          height: 1.47,
        );

    final subtitleStyle = AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontSize: 12,
          fontFamily: 'Adobe Clean',
          // FontWeight.w350 is not standard; map to w300 for a light look
          fontWeight: FontWeight.w300,
          height: 1.83,
        ) ?? TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontFamily: 'Adobe Clean',
          fontWeight: FontWeight.w300,
          height: 1.83,
        );

    return Container(
      width: double.infinity,
      height: 1000,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(200),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top image with dynamic height scaled by `sy`
          Container(
            width: double.infinity,
            height: imageHeight * sy,
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              image: DecorationImage(
                image: AssetImage(asset),
                fit: BoxFit.cover,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
            ),
          ),

          // Bottom card area with same paddings and spacing as provided
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: cardBgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title constrained to the exact width requested
                SizedBox(
                  width: 150.50 * sx,
                  child: Text(
                    title,
                    style: titleStyle,
                  ),
                ),

                SizedBox(height: 12),

                SizedBox(
                  width: 150.50 * sx,
                  child: Text(
                    subtitle,
                    style: subtitleStyle,
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

// Usage:
// HomeCard(
//   title: 'Move, Remove & Inpaint',
//   subtitle: 'A bundle edit feature to change the photo based on conversations and Adobe AI',
//   asset: 'assets/sample_feature.png',
//   cardBgColor: cardBgColor,
//   sx: sx,
//   sy: sy,
// ),