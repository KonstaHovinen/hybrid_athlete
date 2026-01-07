import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data_models.dart';
import '../app_theme.dart';
import '../design_system.dart';
import '../utils/stats_cache.dart';
import '../utils/workout_history_cache.dart';
import '../utils/preferences_cache.dart';
import '../utils/sync_service.dart';
import '../utils/hybrid_athlete_ai.dart';
import 'dart:async';
import 'stats_screen.dart';
import 'history_screen.dart';
import 'workout_calendar_screen.dart';
import 'profile_screen.dart';
import 'device_sync_screen.dart';
import 'ai_assistant_screen.dart';

/// Desktop Command Center - View-only version for planning and analysis
/// NO active workout tracking - designed for desktop viewing and planning
class DesktopCommandCenter extends StatefulWidget {
  const DesktopCommandCenter({super.key});

  @override
  State<DesktopCommandCenter> createState() => _DesktopCommandCenterState();
}

class _DesktopCommandCenterState extends State<DesktopCommandCenter> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  UserProfile? _userProfile;
  DateTime? _lastSyncTime;
  bool _isSyncing = false;
  Timer? _syncCheckTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadProfile();
    _checkSyncStatus();
    _startSyncWatcher();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _syncCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkSyncStatus() async {
    final lastSync = await SyncService.getLastSyncTime();
    if (!mounted) return;
    setState(() => _lastSyncTime = lastSync);
  }

  void _startSyncWatcher() {
    // Check for sync file changes every 2 seconds
    _syncCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final lastSync = await SyncService.getLastSyncTime();
      if (lastSync != _lastSyncTime && mounted) {
        setState(() {
          _lastSyncTime = lastSync;
        });
        // Refresh data when sync file changes
        if (_selectedIndex == 0) {
          setState(() {}); // Trigger dashboard refresh
        }
      }
    });
  }

  Future<void> _manualSync() async {
    setState(() => _isSyncing = true);
    await Future.delayed(const Duration(milliseconds: 500)); // Visual feedback
    await _checkSyncStatus();
    if (!mounted) return;
    setState(() => _isSyncing = false);
  }

  Future<void> _loadProfile() async {
    // Try to load from sync file first (desktop mode)
    final syncData = await SyncService.importData();
    if (syncData != null && syncData['data'] != null) {
      final data = syncData['data'] as Map<String, dynamic>;
      final profileJson = data['user_profile'] as String?;
      if (profileJson != null) {
        try {
          final profile = UserProfile.fromJson(jsonDecode(profileJson));
          if (!mounted) return;
          setState(() => _userProfile = profile);
          return;
        } catch (e) {
          // Fall through to regular load
        }
      }
    }
    
    // Fallback to regular profile load
    final profile = await ProfileManager.getProfile();
    if (!mounted) return;
    setState(() => _userProfile = profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                right: BorderSide(color: AppColors.surfaceLight, width: 1),
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: AppSpacing.paddingLG,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    border: Border(
                      bottom: BorderSide(color: AppColors.surfaceLight, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: AppSpacing.paddingSM,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: AppBorderRadius.borderRadiusMD,
                        ),
                        child: const Icon(
                          Icons.dashboard,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      AppSpacing.gapHorizontalMD,
                      const Expanded(
                        child: Text(
                          "Command Center",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // User Profile Section
                Container(
                  padding: AppSpacing.paddingLG,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withOpacity(0.2),
                        child: Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      AppSpacing.gapHorizontalMD,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userProfile?.name ?? 'Athlete',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              "${_userProfile?.totalExercises ?? 0} workouts",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(),
                
                // Navigation Items
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _NavItem(
                        icon: Icons.dashboard_rounded,
                        label: "Dashboard",
                        isSelected: _selectedIndex == 0,
                        onTap: () => setState(() => _selectedIndex = 0),
                      ),
                      _NavItem(
                        icon: Icons.bar_chart_rounded,
                        label: "Statistics",
                        isSelected: _selectedIndex == 1,
                        onTap: () => setState(() => _selectedIndex = 1),
                      ),
                      _NavItem(
                        icon: Icons.history_rounded,
                        label: "History",
                        isSelected: _selectedIndex == 2,
                        onTap: () => setState(() => _selectedIndex = 2),
                      ),
                      _NavItem(
                        icon: Icons.calendar_month_rounded,
                        label: "Calendar",
                        isSelected: _selectedIndex == 3,
                        onTap: () => setState(() => _selectedIndex = 3),
                      ),
                      _NavItem(
                        icon: Icons.emoji_events_rounded,
                        label: "Goals",
                        isSelected: _selectedIndex == 4,
                        onTap: () => setState(() => _selectedIndex = 4),
                      ),
                      _NavItem(
                        icon: Icons.fitness_center_rounded,
                        label: "Templates",
                        isSelected: _selectedIndex == 5,
                        onTap: () => setState(() => _selectedIndex = 5),
                      ),
                      _NavItem(
                        icon: Icons.person_rounded,
                        label: "Profile",
                        isSelected: _selectedIndex == 6,
                        onTap: () => setState(() => _selectedIndex = 6),
                      ),
                      _NavItem(
                        icon: Icons.sync_rounded,
                        label: "Device Sync",
                        isSelected: _selectedIndex == 7,
                        onTap: () => setState(() => _selectedIndex = 7),
                      ),
                    ],
                  ),
                ),
                
                // Sync Status & Footer
                Container(
                  padding: AppSpacing.paddingLG,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.surfaceLight, width: 1),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Sync Status
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            padding: AppSpacing.paddingSM,
                            decoration: BoxDecoration(
                              color: _lastSyncTime != null
                                  ? AppColors.primary.withOpacity(0.15 * _pulseAnimation.value)
                                  : AppColors.textMuted.withOpacity(0.1),
                              borderRadius: AppBorderRadius.borderRadiusMD,
                              border: Border.all(
                                color: _lastSyncTime != null
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _lastSyncTime != null
                                      ? Icons.sync
                                      : Icons.sync_disabled,
                                  size: 16,
                                  color: _lastSyncTime != null
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                                AppSpacing.gapHorizontalSM,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _lastSyncTime != null
                                            ? "Synced"
                                            : "No Sync",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _lastSyncTime != null
                                              ? AppColors.primary
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                      if (_lastSyncTime != null)
                                        Text(
                                          _formatSyncTime(_lastSyncTime!),
                                          style: Theme.of(context).textTheme.labelSmall,
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: _isSyncing
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.refresh, size: 18),
                                  onPressed: _isSyncing ? null : _manualSync,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      AppSpacing.gapVerticalMD,
                      Text(
                        "Desktop Command Center",
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      AppSpacing.gapVerticalXS,
                      Text(
                        "View & Plan • No Active Tracking",
                        style: Theme.of(context).textTheme.labelSmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content Area
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _DashboardView();
      case 1:
        return const WeeklyStatsScreen();
      case 2:
        return const WorkoutHistoryScreen();
      case 3:
        return const WorkoutCalendarScreen();
      case 4:
        return const EditGoalsScreen();
      case 5:
        return const _TemplatesView();
      case 6:
        return _userProfile != null
            ? ProfileScreen(profile: _userProfile!)
            : const Center(child: CircularProgressIndicator());
      case 7:
        return const DeviceSyncScreen();
      default:
        return _DashboardView();
    }
  }

  String _formatSyncTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) {
      return "Just now";
    } else if (diff.inMinutes < 60) {
      return "${diff.inMinutes}m ago";
    } else if (diff.inHours < 24) {
      return "${diff.inHours}h ago";
    } else {
      return "${diff.inDays}d ago";
    }
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.15)
                : Colors.transparent,
            border: isSelected
                ? Border(
                    left: BorderSide(
                      color: AppColors.primary,
                      width: 3,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
                size: 24,
              ),
              AppSpacing.gapHorizontalMD,
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardView extends StatefulWidget {
  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _recentWorkouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final stats = await StatsCache.getStats();
    final recent = await WorkoutHistoryCache.getRecentWorkouts(5);
    
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _recentWorkouts = recent;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = _stats!;
    
    return SingleChildScrollView(
      padding: AppSpacing.paddingXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  AppSpacing.gapVerticalXS,
                  Text(
                    "Command Center Dashboard",
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ],
              ),
              Container(
                padding: AppSpacing.paddingMD,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: AppBorderRadius.borderRadiusLG,
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                    AppSpacing.gapHorizontalSM,
                    Text(
                      "View & Plan Mode",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          AppSpacing.gapVerticalXL,
          
          // Quick Stats Grid
          Row(
            children: [
              Expanded(
                child: _QuickStatCard(
                  icon: Icons.local_fire_department,
                  iconColor: AppColors.warning,
                  label: "Current Streak",
                  value: "${stats['currentStreak']} days",
                  subtitle: "Longest: ${stats['longestStreak']} days",
                ),
              ),
              AppSpacing.gapHorizontalMD,
              Expanded(
                child: _QuickStatCard(
                  icon: Icons.fitness_center,
                  iconColor: AppColors.accent,
                  label: "This Week",
                  value: "${stats['thisWeekWorkouts']} workouts",
                  subtitle: "${stats['lastWeekWorkouts']} last week",
                ),
              ),
              AppSpacing.gapHorizontalMD,
              Expanded(
                child: _QuickStatCard(
                  icon: Icons.trending_up,
                  iconColor: AppColors.primary,
                  label: "Volume",
                  value: "${((stats['thisWeekVolume'] as double) / 1000).toStringAsFixed(1)}k kg",
                  subtitle: "${stats['thisWeekWorkouts']} workouts",
                ),
              ),
            ],
          ),
          
          AppSpacing.gapVerticalXL,
          
          // Recent Workouts
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history, color: AppColors.primary, size: 24),
                        AppSpacing.gapHorizontalSM,
                        Text(
                          "Recent Workouts",
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    AppSpacing.gapVerticalMD,
                    if (_recentWorkouts.isEmpty)
                      Container(
                        padding: AppSpacing.paddingXL,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: AppBorderRadius.borderRadiusLG,
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: Center(
                          child: Text(
                            "No workouts yet",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._recentWorkouts.map((workout) => Container(
                        margin: EdgeInsets.only(bottom: AppSpacing.md),
                        padding: AppSpacing.paddingLG,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: AppBorderRadius.borderRadiusLG,
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: AppSpacing.paddingSM,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: AppBorderRadius.borderRadiusMD,
                              ),
                              child: Icon(
                                workout['type'] == 'running'
                                    ? Icons.directions_run
                                    : workout['type'] == 'futsal'
                                        ? Icons.sports_soccer
                                        : Icons.fitness_center,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            AppSpacing.gapHorizontalMD,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    workout['template_name'] ?? 'Workout',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  AppSpacing.gapVerticalXS,
                                  Text(
                                    workout['date'] ?? '',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (workout['energy'] != null)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.15),
                                  borderRadius: AppBorderRadius.borderRadiusSM,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bolt,
                                      size: 14,
                                      color: AppColors.warning,
                                    ),
                                    AppSpacing.gapHorizontalXS,
                                    Text(
                                      "${workout['energy']}/5",
                                      style: TextStyle(
                                        color: AppColors.warning,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      )),
                  ],
                ),
              ),
              
              AppSpacing.gapHorizontalXL,
              
              // Goals & PRs
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.emoji_events, color: AppColors.warning, size: 24),
                        AppSpacing.gapHorizontalSM,
                        Text(
                          "Recent PRs",
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    AppSpacing.gapVerticalMD,
                    FutureBuilder<Map<String, double>>(
                      future: ProStats.getGoals(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        final prs = stats['recentPRs'] as Map<String, double>;
                        final goals = snapshot.data!;
                        
                        if (prs.isEmpty) {
                          return Container(
                            padding: AppSpacing.paddingXL,
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: AppBorderRadius.borderRadiusLG,
                              border: Border.all(color: AppColors.surfaceLight),
                            ),
                            child: Center(
                              child: Text(
                                "Complete workouts to see PRs",
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          );
                        }
                        
                        return Column(
                          children: prs.entries.take(5).map((entry) {
                            final goal = goals[entry.key] ?? 0;
                            final progress = goal > 0 ? (entry.value / goal).clamp(0.0, 1.0) : 0.0;
                            
                            return Container(
                              margin: EdgeInsets.only(bottom: AppSpacing.md),
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
                                      Expanded(
                                        child: Text(
                                          entry.key,
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                          vertical: AppSpacing.xs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.warning.withOpacity(0.15),
                                          borderRadius: AppBorderRadius.borderRadiusSM,
                                        ),
                                        child: Text(
                                          "${entry.value.toStringAsFixed(1)} kg",
                                          style: TextStyle(
                                            color: AppColors.warning,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (goal > 0) ...[
                                    AppSpacing.gapVerticalSM,
                                    LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                      backgroundColor: AppColors.surfaceLight,
                                      valueColor: AlwaysStoppedAnimation(
                                        progress >= 1.0
                                            ? AppColors.primary
                                            : AppColors.secondary,
                                      ),
                                    ),
                                    AppSpacing.gapVerticalXS,
                                    Text(
                                      "${(progress * 100).toStringAsFixed(0)}% of ${goal} kg goal",
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;

  const _QuickStatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingXL,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppBorderRadius.borderRadiusLG,
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: AppSpacing.paddingSM,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: AppBorderRadius.borderRadiusMD,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          AppSpacing.gapVerticalMD,
          Text(
            value,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: iconColor,
            ),
          ),
          AppSpacing.gapVerticalXS,
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          AppSpacing.gapVerticalXS,
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TemplatesView extends StatefulWidget {
  const _TemplatesView();

  @override
  State<_TemplatesView> createState() => _TemplatesViewState();
}

class _TemplatesViewState extends State<_TemplatesView> {
  List<WorkoutTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final prefs = await PreferencesCache.getInstance();
    final String? templatesJson = prefs.getString('user_templates');
    
    if (!mounted) return;
    
    setState(() {
      if (templatesJson != null) {
        try {
          List<dynamic> decoded = jsonDecode(templatesJson);
          _templates = decoded
              .map((e) => WorkoutTemplate.fromJson(e))
              .toList();
        } catch (e) {
          _templates = [];
        }
      } else {
        _templates = [];
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: AppSpacing.paddingXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fitness_center, color: AppColors.primary, size: 28),
              AppSpacing.gapHorizontalMD,
              Text(
                "Workout Templates",
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ],
          ),
          AppSpacing.gapVerticalXL,
          
          if (_templates.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fitness_center_outlined, size: 64, color: AppColors.textMuted),
                    AppSpacing.gapVerticalLG,
                    Text(
                      "No templates yet",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    AppSpacing.gapVerticalSM,
                    Text(
                      "Create templates on your mobile device",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: _templates.length,
                itemBuilder: (context, index) {
                  final template = _templates[index];
                  return Container(
                    padding: AppSpacing.paddingLG,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: AppBorderRadius.borderRadiusLG,
                      border: Border.all(color: AppColors.surfaceLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: AppSpacing.paddingSM,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: AppBorderRadius.borderRadiusMD,
                          ),
                          child: Icon(
                            Icons.playlist_play,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        AppSpacing.gapVerticalMD,
                        Text(
                          template.name,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        AppSpacing.gapVerticalXS,
                        Text(
                          "${template.exercises.length} exercises",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        AppSpacing.gapVerticalSM,
                        Expanded(
                          child: Text(
                            template.exercises.take(3).join(", "),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
