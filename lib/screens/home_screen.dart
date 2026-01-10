import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data_models.dart';
import '../app_theme.dart';
import '../design_system.dart';
import 'futsal_screen.dart';
import 'settings_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfile? _userProfile;
  int _totalGoals = 0;
  int _totalAssists = 0;
  int _matchesPlayed = 0;
  int _practiceHours = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadProfile();
    await _loadFutsalStats();
  }

  Future<void> _loadProfile() async {
    UserProfile profile = await ProfileManager.getProfile();
    if (!mounted) return;
    setState(() => _userProfile = profile);
  }

  Future<void> _loadFutsalStats() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('workout_history') ?? [];
    
    int goals = 0;
    int assists = 0;
    int matches = 0;

    for (String item in history) {
      try {
        final data = jsonDecode(item);
        if (data['type'] == 'futsal' || data['template_name'] == 'Futsal Session') {
          matches++;
          goals += (data['totalGoals'] as int? ?? 0);
          assists += (data['totalAssists'] as int? ?? 0);
        }
      } catch (e) {
        debugPrint('Error parsing history item: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _totalGoals = goals;
      _totalAssists = assists;
      _matchesPlayed = matches;
    });
  }

  void _navigateToFutsal() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FutsalLoggerScreen()),
    );
    if (mounted) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    String dateDisplay = DateFormat('EEEE, MMM d').format(DateTime.now());
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingXL, // Use padding from design system
          child: Column(
            children: [
              _buildHeader(dateDisplay),
              AppSpacing.gapVerticalXL,
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LEFT SIDE: Buttons
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMainFutsalButton(),
                          AppSpacing.gapVerticalLG,
                          _buildSecondaryButtons(),
                        ],
                      ),
                    ),
                    AppSpacing.gapHorizontalXL,
                    // RIGHT SIDE: Stats Summary
                    Expanded(
                      flex: 3,
                      child: _buildStatsSummary(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String date) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              date.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.5,
              ),
            ),
            AppSpacing.gapVerticalXS,
            Text(
              "Welcome, ${_userProfile?.name ?? 'Athlete'}",
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ],
        ),
        // Redundant settings icon removed as per cleaner UI, or can keep as shortcut
        IconButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => _loadData());
          },
          icon: const Icon(Icons.settings, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildMainFutsalButton() {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _navigateToFutsal,
          borderRadius: AppBorderRadius.borderRadiusXXL,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: AppBorderRadius.borderRadiusXXL,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sports_soccer, size: 64, color: Colors.white),
                ),
                AppSpacing.gapVerticalLG,
                const Text(
                  "FUTSAL",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Log Session",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButtons() {
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          Expanded(
            child: _SecondaryButton(
              icon: Icons.history,
              label: "History",
              color: AppColors.secondary,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkoutHistoryScreen()));
              },
            ),
          ),
          AppSpacing.gapHorizontalMD,
          Expanded(
            child: _SecondaryButton(
              icon: Icons.settings_outlined, // Changed to settings icon
              label: "Settings", // Changed from Profile to Settings
              color: AppColors.accent,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => _loadData());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary() {
    return Container(
      padding: AppSpacing.paddingLG,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppBorderRadius.borderRadiusXL,
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: AppColors.textMuted),
              AppSpacing.gapHorizontalSM,
              const Text(
                "SUMMARY",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalLG,
          _StatRow(
            label: "Goals",
            value: "$_totalGoals",
            icon: Icons.emoji_events,
            color: AppColors.primary,
          ),
          Divider(color: AppColors.surfaceLight, height: 32),
          _StatRow(
            label: "Assists",
            value: "$_totalAssists",
            icon: Icons.assistant_direction,
            color: AppColors.secondary,
          ),
          Divider(color: AppColors.surfaceLight, height: 32),
          _StatRow(
            label: "Points",
            value: "${_totalGoals + _totalAssists}",
            icon: Icons.star,
            color: AppColors.warning,
          ),
          Divider(color: AppColors.surfaceLight, height: 32),
          _StatRow(
            label: "Matches",
            value: "$_matchesPlayed",
            icon: Icons.calendar_today,
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppBorderRadius.borderRadiusLG,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppBorderRadius.borderRadiusLG,
            border: Border.all(color: AppColors.surfaceLight),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        AppSpacing.gapHorizontalMD,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
      ],
    );
  }
}