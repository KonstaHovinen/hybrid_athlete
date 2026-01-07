import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'preferences_cache.dart';
import 'sync_service.dart';

/// Cloud Sync Service - Alternative to local network sync
/// Works everywhere including iOS PWA
class CloudSyncService {
  static const String _githubApiUrl = 'https://api.github.com/gists';
  static Timer? _syncTimer;
  static String? _lastCloudSyncId;
  static bool _isCloudSyncEnabled = false;
  
  /// Initialize cloud sync
  static Future<void> initialize() async {
    final prefs = await PreferencesCache.getInstance();
    final isGuestMode = prefs.getBool('guest_mode') ?? false;
    
    // Disable cloud sync in guest mode
    if (isGuestMode) {
      _isCloudSyncEnabled = false;
      await prefs.setBool('cloud_sync_enabled', false);
      return;
    }
    
    _isCloudSyncEnabled = prefs.getBool('cloud_sync_enabled') ?? false;
    
    if (_isCloudSyncEnabled) {
      _startPeriodicSync();
    }
  }
  
  /// Enable/disable cloud sync
  static Future<void> setCloudSyncEnabled(bool enabled) async {
    final prefs = await PreferencesCache.getInstance();
    final isGuestMode = prefs.getBool('guest_mode') ?? false;
    
    // Prevent enabling cloud sync in guest mode
    if (isGuestMode && enabled) {
      throw Exception('Cloud sync is not available in guest mode');
    }
    
    await prefs.setBool('cloud_sync_enabled', enabled);
    _isCloudSyncEnabled = enabled;
    
    if (enabled) {
      _startPeriodicSync();
    } else {
      _syncTimer?.cancel();
    }
  }
  
