import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'preferences_cache.dart';
import 'device_id.dart';
import 'sync_service.dart';

/// Free Cloud Sync using GitHub Gists
/// Perfect for personal use - completely free and reliable
class GitHubGistSync {
  static const String _githubApi = 'https://api.github.com';
  static String? _userToken;
  static String? _syncGistId;
  static bool _isInitialized = false;
  
  /// Initialize GitHub Gist sync
  static Future<bool> initialize() async {
    try {
      final prefs = await PreferencesCache.getInstance();
      _userToken = prefs.getString('github_token');
      _syncGistId = prefs.getString('sync_gist_id');
      
      // Check if token is valid
      if (_userToken != null && _userToken!.isNotEmpty) {
        final isValid = await _validateToken();
        if (!isValid) {
          await prefs.remove('github_token');
          _userToken = null;
        }
      }
      
      _isInitialized = true;
      print('GitHub Gist sync initialized');
      return true;
    } catch (e) {
      print('GitHub Gist initialization failed: $e');
      return false;
    }
  }
  
  /// Set up GitHub token for sync
  static Future<bool> setupToken(String token) async {
    try {
      // Validate token format
      if (!token.startsWith('ghp_') && token.length < 30) {
        throw Exception('Invalid GitHub token format');
      }
      
      // Test token
      final response = await http.get(
        Uri.parse('$_githubApi/user'),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final prefs = await PreferencesCache.getInstance();
        await prefs.setString('github_token', token);
        _userToken = token;
        print('GitHub token validated and saved');
        return true;
      } else {
        throw Exception('Invalid GitHub token');
      }
    } catch (e) {
      print('GitHub token setup failed: $e');
      return false;
    }
  }
  
  /// Upload data to GitHub Gist
  static Future<bool> uploadToGist() async {
    if (_userToken == null) {
      throw Exception('GitHub token not set');
    }
    
    try {
      final deviceId = await DeviceId.getDeviceId();
      final syncData = await SyncService.importData();
      
      if (syncData == null) return false;
      
      final gistContent = {
        'description': 'Hybrid Athlete Sync Data - Device: $deviceId',
        'public': false, // Private gist
        'files': {
          'hybrid_athlete_sync.json': {
            'content': jsonEncode(syncData),
          }
        },
      };
      
      final response = await _createOrUpdateGist(gistContent);
      
      if (response != null) {
        print('Data uploaded to GitHub Gist');
        return true;
      }
      
      return false;
    } catch (e) {
      print('Gist upload error: $e');
      return false;
    }
  }
  
  /// Download data from GitHub Gist
  static Future<bool> downloadFromGist() async {
    if (_userToken == null || _syncGistId == null) {
      return false;
    }
    
    try {
      final response = await http.get(
        Uri.parse('$_githubApi/gists/$_syncGistId'),
        headers: {
          'Authorization': 'token $_userToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final gist = jsonDecode(response.body);
        final content = gist['files']['hybrid_athlete_sync.json']['content'];
        
        if (content != null) {
          final syncData = jsonDecode(content) as Map<String, dynamic>;
          await _importGistData(syncData);
          print('Data downloaded from GitHub Gist');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Gist download error: $e');
      return false;
    }
  }
  
  /// Bidirectional sync with GitHub Gist
  static Future<Map<String, dynamic>> bidirectionalSync() async {
    try {
      // 1. Upload current data
      final uploadSuccess = await uploadToGist();
      
      // 2. Download latest data (in case other device updated)
      final downloadSuccess = await downloadFromGist();
      
      return {
        'upload_success': uploadSuccess,
        'download_success': downloadSuccess,
        'timestamp': DateTime.now().toIso8601String(),
        'gist_id': _syncGistId,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
  
  /// Get sync status
  static Map<String, dynamic> getSyncStatus() {
    return {
      'initialized': _isInitialized,
      'has_token': _userToken != null,
      'has_gist': _syncGistId != null,
      'sync_ready': _userToken != null && _syncGistId != null,
    };
  }
  
  /// Clear GitHub sync data
  static Future<void> clearSyncData() async {
    final prefs = await PreferencesCache.getInstance();
    await prefs.remove('github_token');
    await prefs.remove('sync_gist_id');
    _userToken = null;
    _syncGistId = null;
    print('GitHub sync data cleared');
  }
  
  /// Validate GitHub token
  static Future<bool> _validateToken() async {
    if (_userToken == null) return false;
    
    try {
      final response = await http.get(
        Uri.parse('$_githubApi/user'),
        headers: {
          'Authorization': 'token $_userToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Create or update Gist
  static Future<Map<String, dynamic>?> _createOrUpdateGist(Map<String, dynamic> gistContent) async {
    if (_userToken == null) return null;
    
    try {
      final response = await http.post(
        Uri.parse('$_githubApi/gists'),
        headers: {
          'Authorization': 'token $_userToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(gistContent),
      ).timeout(Duration(seconds: 15));
      
      if (response.statusCode == 201) {
        final gist = jsonDecode(response.body);
        _syncGistId = gist['id'];
        
        // Save gist ID
        final prefs = await PreferencesCache.getInstance();
        await prefs.setString('sync_gist_id', _syncGistId!);
        
        return gist;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Import Gist data to local storage
  static Future<void> _importGistData(Map<String, dynamic> gistData) async {
    final prefs = await PreferencesCache.getInstance();
    final data = gistData['data'] as Map<String, dynamic>?;
    
    if (data == null) return;
    
    // Import all data types
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
    
    // Invalidate caches
    await _invalidateAllCaches();
  }
  
  /// Invalidate all caches after sync
  static Future<void> _invalidateAllCaches() async {
    final prefs = await PreferencesCache.getInstance();
    await prefs.remove('cached_stats');
    await prefs.remove('stats_cache_timestamp');
    await prefs.remove('workout_history_cache');
    await prefs.remove('workout_history_cache_timestamp');
    print('All caches invalidated after GitHub Gist sync');
  }
}