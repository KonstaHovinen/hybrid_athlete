import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import '../app_theme.dart';
import '../design_system.dart';
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
    _loadVersion();
    _loadSyncMeta();
    _aiStatus = HybridAthleteAI.getStatus();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${info.version}+${info.buildNumber}';
    });
  }

  Future<void> _loadSyncMeta() async {
    final prefs = await PreferencesCache.getInstance();
    setState(() {
      _gistId = prefs.getString('sync_gist_id');
      _lastSync = prefs.getString('last_sync_time');
    });
  }

  Future<void> _checkUpdates() async {
    setState(() { _checkingUpdate = true; _updateStatus = 'Checking...'; });
    try {
      final uri = Uri.parse('https://api.github.com/repos/KonstaHovinen/hybrid_athlete/releases/latest');
      final resp = await http.get(uri);
      final body = resp.body;
      if (resp.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final tag = (json['tag_name'] ?? '').toString();
        setState(() { _updateStatus = tag.isEmpty ? 'Up-to-date' : 'Latest release: $tag'; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update check complete: ${_updateStatus}')),
        );
      } else {
        setState(() { _updateStatus = 'Error ${resp.statusCode}'; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update check failed: HTTP ${resp.statusCode}')),
        );
      }
    } catch (e) {
      setState(() { _updateStatus = 'Error'; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update check error: $e')),
      );
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
      setState(() { _syncStatus = 'Upload: ${results['upload_success']}, Download: ${results['download_success']}'; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync done. Upload: ${results['upload_success']}  Download: ${results['download_success']}  Gist: ${results['gist_id'] ?? 'n/a'}')),
      );
    } catch (e) {
      setState(() { _syncStatus = 'Error'; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync error: $e')),
      );
    } finally {
      if (mounted) setState(() { _syncing = false; });
    }
  }

  Future<void> _testAI() async {
    try {
      final res = await HybridAthleteAI.processCommand('ping');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res == null ? 'AI test failed' : 'AI responded.')),
      );
      setState(() { _aiStatus = HybridAthleteAI.getStatus(); });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI test error: $e')),
      );
    }
  }

  Future<void> _exportData() async {
    try {
      final prefs = await PreferencesCache.getInstance();
      final data = <String, dynamic>{
        'workout_history': prefs.getStringList('workout_history') ?? [],
        'logged_workouts': prefs.getString('logged_workouts'),
        'scheduled_workouts': prefs.getString('scheduled_workouts'),
        'user_templates': prefs.getString('user_templates'),
        'user_exercises': prefs.getString('user_exercises'),
        'user_profile': prefs.getString('user_profile'),
        'exercise_settings': prefs.getString('exercise_settings'),
        'pro_goals': prefs.getString('pro_goals'),
        'weekly_goal': prefs.getInt('weekly_goal'),
        'earned_badges': prefs.getStringList('earned_badges') ?? [],
        'ai_memory': prefs.getString('ai_memory'),
        'ai_interaction_history': prefs.getStringList('ai_interaction_history') ?? [],
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      await showDialog(context: context, builder: (c) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Export Data'),
        content: SingleChildScrollView(child: SelectableText(jsonStr)),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export error: $e')),
      );
    }
  }

  Future<void> _importData() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Manual import via UI is not available yet. Use GitHub Sync or manually merge JSON.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Updates'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingXL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Updates'),
            _card([
              _kv('Current version', _version.isEmpty ? '...' : _version),
              AppSpacing.gapVerticalSM,
              Row(children: [
                ElevatedButton(
                  onPressed: _checkingUpdate ? null : _checkUpdates,
                  child: Text(_checkingUpdate ? 'Checking...' : 'Check for updates now'),
                ),
                AppSpacing.gapHorizontalMD,
                Expanded(child: Text(_updateStatus, style: const TextStyle(fontSize: 12))),
              ]),
            ]),

            AppSpacing.gapVerticalXL,
            _sectionHeader('Sync (GitHub Gist)'),
            _card([
              _kv('Token configured', GitHubGistSync.getSyncStatus()['has_token'] == true ? 'Yes' : 'No'),
              _kv('Gist ID', _gistId ?? '—'),
              _kv('Last sync', _lastSync ?? '—'),
              AppSpacing.gapVerticalSM,
              Row(children: [
                ElevatedButton(
                  onPressed: _syncing ? null : _syncNow,
                  child: Text(_syncing ? 'Syncing...' : 'Sync now'),
                ),
                AppSpacing.gapHorizontalMD,
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GitHubSetupScreen())).then((_) => _loadSyncMeta()),
                  child: const Text('Manage token'),
                ),
              ]),
              if (_syncStatus.isNotEmpty) ...[
                AppSpacing.gapVerticalXS,
                Text(_syncStatus, style: const TextStyle(fontSize: 12)),
              ],
            ]),

            AppSpacing.gapVerticalXL,
            _sectionHeader('AI diagnostics'),
            _card([
              _kv('Initialized', (_aiStatus['initialized'] == true).toString()),
              _kv('Learning active', (_aiStatus['learning_active'] == true).toString()),
              _kv('Interactions', (_aiStatus['interaction_count'] ?? 0).toString()),
              _kv('Memory size', (_aiStatus['memory_size'] ?? 0).toString()),
              _kv('Last learning', (_aiStatus['last_learning'] ?? '—').toString()),
              AppSpacing.gapVerticalSM,
              ElevatedButton(onPressed: _testAI, child: const Text('Test AI')),
            ]),

            AppSpacing.gapVerticalXL,
            _sectionHeader('Import / Export'),
            _card([
              Row(children: [
                ElevatedButton(onPressed: _exportData, child: const Text('Export data')),
                AppSpacing.gapHorizontalMD,
                ElevatedButton(onPressed: _importData, child: const Text('Import data')),
              ]),
              if (!kIsWeb) const SizedBox(height: 8),
              if (!kIsWeb) const Text('Import expects a file named import_hybrid_athlete.json in the app directory.', style: TextStyle(fontSize: 12)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  );

  Widget _kv(String k, String v) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [Text(k), Flexible(child: Align(alignment: Alignment.centerRight, child: Text(v, overflow: TextOverflow.ellipsis)))],
  );

  Widget _card(List<Widget> children) => Container(
    width: double.infinity,
    padding: AppSpacing.paddingLG,
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: AppBorderRadius.borderRadiusLG,
      border: Border.all(color: AppColors.surfaceLight),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}
