import 'package:adobe_mvp/features/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:adobe_mvp/ui/theme/app_theme.dart';

class HomeTopNav extends StatelessWidget {
  const HomeTopNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 41,
                height: 40,
                child: Image.asset('assets/logo.png', fit: BoxFit.cover),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: ClipOval(
                        child: Image.asset('assets/icons/Cloud.png'
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/profile_demo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}