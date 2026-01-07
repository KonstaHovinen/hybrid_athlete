import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import '../app_theme.dart';
import '../design_system.dart';
import '../utils/cloud_sync_service.dart';
import '../utils/sync_service.dart';
import 'dart:async';

/// Cloud Sync Screen - Manage cloud synchronization
class DeviceSyncScreen extends StatefulWidget {
  const DeviceSyncScreen({super.key});

  @override
  State<DeviceSyncScreen> createState() => _DeviceSyncScreenState();
}

class _DeviceSyncScreenState extends State<DeviceSyncScreen> {
  Timer? _statusTimer;
  bool _isCloudSyncEnabled = false;
  bool _isCloudSyncing = false;

  @override
  void initState() {
    super.initState();
    _startStatusUpdates();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startStatusUpdates() {
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (mounted) {
        final cloudStatus = CloudSyncService.getCloudSyncStatus();
        setState(() {
          _isCloudSyncEnabled = cloudStatus['enabled'] ?? false;
        });
      }
    });
  }

  Future<void> _toggleCloudSync() async {
    setState(() => _isCloudSyncing = true);
    
    try {
      await CloudSyncService.setCloudSyncEnabled(!_isCloudSyncEnabled);
      
                    if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isCloudSyncEnabled ? 'Cloud sync disabled' : 'Cloud sync enabled'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cloud sync error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _isCloudSyncing = false);
    }
  }
  
  Future<void> _manualCloudSync() async {
    setState(() => _isCloudSyncing = true);
    
    try {
      final success = await CloudSyncService.manualCloudSync();
      
                    if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Cloud sync successful!' : 'Cloud sync failed'),
          backgroundColor: success ? AppColors.primary : AppColors.error,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cloud sync error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _isCloudSyncing = false);
    }
  }

  Future<void> _exportData() async {
    try {
      final data = await SyncService.generateExportData();
      final jsonStr = jsonEncode(data);
      
      if (!mounted) return;

      if (kIsWeb) {
        // Show dialog with copy option for Web
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Data'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Copy this JSON data to save your backup:', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  height: 150,
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonStr,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy to Clipboard'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: jsonStr));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data copied to clipboard!')),
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      } else {
        // Native export
        final success = await SyncService.exportData();
        final path = await SyncService.getSyncFilePath();
        
        if (!mounted) return;
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup saved to: $path'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export failed'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Sync'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingXL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cloud Sync Section
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
                            'Cloud Sync',
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
                                  color: _isCloudSyncEnabled
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              AppSpacing.gapHorizontalSM,
                              Text(
                                _isCloudSyncEnabled ? 'Enabled' : 'Disabled',
                                style: TextStyle(
                                  color: _isCloudSyncEnabled
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: Icon(_isCloudSyncEnabled ? Icons.cloud_off : Icons.cloud_upload),
                        label: Text(_isCloudSyncEnabled ? 'Disable' : 'Enable'),
                        onPressed: _isCloudSyncing ? null : _toggleCloudSync,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isCloudSyncEnabled
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalMD,
                  Text(
                    _isCloudSyncEnabled
                        ? 'Your data syncs to the cloud automatically. Works on all platforms including iOS PWA.'
                        : 'Enable cloud sync to backup your data and sync across all devices.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_isCloudSyncEnabled) ...[
                    AppSpacing.gapVerticalMD,
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isCloudSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync),
                        label: Text(_isCloudSyncing ? 'Syncing...' : 'Sync Now'),
                        onPressed: _isCloudSyncing ? null : _manualCloudSync,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            AppSpacing.gapVerticalXL,

            // Data Management Section
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
                  const Row(
                    children: [
                      Icon(Icons.save_alt, color: AppColors.secondary),
                      AppSpacing.gapHorizontalSM,
                      Text(
                        'Manual Backup',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalMD,
                  const Text(
                    'Export your data to a JSON file. Useful for manual backups or transferring data.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  AppSpacing.gapVerticalMD,
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('Export Data (JSON)'),
                      onPressed: _exportData,
                    ),
                  ),
                ],
              ),
            ),

            AppSpacing.gapVerticalXL,

            // Info Card
            Container(
              padding: AppSpacing.paddingLG,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                borderRadius: AppBorderRadius.borderRadiusLG,
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary),
                      AppSpacing.gapHorizontalSM,
                      Text(
                        'How It Works',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalMD,
                  _buildInfoItem('1', 'Data is saved to your private GitHub Gist'),
                  _buildInfoItem('2', 'Sync works automatically every 5 minutes'),
                  _buildInfoItem('3', 'Use "Sync Now" to force an immediate update'),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
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
