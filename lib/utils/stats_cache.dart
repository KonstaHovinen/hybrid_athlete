import 'dart:convert';
import '../utils/preferences_cache.dart';

/// Cached stats calculations to avoid recalculating on every screen open
class StatsCache {
  static Map<String, dynamic>? _cachedStats;
  static DateTime? _lastCacheTime;
  static const Duration _cacheTimeout = Duration(minutes: 2);

  /// Get cached stats or calculate if cache expired
  static Future<Map<String, dynamic>> getStats({bool forceRefresh = false}) async {
    // Return cache if valid
    if (!forceRefresh &&
        _cachedStats != null &&
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheTimeout) {
      return Map<String, dynamic>.from(_cachedStats!);
    }

    // Calculate stats
    final stats = await _calculateStats();
    _cachedStats = stats;
    _lastCacheTime = DateTime.now();
    return stats;
  }

  /// Calculate stats from workout history
  static Future<Map<String, dynamic>> _calculateStats() async {
    final prefs = await PreferencesCache.getInstance();
    final history = prefs.getStringList('workout_history') ?? [];
    final loggedRaw = prefs.getString('logged_workouts');

    final now = DateTime.now();
    final startOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));

    int thisWeek = 0;
    int lastWeek = 0;
    double thisWeekVol = 0;
    double lastWeekVol = 0;
    Map<String, double> prs = {};
    Set<String> thisWeekDates = {};

    // Only process recent workouts for performance (last 6 months)
    final sixMonthsAgo = now.subtract(const Duration(days: 180));
    
    for (var item in history) {
      try {
        final workout = jsonDecode(item);
        final dateStr = workout['date']?.toString() ?? '';
        final date = DateTime.tryParse(dateStr);
        if (date == null || date.isBefore(sixMonthsAgo)) continue;

        // Calculate volume
        double workoutVolume = 0;
        final sets = workout['sets'] as List<dynamic>? ?? [];
        for (var ex in sets) {
          final exSets = ex['sets'] as List<dynamic>? ?? [];
          for (var s in exSets) {
            double w = double.tryParse(s['weight']?.toString() ?? '0') ?? 0;
            int r = int.tryParse(s['reps']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
            workoutVolume += w * r;

            // Track PRs
            String exName = ex['exercise']?.toString() ?? '';
            if (exName.isNotEmpty && w > 0) {
              prs[exName] = (prs[exName] ?? 0) < w ? w : prs[exName]!;
            }
          }
        }

        if (date.isAfter(startOfThisWeek.subtract(const Duration(days: 1)))) {
          thisWeek++;
          thisWeekVol += workoutVolume;
          thisWeekDates.add(dateStr);
        } else if (date.isAfter(startOfLastWeek.subtract(const Duration(days: 1)))) {
          lastWeek++;
          lastWeekVol += workoutVolume;
        }
      } catch (e) {
        continue;
      }
    }

    // Calculate streak
    int streak = 0;
    int maxStreak = 0;
    if (loggedRaw != null) {
      try {
        final logged = Map<String, dynamic>.from(jsonDecode(loggedRaw));
        DateTime checkDate = DateTime(now.year, now.month, now.day);

        // Check consecutive days backwards
        while (true) {
          final key = checkDate.toIso8601String().split('T')[0];
          if (logged.containsKey(key)) {
            streak++;
            checkDate = checkDate.subtract(const Duration(days: 1));
          } else {
            break;
          }
        }

        // Calculate longest streak (limit to last 2 years for performance)
        final twoYearsAgo = now.subtract(const Duration(days: 730));
        List<DateTime> dates = logged.keys
            .map((k) => DateTime.tryParse(k))
            .whereType<DateTime>()
            .where((d) => d.isAfter(twoYearsAgo))
            .toList();
        dates.sort();
        int tempStreak = 1;
        for (int i = 1; i < dates.length; i++) {
          if (dates[i].difference(dates[i - 1]).inDays == 1) {
            tempStreak++;
            maxStreak = tempStreak > maxStreak ? tempStreak : maxStreak;
          } else {
            tempStreak = 1;
          }
        }
        maxStreak = maxStreak > streak ? maxStreak : streak;
      } catch (e) {
        // If logged_workouts is corrupted, just use 0
      }
    }

    // Mark which days of current week have workouts
    List<bool> weekDays = List.filled(7, false);
    for (int i = 0; i < 7; i++) {
      final day = startOfThisWeek.add(Duration(days: i));
      final key = day.toIso8601String().split('T')[0];
      if (thisWeekDates.contains(key)) {
        weekDays[i] = true;
      }
    }

    // Load weekly goal
    int goal = prefs.getInt('weekly_goal') ?? 4;

    return {
      'thisWeekWorkouts': thisWeek,
      'lastWeekWorkouts': lastWeek,
      'thisWeekVolume': thisWeekVol,
      'lastWeekVolume': lastWeekVol,
      'currentStreak': streak,
      'longestStreak': maxStreak,
      'recentPRs': prs,
      'weekDays': weekDays,
      'weeklyGoal': goal,
    };
  }

  /// Invalidate cache (call after logging/editing/deleting workouts)
  static void invalidateCache() {
    _cachedStats = null;
    _lastCacheTime = null;
  }
}
