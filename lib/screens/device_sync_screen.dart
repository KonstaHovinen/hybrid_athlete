import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import '../app_theme.dart';
import '../design_system.dart';
import '../utils/cloud_sync_service.dart';
import '../utils/sync_service.dart';
import '../utils/preferences_cache.dart';
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
  String _maskedToken = "Not Connected";

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
      final prefs = await PreferencesCache.getInstance();
      final token = prefs.getString('github_token');
      
      if (mounted) {
        final cloudStatus = CloudSyncService.getCloudSyncStatus();
        setState(() {
          _isCloudSyncEnabled = cloudStatus['enabled'] ?? false;
          _maskedToken = (token != null && token.isNotEmpty) 
              ? "•••• ${token.substring(token.length > 4 ? token.length - 4 : 0)}" 
              : "Not Connected";
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

  Future<void> _showTokenDialog() async {
    final prefs = await PreferencesCache.getInstance();
    final currentToken = prefs.getString('github_token') ?? '';
    final TextEditingController tokenController = TextEditingController(text: currentToken);
    bool isObscured = true;

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("GitHub Token"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tokenController,
                obscureText: isObscured,
                decoration: InputDecoration(
                  labelText: "Token",
                  border: const OutlineInputBorder(),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(isObscured ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => isObscured = !isObscured),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: tokenController.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Copied to clipboard")),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
        ),
      ),
    );
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

  Future<void> _importData() async {
    final TextEditingController controller = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste your JSON backup data here:', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '{"version": "1.0", ...}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                if (controller.text.isEmpty) return;
                final data = jsonDecode(controller.text);
                await CloudSyncService.importCloudData(data); // Reuse the import logic
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data imported successfully! Restart app to see changes.')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invalid JSON: $e'), backgroundColor: AppColors.error),
                );
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _runDiagnostics() async {
    setState(() => _isCloudSyncing = true);
    await Future.delayed(const Duration(seconds: 1)); // Fake delay for feel
    
    final isOnline = await CloudSyncService.isCloudSyncAvailable();
    final prefs = await PreferencesCache.getInstance();
    final hasToken = prefs.getString('github_token')?.isNotEmpty ?? false;
    
    if (!mounted) return;
    setState(() => _isCloudSyncing = false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("System Diagnostics"),
        content: Text(
          "System Check:\n\n"
          "• Token Present: ${hasToken ? 'YES' : 'NO'}\n"
          "• Cloud Reachable: ${isOnline ? 'YES' : 'NO'}\n"
          "• App Version: 1.0.2\n"
          "• Platform: ${kIsWeb ? 'Web' : Platform.operatingSystem}",
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
                            'Cloud Backup',
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
                                      ? AppColors.success
                                      : AppColors.textMuted,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              AppSpacing.gapHorizontalSM,
                              Text(
                                _isCloudSyncEnabled ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  color: _isCloudSyncEnabled
                                      ? AppColors.success
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.visibility, color: AppColors.textSecondary),
                        onPressed: _showTokenDialog,
                        tooltip: "View Token",
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalMD,
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.key, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Text(_maskedToken, style: const TextStyle(fontFamily: 'monospace')),
                      ],
                    ),
                  ),
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
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
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
                        'Data Management',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalMD,
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Export'),
                          onPressed: _exportData,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.upload, size: 18),
                          label: const Text('Import'),
                          onPressed: _importData,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            AppSpacing.gapVerticalXL,

            // System Diagnostics
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
                      Icon(Icons.bug_report, color: AppColors.warning),
                      AppSpacing.gapHorizontalSM,
                      Text(
                        'System Diagnostics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapVerticalMD,
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Run System Check'),
                      onPressed: _runDiagnostics,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
