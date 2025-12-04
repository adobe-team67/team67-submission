// features/splash/splash_screen.dart
// Responsive splash screen converted from fixed 393x852 design (iPhone 16 reference).
// Uses MediaQuery to scale positions and sizes. Uses theme colors from AppTheme.
// Design reference: `ui-ux.mp4` at project root.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:adobe_mvp/ui/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Reference size from design
    const refW = 393.0, refH = 852.0;
    final sx = mq.size.width / refW;
    final sy = mq.size.height / refH;

    // We mimic original layout but scale dynamically
    final bgColor = AppTheme.darkTheme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ClipRect(
          child: Stack(
            children: [
              // Centered placeholder image, original left:132 top:362 size 130x127
              Positioned(
                left: 132 * sx,
                top: 362 * sy,
                child: ScaleTransition(
                  scale: CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
                  child: SizedBox(
                    width: 130 * sx,
                    height: 127 * sy,
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                      // If PNG is missing or fails to load, fall back to svg (if available)
                      errorBuilder: (context, error, stackTrace) => SvgPicture.asset('assets/logo/logo.svg', fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),

              // // Top status bar area (time and indicators) — reflowed using Row and SizedBox
              // Positioned(
              //   left: 0,
              //   top: 0,
              //   right: 0,
              //   child: Container(
              //     padding: EdgeInsets.only(top: 21 * sy, left: 16 * sx, right: 16 * sx, bottom: 19 * sy),
              //     color: bgColor,
              //     child: Row(
              //       children: [
              //         Expanded(
              //           child: Container(
              //             height: 22 * sy,
              //             padding: EdgeInsets.only(top: 2 * sy),
              //             alignment: Alignment.centerLeft,
              //             child: Text(
              //               '9:41',
              //               style: TextStyle(
              //                 color: Colors.white,
              //                 fontSize: 17 * sx,
              //                 fontFamily: 'SF Pro',
              //                 fontWeight: FontWeight.w600,
              //                 height: 1.29,
              //               ),
              //             ),
              //           ),
              //         ),
              //         Expanded(
              //           child: Container(
              //             height: 22 * sy,
              //             padding: EdgeInsets.only(top: 1 * sy),
              //             alignment: Alignment.centerRight,
              //             child: Row(
              //               mainAxisSize: MainAxisSize.min,
              //               children: [
              //                 Opacity(
              //                   opacity: 0.35,
              //                   child: Container(
              //                     width: 25 * sx,
              //                     height: 13 * sy,
              //                     decoration: BoxDecoration(
              //                       border: Border.all(color: Colors.white, width: 1),
              //                       borderRadius: BorderRadius.circular(4.3 * sx),
              //                     ),
              //                   ),
              //                 ),
              //                 SizedBox(width: 7 * sx),
              //                 Container(
              //                   width: 21 * sx,
              //                   height: 9 * sy,
              //                   decoration: BoxDecoration(
              //                     color: Colors.white,
              //                     borderRadius: BorderRadius.circular(2.5 * sx),
              //                   ),
              //                 ),
              //               ],
              //             ),
              //           ),
              //         )
              //       ],
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
