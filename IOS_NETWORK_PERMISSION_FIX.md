# iOS Network Permission Fix for Sync Feature

## Problem
iOS shows "error: check network permissions" when trying to use the sync feature.

## Solution Applied

### 1. Info.plist Updates
Added required permissions to `ios/Runner/Info.plist`:
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app needs local network access to sync workout data between your devices on the same WiFi network.</string>
<key>NSBonjourServices</key>
<array>
	<string>_http._tcp</string>
</array>
```

### 2. Entitlements Files
Created network entitlements files:
- `ios/Runner/DebugProfile.entitlements`
- `ios/Runner/Release.entitlements`

Both contain:
```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
<key>com.apple.security.network.local-wifi</key>
<true/>
```

### 3. Enhanced Error Handling
- Added network permission checks in `NetworkSync` class
- Improved error messages for iOS users
- Better user feedback in the device sync screen

## User Instructions

### For iOS Users:
1. **Build and install the app** with the new permissions
2. **Grant Local Network permission** when prompted (first time using sync)
3. **Manual permission grant** (if missed):
   - Go to iOS Settings > Hybrid Athlete
   - Enable "Local Network" toggle
4. **Ensure both devices are on the same WiFi network**

### Testing Steps:
1. Set the same Device ID on both devices
2. Start sync server on one device
3. Scan for devices on the other device
4. Connect and sync

## Technical Details

The sync feature uses HTTP server/client model:
- One device hosts an HTTP server on port 8080
- Other devices scan the local network (192.168.x.x range)
- Devices connect only if they have the same Device ID
- Bidirectional sync transfers all workout data

## Files Modified
- `ios/Runner/Info.plist` - Added network permissions
- `ios/Runner/DebugProfile.entitlements` - Created network entitlements
- `ios/Runner/Release.entitlements` - Created network entitlements
- `lib/utils/network_sync.dart` - Added permission checks and better error handling
- `lib/screens/device_sync_screen.dart` - Improved iOS error messages