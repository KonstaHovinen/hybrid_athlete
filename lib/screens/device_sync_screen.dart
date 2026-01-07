import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../app_theme.dart';
import '../design_system.dart';
import '../utils/device_id.dart';
import '../utils/network_sync.dart';
import 'dart:async';

/// Device Sync Screen - Manage device ID and network sync
class DeviceSyncScreen extends StatefulWidget {
  const DeviceSyncScreen({super.key});

  @override
  State<DeviceSyncScreen> createState() => _DeviceSyncScreenState();
}

class _DeviceSyncScreenState extends State<DeviceSyncScreen> {
  String _deviceId = '';
  String _deviceName = '';
  bool _isServerRunning = false;
  List<String> _discoveredDevices = [];
  bool _isDiscovering = false;
  String? _connectedDevice;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _checkServerStatus();
    _startStatusUpdates();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startStatusUpdates() {
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _isServerRunning = NetworkSync.isServerRunning();
          _connectedDevice = NetworkSync.getConnectedDevice();
        });
      }
    });
  }

  Future<void> _loadDeviceInfo() async {
    final id = await DeviceId.getDeviceId();
    final name = await DeviceId.getDeviceName();
    if (!mounted) return;
    setState(() {
      _deviceId = id;
      _deviceName = name;
    });
  }

  void _checkServerStatus() {
    setState(() {
      _isServerRunning = NetworkSync.isServerRunning();
    });
  }

Future<void> _toggleServer() async {
    if (_isServerRunning) {
      await NetworkSync.stopServer();
    } else {
      final started = await NetworkSync.startServer();
      if (!started && mounted) {
        String errorMessage = 'Failed to start server. Check network permissions.';
        if (kIsWeb) {
          errorMessage = 'Web PWA: Network sync limited. Use native app for full sync features.';
        } else if (Platform.isIOS) {
          errorMessage = 'iOS: Check Local Network permissions in Settings > Hybrid Athlete.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
    _checkServerStatus();
  }

Future<void> _discoverDevices() async {
    setState(() => _isDiscovering = true);
    final devices = await NetworkSync.discoverDevices();
    if (!mounted) return;
    
    // Show platform-specific message if no devices found
    if (devices.isEmpty) {
      String message = 'No devices found. Check WiFi and Device ID.';
      if (kIsWeb) {
        message = 'Web PWA: Network discovery limited. Use native app for device scanning.';
      } else if (Platform.isIOS) {
        message = 'iOS: Make sure Local Network permission is granted in Settings.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
    
    setState(() {
      _discoveredDevices = devices;
      _isDiscovering = false;
    });
  }

  Future<void> _connectToDevice(String deviceUrl) async {
    final success = await NetworkSync.connectAndSync(deviceUrl);
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Synced successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
      setState(() {
        _connectedDevice = deviceUrl;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Sync failed. Try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _setDeviceId() async {
    final controller = TextEditingController(text: _deviceId);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Enter Device ID', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'HA-xxxxxxxx',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Set'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final success = await DeviceId.setDeviceId(result);
      if (success && mounted) {
        await _loadDeviceInfo();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device ID updated!'),
            backgroundColor: AppColors.primary,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid device ID format. Use: HA-xxxxxxxx'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _setDeviceName() async {
    final controller = TextEditingController(text: _deviceName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Device Name', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'My Phone',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await DeviceId.setDeviceName(result);
      if (mounted) {
        await _loadDeviceInfo();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Sync'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingXL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device Identity Card
            Container(
              padding: AppSpacing.paddingXL,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: AppBorderRadius.borderRadiusLG,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.fingerprint, color: Colors.white, size: 32),
                      AppSpacing.gapHorizontalMD,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Device ID',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            AppSpacing.gapVerticalXS,
                            Text(
                              _deviceId,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white),
                        onPressed: _setDeviceId,
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalMD,
                  Row(
                    children: [
                      const Icon(Icons.devices, color: Colors.white70, size: 20),
                      AppSpacing.gapHorizontalSM,
                      Expanded(
                        child: Text(
                          _deviceName,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                      TextButton(
                        onPressed: _setDeviceName,
                        child: const Text('Rename', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            AppSpacing.gapVerticalXL,

            // Server Status
            Container(
              padding: AppSpacing.paddingLG,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: AppBorderRadius.borderRadiusLG,
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sync Server',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          AppSpacing.gapVerticalXS,
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _isServerRunning
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              AppSpacing.gapHorizontalSM,
                              Text(
                                _isServerRunning ? 'Running' : 'Stopped',
                                style: TextStyle(
                                  color: _isServerRunning
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: Icon(_isServerRunning ? Icons.stop : Icons.play_arrow),
                        label: Text(_isServerRunning ? 'Stop' : 'Start'),
                        onPressed: _toggleServer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isServerRunning
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalMD,
                  Text(
                    _isServerRunning
                        ? 'Other devices with the same ID can connect to this device.'
                        : 'Start server to allow other devices to sync with you.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            AppSpacing.gapVerticalXL,

            // Discover Devices
            Container(
              padding: AppSpacing.paddingLG,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: AppBorderRadius.borderRadiusLG,
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Discover Devices',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: _isDiscovering
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search),
                        label: const Text('Scan'),
                        onPressed: _isDiscovering ? null : _discoverDevices,
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalMD,
                  if (_discoveredDevices.isEmpty)
                    Text(
                      _isDiscovering
                          ? 'Scanning network...'
                          : 'No devices found. Make sure devices are on the same WiFi and have the same Device ID.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    ..._discoveredDevices.map((deviceUrl) => Container(
                          margin: EdgeInsets.only(bottom: AppSpacing.md),
                          padding: AppSpacing.paddingMD,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppBorderRadius.borderRadiusMD,
                            border: Border.all(
                              color: _connectedDevice == deviceUrl
                                  ? AppColors.primary
                                  : AppColors.surfaceLight,
                              width: _connectedDevice == deviceUrl ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.devices,
                                color: _connectedDevice == deviceUrl
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                              AppSpacing.gapHorizontalMD,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      deviceUrl,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _connectedDevice == deviceUrl
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    if (_connectedDevice == deviceUrl)
                                      Text(
                                        'Connected',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppColors.primary,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                              if (_connectedDevice != deviceUrl)
                                TextButton(
                                  onPressed: () => _connectToDevice(deviceUrl),
                                  child: const Text('Connect'),
                                ),
                            ],
                          ),
                        )),
                ],
              ),
            ),

            AppSpacing.gapVerticalXL,

            // Info Card
            Container(
              padding: AppSpacing.paddingLG,
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.5),
                borderRadius: AppBorderRadius.borderRadiusLG,
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primary),
                      AppSpacing.gapHorizontalSM,
                      const Text(
                        'How It Works',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalMD,
                  _buildInfoItem('1', 'Set the same Device ID on all your devices'),
                  _buildInfoItem('2', 'Connect all devices to the same WiFi network'),
                  _buildInfoItem('3', 'Start server on one device, scan on others'),
                  _buildInfoItem('4', 'Devices automatically sync when connected'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String number, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          AppSpacing.gapHorizontalMD,
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
