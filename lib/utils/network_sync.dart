import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'device_id.dart';
import 'sync_service.dart';
import 'preferences_cache.dart';

/// Network Sync Service
/// Devices with the same Device ID can sync over local network
/// Uses HTTP server/client model - one device hosts, others connect
class NetworkSync {
  static HttpServer? _server;
  static Timer? _discoveryTimer;
  static String? _connectedDeviceUrl;
  
  /// Start HTTP server to host sync data
  /// Other devices can connect to this device
  static Future<bool> startServer({int port = 8080}) async {
    try {
      if (_server != null) {
        return true; // Already running
      }
      
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server!.listen((HttpRequest request) {
        _handleRequest(request);
      });
      
      return true;
    } catch (e) {
      print('Failed to start sync server: $e');
      return false;
    }
  }
  
  /// Stop the HTTP server
  static Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
  }
  
  /// Handle incoming HTTP requests
  static void _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;
    
    // CORS headers for web compatibility
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');
    
    if (method == 'OPTIONS') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }
    
    try {
      if (path == '/ping' && method == 'GET') {
        // Device discovery - check if device ID matches
        final queryParams = request.uri.queryParameters;
        final remoteDeviceId = queryParams['deviceId'];
        final localDeviceId = await DeviceId.getDeviceId();
        
        if (remoteDeviceId == localDeviceId) {
          // Same device ID - allow connection
          final deviceInfo = await DeviceId.getDeviceInfo();
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'status': 'ok',
              'deviceId': localDeviceId,
              'deviceName': deviceInfo['name'],
              'platform': deviceInfo['platform'],
            }));
        } else {
          // Different device ID - reject
          request.response
            ..statusCode = 403
            ..write(jsonEncode({'status': 'forbidden', 'reason': 'device_id_mismatch'}));
        }
        await request.response.close();
        
      } else if (path == '/sync' && method == 'GET') {
        // Get sync data
        final syncData = await SyncService.importData();
        if (syncData != null) {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(syncData));
        } else {
          request.response
            ..statusCode = 404
            ..write(jsonEncode({'status': 'no_data'}));
        }
        await request.response.close();
        
      } else if (path == '/sync' && method == 'POST') {
        // Receive sync data from another device
        final body = await utf8.decoder.bind(request).join();
        final syncData = jsonDecode(body) as Map<String, dynamic>;
        
        // Import the data
        await _importSyncData(syncData);
        
        request.response
          ..statusCode = 200
          ..write(jsonEncode({'status': 'imported'}));
        await request.response.close();
        
      } else {
        request.response
          ..statusCode = 404
          ..write(jsonEncode({'status': 'not_found'}));
        await request.response.close();
      }
    } catch (e) {
      request.response
        ..statusCode = 500
        ..write(jsonEncode({'status': 'error', 'message': e.toString()}));
      await request.response.close();
    }
  }
  
  /// Import sync data into local storage
  static Future<void> _importSyncData(Map<String, dynamic> syncData) async {
    final prefs = await PreferencesCache.getInstance();
    final data = syncData['data'] as Map<String, dynamic>?;
    
    if (data == null) return;
    
    // Import all data fields
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
    
    // Invalidate caches
    // Note: Import the cache classes if needed
  }
  
  /// Discover devices on local network with same device ID
  /// Scans common local IP ranges
  static Future<List<String>> discoverDevices() async {
    final localDeviceId = await DeviceId.getDeviceId();
    final discovered = <String>[];
    
    // Get local IP address
    final localIp = await _getLocalIpAddress();
    if (localIp == null) return discovered;
    
    // Extract network prefix (e.g., 192.168.1.x)
    final parts = localIp.split('.');
    if (parts.length != 4) return discovered;
    
    final networkPrefix = '${parts[0]}.${parts[1]}.${parts[2]}.';
    
    // Scan common IPs in network (1-254)
    final futures = <Future>[];
    for (int i = 1; i <= 254; i++) {
      final ip = '$networkPrefix$i';
      if (ip == localIp) continue; // Skip self
      
      futures.add(_checkDevice(ip, localDeviceId).then((url) {
        if (url != null) discovered.add(url);
      }));
    }
    
    await Future.wait(futures, eagerError: false);
    return discovered;
  }
  
  /// Check if a specific IP has a device with matching ID
  static Future<String?> _checkDevice(String ip, String deviceId) async {
    try {
      final url = 'http://$ip:8080/ping?deviceId=$deviceId';
      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 1));
      
      if (response.statusCode == 200) {
        return 'http://$ip:8080';
      }
    } catch (e) {
      // Device not found or not responding - ignore
    }
    return null;
  }
  
  /// Get local IP address
  static Future<String?> _getLocalIpAddress() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error getting local IP: $e');
    }
    return null;
  }
  
  /// Connect to a discovered device and sync data
  static Future<bool> connectAndSync(String deviceUrl) async {
    try {
      // 1. Get sync data from remote device
      final response = await http.get(Uri.parse('$deviceUrl/sync'));
      
      if (response.statusCode == 200) {
        final syncData = jsonDecode(response.body) as Map<String, dynamic>;
        
        // 2. Import the data
        await _importSyncData(syncData);
        
        // 3. Export our data back (bidirectional sync)
        await SyncService.exportData();
        final ourData = await SyncService.importData();
        if (ourData != null) {
          await http.post(
            Uri.parse('$deviceUrl/sync'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(ourData),
          );
        }
        
        _connectedDeviceUrl = deviceUrl;
        return true;
      }
    } catch (e) {
      print('Sync connection error: $e');
    }
    return false;
  }
  
  /// Start auto-discovery (periodically scan for devices)
  static void startAutoDiscovery(Function(List<String>) onDevicesFound) {
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final devices = await discoverDevices();
      if (devices.isNotEmpty) {
        onDevicesFound(devices);
      }
    });
  }
  
  /// Stop auto-discovery
  static void stopAutoDiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
  }
  
  /// Get server status
  static bool isServerRunning() {
    return _server != null;
  }
  
  /// Get connected device URL
  static String? getConnectedDevice() {
    return _connectedDeviceUrl;
  }
}
