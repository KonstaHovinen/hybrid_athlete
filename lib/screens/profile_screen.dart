import 'package:flutter/material.dart' hide Badge; 
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data_models.dart';
import '../app_theme.dart';
import 'device_sync_screen.dart';
import '../utils/cloud_sync_service.dart';

// --- PROFILE SCREEN ---
class ProfileScreen extends StatefulWidget {
  final UserProfile profile;
  const ProfileScreen({super.key, required this.profile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserProfile _profile;
  late List<Badge> _earnedBadges;
  int _totalWorkouts = 0;
  int _currentStreak = 0;
  String _memberSince = "";
  bool _isGitHubConnected = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _earnedBadges = ProfileManager.awardEarnedBadges(_profile);
    if (_earnedBadges.isEmpty) {
      _earnedBadges = [ProfileManager.getAllAvailableBadges().first];
    }
    _loadExtraStats();
    _checkGitHubStatus();
  }

  Future<void> _loadExtraStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('workout_history') ?? [];
      final loggedRaw = prefs.getString('logged_workouts');
      
      // Calculate streak
      int streak = 0;
      if (loggedRaw != null) {
        try {
          final logged = Map<String, String>.from(jsonDecode(loggedRaw));
          DateTime checkDate = DateTime.now();
          while (true) {
            final key = DateTime(checkDate.year, checkDate.month, checkDate.day).toIso8601String().split('T')[0];
            if (logged.containsKey(key)) {
              streak++;
              checkDate = checkDate.subtract(const Duration(days: 1));
            } else {
              break;
            }
          }
        } catch (e) {
          // ignore malformed logged_workouts data
        }
      }

      // Get member since date (first workout)
      String memberSince = "Today";
      if (history.isNotEmpty) {
        try {
          final firstWorkout = jsonDecode(history.first);
          memberSince = firstWorkout['date'] ?? "Today";
        } catch (e) {
          // ignore
        }
      }

      if (mounted) {
        setState(() {
          _totalWorkouts = history.length;
          _currentStreak = streak;
          _memberSince = memberSince;
        });
      }
    } catch (e) {
      // Fail gracefully if stats can't be loaded
      if (mounted) {
        setState(() {
          _totalWorkouts = 0;
          _currentStreak = 0;
          _memberSince = "Today";
        });
      }
    }
  }

  Future<void> _checkGitHubStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('github_token');
    if (mounted) {
      setState(() {
        _isGitHubConnected = token != null && token.isNotEmpty;
      });
    }
  }

  // --- BADGE CLICK LOGIC ---
  void _handleBadgeClick(Badge badge, bool isEarned) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isEarned ? badge.color.withValues(alpha: 0.2) : AppColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(badge.icon, size: 50, color: isEarned ? badge.color : AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              Text(badge.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                badge.description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              if (!isEarned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, color: AppColors.error, size: 16),
                      SizedBox(width: 6),
                      Text("LOCKED", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted)),
            ),
            if (isEarned)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [badge.color, badge.color.withValues(alpha: 0.7)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onPressed: () async {
                    setState(() {
                      _profile.activeBadgeId = badge.id;
                    });
                    await ProfileManager.saveProfile(_profile);
                    if (!mounted) return;
                    if (context.mounted) Navigator.pop(context); 
                  },
                  child: const Text("Set Active", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        );
      },
    );
  }

  // --- RESTORED: NAME EDIT LOGIC ---
  void _editName() {
    final TextEditingController nameController = TextEditingController(text: _profile.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Name"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                _profile.name = nameController.text;
                await ProfileManager.saveProfile(_profile);
                if (mounted) setState(() {});
              }
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showGitHubTokenDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final currentToken = prefs.getString('github_token') ?? '';
    final TextEditingController tokenController = TextEditingController(text: currentToken);

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("GitHub Cloud Sync"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter your GitHub Personal Access Token with 'gist' scope to enable cloud sync.",
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                labelText: "GitHub Token",
                border: OutlineInputBorder(),
                hintText: "ghp_...",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await prefs.setString('github_token', tokenController.text.trim());
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Token saved! Syncing data...")),
                );
                // Immediate sync to restore data
                await CloudSyncService.downloadFromCloud();
                await _loadExtraStats(); // Refresh UI
                _checkGitHubStatus();
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("👤 Profile"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header Card with gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar with active badge
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
                          ),
                          child: const Icon(Icons.person, size: 45, color: Colors.white),
                        ),
                        if (_profile.activeBadgeId != null)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: () {
                              final activeBadge = _earnedBadges.firstWhere(
                                (b) => b.id == _profile.activeBadgeId,
                                orElse: () => _earnedBadges.isNotEmpty ? _earnedBadges.first : Badge(id: 'default', name: 'Default', description: '', icon: Icons.person, color: Colors.grey),
                              );
                              return Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.warning,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(color: AppColors.warning.withValues(alpha: 0.5), blurRadius: 10),
                                  ],
                                ),
                                child: Icon(
                                  activeBadge.icon,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              );
                            }(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _profile.name,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: Colors.white70),
                          onPressed: _editName,
                        ),
                      ],
                    ),
                    Text("Member since $_memberSince", style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                    const SizedBox(height: 20),
                    // Quick stats row
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _QuickStat(value: "$_totalWorkouts", label: "Workouts"),
                          Container(width: 1, height: 35, color: Colors.white24),
                          _QuickStat(value: "$_currentStreak", label: "Day Streak"),
                          Container(width: 1, height: 35, color: Colors.white24),
                          _QuickStat(value: "${_profile.maxLifted.toStringAsFixed(0)}kg", label: "Max Lift"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Badges Section with progress
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.workspace_premium, color: AppColors.warning, size: 22),
                      SizedBox(width: 8),
                      Text("Badges", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text("${_earnedBadges.length}/${ProfileManager.getAllAvailableBadges().length}", 
                      style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 150, 
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: ProfileManager.getAllAvailableBadges().length,
                  itemBuilder: (context, index) {
                    final badge = ProfileManager.getAllAvailableBadges()[index];
                    final isEarned = _earnedBadges.any((b) => b.id == badge.id);
                    final isActive = _profile.activeBadgeId == badge.id;
                    final progress = _getBadgeProgress(badge.id);
                    
                    return GestureDetector(
                      onTap: () => _handleBadgeClick(badge, isEarned),
                      child: Container(
                        width: 105,
                        margin: const EdgeInsets.only(right: 12.0),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: isActive 
                            ? Border.all(color: AppColors.warning, width: 2) 
                            : Border.all(color: AppColors.surfaceLight),
                          boxShadow: isActive ? [
                            BoxShadow(color: AppColors.warning.withValues(alpha: 0.3), blurRadius: 10),
                          ] : null,
                        ),
                        child: Opacity(
                          opacity: isEarned ? 1.0 : 0.5, 
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: badge.color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(badge.icon, size: 32, color: badge.color),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                child: Text(
                                  badge.name, 
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                                  maxLines: 2,
                                ),
                              ),
                              if (isActive)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text("ACTIVE", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              if (!isEarned && progress != null) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 4,
                                      backgroundColor: AppColors.surfaceLight,
                                      valueColor: AlwaysStoppedAnimation(badge.color.withValues(alpha: 0.7)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),

              // Personal Records Section
              const Row(
                children: [
                  Icon(Icons.emoji_events, color: AppColors.accent, size: 22),
                  SizedBox(width: 8),
                  Text("Personal Records", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              if (_profile.personalRecords.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.emoji_events_outlined, size: 48, color: AppColors.textMuted),
                      SizedBox(height: 12),
                      Text("No records yet", style: TextStyle(color: AppColors.textMuted)),
                      Text("Complete workouts to track PRs!", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )
              else
                ..._profile.personalRecords.entries.map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.emoji_events, color: AppColors.warning, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${e.value.toStringAsFixed(1)} kg",
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                )),
              
              const SizedBox(height: 28),
              
              // Stats Overview
              const Row(
                children: [
                  Icon(Icons.analytics, color: AppColors.secondary, size: 22),
                  SizedBox(width: 8),
                  Text("Lifetime Stats", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.fitness_center,
                      color: AppColors.secondary,
                      label: "Total Exercises",
                      value: "${_profile.totalExercises}",
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.directions_run,
                      color: AppColors.primary,
                      label: "Total Run Sessions",
                      value: "${_profile.totalRunExercises}",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.trending_up,
                      color: AppColors.accent,
                      label: "Max Lifted",
                      value: "${_profile.maxLifted.toStringAsFixed(0)} kg",
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.local_fire_department,
                      color: AppColors.warning,
                      label: "Total Workouts",
                      value: "$_totalWorkouts",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload, color: AppColors.accent, size: 32),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cloud Backup',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Sync data to GitHub Gist',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isGitHubConnected)
                      IconButton(
                        icon: const Icon(Icons.settings, color: AppColors.accent),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const DeviceSyncScreen()),
                          );
                        },
                      ),
                    ElevatedButton(
                      onPressed: _showGitHubTokenDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isGitHubConnected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
                        foregroundColor: _isGitHubConnected ? AppColors.primary : AppColors.accent,
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isGitHubConnected) ...[
                            const Icon(Icons.check, size: 16),
                            const SizedBox(width: 4),
                          ],
                          Text(_isGitHubConnected ? 'Connected' : 'Setup'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  double? _getBadgeProgress(String badgeId) {
    switch (badgeId) {
      case 'first_exercise':
        return _profile.totalExercises >= 1 ? 1.0 : 0.0;
      case 'hundred_exercises':
        return (_profile.totalExercises / 100).clamp(0.0, 1.0);
      case 'iron_lifter':
        return (_profile.maxLifted / 150).clamp(0.0, 1.0);
      case 'runner':
        return (_profile.longestRunDistance / 10).clamp(0.0, 1.0);
      default:
        return null;
    }
  }
}

// --- EDIT GOALS SCREEN ---
class EditGoalsScreen extends StatefulWidget {
  const EditGoalsScreen({super.key});
  @override
  State<EditGoalsScreen> createState() => _EditGoalsScreenState();
}

// Helper widgets for Profile
class _QuickStat extends StatelessWidget {
  final String value;
  final String label;
  const _QuickStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatTile({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _EditGoalsScreenState extends State<EditGoalsScreen> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    Map<String, double> goals = await ProStats.getGoals();
    if (!mounted) return;
    setState(() {
      goals.forEach((name, value) {
        _controllers[name] = TextEditingController(text: value.toString());
      });
    });
  }

  void _saveAllGoals() async {
    Map<String, double> newGoals = {};
    _controllers.forEach((name, controller) {
      newGoals[name] = double.tryParse(controller.text) ?? 0;
    });
    await ProStats.saveGoals(newGoals);
                    if (!mounted) return;
    if (mounted) Navigator.pop(context);
  }

  // --- RESTORED: ADD NEW GOAL ---
  void _addNewGoal() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController valueController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Goal"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Exercise Name")),
            const SizedBox(height: 10),
            TextField(controller: valueController, decoration: const InputDecoration(labelText: "Target"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && valueController.text.isNotEmpty) {
                setState(() {
                  _controllers[nameController.text] = TextEditingController(text: valueController.text);
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _deleteGoal(String key) {
    setState(() {
      _controllers.remove(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Goals"),
        actions: [
          // ADD BUTTON
          IconButton(icon: const Icon(Icons.add), onPressed: _addNewGoal),
          // SAVE BUTTON
          IconButton(icon: const Icon(Icons.save), onPressed: _saveAllGoals),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _controllers.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: ListTile(
              title: Text(entry.key),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: entry.value,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteGoal(entry.key),
                  )
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}