import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../design_system.dart';
import '../data_models.dart';
import '../utils/preferences_cache.dart';
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

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await _loadProfile();
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

  Future<void> _importData() async {
     ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use GitHub Sync to restore data automatically.')),
      );
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

              // --- SYSTEM SECTION ---
              _sectionHeader('System'),
              _card([
                 Row(children: [
                  Expanded(child: OutlinedButton(onPressed: _exportData, child: const Text('Export Data'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton(onPressed: _importData, child: const Text('Import Data'))),
                ]),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GitHubSetupScreen())),
                    child: const Text("Configure Cloud Sync", style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
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