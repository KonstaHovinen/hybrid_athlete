import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data_models.dart';
import '../app_theme.dart';
import '../utils/sync_service.dart';
import 'workout_screens.dart';

class FutsalLoggerScreen extends StatefulWidget {
  const FutsalLoggerScreen({super.key});
  @override
  State<FutsalLoggerScreen> createState() => _FutsalLoggerScreenState();
}

class _FutsalLoggerScreenState extends State<FutsalLoggerScreen> {
  final List<GameStats> _games = [GameStats()];

  // Overall session tracking
  int _energyLevel = 3;
  final List<String> _selectedMoods = [];
  final TextEditingController _notesController = TextEditingController();
  final List<String> _moodOptions = [
    '💪 Dominant',
    '🔥 On Fire',
    '😴 Tired',
    '😤 Frustrated',
    '🎯 Clinical',
    '🏃 High Energy',
    '🧠 Smart Plays',
  ];

  void _addGame() {
    setState(() => _games.add(GameStats()));
  }

  void _removeGame(int index) {
    if (_games.length > 1) {
      setState(() => _games.removeAt(index));
    }
  }

  int get _totalGoals => _games.fold(0, (sum, g) => sum + g.goals);
  int get _totalAssists => _games.fold(0, (sum, g) => sum + g.assists);

  Future<void> _logSession() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('workout_history') ?? [];

    final sessionData = {
      'date': DateTime.now().toString().split(' ')[0],
      'template_name': 'Futsal Session',
      'type': 'futsal',
      'games': _games.map((g) => g.toJson()).toList(),
      'totalGoals': _totalGoals,
      'totalAssists': _totalAssists,
      'energy': _energyLevel,
      'mood': _selectedMoods,
      'notes': _notesController.text,
      'sets': [], // For compatibility
    };

    history.add(jsonEncode(sessionData));
    await prefs.setStringList('workout_history', history);
    // Sync to desktop
    await SyncService.exportData();

    // Mark calendar with futsal session details
    final today = DateTime.now();
    await logWorkoutForDate(DateTime(today.year, today.month, today.day), {
      'name': 'Futsal Session',
      'type': 'futsal',
      'totalGoals': _totalGoals,
      'totalAssists': _totalAssists,
      'energy': _energyLevel,
      'mood': _selectedMoods,
    });

