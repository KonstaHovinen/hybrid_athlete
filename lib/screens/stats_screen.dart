import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';

class WeeklyStatsScreen extends StatefulWidget {
  const WeeklyStatsScreen({super.key});
  @override
  State<WeeklyStatsScreen> createState() => _WeeklyStatsScreenState();
}

class _WeeklyStatsScreenState extends State<WeeklyStatsScreen> {
  int _thisWeekWorkouts = 0;
  int _lastWeekWorkouts = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  double _thisWeekVolume = 0;
  double _lastWeekVolume = 0;
  int _weeklyGoal = 4;
  Map<String, double> _recentPRs = {};
  List<bool> _weekDays = List.filled(7, false); // Mon-Sun

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('workout_history') ?? [];
    final loggedRaw = prefs.getString('logged_workouts');
    
    final now = DateTime.now();
    final startOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
    
    int thisWeek = 0;
    int lastWeek = 0;
    double thisWeekVol = 0;
    double lastWeekVol = 0;
    Map<String, double> prs = {};
    Set<String> thisWeekDates = {};

    for (var item in history) {
      try {
        final workout = jsonDecode(item);
        final dateStr = workout['date']?.toString() ?? '';
        final date = DateTime.tryParse(dateStr);
        if (date == null) continue;

        // Calculate volume
        double workoutVolume = 0;
        final sets = workout['sets'] as List<dynamic>? ?? [];
        for (var ex in sets) {
          final exSets = ex['sets'] as List<dynamic>? ?? [];
          for (var s in exSets) {
            double w = double.tryParse(s['weight']?.toString() ?? '0') ?? 0;
            int r = int.tryParse(s['reps']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
            workoutVolume += w * r;
            
            // Track PRs
            String exName = ex['exercise']?.toString() ?? '';
            if (exName.isNotEmpty && w > 0) {
              prs[exName] = (prs[exName] ?? 0) < w ? w : prs[exName]!;
            }
          }
        }

        if (date.isAfter(startOfThisWeek.subtract(const Duration(days: 1)))) {
          thisWeek++;
          thisWeekVol += workoutVolume;
          thisWeekDates.add(dateStr);
        } else if (date.isAfter(startOfLastWeek.subtract(const Duration(days: 1)))) {
          lastWeek++;
          lastWeekVol += workoutVolume;
        }
      } catch (e) {
        continue;
      }
    }

    // Calculate streak from logged workouts
    int streak = 0;
    int maxStreak = 0;
    if (loggedRaw != null) {
      final logged = Map<String, String>.from(jsonDecode(loggedRaw));
      DateTime checkDate = DateTime(now.year, now.month, now.day);
      
      // Check consecutive days backwards
      while (true) {
        final key = checkDate.toIso8601String().split('T')[0];
        if (logged.containsKey(key)) {
          streak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
      
      // Calculate longest streak
      List<DateTime> dates = logged.keys.map((k) => DateTime.tryParse(k)).whereType<DateTime>().toList();
      dates.sort();
      int tempStreak = 1;
      for (int i = 1; i < dates.length; i++) {
        if (dates[i].difference(dates[i - 1]).inDays == 1) {
          tempStreak++;
          maxStreak = tempStreak > maxStreak ? tempStreak : maxStreak;
        } else {
          tempStreak = 1;
        }
      }
      maxStreak = maxStreak > streak ? maxStreak : streak;
    }

    // Mark which days of current week have workouts
    List<bool> weekDays = List.filled(7, false);
    for (int i = 0; i < 7; i++) {
      final day = startOfThisWeek.add(Duration(days: i));
      final key = day.toIso8601String().split('T')[0];
      if (thisWeekDates.contains(key)) {
        weekDays[i] = true;
      }
    }

    // Load weekly goal
    int goal = prefs.getInt('weekly_goal') ?? 4;

    setState(() {
      _thisWeekWorkouts = thisWeek;
      _lastWeekWorkouts = lastWeek;
      _thisWeekVolume = thisWeekVol;
      _lastWeekVolume = lastWeekVol;
      _currentStreak = streak;
      _longestStreak = maxStreak;
      _recentPRs = prs;
      _weekDays = weekDays;
      _weeklyGoal = goal;
    });
  }

  Future<void> _setWeeklyGoal() async {
    int tempGoal = _weeklyGoal;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Set Weekly Goal"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("$tempGoal workouts per week", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Slider(
                value: tempGoal.toDouble(),
                min: 1,
                max: 7,
                divisions: 6,
                onChanged: (v) => setDialogState(() => tempGoal = v.toInt()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('weekly_goal', tempGoal);
                if (!mounted) return;
                setState(() => _weeklyGoal = tempGoal);
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _thisWeekWorkouts / _weeklyGoal;
    final volumeChange = _lastWeekVolume > 0 
        ? ((_thisWeekVolume - _lastWeekVolume) / _lastWeekVolume * 100) 
        : 0.0;
    final workoutChange = _lastWeekWorkouts > 0 
        ? _thisWeekWorkouts - _lastWeekWorkouts 
        : _thisWeekWorkouts;

    return Scaffold(
      appBar: AppBar(
        title: const Text("📊 Weekly Stats"),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(icon: const Icon(Icons.flag, color: AppColors.accent), onPressed: _setWeeklyGoal, tooltip: "Set weekly goal"),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weekly Goal Progress Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("This Week", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "$_thisWeekWorkouts / $_weeklyGoal",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 14,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(
                        progress >= 1.0 ? AppColors.warning : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Week days visualization
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((e) {
                      bool done = _weekDays[e.key];
                      return Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done ? AppColors.warning : Colors.white.withOpacity(0.15),
                              border: done ? null : Border.all(color: Colors.white24),
                            ),
                            child: Icon(
                              done ? Icons.check : Icons.circle_outlined,
                              size: 18,
                              color: done ? Colors.black : Colors.white38,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(e.value, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Streak & Comparison Row
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.local_fire_department,
                    iconColor: AppColors.warning,
                    title: "Current Streak",
                    value: "$_currentStreak days",
                    subtitle: "Longest: $_longestStreak days",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: workoutChange >= 0 ? Icons.trending_up : Icons.trending_down,
                    iconColor: workoutChange >= 0 ? AppColors.primary : AppColors.error,
                    title: "vs Last Week",
                    value: "${workoutChange >= 0 ? '+' : ''}$workoutChange workouts",
                    subtitle: "Last: $_lastWeekWorkouts workouts",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Volume Card
            _StatCard(
              icon: Icons.fitness_center,
              iconColor: AppColors.accent,
              title: "Total Volume This Week",
              value: "${(_thisWeekVolume / 1000).toStringAsFixed(1)}k kg",
              subtitle: volumeChange != 0 
                  ? "${volumeChange >= 0 ? '+' : ''}${volumeChange.toStringAsFixed(0)}% vs last week"
                  : "Start lifting to track volume!",
              fullWidth: true,
            ),
            const SizedBox(height: 24),

            // Recent PRs
            const Row(
              children: [
                Icon(Icons.emoji_events, color: AppColors.warning, size: 22),
                SizedBox(width: 8),
                Text("Recent Personal Records", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            if (_recentPRs.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: const Center(
                  child: Text("Complete workouts to see your PRs here!", style: TextStyle(color: AppColors.textMuted)),
                ),
              )
            else
              ...(_recentPRs.entries.take(5).map((e) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
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
                            color: AppColors.warning.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.emoji_events, color: AppColors.warning, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text("${e.value.toStringAsFixed(1)} kg", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ))),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;
  final bool fullWidth;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(18),
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
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: iconColor)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}
