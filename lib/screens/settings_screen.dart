import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../design_system.dart';
import '../data_models.dart';
import '../utils/github_gist_sync.dart';
import '../utils/preferences_cache.dart';
import '../utils/hybrid_athlete_ai.dart';
import 'github_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Profile State
  UserProfile _profile = UserProfile();
  bool _loadingProfile = true;

  // Settings State
  String _version = '';
  bool _checkingUpdate = false;
  String _updateStatus = '';
  bool _syncing = false;
  String _syncStatus = '';
  Map<String, dynamic> _aiStatus = {};
  String? _gistId;
  String? _lastSync;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadProfile(),
      _loadVersion(),
      _loadSyncMeta(),
    ]);
    _aiStatus = HybridAthleteAI.getStatus();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileManager.getProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _loadingProfile = false;
      });
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = '${info.version}+${info.buildNumber}';
      });
    }
  }

  Future<void> _loadSyncMeta() async {
    final prefs = await PreferencesCache.getInstance();
    if (mounted) {
      setState(() {
        _gistId = prefs.getString('sync_gist_id');
        _lastSync = prefs.getString('last_sync_time');
      });
    }
  }

  Future<void> _editName() async {
    final TextEditingController nameController = TextEditingController(text: _profile.name);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text("Edit Name"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: "Display Name",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                setState(() {
                  _profile.name = nameController.text;
                });
                await ProfileManager.saveProfile(_profile);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // --- Settings Actions ---

  Future<void> _checkUpdates() async {
    setState(() { _checkingUpdate = true; _updateStatus = 'Checking...'; });
    try {
      final uri = Uri.parse('https://api.github.com/repos/KonstaHovinen/hybrid_athlete/releases/latest');
      final resp = await http.get(uri);
      
      if (!mounted) return;

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final tag = (json['tag_name'] ?? '').toString();
        setState(() { _updateStatus = tag.isEmpty ? 'Up-to-date' : 'Latest release: $tag'; });
      } else {
        setState(() { _updateStatus = 'Error ${resp.statusCode}'; });
      }
    } catch (e) {
      if (mounted) setState(() { _updateStatus = 'Error'; });
    } finally {
      if (mounted) setState(() { _checkingUpdate = false; });
    }
  }

  Future<void> _syncNow() async {
    setState(() { _syncing = true; _syncStatus = 'Syncing...'; });
    try {
      final results = await GitHubGistSync.bidirectionalSync();
      final prefs = await PreferencesCache.getInstance();
      await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
      await _loadSyncMeta();
      // Reload profile in case sync updated it
      await _loadProfile();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync complete. Upload: ${results['upload_success']}, Download: ${results['download_success']}')),
      );
      setState(() { _syncStatus = 'Synced just now'; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync error: $e')));
        setState(() { _syncStatus = 'Error syncing'; });
      }
    } finally {
      if (mounted) setState(() { _syncing = false; });
    }
  }

  Future<void> _exportData() async {
    try {
      final prefs = await PreferencesCache.getInstance();
      final data = <String, dynamic>{
        'workout_history': prefs.getStringList('workout_history') ?? [],
        'logged_workouts': prefs.getString('logged_workouts'),
        'user_templates': prefs.getString('user_templates'),
        'user_exercises': prefs.getString('user_exercises'),
        'user_profile': prefs.getString('user_profile'),
        'exercise_settings': prefs.getString('exercise_settings'),
        'pro_goals': prefs.getString('pro_goals'),
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      
      if (!mounted) return;

      await showDialog(context: context, builder: (c) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Export Data'),
        content: SingleChildScrollView(child: SelectableText(jsonStr)),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surface,
      ),
      body: _loadingProfile 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          padding: AppSpacing.paddingXL,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- PERSONAL INFO SECTION ---
              _sectionHeader('Personal Info'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: AppBorderRadius.borderRadiusLG,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                      ),
                      child: const Icon(Icons.person, size: 30, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profile.name,
                            style: const TextStyle(
                              fontSize: 20, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.white
                            ),
                          ),
                          Text(
                            "Athlete", 
                            style: TextStyle(
                              fontSize: 14, 
                              color: Colors.white.withValues(alpha: 0.8)
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _editName,
                      icon: const Icon(Icons.edit, color: Colors.white),
                      tooltip: "Edit Name",
                    ),
                  ],
                ),
              ),

              AppSpacing.gapVerticalXL,

              // --- SETTINGS SECTIONS ---
              _sectionHeader('Updates'),
              _card([
                _kv('Version', _version.isEmpty ? '...' : _version),
                AppSpacing.gapVerticalSM,
                Row(children: [
                  ElevatedButton(
                    onPressed: _checkingUpdate ? null : _checkUpdates,
                    child: Text(_checkingUpdate ? 'Checking...' : 'Check for updates'),
                  ),
                  AppSpacing.gapHorizontalMD,
                  Expanded(child: Text(_updateStatus, style: const TextStyle(fontSize: 12))),
                ]),
              ]),

              AppSpacing.gapVerticalXL,
              _sectionHeader('Sync (GitHub Gist)'),
              _card([
                _kv('Status', GitHubGistSync.getSyncStatus()['has_token'] == true ? 'Token Configured' : 'No Token'),
                _kv('Last sync', _lastSync ?? 'Never'),
                AppSpacing.gapVerticalSM,
                Row(children: [
                  ElevatedButton(
                    onPressed: _syncing ? null : _syncNow,
                    child: Text(_syncing ? 'Syncing...' : 'Sync Now'),
                  ),
                  AppSpacing.gapHorizontalMD,
                  OutlinedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GitHubSetupScreen())).then((_) => _loadSyncMeta()),
                    child: const Text('Configure'),
                  ),
                ]),
              ]),

              AppSpacing.gapVerticalXL,
              _sectionHeader('System'),
              _card([
                 Row(children: [
                  Expanded(child: OutlinedButton(onPressed: _exportData, child: const Text('Export Data'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton(onPressed: () {
                     ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Use GitHub Sync to restore data.')),
                    );
                  }, child: const Text('Import Data'))),
                ]),
                const SizedBox(height: 12),
                _kv('AI Status', _aiStatus['initialized'] == true ? 'Active' : 'Inactive'),
              ]),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
  );

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: const TextStyle(color: AppColors.textMuted)), 
        Text(v, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    ),
  );

  Widget _card(List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.surfaceLight),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}