// lib/widgets/app_bottom_nav.dart
import 'package:flutter/material.dart';

/// Reusable bottom navigation bar used on Home, Files, Learn pages.
/// Navigates using named routes: '/home', '/files', '/learn'.
class AppBottomNav extends StatelessWidget {
  final Color backgroundColor;
  final double height;

  const AppBottomNav({
    Key? key,
    this.backgroundColor = const Color(0xFF1E1E1E),
    this.height = 72,
  }) : super(key: key);

  int _indexFromRoute(String? routeName) {
    switch (routeName) {
      case '/files':
        return 1;
      case '/learn':
        return 2;
      case '/home':
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeName = ModalRoute.of(context)?.settings.name;
    final currentIndex = _indexFromRoute(routeName);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              label: 'Home',
              selected: currentIndex == 0,
              onTap: () {
                if (routeName != '/home') Navigator.of(context).pushReplacementNamed('/home');
              },
            ),
            _NavItem(
              icon: Icons.folder_open_outlined,
              label: 'Files',
              selected: currentIndex == 1,
              onTap: () {
                if (routeName != '/files') Navigator.of(context).pushReplacementNamed('/files');
              },
            ),
            _NavItem(
              icon: Icons.school_outlined,
              label: 'Learn',
              selected: currentIndex == 2,
              onTap: () {
                if (routeName != '/learn') Navigator.of(context).pushReplacementNamed('/learn');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = selected ? Color(0xFF3B62FB) : Colors.white70;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 84,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontFamily: 'Adobe Clean')),
          ],
        ),
      ),
    );
  }
}
