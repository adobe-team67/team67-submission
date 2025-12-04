
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enum to track the source type of the current edit session
enum EditSourceType {
  image,  // User uploaded an image
  canvas, // User created a blank canvas
}

/// Model for canvas preset sizes
class CanvasPreset {
  final String name;
  final String category;
  final int width;
  final int height;
  final String? platform; // e.g., 'Instagram', 'Facebook'
  
  const CanvasPreset({
    required this.name,
    required this.category,
    required this.width,
    required this.height,
    this.platform,
  });
  
  double get aspectRatio => width / height;
  String get dimensions => '${width}x$height';
}

/// All available canvas presets organized by platform
class CanvasPresets {
  static const List<CanvasPreset> instagram = [
    CanvasPreset(name: 'Square', category: 'Social', width: 1080, height: 1080, platform: 'Instagram'),
    CanvasPreset(name: 'Story', category: 'Social', width: 1080, height: 1920, platform: 'Instagram'),
    CanvasPreset(name: 'Portrait', category: 'Social', width: 1080, height: 1350, platform: 'Instagram'),
    CanvasPreset(name: 'Landscape', category: 'Social', width: 1080, height: 566, platform: 'Instagram'),
    CanvasPreset(name: 'Profile Photo', category: 'Social', width: 320, height: 320, platform: 'Instagram'),
  ];
  
  static const List<CanvasPreset> facebook = [
    CanvasPreset(name: 'Story', category: 'Social', width: 1080, height: 1920, platform: 'Facebook'),
    CanvasPreset(name: 'Portrait Post', category: 'Social', width: 1080, height: 1350, platform: 'Facebook'),
    CanvasPreset(name: 'Landscape Post', category: 'Social', width: 1200, height: 630, platform: 'Facebook'),
    CanvasPreset(name: 'Profile Photo', category: 'Social', width: 180, height: 180, platform: 'Facebook'),
    CanvasPreset(name: 'Cover Photo', category: 'Social', width: 820, height: 312, platform: 'Facebook'),
  ];
  
  static const List<CanvasPreset> other = [
    CanvasPreset(name: 'HD (1920x1080)', category: 'Other', width: 1920, height: 1080),
    CanvasPreset(name: '4K (3840x2160)', category: 'Other', width: 3840, height: 2160),
    CanvasPreset(name: 'A4 Portrait', category: 'Other', width: 2480, height: 3508),
    CanvasPreset(name: 'A4 Landscape', category: 'Other', width: 3508, height: 2480),
    CanvasPreset(name: 'Square (1024x1024)', category: 'Other', width: 1024, height: 1024),
  ];
  
  static List<CanvasPreset> get all => [...instagram, ...facebook, ...other];
}

class GlobalConfig {
  // Add any global variables you need here with sensible defaults.
  static bool useDarkMode = true;
  static String userName = '';
  static int lastProjectId = -1;
  static String selectedModelName = 'Atom';
  static String selectedModelType = 'FREE';
  
  // Canvas/Image source tracking
  static EditSourceType currentEditSource = EditSourceType.image;
  static CanvasPreset? currentCanvasPreset;
  static Size? currentCanvasSize;
  static Color canvasBackgroundColor = Colors.white;
  
  // Original image size (as placed on canvas, after scaling)
  // This is the dimensions of the scaled image within the canvas
  static Size? originalImageSizeOnCanvas;

  // Keys used in SharedPreferences
  static const _kUseDarkMode = 'use_dark_mode';
  static const _kUserName = 'user_name';
  static const _kLastProjectId = 'last_project_id';
  static const _kSelectedModelName = 'selected_model_name';
  static const _kSelectedModelType = 'selected_model_type';

