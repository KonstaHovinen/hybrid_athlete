import 'dart:convert';
import '../utils/preferences_cache.dart';

/// Cached workout history with pagination support
/// This dramatically improves performance by avoiding repeated JSON parsing
class WorkoutHistoryCache {
  static List<Map<String, dynamic>>? _cachedHistory;
  static DateTime? _lastCacheTime;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Get workout history with optional pagination
  /// [limit] - Maximum number of workouts to return (null = all)
  /// [offset] - Number of workouts to skip (for pagination)
  static Future<List<Map<String, dynamic>>> getHistory({
    int? limit,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    // Use cache if available and not expired
    if (!forceRefresh && 
        _cachedHistory != null && 
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheTimeout) {
      return _getPaginatedList(_cachedHistory!, limit: limit, offset: offset);
    }

    // Load from SharedPreferences
    final prefs = await PreferencesCache.getInstance();
    final List<String>? historyJson = prefs.getStringList('workout_history');
    
    if (historyJson == null) {
      _cachedHistory = [];
      _lastCacheTime = DateTime.now();
      return [];
    }

    // Parse all workouts (cached for 5 minutes)
    _cachedHistory = historyJson
        .map((e) {
          try {
            return jsonDecode(e) as Map<String, dynamic>;
          } catch (_) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();
    
    _lastCacheTime = DateTime.now();
    return _getPaginatedList(_cachedHistory!, limit: limit, offset: offset);
  }

  /// Get paginated subset of list
  static List<Map<String, dynamic>> _getPaginatedList(
    List<Map<String, dynamic>> list, {
    int? limit,
    int offset = 0,
  }) {
    if (limit == null) {
      return list.skip(offset).toList();
    }
    return list.skip(offset).take(limit).toList();
  }

  /// Get total count of workouts
  static Future<int> getTotalCount() async {
    if (_cachedHistory != null) {
      return _cachedHistory!.length;
    }
    final prefs = await PreferencesCache.getInstance();
    final historyJson = prefs.getStringList('workout_history') ?? [];
    return historyJson.length;
  }

  /// Invalidate cache (call after adding/editing/deleting workouts)
  static void invalidateCache() {
    _cachedHistory = null;
    _lastCacheTime = null;
  }

  /// Get recent workouts (last N workouts)
  static Future<List<Map<String, dynamic>>> getRecentWorkouts(int count) async {
    final all = await getHistory();
    return all.take(count).toList();
  }
}
