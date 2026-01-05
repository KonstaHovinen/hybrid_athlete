import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data_models.dart';
import '../app_theme.dart';
import 'workout_screens.dart';

// --- EDIT SET ROW WIDGET (Isolated state for text fields) ---
class _EditSetRowWidget extends StatefulWidget {
  final int setIndex;
  final String initialWeight;
  final String initialReps;
  final String? initialTime;
  final Function(String) onWeightChanged;
  final Function(String) onRepsChanged;
  final Function(String)? onTimeChanged;

  const _EditSetRowWidget({
    super.key,
    required this.setIndex,
    required this.initialWeight,
    required this.initialReps,
    this.initialTime,
    required this.onWeightChanged,
    required this.onRepsChanged,
    this.onTimeChanged,
  });

  @override
  State<_EditSetRowWidget> createState() => _EditSetRowWidgetState();
}

class _EditSetRowWidgetState extends State<_EditSetRowWidget> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  TextEditingController? _timeController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.initialWeight);
    _repsController = TextEditingController(text: widget.initialReps);
    if (widget.initialTime != null) {
      _timeController = TextEditingController(text: widget.initialTime);
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _timeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "${widget.setIndex + 1}",
              style: const TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "kg",
                labelStyle: const TextStyle(fontSize: 12),
                isDense: true,
                contentPadding: const EdgeInsets.all(12),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: widget.onWeightChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Reps",
                labelStyle: const TextStyle(fontSize: 12),
                isDense: true,
                contentPadding: const EdgeInsets.all(12),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: widget.onRepsChanged,
            ),
          ),
          if (_timeController != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _timeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Time (s)",
                  labelStyle: const TextStyle(fontSize: 12),
                  isDense: true,
                  contentPadding: const EdgeInsets.all(12),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: widget.onTimeChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --- SIMPLE INPUT (For generic logging) ---
class SimpleInputScreen extends StatefulWidget {
  final String type;
  const SimpleInputScreen({super.key, required this.type});
  @override
  State<SimpleInputScreen> createState() => _SimpleInputScreenState();
}

class _SimpleInputScreenState extends State<SimpleInputScreen> {
  double _feelRating = 5.0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Log ${widget.type}")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text("How did it feel?", style: TextStyle(fontSize: 20)),
            Slider(
              value: _feelRating,
              min: 1,
              max: 10,
              divisions: 9,
              label: _feelRating.round().toString(),
              activeColor: AppColors.primary,
              onChanged: (v) {
                setState(() {
                  _feelRating = v;
                });
              },
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.all(18),
                ),
                child: const Text(
                  "LOG SESSION",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- HISTORY LIST ---
class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});
  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

/// Helper to sync calendar after history changes - stores full workout details
Future<void> _syncCalendarWithHistory() async {
  final prefs = await SharedPreferences.getInstance();
  final history = prefs.getStringList('workout_history') ?? [];

  Map<String, List<Map<String, dynamic>>> logged = {};

  for (final entry in history) {
    try {
      final data = jsonDecode(entry) as Map<String, dynamic>;
      if (data.containsKey('date')) {
        String dateStr = data['date'] as String;
        if (dateStr.contains(' ')) {
          dateStr = dateStr.split(' ')[0];
        }
        final parsed = DateTime.tryParse(dateStr);
        if (parsed != null) {
          final key =
              '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';

          // Build workout detail object
          Map<String, dynamic> workoutDetail = {
            'name': data['template_name'] as String? ?? 'Workout',
            'type': data['type'] as String?,
            'energy': data['energy'] as int?,
            'mood': data['mood'] as List<dynamic>?,
          };

          // Add futsal-specific data
          if (data['type'] == 'futsal') {
            workoutDetail['totalGoals'] = data['totalGoals'] as int? ?? 0;
            workoutDetail['totalAssists'] = data['totalAssists'] as int? ?? 0;
          }

          if (!logged.containsKey(key)) {
            logged[key] = [];
          }
          logged[key]!.add(workoutDetail);
        }
      }
    } catch (_) {}
  }

  await prefs.setString('logged_workouts', jsonEncode(logged));
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  Future<List<Map<String, dynamic>>> _getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? historyJson = prefs.getStringList('workout_history');
    if (historyJson == null) return [];
    return historyJson
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();
  }

  void _deleteWorkout(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyJson = prefs.getStringList('workout_history') ?? [];
    if (index >= 0 && index < historyJson.length) {
      historyJson.removeAt(index);
      await prefs.setStringList('workout_history', historyJson);
      // Re-sync calendar to remove deleted workout date if needed
      await _syncCalendarWithHistory();
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _editWorkoutDate(int index, Map<String, dynamic> workout) async {
    // Parse current date
    String currentDateStr = workout['date'] ?? '';
    DateTime currentDate = DateTime.now();
    if (currentDateStr.isNotEmpty) {
      try {
        currentDate = DateTime.parse(currentDateStr.split(' ')[0]);
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.card,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> historyJson = prefs.getStringList('workout_history') ?? [];
    
    if (index >= 0 && index < historyJson.length) {
      final updatedWorkout = Map<String, dynamic>.from(workout);
      updatedWorkout['date'] = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      historyJson[index] = jsonEncode(updatedWorkout);
      await prefs.setStringList('workout_history', historyJson);
      await _syncCalendarWithHistory();
      if (!mounted) return;
      setState(() {});
    }
  }

  void _showWorkoutDetails(Map<String, dynamic> workout) {
    final type = workout['type'] as String?;
    final isRunning = type == 'running';
    final isFutsal = type == 'futsal';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title
                  Row(
                    children: [
                      Icon(
                        isRunning ? Icons.directions_run : 
                        isFutsal ? Icons.sports_soccer : Icons.fitness_center,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          workout['template_name'] ?? 'Workout',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    workout['date'] ?? '',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 20),

                  // Running details
                  if (isRunning) ...[
                    _buildDetailRow('Run Type', workout['runType'] ?? 'Run'),
                    _buildDetailRow('Distance', '${workout['distance'] ?? 0} km'),
                    _buildDetailRow('Time', '${workout['time'] ?? 0} min'),
                    _buildDetailRow('Pace', '${(workout['pace'] ?? 0).toStringAsFixed(2)} min/km'),
                  ],

                  // Futsal details
                  if (isFutsal) ...[
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Goals', '${workout['totalGoals'] ?? 0}', Icons.sports_soccer, AppColors.primary)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Assists', '${workout['totalAssists'] ?? 0}', Icons.assistant, AppColors.secondary)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Points', '${(workout['totalGoals'] ?? 0) + (workout['totalAssists'] ?? 0)}', Icons.star, AppColors.accent)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (workout['games'] != null)
                      ...((workout['games'] as List).map((game) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text('Game ${game['gameNumber']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text('⚽ ${game['goals']}  🎯 ${game['assists']}'),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getImpactColor(game['impact']).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                game['impact'] ?? '',
                                style: TextStyle(
                                  color: _getImpactColor(game['impact']),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))),
                  ],

                  // Energy & Mood
                  if (workout['energy'] != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow('Energy Level', _getEnergyText(workout['energy'])),
                  ],
                  if (workout['mood'] != null && (workout['mood'] as List).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Mood', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: (workout['mood'] as List).map((m) => Chip(
                        label: Text(m.toString(), style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppColors.surface,
                      )).toList(),
                    ),
                  ],

                  // Notes
                  if (workout['notes'] != null && workout['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Notes', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(workout['notes'].toString(), style: const TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  String _getEnergyText(int energy) {
    switch (energy) {
      case 1: return '😫 Very Low';
      case 2: return '😔 Low';
      case 3: return '😐 Normal';
      case 4: return '😊 Good';
      case 5: return '🔥 Excellent';
      default: return 'Unknown';
    }
  }

  Color _getEnergyColor(int energy) {
    if (energy <= 2) return AppColors.error;
    if (energy == 3) return AppColors.accent;
    if (energy == 4) return AppColors.warning;
    return AppColors.primary;
  }

  Color _getImpactColor(String? impact) {
    switch (impact) {
      case 'Struggle':
        return AppColors.error;
      case 'Even':
        return AppColors.accent;
      case 'Push':
        return AppColors.primary;
      default:
        return AppColors.textMuted;
    }
  }

  // --- SMART FORMATTER: This fixes your "nullkg" and "kg x" issues ---
  String _formatSetDisplay(Map<String, dynamic> set) {
    String weight = set['weight']?.toString() ?? "";
    String reps = set['reps']?.toString() ?? "";
    String time = set['time']?.toString() ?? "";

    // 1. If there is time (Sprints)
    if (time.isNotEmpty) {
      if (reps.isNotEmpty && reps != "0") {
        return "Time: ${time}s ($reps reps)";
      }
      return "Time: ${time}s";
    }

    // 2. If there is weight (Gym)
    if (weight.isNotEmpty && weight != "0" && weight != "null") {
      return "$weight kg x $reps";
    }

    // 3. Just Bodyweight/Reps (Planks, etc)
    return reps;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📋 Workout History")),
      body: FutureBuilder(
        future: _getHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 60,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Error: ${snapshot.error}",
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  const Text(
                    "No history found",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Complete a workout to see it here!",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            );
          }
          final history = snapshot.data!.reversed.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final workout = history[index];
              // Calculate original index because list is reversed
              final originalIndex = snapshot.data!.length - 1 - index;

              // Check if this is a futsal session
              final isFutsal = workout['type'] == 'futsal';
              final hasEnergy = workout['energy'] != null;
              final hasMood =
                  workout['mood'] != null &&
                  (workout['mood'] as List).isNotEmpty;
              final hasNotes =
                  workout['notes'] != null &&
                  workout['notes'].toString().isNotEmpty;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isFutsal
                            ? AppColors.accent.withOpacity(0.15)
                            : AppColors.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isFutsal ? Icons.sports_soccer : Icons.fitness_center,
                        color: isFutsal
                            ? AppColors.accent
                            : AppColors.secondary,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      workout['template_name'] ?? "Workout",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          workout['date'] ?? "Unknown Date",
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        if (hasEnergy || hasMood)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                if (hasEnergy) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getEnergyColor(
                                        workout['energy'],
                                      ).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.bolt,
                                          size: 12,
                                          color: _getEnergyColor(
                                            workout['energy'],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${workout['energy']}/5",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _getEnergyColor(
                                              workout['energy'],
                                            ),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (hasMood)
                                  Text(
                                    (workout['mood'] as List).join(' '),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    children: [
                      // Energy & Mood Section
                      if (hasEnergy || hasMood || hasNotes)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasEnergy)
                                Row(
                                  children: [
                                    const Text(
                                      "Energy: ",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    ...List.generate(
                                      5,
                                      (i) => Icon(
                                        Icons.bolt,
                                        size: 16,
                                        color: i < workout['energy']
                                            ? _getEnergyColor(workout['energy'])
                                            : AppColors.surfaceLight,
                                      ),
                                    ),
                                  ],
                                ),
                              if (hasMood)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      const Text(
                                        "Mood: ",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        (workout['mood'] as List).join('  '),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              if (hasNotes)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Notes: ",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          workout['notes'],
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontStyle: FontStyle.italic,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Futsal Games
                      if (isFutsal && workout['games'] != null)
                        ...workout['games']
                            .map<Widget>(
                              (game) => Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getImpactColor(
                                      game['impact'],
                                    ).withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _getImpactColor(
                                          game['impact'],
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "G${game['gameNumber']}",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _getImpactColor(
                                            game['impact'],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.sports_soccer,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        Text(
                                          " ${game['goals']}  ",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Icon(
                                          Icons.assistant,
                                          size: 16,
                                          color: AppColors.secondary,
                                        ),
                                        Text(
                                          " ${game['assists']}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getImpactColor(
                                          game['impact'],
                                        ).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        game['impact'],
                                        style: TextStyle(
                                          color: _getImpactColor(
                                            game['impact'],
                                          ),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),

                      // Regular Workout Sets
                      if (!isFutsal && workout['sets'] != null)
                        for (var exercise in workout['sets'])
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exercise['exercise'],
                                  style: const TextStyle(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  (exercise['sets'] as List)
                                      .map((s) => _formatSetDisplay(s))
                                      .join("  |  "),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                      const SizedBox(height: 8),

                      // Action buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Details button for running/futsal
                            if (workout['type'] == 'running' || workout['type'] == 'futsal')
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                label: const Text(
                                  "Details",
                                  style: TextStyle(color: AppColors.primary),
                                ),
                                onPressed: () => _showWorkoutDetails(workout),
                              ),
                            // Date edit button
                            TextButton.icon(
                              icon: const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: AppColors.accent,
                              ),
                              label: const Text(
                                "Date",
                                style: TextStyle(color: AppColors.accent),
                              ),
                              onPressed: () => _editWorkoutDate(originalIndex, workout),
                            ),
                            // Edit button for regular workouts
                            if (workout['type'] != 'futsal' && workout['type'] != 'running')
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: AppColors.secondary,
                                ),
                                label: const Text(
                                  "Edit",
                                  style: TextStyle(color: AppColors.secondary),
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditWorkoutScreen(
                                      workoutIndex: originalIndex,
                                      workout: workout,
                                    ),
                                  ),
                                ).then((_) => setState(() {})),
                              ),
                            TextButton.icon(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: AppColors.error,
                              ),
                              label: const Text(
                                "Delete",
                                style: TextStyle(color: AppColors.error),
                              ),
                              onPressed: () => _deleteWorkout(originalIndex),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- EDIT WORKOUT SCREEN (Full Editing) ---
class EditWorkoutScreen extends StatefulWidget {
  final int workoutIndex;
  final Map<String, dynamic> workout;
  const EditWorkoutScreen({
    super.key,
    required this.workoutIndex,
    required this.workout,
  });
  @override
  State<EditWorkoutScreen> createState() => _EditWorkoutScreenState();
}

class _EditWorkoutScreenState extends State<EditWorkoutScreen> {
  late List<Map<String, dynamic>> exercises;
  late TextEditingController templateNameController;
  List<Exercise> _availableExercises = [];

  // Key to force rebuild when sets change
  int _editKey = 0;

  // Clean value - remove non-numeric strings like "reps"
  String _cleanValue(dynamic val) {
    if (val == null) return '';
    final str = val.toString().trim();
    // Only keep if it looks like a number
    if (str.isEmpty || str == 'null') return '';
    // Try parsing as number - if it fails, return empty
    if (double.tryParse(str) == null) return '';
    return str;
  }

  @override
  void initState() {
    super.initState();
    templateNameController = TextEditingController(
      text: widget.workout['template_name'] ?? "Workout",
    );
    _loadAvailableExercises();

    // Deep copy the data so we can edit it safely
    exercises = [];
    final sets = widget.workout['sets'];
    if (sets is List) {
      for (var ex in sets) {
        final exSets = ex['sets'];
        List<Map<String, dynamic>> setList = [];
        if (exSets is List) {
          for (var s in exSets) {
            if (s is Map<String, dynamic>) {
              setList.add(Map<String, dynamic>.from(s));
            }
          }
        }
        exercises.add({
          "exercise": ex['exercise'] ?? "Unknown",
          "sets": setList,
        });
      }
    }
  }

  @override
  void dispose() {
    templateNameController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableExercises() async {
    final list = await ExerciseLibrary.getAllExercisesWithUser();
    if (!mounted) return;
    setState(() => _availableExercises = list);
  }

  Future<void> _saveChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> historyJson =
        prefs.getStringList('workout_history') ?? [];

    if (widget.workoutIndex >= 0 && widget.workoutIndex < historyJson.length) {
      final updated = {
        ...widget.workout,
        'sets': exercises,
        'template_name': templateNameController.text,
      };
      historyJson[widget.workoutIndex] = jsonEncode(updated);
      await prefs.setStringList('workout_history', historyJson);
      // Re-sync calendar to reflect edited workout
      await _syncCalendarWithHistory();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("✏️ Edit Workout Log"),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: _saveChanges,
              child: const Text(
                "Save",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: TextField(
                  controller: templateNameController,
                  decoration: InputDecoration(
                    labelText: "Workout Name",
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(
                      Icons.edit,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // List of Exercises
              for (int i = 0; i < exercises.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Exercise Name Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final currentExName =
                                      exercises[i]['exercise'] as String;
                                  final matches = _availableExercises.where(
                                    (ex) =>
                                        ex.name.toLowerCase() ==
                                        currentExName.toLowerCase(),
                                  );
                                  final matchingEx = matches.isNotEmpty
                                      ? matches.first
                                      : null;
                                  final items = _availableExercises
                                      .map(
                                        (ex) => DropdownMenuItem<String>(
                                          value: ex.name,
                                          child: Text(ex.name),
                                        ),
                                      )
                                      .toList();
                                  if (matchingEx == null) {
                                    items.add(
                                      DropdownMenuItem<String>(
                                        value: currentExName,
                                        child: Text(currentExName),
                                      ),
                                    );
                                  }
                                  return DropdownButtonFormField<String>(
                                    initialValue:
                                        matchingEx?.name ?? currentExName,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                    ),
                                    dropdownColor: AppColors.surface,
                                    items: items,
                                    onChanged: (val) {
                                      if (val == null) return;
                                      setState(
                                        () => exercises[i]['exercise'] = val,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                              onPressed: () =>
                                  setState(() => exercises.removeAt(i)),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_box,
                                color: AppColors.primary,
                              ),
                              tooltip: 'Open exercise library',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (c) => const ExerciseLibraryScreen(),
                                ),
                              ).then((_) => _loadAvailableExercises()),
                            ),
                          ],
                        ),
                        Divider(color: AppColors.surfaceLight),

                        // Sets List
                        for (
                          int j = 0;
                          j < (exercises[i]['sets'] as List).length;
                          j++
                        )
                          _EditSetRowWidget(
                            key: ValueKey('editset_${_editKey}_${i}_$j'),
                            setIndex: j,
                            initialWeight: _cleanValue(
                              exercises[i]['sets'][j]['weight'],
                            ),
                            initialReps: _cleanValue(
                              exercises[i]['sets'][j]['reps'],
                            ),
                            initialTime:
                                exercises[i]['sets'][j].containsKey('time') &&
                                    exercises[i]['sets'][j]['time'] != null
                                ? _cleanValue(exercises[i]['sets'][j]['time'])
                                : null,
                            onWeightChanged: (val) =>
                                exercises[i]['sets'][j]['weight'] = val,
                            onRepsChanged: (val) =>
                                exercises[i]['sets'][j]['reps'] = val,
                            onTimeChanged:
                                exercises[i]['sets'][j].containsKey('time')
                                ? (val) => exercises[i]['sets'][j]['time'] = val
                                : null,
                          ),

                        // Add Set / Delete Set Buttons
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() {
                                  (exercises[i]['sets'] as List).add({
                                    "weight": "",
                                    "reps": "",
                                  });
                                  _editKey++;
                                }),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                ),
                                child: const Text(
                                  "ADD SET",
                                  style: TextStyle(color: AppColors.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    (exercises[i]['sets'] as List).isEmpty
                                    ? null
                                    : () => setState(() {
                                        (exercises[i]['sets'] as List)
                                            .removeLast();
                                        _editKey++;
                                      }),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppColors.error,
                                  ),
                                ),
                                child: const Text(
                                  "DELETE SET",
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
