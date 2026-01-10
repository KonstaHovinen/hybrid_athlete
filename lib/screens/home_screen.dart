import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
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
  
  // Recent Form (Last 5 matches)
  List<int> _recentImpacts = []; // -1, 0, 1
  // Chart Data (Last 10 matches)
  List<FlSpot> _pointsHistory = [];

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
    
    // Temporary lists for processing
    List<Map<String, dynamic>> futsalSessions = [];

    for (String item in history) {
      try {
        final data = jsonDecode(item);
        if (data['type'] == 'futsal' || data['template_name'] == 'Futsal Session') {
          // Add to totals
          matches++;
          goals += (data['totalGoals'] as int? ?? 0);
          assists += (data['totalAssists'] as int? ?? 0);
          
          futsalSessions.add(data);
        }
      } catch (e) {
        debugPrint('Error parsing history item: $e');
      }
    }

    // Sort by date (assuming ISO string date) and take recent
    // Warning: date string format varies, but usually YYYY-MM-DD. 
    // If identical dates, order in list might matter, but let's assume appended order is chronological.
    // Creating a robust sort might be tricky if date format isn't strict, 
    // but the app appends new logs to the end, so taking the LAST items is usually correct.
    
    // We want the MOST RECENT at the end of the history list.
    // So 'futsalSessions' should already be in chronological order if `history` was.
    
    List<int> impacts = [];
    List<FlSpot> spots = [];
    
    // Take last 5 for Form Guide (Right -> Left = New -> Old? Or L->R?)
    // Standard is: Left is oldest, Right is newest.
    // Or "Recent Form: W W L D W" (Left is most recent?) 
    // Usually Form Guide is displayed L->R as Oldest->Newest or Newest->Oldest.
    // Let's do: [Oldest] ... [Newest] (L->R)
    
    final int totalSessions = futsalSessions.length;
    final int startIdx = totalSessions > 10 ? totalSessions - 10 : 0;
    
    for (int i = startIdx; i < totalSessions; i++) {
      final session = futsalSessions[i];
      final p = (session['totalGoals'] as int? ?? 0) + (session['totalAssists'] as int? ?? 0);
      spots.add(FlSpot((i - startIdx).toDouble(), p.toDouble()));
    }

    // Form Guide (Last 5)
    final int formStartIdx = totalSessions > 5 ? totalSessions - 5 : 0;
    for (int i = formStartIdx; i < totalSessions; i++) {
        final session = futsalSessions[i];
        // Use explicit impact if available, else derive from points (3+ = Good/Green, 0 = Bad/Red)
        if (session.containsKey('impact')) {
           impacts.add(session['impact'] as int? ?? 0);
        } else {
           // Fallback logic
           final p = (session['totalGoals'] as int? ?? 0) + (session['totalAssists'] as int? ?? 0);
           if (p >= 3) impacts.add(1);
           else if (p > 0) impacts.add(0);
           else impacts.add(-1);
        }
    }

    if (!mounted) return;
    setState(() {
      _totalGoals = goals;
      _totalAssists = assists;
      _matchesPlayed = matches;
      _recentImpacts = impacts;
      _pointsHistory = spots;
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
          padding: AppSpacing.paddingXL,
          child: Column(
            children: [
              _buildHeader(dateDisplay),
              AppSpacing.gapVerticalXL,
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LEFT SIDE: Actions
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
                    // RIGHT SIDE: Dashboard Stats
                    Expanded(
                      flex: 4, // Slightly wider for chart
                      child: _buildDashboardCard(),
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
                  "LOG MATCH",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Track Performance",
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
              icon: Icons.settings_outlined,
              label: "Settings",
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

  Widget _buildDashboardCard() {
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
           // Recent Form Section
           const Text(
            "RECENT FORM",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
              letterSpacing: 1,
              fontSize: 12,
            ),
          ),
          AppSpacing.gapVerticalMD,
          Row(
            children: _recentImpacts.isEmpty 
              ? [const Text("No matches played yet", style: TextStyle(color: AppColors.textMuted))]
              : _recentImpacts.map((impact) => _FormIndicator(impact: impact)).toList(),
          ),
          
          AppSpacing.gapVerticalXL,
          
          // Performance Chart Section
           const Text(
            "POINTS TREND (Last 10)",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
              letterSpacing: 1,
              fontSize: 12,
            ),
          ),
          AppSpacing.gapVerticalMD,
          Expanded(
            child: _pointsHistory.isEmpty
             ? const Center(child: Text("Play more matches to see trends", style: TextStyle(color: AppColors.textMuted)))
             : LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _pointsHistory,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  minY: -1,
                ),
              ),
          ),
          
          AppSpacing.gapVerticalXL,
          
          // Quick Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniStat(label: "GOALS", value: "$_totalGoals", color: AppColors.primary),
              _MiniStat(label: "ASSISTS", value: "$_totalAssists", color: AppColors.secondary),
              _MiniStat(label: "MATCHES", value: "$_matchesPlayed", color: AppColors.accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormIndicator extends StatelessWidget {
  final int impact; // -1, 0, 1
  
  const _FormIndicator({required this.impact});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (impact > 0) color = AppColors.success;
    else if (impact < 0) color = AppColors.error;
    else color = AppColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
      ],
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