    // Update profile
    UserProfile profile = await ProfileManager.getProfile();
    profile.totalExercises++;
    await ProfileManager.saveProfile(profile);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => FutsalSummaryScreen(
            games: _games,
            totalGoals: _totalGoals,
            totalAssists: _totalAssists,
            energy: _energyLevel,
            moods: _selectedMoods,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("⚽ Futsal Session"),
        actions: [
          TextButton.icon(
            onPressed: _addGame,
            icon: const Icon(Icons.add, color: AppColors.accent),
            label: const Text(
              "Add Game",
              style: TextStyle(color: AppColors.accent),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary bar with gradient
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accent.withValues(alpha: 0.2), AppColors.surface],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryItem(
                  icon: Icons.sports_soccer,
                  label: "Games",
                  value: "${_games.length}",
                  color: AppColors.accent,
                ),
                _SummaryItem(
                  icon: Icons.emoji_events,
                  label: "Goals",
                  value: "$_totalGoals",
                  color: AppColors.primary,
                ),
                _SummaryItem(
                  icon: Icons.assistant,
                  label: "Assists",
                  value: "$_totalAssists",
                  color: AppColors.secondary,
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Game cards
                ..._games.asMap().entries.map((entry) {
                  final index = entry.key;
                  final game = entry.value;
                  return _GameCard(
                    gameNumber: index + 1,
                    game: game,
                    onChanged: () => setState(() {}),
                    onRemove: _games.length > 1
                        ? () => _removeGame(index)
                        : null,
                  );
                }),

                const SizedBox(height: 16),

                // Add game button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _addGame,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, color: AppColors.accent),
                          SizedBox(width: 8),
                          Text(
                            "Add Another Game",
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Energy & Notes section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.psychology,
                            color: AppColors.accent,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Session Feeling",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Text(
                            "Energy:",
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 10),
                          ...List.generate(
                            5,
                            (i) => GestureDetector(
                              onTap: () => setState(() => _energyLevel = i + 1),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Icon(
                                  i < _energyLevel
                                      ? Icons.bolt
                                      : Icons.bolt_outlined,
                                  color: i < _energyLevel
                                      ? AppColors.warning
                                      : AppColors.textMuted,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _moodOptions
                            .map(
                              (mood) => FilterChip(
                                label: Text(
                                  mood,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                selected: _selectedMoods.contains(mood),
                                selectedColor: AppColors.accent.withValues(alpha: 
                                  0.3,
                                ),
                                checkmarkColor: AppColors.accent,
                                onSelected: (selected) => setState(() {
                                  if (selected) {
                                    _selectedMoods.add(mood);
                                  } else {
                                    _selectedMoods.remove(mood);
                                  }
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          hintText:
                              "Session notes (tactics, highlights, areas to improve)...",
                          hintStyle: const TextStyle(
                            color: AppColors.textMuted,
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Log button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _logSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.all(18),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "LOG FUTSAL SESSION",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- GAME STATS MODEL ---
class GameStats {
  int goals = 0;
  int assists = 0;
  String impact = 'Even'; // Struggle, Even, Push

  Map<String, dynamic> toJson() => {
    'goals': goals,
    'assists': assists,
    'impact': impact,
  };
}

// --- GAME CARD WIDGET ---
class _GameCard extends StatelessWidget {
  final int gameNumber;
  final GameStats game;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const _GameCard({
    required this.gameNumber,
    required this.game,
    required this.onChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.secondaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Game $gameNumber",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ImpactBadge(impact: game.impact),
                  ],
                ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onRemove,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Goals & Assists Row
            Row(
              children: [
                Expanded(
                  child: _StatCounter(
                    label: "Goals",
                    value: game.goals,
                    icon: Icons.sports_soccer,
                    color: AppColors.primary,
                    onIncrement: () {
                      game.goals++;
                      onChanged();
                    },
                    onDecrement: () {
                      if (game.goals > 0) {
                        game.goals--;
                        onChanged();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCounter(
                    label: "Assists",
                    value: game.assists,
                    icon: Icons.assistant,
                    color: AppColors.secondary,
                    onIncrement: () {
                      game.assists++;
                      onChanged();
                    },
                    onDecrement: () {
                      if (game.assists > 0) {
                        game.assists--;
                        onChanged();
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Impact selector
            const Text(
              "Impact",
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: ['Struggle', 'Even', 'Push'].map((impact) {
                final isSelected = game.impact == impact;
                Color bgColor;
                Color textColor;
                IconData icon;

                switch (impact) {
                  case 'Struggle':
                    bgColor = isSelected
                        ? AppColors.error
                        : AppColors.error.withValues(alpha: 0.1);
                    textColor = isSelected ? Colors.white : AppColors.error;
                    icon = Icons.trending_down;
                    break;
                  case 'Push':
                    bgColor = isSelected
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.1);
                    textColor = isSelected ? Colors.white : AppColors.primary;
                    icon = Icons.trending_up;
                    break;
                  default:
                    bgColor = isSelected
                        ? AppColors.accent
                        : AppColors.accent.withValues(alpha: 0.1);
                    textColor = isSelected ? Colors.white : AppColors.accent;
                    icon = Icons.trending_flat;
                }

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: impact != 'Push' ? 8 : 0),
                    child: GestureDetector(
                      onTap: () {
                        game.impact = impact;
                        onChanged();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: textColor.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 16, color: textColor),
                            const SizedBox(width: 4),
                            Text(
                              impact,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// --- HELPER WIDGETS ---
class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _StatCounter extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _StatCounter({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: onDecrement,
                color: AppColors.textMuted,
                iconSize: 30,
              ),
              Text(
                "$value",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle, color: color),
                onPressed: onIncrement,
                iconSize: 30,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactBadge extends StatelessWidget {
  final String impact;
  const _ImpactBadge({required this.impact});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (impact) {
      case 'Struggle':
        color = AppColors.error;
        icon = Icons.trending_down;
        break;
      case 'Push':
        color = AppColors.primary;
        icon = Icons.trending_up;
        break;
      default:
        color = AppColors.accent;
        icon = Icons.trending_flat;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            impact,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// --- FUTSAL SUMMARY SCREEN ---
class FutsalSummaryScreen extends StatelessWidget {
  final List<GameStats> games;
  final int totalGoals;
  final int totalAssists;
  final int energy;
  final List<String> moods;

  const FutsalSummaryScreen({
    super.key,
    required this.games,
    required this.totalGoals,
    required this.totalAssists,
    required this.energy,
    required this.moods,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate dominant impact
    Map<String, int> impactCounts = {'Struggle': 0, 'Even': 0, 'Push': 0};
    for (var game in games) {
      impactCounts[game.impact] = (impactCounts[game.impact] ?? 0) + 1;
    }
    String dominantImpact = impactCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    Color impactColor;
    String impactEmoji;
    switch (dominantImpact) {
      case 'Push':
        impactColor = AppColors.primary;
        impactEmoji = '🔥';
        break;
      case 'Struggle':
        impactColor = AppColors.error;
        impactEmoji = '😤';
        break;
      default:
        impactColor = AppColors.accent;
        impactEmoji = '⚖️';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("⚽ Session Complete"),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sports_soccer,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                "${games.length} ${games.length == 1 ? 'Game' : 'Games'} Played",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SummaryStatBig(
                    label: "Goals",
                    value: "$totalGoals",
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 50),
                  _SummaryStatBig(
                    label: "Assists",
                    value: "$totalAssists",
                    color: AppColors.secondary,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: impactColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: impactColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  "$impactEmoji Overall: $dominantImpact",
                  style: TextStyle(
                    color: impactColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < energy ? Icons.bolt : Icons.bolt_outlined,
                      color: i < energy
                          ? AppColors.warning
                          : AppColors.textMuted,
                      size: 28,
                    ),
                  ),
                ),
              ),

              if (moods.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  children: moods
                      .map(
                        (m) => Chip(
                          label: Text(m, style: const TextStyle(fontSize: 12)),
                          backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                        ),
                      )
                      .toList(),
                ),
              ],

              const Spacer(),

              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.all(18),
                  ),
                  child: const Text(
                    "DONE",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryStatBig extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryStatBig({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }
}
