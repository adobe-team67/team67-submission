// features/home/widgets/create_canvas_slider.dart
import 'package:flutter/material.dart';
import 'package:adobe_mvp/core/global.dart';

/// Bottom sheet slider for creating a new canvas with preset sizes.
/// Shows tabs for Social and Other categories with platform-specific presets.
class CreateCanvasSlider extends StatefulWidget {
  final VoidCallback? onClose;
  final void Function(CanvasPreset preset)? onCanvasSelected;

  const CreateCanvasSlider({
    super.key,
    this.onClose,
    this.onCanvasSelected,
  });

  @override
  State<CreateCanvasSlider> createState() => _CreateCanvasSliderState();
}

class _CreateCanvasSliderState extends State<CreateCanvasSlider>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Tab categories
  static const _tabs = ['Social', 'Other'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onPresetTap(CanvasPreset preset) {
    widget.onCanvasSelected?.call(preset);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const ShapeDecoration(
        color: Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with title and close button
          _buildHeader(),
          
          // Tab bar
          _buildTabBar(),
          
          // Tab content
          SizedBox(
            height: 450,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Social tab
                _buildSocialContent(),
                // Other tab
                _buildOtherContent(),
              ],
            ),
          ),
          
          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 45,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
      child: Stack(
        children: [
          // Handle bar
          Positioned(
            left: 0,
            right: 0,
            top: 8,
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          // Title
          const Positioned(
            left: 0,
            right: 0,
            top: 18,
            child: Text(
              'Create new canvas',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontFamily: 'Adobe Clean',
                fontWeight: FontWeight.w700,
                letterSpacing: -0.34,
              ),
            ),
          ),
          // Close button
          Positioned(
            right: 16,
            top: 10,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 0.5,
              color: Colors.white.withValues(alpha: 0.20),
            ),
          ),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
          labelStyle: const TextStyle(
            fontSize: 14,
            fontFamily: 'Adobe Clean',
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontFamily: 'Adobe Clean',
            fontWeight: FontWeight.w500,
          ),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
    );
  }

  Widget _buildSocialContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instagram section
          _buildPlatformSection(
            icon: Icons.camera_alt_outlined,
            platform: 'Instagram',
            presets: CanvasPresets.instagram,
          ),
          
          // Facebook section
          _buildPlatformSection(
            icon: Icons.facebook_outlined,
            platform: 'Facebook',
            presets: CanvasPresets.facebook,
          ),
        ],
      ),
    );
  }

  Widget _buildOtherContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPlatformSection(
            icon: Icons.aspect_ratio,
            platform: 'Standard Sizes',
            presets: CanvasPresets.other,
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformSection({
    required IconData icon,
    required String platform,
    required List<CanvasPreset> presets,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Platform header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 24,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  platform,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'Adobe Clean',
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.36,
                  ),
                ),
              ],
            ),
          ),
          
          // Preset items
          ...presets.map((preset) => _buildPresetItem(preset)),
        ],
      ),
    );
  }

  Widget _buildPresetItem(CanvasPreset preset) {
    return GestureDetector(
      onTap: () => _onPresetTap(preset),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 14),
        decoration: const BoxDecoration(color: Color(0xFF1E1E1E)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              preset.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontFamily: 'Adobe Clean',
                fontWeight: FontWeight.w400,
                height: 1.35,
                letterSpacing: -0.09,
              ),
            ),
            Text(
              preset.dimensions,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                fontFamily: 'Adobe Clean',
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
