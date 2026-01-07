import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'preferences_cache.dart';
import 'device_id.dart';

/// Sync Service - Exports workout data to JSON for desktop sync
/// Works like athlete → coach: phone logs, desktop analyzes
class SyncService {
  static const String _syncFileName = 'hybrid_athlete_sync.json';
  static const String _syncFolderName = 'HybridAthlete';

  /// Get sync file path (works on both mobile and desktop)
  static Future<File> _getSyncFile() async {
    if (kIsWeb) {
      throw UnsupportedError('File system not supported on web');
    }

    Directory directory;
    
    if (Platform.isWindows) {
      // Windows: Use Documents folder
      final documentsPath = Platform.environment['USERPROFILE'] ?? '';
      directory = Directory('$documentsPath\\Documents\\$_syncFolderName');
    } else if (Platform.isMacOS || Platform.isLinux) {
      // macOS/Linux: Use Documents folder
      final homePath = Platform.environment['HOME'] ?? '';
      directory = Directory('$homePath/Documents/$_syncFolderName');
    } else {
      // Mobile: Use app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      directory = Directory('${appDir.path}/$_syncFolderName');
    }
    
    // Create directory if it doesn't exist
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    return File('${directory.path}/$_syncFileName');
  }

  /// Generate export data map (platform agnostic)
  static Future<Map<String, dynamic>> generateExportData() async {
    final prefs = await PreferencesCache.getInstance();
    
    // Gather all data
    final workoutHistory = prefs.getStringList('workout_history') ?? [];
    final loggedWorkouts = prefs.getString('logged_workouts');
    final scheduledWorkouts = prefs.getString('scheduled_workouts');
    final userTemplates = prefs.getString('user_templates');
    final userExercises = prefs.getString('user_exercises');
    final userProfile = prefs.getString('user_profile');
    final exerciseSettings = prefs.getString('exercise_custom_settings');
    final proGoals = prefs.getString('pro_goals');
    final weeklyGoal = prefs.getInt('weekly_goal');
    final activeBadgeId = prefs.getString('active_badge_id');
    final earnedBadges = prefs.getStringList('earned_badges');
    
    // Get device ID for sync metadata (handle web gracefully)
    String deviceId = 'web_device';
    Map<String, String> deviceInfo = {'name': 'Web', 'platform': 'web'};
    
    if (!kIsWeb) {
      deviceId = await DeviceId.getDeviceId();
      deviceInfo = await DeviceId.getDeviceInfo();
    }
    
    return {
      'version': '1.0',
      'lastSync': DateTime.now().toIso8601String(),
      'deviceId': deviceId,
      'deviceName': deviceInfo['name'],
      'platform': deviceInfo['platform'],
      'data': {
        'workout_history': workoutHistory,
        'logged_workouts': loggedWorkouts,
        'scheduled_workouts': scheduledWorkouts,
        'user_templates': userTemplates,
        'user_exercises': userExercises,
        'user_profile': userProfile,
        'exercise_settings': exerciseSettings,
        'pro_goals': proGoals,
        'weekly_goal': weeklyGoal,
        'active_badge_id': activeBadgeId,
        'earned_badges': earnedBadges,
      },
    };
  }

  /// Export all workout data to sync file
  static Future<bool> exportData() async {
    try {
      if (kIsWeb) return false; // File system not supported on web

      final syncData = await generateExportData();
      final syncFile = await _getSyncFile();
      
      // Write to file
      await syncFile.writeAsString(
        jsonEncode(syncData),
        mode: FileMode.write,
      );
      
      return true;
    } catch (e) {
      debugPrint('Sync export error: $e');
      return false;
    }
  }

  /// Import data from sync file (for desktop)
  static Future<Map<String, dynamic>?> importData() async {
    try {
      if (kIsWeb) return null;

      final syncFile = await _getSyncFile();
      
      if (!await syncFile.exists()) {
        return null;
      }
      
      final content = await syncFile.readAsString();
      final syncData = jsonDecode(content) as Map<String, dynamic>;
      
      return syncData;
    } catch (e) {
      debugPrint('Sync import error: $e');
      return null;
    }
  }

  /// Check if sync file exists and get last sync time
  static Future<DateTime?> getLastSyncTime() async {
    try {
      final syncFile = await _getSyncFile();
      if (!await syncFile.exists()) return null;
      
      final content = await syncFile.readAsString();
      final syncData = jsonDecode(content) as Map<String, dynamic>;
      final lastSyncStr = syncData['lastSync'] as String?;
      
      if (lastSyncStr != null) {
        return DateTime.parse(lastSyncStr);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get sync file path (for display)
  static Future<String> getSyncFilePath() async {
    final syncFile = await _getSyncFile();
    return syncFile.path;
  }
}
