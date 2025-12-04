// config/env.dart
// Environment configuration loaded from .env file
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  /// Load environment variables from .env file
  /// Call this in main() before runApp()
  static Future<void> load() async {
    await dotenv.load(fileName: ".env");
  }

  /// Backend API base URL
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://adobe.artiqa.live/';

  /// Whether to use mock API implementation (no backend required)
  static bool get useMockApi =>
      dotenv.env['USE_MOCK_API']?.toLowerCase() == 'true';
}