  // Initialize global config from local storage
  static Future<void> loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    useDarkMode = prefs.getBool(_kUseDarkMode) ?? useDarkMode;
    userName = prefs.getString(_kUserName) ?? userName;
    lastProjectId = prefs.getInt(_kLastProjectId) ?? lastProjectId;
    selectedModelName = prefs.getString(_kSelectedModelName) ?? selectedModelName;
    selectedModelType = prefs.getString(_kSelectedModelType) ?? selectedModelType;
  }

  // Optionally provide a way to persist changes:
  static Future<void> saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUseDarkMode, useDarkMode);
    await prefs.setString(_kUserName, userName);
    await prefs.setInt(_kLastProjectId, lastProjectId);
    await prefs.setString(_kSelectedModelName, selectedModelName);
    await prefs.setString(_kSelectedModelType, selectedModelType);
  }

  static void resetToDefaults() {
    useDarkMode = true;
    userName = '';
    lastProjectId = -1;
    selectedModelName = 'Atom';
    selectedModelType = 'FREE';
    currentEditSource = EditSourceType.image;
    currentCanvasPreset = null;
    currentCanvasSize = null;
    canvasBackgroundColor = Colors.white;
    originalImageSizeOnCanvas = null;

    saveToLocal();
  }

  static void setModelType(String modelName, String modelType) {
    selectedModelName = modelName;
    selectedModelType = modelType;
    saveToLocal();
  }
  
  /// Set canvas mode with a preset
  static void setCanvasMode(CanvasPreset preset, {Color? backgroundColor}) {
    currentEditSource = EditSourceType.canvas;
    currentCanvasPreset = preset;
    currentCanvasSize = Size(preset.width.toDouble(), preset.height.toDouble());
    canvasBackgroundColor = backgroundColor ?? Colors.white;
  }
  
  /// Set image mode (when user uploads an image)
  static void setImageMode() {
    currentEditSource = EditSourceType.image;
    currentCanvasPreset = null;
    currentCanvasSize = null;
    originalImageSizeOnCanvas = null;
  }
  
  /// Check if currently in canvas mode
  static bool get isCanvasMode => currentEditSource == EditSourceType.canvas;
  
  /// Check if currently in image mode  
  static bool get isImageMode => currentEditSource == EditSourceType.image;
}

/// Enum representing the editor feature/tool to open
enum EditorFeature {
  edit,
  select,
  prompt,
  layers,
  stylize,
  none,
}

/// Model for tutorial/video content that can link to a feature
class FeatureTutorial {
  final String title;
  final String? description;
  final String? videoAsset;
  final String? thumbnailAsset;
  final EditorFeature targetFeature;
  final String? ctaButtonText;
  
  const FeatureTutorial({
    required this.title,
    this.description,
    this.videoAsset,
    this.thumbnailAsset,
    this.targetFeature = EditorFeature.none,
    this.ctaButtonText,
  });
  
  /// Returns true if this tutorial has a feature to navigate to
  bool get hasFeatureAction => targetFeature != EditorFeature.none;
  
  /// Get the CTA button text, with a default based on feature
  String get buttonText {
    if (ctaButtonText != null) return ctaButtonText!;
    switch (targetFeature) {
      case EditorFeature.prompt:
        return 'Try Prompt Editing';
      case EditorFeature.stylize:
        return 'Try Stylize';
      case EditorFeature.select:
        return 'Try Select & Edit';
      case EditorFeature.edit:
        return 'Try Editing';
      case EditorFeature.layers:
        return 'Try Layers';
      case EditorFeature.none:
        return 'Use this Feature';
    }
  }
}

