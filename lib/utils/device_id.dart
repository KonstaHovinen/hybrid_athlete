import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'preferences_cache.dart';

/// Device Identity System
/// Each device gets a unique ID that identifies "YOU" across all your devices
/// Devices with the same ID can sync on the same network
class DeviceId {
  static const String _deviceIdKey = 'device_identity_id';
  static const String _deviceNameKey = 'device_identity_name';
  
  /// Get or generate device ID
  /// This ID is YOUR identity - same across all your devices
  static Future<String> getDeviceId() async {
    final prefs = await PreferencesCache.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);
    
    if (deviceId == null || deviceId.isEmpty) {
      // Generate new device ID
      deviceId = _generateDeviceId();
      await prefs.setString(_deviceIdKey, deviceId);
    }
    
    return deviceId;
  }
  
  /// Generate a unique device ID
  /// Format: "HA-[8-char-hash]" (e.g., "HA-a3f9b2c1")
  static String _generateDeviceId() {
    // Combine timestamp + random + platform info for uniqueness
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    final platform = Platform.operatingSystem;
    
    final combined = '$timestamp-$random-$platform';
    final bytes = utf8.encode(combined);
    final hash = sha256.convert(bytes);
    
    // Take first 8 characters of hash for readable ID
    final shortHash = hash.toString().substring(0, 8);
    return 'HA-$shortHash';
  }
  
  /// Set device ID (for pairing devices - enter same ID on all devices)
  static Future<bool> setDeviceId(String id) async {
    if (!_isValidDeviceId(id)) {
      return false;
    }
    
    final prefs = await PreferencesCache.getInstance();
    await prefs.setString(_deviceIdKey, id);
    return true;
  }
  
  /// Validate device ID format
  static bool _isValidDeviceId(String id) {
    // Format: HA-xxxxxxxx (8 hex chars)
    final regex = RegExp(r'^HA-[a-f0-9]{8}$', caseSensitive: false);
    return regex.hasMatch(id);
  }
  
  /// Get device name (for display)
  static Future<String> getDeviceName() async {
    final prefs = await PreferencesCache.getInstance();
    String? name = prefs.getString(_deviceNameKey);
    
    if (name == null || name.isEmpty) {
      // Generate default name based on platform
      if (Platform.isAndroid) {
        name = 'Android Phone';
      } else if (Platform.isIOS) {
        name = 'iPhone';
      } else if (Platform.isWindows) {
        name = 'Windows PC';
      } else if (Platform.isMacOS) {
        name = 'Mac';
      } else if (Platform.isLinux) {
        name = 'Linux PC';
      } else {
        name = 'Device';
      }
      
      await prefs.setString(_deviceNameKey, name);
    }
    
    return name;
  }
  
  /// Set device name (custom name for this device)
  static Future<void> setDeviceName(String name) async {
    final prefs = await PreferencesCache.getInstance();
    await prefs.setString(_deviceNameKey, name);
  }
  
  /// Check if device ID is set
  static Future<bool> hasDeviceId() async {
    final prefs = await PreferencesCache.getInstance();
    return prefs.containsKey(_deviceIdKey);
  }
  
  /// Get full device info (ID + name)
  static Future<Map<String, String>> getDeviceInfo() async {
    return {
      'id': await getDeviceId(),
      'name': await getDeviceName(),
      'platform': Platform.operatingSystem,
    };
  }
}
