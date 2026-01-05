import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data_models.dart';
import '../app_theme.dart';
import 'workout_screens.dart';

class QuickLogScreen extends StatefulWidget {
  const QuickLogScreen({super.key});
  @override
  State<QuickLogScreen> createState() => _QuickLogScreenState();
}

class _QuickLogScreenState extends State<QuickLogScreen> {
  List<Exercise> _allExercises = [];
  List<Exercise> _filteredExercises = [];
  List<String> _recentExercises = [];
  final TextEditingController _searchController = TextEditingController();
  
  // Quick log form
  Exercise? _selectedExercise;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _setsController = TextEditingController(text: "1");

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _loadRecentExercises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _weightController.dispose();
    _repsController.dispose();
    _setsController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    final list = await ExerciseLibrary.getAllExercisesWithUser();
    if (!mounted) return;
    setState(() {
      _allExercises = list;
      _filteredExercises = list;
    });
  }

  Future<void> _loadRecentExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList('recent_quick_log') ?? [];
    if (!mounted) return;
    setState(() => _recentExercises = recent);
  }

  Future<void> _saveRecentExercise(String name) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recent = prefs.getStringList('recent_quick_log') ?? [];
    recent.remove(name);
    recent.insert(0, name);
    if (recent.length > 5) recent = recent.sublist(0, 5);
    await prefs.setStringList('recent_quick_log', recent);
  }

  void _filterExercises(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredExercises = _allExercises;
      } else {
        _filteredExercises = _allExercises
            .where((e) => e.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _selectExercise(Exercise exercise) async {
    final settings = await ExerciseSettingsManager.getExerciseWithSettings(exercise);
    if (!mounted) return;
    setState(() {
      _selectedExercise = exercise;
      _repsController.text = settings.repRange;
      _setsController.text = settings.presetSets.toString();
      if (settings.startingWeight != null) {
        _weightController.text = settings.startingWeight.toString();
      }
    });
  }

  Future<void> _logExercise() async {
    if (_selectedExercise == null) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('workout_history') ?? [];

    int sets = int.tryParse(_setsController.text) ?? 1;
    List<Map<String, String>> setData = [];
    for (int i = 0; i < sets; i++) {
      setData.add({
        "weight": _weightController.text,
        "reps": _repsController.text,
      });
    }

    final workoutData = {
      'date': DateTime.now().toString().split(' ')[0],
      'template_name': 'Quick Log',
      'sets': [
        {
          'exercise': _selectedExercise!.name,
          'sets': setData,
        }
      ]
    };

    history.add(jsonEncode(workoutData));
    await prefs.setStringList('workout_history', history);

    // Mark calendar with workout details
    final today = DateTime.now();
    await logWorkoutForDate(DateTime(today.year, today.month, today.day), {
      'name': 'Quick: ${_selectedExercise!.name}',
    });

    // Save to recent
    await _saveRecentExercise(_selectedExercise!.name);

    // Update profile
    UserProfile profile = await ProfileManager.getProfile();
    profile.totalExercises++;
    double w = double.tryParse(_weightController.text) ?? 0;
    if (w > 0) {
      double current = profile.personalRecords[_selectedExercise!.name] ?? 0;
      if (w > current) {
        profile.personalRecords[_selectedExercise!.name] = w;
      }
      if (w > profile.maxLifted) profile.maxLifted = w;
    }
    await ProfileManager.saveProfile(profile);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logged ${_selectedExercise!.name}!"),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("⚡ Quick Log"),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search exercises...",
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _filterExercises,
            ),
          ),

          // Selected exercise form
          if (_selectedExercise != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.secondary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.fitness_center, color: AppColors.secondary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _selectedExercise!.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                        onPressed: () => setState(() => _selectedExercise = null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_selectedExercise!.type == "Gym") ...[
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Weight (kg)",
                              labelStyle: const TextStyle(fontSize: 12),
                              filled: true,
                              fillColor: AppColors.surfaceLight,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: TextField(
                          controller: _repsController,
                          decoration: InputDecoration(
                            labelText: "Reps",
                            labelStyle: const TextStyle(fontSize: 12),
                            filled: true,
                            fillColor: AppColors.surfaceLight,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _setsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Sets",
                            labelStyle: const TextStyle(fontSize: 12),
                            filled: true,
                            fillColor: AppColors.surfaceLight,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _logExercise,
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text("LOG EXERCISE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Recent exercises
          if (_recentExercises.isNotEmpty && _selectedExercise == null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  const Text("Recent", style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _recentExercises.length,
                itemBuilder: (context, index) {
                  final name = _recentExercises[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(name, style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppColors.accent.withOpacity(0.15),
                      side: BorderSide(color: AppColors.accent.withOpacity(0.3)),
                      onPressed: () {
                        final ex = _allExercises.firstWhere(
                          (e) => e.name.toLowerCase() == name.toLowerCase(),
                          orElse: () => Exercise(name: name, category: "General", description: "", difficulty: "Medium"),
                        );
                        _selectExercise(ex);
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Exercise list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredExercises.length,
              itemBuilder: (context, index) {
                final exercise = _filteredExercises[index];
                final isSelected = _selectedExercise?.name == exercise.name;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.secondary.withOpacity(0.15) : AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? AppColors.secondary : AppColors.surfaceLight),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (exercise.type == "Running" ? AppColors.primary 
                          : exercise.type == "Recovery" ? AppColors.accent 
                          : AppColors.secondary).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        exercise.type == "Running" ? Icons.directions_run 
                          : exercise.type == "Recovery" ? Icons.self_improvement 
                          : Icons.fitness_center,
                        color: exercise.type == "Running" ? AppColors.primary 
                          : exercise.type == "Recovery" ? AppColors.accent 
                          : AppColors.secondary,
                        size: 20,
                      ),
                    ),
                    title: Text(exercise.name),
                    subtitle: Text(exercise.category, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    trailing: Icon(Icons.add_circle_outline, color: isSelected ? AppColors.secondary : AppColors.textMuted),
                    onTap: () => _selectExercise(exercise),
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