/// Pre-defined tutorials for the app
class AppTutorials {
  static const List<FeatureTutorial> homeFeatures = [
    FeatureTutorial(
      title: 'Move, Remove & Inpaint',
      // description: 'Select objects to move, remove, or replace with AI',
      videoAsset: 'assets/sample_video.mp4',
      thumbnailAsset: 'assets/learn_sample.png',
      targetFeature: EditorFeature.select,
      ctaButtonText: 'Try Select Tool',
    ),
    FeatureTutorial(
      title: 'Transform with Prompts',
      // description: 'Describe the edit you want and let AI do the work',
      videoAsset: 'assets/sample_video.mp4',
      thumbnailAsset: 'assets/learn_sample.png',
      targetFeature: EditorFeature.prompt,
      ctaButtonText: 'Try Prompt Editing',
    ),
    FeatureTutorial(
      title: 'Stylize Your Photos',
      // description: 'Apply artistic styles to transform your images',
      videoAsset: 'assets/sample_video.mp4',
      thumbnailAsset: 'assets/learn_sample.png',
      targetFeature: EditorFeature.stylize,
      ctaButtonText: 'Try Stylize',
    ),
    FeatureTutorial(
      title: 'Layer-based Editing',
      // description: 'Work with multiple layers for complex edits',
      videoAsset: 'assets/sample_video.mp4',
      thumbnailAsset: 'assets/learn_sample.png',
      targetFeature: EditorFeature.layers,
      ctaButtonText: 'Try Layers',
    ),
    FeatureTutorial(
      title: 'Edit & Enhance',
      // description: 'Adjust brightness, contrast, and more',
      videoAsset: 'assets/sample_video.mp4',
      thumbnailAsset: 'assets/learn_sample.png',
      targetFeature: EditorFeature.edit,
      ctaButtonText: 'Try Editing',
    ),
  ];
  
  static const List<FeatureTutorial> learnTutorials = [
    FeatureTutorial(
      title: 'Move, Remove & Inpaint',
      description: 'A bundle edit feature to change the photo based on conversations and Adobe AI',
      videoAsset: 'assets/sample_video.mp4',
      thumbnailAsset: 'assets/learn_sample.png',
      targetFeature: EditorFeature.select,
    ),
    FeatureTutorial(
      title: 'Smart Object Selection',
      description: 'Learn how AI detects and selects objects automatically',
      videoAsset: 'assets/sample_video.mp4',
      thumbnailAsset: 'assets/learn_sample.png',
      targetFeature: EditorFeature.select,
    ),
    FeatureTutorial(
      title: 'Text-to-Edit Magic',
      description: 'Transform images with natural language prompts',
      videoAsset: 'assets/sample_video.mp4',
      thumbnailAsset: 'assets/learn_sample.png',
      targetFeature: EditorFeature.prompt,
    ),
    FeatureTutorial(
      title: 'Style Transfer',
      description: 'Apply artistic styles from reference images',
      videoAsset: 'assets/sample_video.mp4',
      thumbnailAsset: 'assets/learn_sample.png',
      targetFeature: EditorFeature.stylize,
    ),
    FeatureTutorial(
      title: 'Advanced Layers',
      description: 'Master layer-based non-destructive editing',
      videoAsset: 'assets/sample_video.mp4',
      thumbnailAsset: 'assets/learn_sample.png',
      targetFeature: EditorFeature.layers,
    ),
    FeatureTutorial(
      title: 'Pro Editing Tips',
      description: 'Professional techniques for stunning results',
      videoAsset: 'assets/sample_video.mp4',
      thumbnailAsset: 'assets/learn_sample.png',
      targetFeature: EditorFeature.edit,
    ),
  ];
  
  static const List<FeatureTutorial> stylizeTrends = [
    FeatureTutorial(
      title: 'Cinematic Look',
      thumbnailAsset: 'assets/learn_sample.png',
      targetFeature: EditorFeature.stylize,
    ),
    FeatureTutorial(
      title: 'Vintage Vibes',
      thumbnailAsset: 'assets/learn_sample.png',
      targetFeature: EditorFeature.stylize,
    ),
    FeatureTutorial(
      title: 'Neon Dreams',
      thumbnailAsset: 'assets/learn_sample.png',
      targetFeature: EditorFeature.stylize,
    ),
    FeatureTutorial(
      title: 'Watercolor Art',
      thumbnailAsset: 'assets/learn_sample.png',
      targetFeature: EditorFeature.stylize,
    ),
    FeatureTutorial(
      title: 'Oil Painting',
      thumbnailAsset: 'assets/learn_sample.png',
      targetFeature: EditorFeature.stylize,
    ),
  ];
}