  /// Upload all data to cloud
  static Future<bool> uploadToCloud() async {
    try {
      final exportData = await SyncService.generateExportData();
      final syncData = exportData['data'] as Map<String, dynamic>?;
      
      if (syncData == null) return false;
      
      // Prepare cloud sync payload
      final cloudData = {
        'timestamp': DateTime.now().toIso8601String(),
        'syncType': 'full_sync',
        'data': syncData,
        'version': '1.0',
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      };
      
      final response = await _uploadToCloudService(cloudData);
      
      if (response != null) {
        _lastCloudSyncId = response;
        debugPrint('Cloud upload successful: $response');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Cloud upload error: $e');
      return false;
    }
  }
  
  /// Download data from cloud
  static Future<bool> downloadFromCloud() async {
    try {
      final cloudData = await _downloadFromCloudService();
      
      if (cloudData != null) {
        await _importCloudData(cloudData);
        debugPrint('Cloud download successful');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Cloud download error: $e');
      return false;
    }
  }
  
  /// Bidirectional cloud sync
  static Future<Map<String, dynamic>> bidirectionalSync() async {
    try {
      // 1. Upload current data
      final uploadSuccess = await uploadToCloud();
      
      // 2. Download latest data
      final downloadSuccess = await downloadFromCloud();
      
      // 3. Resolve conflicts if needed
      final conflictsResolved = await _resolveConflicts();
      
      return {
        'upload_success': uploadSuccess,
        'download_success': downloadSuccess,
        'conflicts_resolved': conflictsResolved,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Bidirectional sync error: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
  
  /// Manual cloud sync triggered by user
  static Future<bool> manualCloudSync() async {
    try {
      final result = await bidirectionalSync();
      return result['error'] == null;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if cloud sync is available
  static Future<bool> isCloudSyncAvailable() async {
    final prefs = await PreferencesCache.getInstance();
    final token = prefs.getString('github_token');
    return token != null && token.isNotEmpty;
  }
  
  /// Get cloud sync status
  static Map<String, dynamic> getCloudSyncStatus() {
    return {
      'enabled': _isCloudSyncEnabled,
      'last_sync_id': _lastCloudSyncId,
      'sync_active': _syncTimer?.isActive ?? false,
    };
  }
  
  /// Upload to GitHub Gist
  static Future<String?> _uploadToCloudService(Map<String, dynamic> data) async {
    try {
      final prefs = await PreferencesCache.getInstance();
      final token = prefs.getString('github_token');
      var gistId = prefs.getString('gist_id');

      if (token == null || token.isEmpty) {
        debugPrint('GitHub token not found');
        return null;
      }

      final contentString = jsonEncode(data);
      final body = {
        "description": "Hybrid Athlete App Data Sync",
        "public": false,
        "files": {
          "hybrid_athlete_data.json": {
            "content": contentString
          }
        }
      };

      http.Response response;
      if (gistId != null && gistId.isNotEmpty) {
        // Update existing Gist
        response = await http.patch(
          Uri.parse('$_githubApiUrl/$gistId'),
          headers: {
            'Authorization': 'token $token',
            'Accept': 'application/vnd.github.v3+json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );
      } else {
        // Create new Gist
        response = await http.post(
          Uri.parse(_githubApiUrl),
          headers: {
            'Authorization': 'token $token',
            'Accept': 'application/vnd.github.v3+json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );
      }
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        final newGistId = result['id'];
        if (gistId != newGistId) {
          await prefs.setString('gist_id', newGistId);
        }
        return newGistId;
      } else {
        debugPrint('Gist upload failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Gist upload error: $e');
    }
    
    return null;
  }
  
  /// Download from GitHub Gist
  static Future<Map<String, dynamic>?> _downloadFromCloudService() async {
    try {
      final prefs = await PreferencesCache.getInstance();
      final token = prefs.getString('github_token');
      var gistId = prefs.getString('gist_id');

      if (token == null) return null;

      // If we have a token but no Gist ID (New Device Login), try to find the data
      if (gistId == null) {
        gistId = await _findGistId(token);
        if (gistId != null) {
          await prefs.setString('gist_id', gistId);
        } else {
          return null; // No existing data found
        }
      }

      final response = await http.get(
        Uri.parse('$_githubApiUrl/$gistId'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final files = jsonResponse['files'] as Map<String, dynamic>;
        if (files.containsKey('hybrid_athlete_data.json')) {
          final content = files['hybrid_athlete_data.json']['content'];
          // The content inside the gist is the cloudData object we uploaded
          return jsonDecode(content);
        }
      }
    } catch (e) {
      debugPrint('Gist download failed: $e');
    }
    
    return null;
  }
  
  /// Find existing Gist ID from GitHub using just the token
  static Future<String?> _findGistId(String token) async {
    try {
      final response = await http.get(
        Uri.parse(_githubApiUrl), // Lists all gists for the user
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> gists = jsonDecode(response.body);
        for (var gist in gists) {
          final files = gist['files'] as Map<String, dynamic>;
          if (files.containsKey('hybrid_athlete_data.json')) {
            return gist['id'];
          }
        }
      }
    } catch (e) {
      debugPrint('Error finding Gist: $e');
    }
    return null;
  }

  /// Import cloud data into local storage
  static Future<void> _importCloudData(Map<String, dynamic> cloudData) async {
    final prefs = await PreferencesCache.getInstance();
    final data = cloudData['data'] as Map<String, dynamic>?;
    
    if (data == null) return;
    
    // Import all data types (ensuring everything syncs)
    if (data['workout_history'] != null) {
      final history = (data['workout_history'] as List).cast<String>();
      await prefs.setStringList('workout_history', history);
    }
    
    if (data['logged_workouts'] != null) {
      await prefs.setString('logged_workouts', data['logged_workouts'] as String);
    }
    
    if (data['scheduled_workouts'] != null) {
      await prefs.setString('scheduled_workouts', data['scheduled_workouts'] as String);
    }
    
    if (data['user_templates'] != null) {
      await prefs.setString('user_templates', data['user_templates'] as String);
    }
    
    if (data['user_exercises'] != null) {
      await prefs.setString('user_exercises', data['user_exercises'] as String);
    }
    
    if (data['user_profile'] != null) {
      await prefs.setString('user_profile', data['user_profile'] as String);
    }
    
    if (data['exercise_settings'] != null) {
      await prefs.setString('exercise_settings', data['exercise_settings'] as String);
    }
    
    if (data['pro_goals'] != null) {
      await prefs.setString('pro_goals', data['pro_goals'] as String);
    }
    
    if (data['weekly_goal'] != null) {
      await prefs.setInt('weekly_goal', data['weekly_goal'] as int);
    }
    
    if (data['active_badge_id'] != null) {
      await prefs.setString('active_badge_id', data['active_badge_id'] as String);
    }
    
    if (data['earned_badges'] != null) {
      await prefs.setStringList('earned_badges', (data['earned_badges'] as List).cast<String>());
    }
    
    // Invalidate all caches to ensure fresh data
    await _invalidateAllCaches();
  }
  
  /// Resolve data conflicts between local and cloud
  static Future<bool> _resolveConflicts() async {
    try {
      // Add conflict resolution logic here
      // For now, assume cloud is latest
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Invalidate all caches after sync
  static Future<void> _invalidateAllCaches() async {
    // Clear stats cache
    final prefs = await PreferencesCache.getInstance();
    await prefs.remove('cached_stats');
    await prefs.remove('stats_cache_timestamp');
    
    // Clear workout history cache
    await prefs.remove('workout_history_cache');
    await prefs.remove('workout_history_cache_timestamp');
    
    debugPrint('All caches invalidated after cloud sync');
  }
  
  /// Start periodic automatic sync
  static void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isCloudSyncEnabled) {
        bidirectionalSync();
      }
    });
  }
  
  /// Stop periodic sync
  static void stopPeriodicSync() {
    _syncTimer?.cancel();
  }
}