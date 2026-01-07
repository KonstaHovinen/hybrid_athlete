import 'package:shared_preferences/shared_preferences.dart';

/// Singleton cache for SharedPreferences to avoid repeated initialization
/// This significantly improves performance by reusing the same instance
class PreferencesCache {
  static SharedPreferences? _instance;
  static bool _isInitializing = false;

  /// Get or initialize SharedPreferences instance
  /// This is safe to call multiple times - it will reuse the cached instance
  static Future<SharedPreferences> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    // Prevent multiple simultaneous initializations
    if (_isInitializing) {
      // Wait a bit and retry
      await Future.delayed(const Duration(milliseconds: 50));
      return getInstance();
    }

    try {
      _isInitializing = true;
      _instance = await SharedPreferences.getInstance();
      return _instance!;
    } finally {
      _isInitializing = false;
    }
  }

  /// Clear the cache (useful for testing or forced refresh)
  static void clearCache() {
    _instance = null;
  }
}
