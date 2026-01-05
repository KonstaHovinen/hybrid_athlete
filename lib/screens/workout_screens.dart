import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data_models.dart';
import '../app_theme.dart';
import 'profile_screen.dart';

/// Converts a date to storage key format (YYYY-MM-DD) - consistent with calendar
String _dateToKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

// --- HELPER: Log workout to calendar ---
/// Marks a workout date as logged in the calendar with workout details
/// Uses normalized date format for consistent calendar sync
/// [workoutDetails] should include: name, type, energy, mood, and for futsal: totalGoals, totalAssists
Future<void> logWorkoutForDate(
  DateTime day,
  Map<String, dynamic> workoutDetails,
) async {
  final prefs = await SharedPreferences.getInstance();
  final normalizedDay = DateTime(day.year, day.month, day.day);
  final key = _dateToKey(normalizedDay);

  Map<String, List<dynamic>> logged = {};
  final loggedRaw = prefs.getString('logged_workouts');
  if (loggedRaw != null) {
    try {
      final decoded = jsonDecode(loggedRaw) as Map<String, dynamic>;
      decoded.forEach((k, v) {
        if (v is List) {
          logged[k] = v;
        } else {
          // Legacy format conversion
          logged[k] = [
            {'name': 'Workout'},
          ];
        }
      });
    } catch (_) {}
  }

  // Add workout details to list for this date
  if (!logged.containsKey(key)) {
    logged[key] = [];
  }
  logged[key]!.add(workoutDetails);

  await prefs.setString('logged_workouts', jsonEncode(logged));

  // Remove scheduled workout for this day (it's now completed)
  final scheduledRaw = prefs.getString('scheduled_workouts');
  if (scheduledRaw != null) {
    try {
      final scheduled = jsonDecode(scheduledRaw) as Map<String, dynamic>;
      if (scheduled.containsKey(key)) {
        scheduled.remove(key);
        await prefs.setString('scheduled_workouts', jsonEncode(scheduled));
      }
    } catch (_) {}
  }
}

/// Simple helper for backward compatibility - just pass workout name
Future<void> logWorkoutForDateSimple(DateTime day, String workoutName) async {
  await logWorkoutForDate(day, {'name': workoutName});
}

// --- EXERCISE EDITOR SCREEN ---
class ExerciseEditorScreen extends StatefulWidget {
  final Exercise exercise;
  const ExerciseEditorScreen({super.key, required this.exercise});

  @override
  State<ExerciseEditorScreen> createState() => _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends State<ExerciseEditorScreen> {
  TextEditingController? _setsController;
  TextEditingController? _repsController;
  TextEditingController? _weightController;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _setsController?.dispose();
    _repsController?.dispose();
    _weightController?.dispose();
    super.dispose();
  }

  void _loadCurrentSettings() async {
    Exercise settings = await ExerciseSettingsManager.getExerciseWithSettings(
      widget.exercise,
    );
    if (!mounted) return;
    setState(() {
      _setsController = TextEditingController(
        text: settings.presetSets.toString(),
      );
      _repsController = TextEditingController(text: settings.repRange);
      _weightController = TextEditingController(
        text: settings.startingWeight?.toString() ?? "",
      );
      _isLoaded = true;
    });
  }

  void _saveSettings() async {
    int sets = int.tryParse(_setsController?.text ?? '') ?? 3;
    String reps = _repsController?.text ?? '';
    double? weight = double.tryParse(_weightController?.text ?? '');

    await ExerciseSettingsManager.saveSettings(
      widget.exercise.name,
      sets,
      reps,
      weight,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    bool isRunning = widget.exercise.type == "Running";
    if (!_isLoaded)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text("Edit ${widget.exercise.name}")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              "Customize Defaults",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Settings will auto-fill next time you start this exercise.",
              style: TextStyle(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            TextField(
              controller: _setsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isRunning ? "Default Sets / Rounds" : "Default Sets",
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _repsController,
              decoration: InputDecoration(
                labelText: isRunning
                    ? "Default Duration/Distance (e.g. '30 min')"
                    : "Default Reps",
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            if (!isRunning)
              TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Starting Weight (kg)",
                  border: OutlineInputBorder(),
                  helperText: "Leave empty to use Smart Auto-Progression.",
                ),
              ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.all(15),
                ),
                child: const Text("SAVE SETTINGS"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- EXERCISE LIBRARY SCREEN ---
class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});
  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  String? selectedCategory;
  List<Exercise> _allExercises = [];
  List<String> _categories = [];
  List<String> _userExerciseNames = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    final list = await ExerciseLibrary.getAllExercisesWithUser();
    final userNames = await ExerciseLibrary.getUserOverrideNames();
    if (!mounted) return;
    setState(() {
      _allExercises = list;
      _categories = list.map((e) => e.category).toSet().toList()..sort();
      _userExerciseNames = userNames;
    });
  }

  bool _isDefaultExercise(String name) {
    return ExerciseLibrary.allExercises.any(
      (e) => e.name.toLowerCase() == name.toLowerCase(),
    );
  }

  bool _isUserAddedExercise(String name) {
    // User-added = in user list but NOT in default list
    return _userExerciseNames.any(
          (n) => n.toLowerCase() == name.toLowerCase(),
        ) &&
        !ExerciseLibrary.allExercises.any(
          (e) => e.name.toLowerCase() == name.toLowerCase(),
        );
  }

  Future<void> _showAddExerciseDialog() async {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final repController = TextEditingController(text: '8-10');
    final setsController = TextEditingController(text: '3');
    String type = 'Gym';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Exercise'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: repController,
                  decoration: const InputDecoration(
                    labelText: 'Default Reps/Range',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: setsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Default Sets'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: type,
                  items: ['Gym', 'Running', 'Recovery']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => type = v ?? 'Gym',
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final category = categoryController.text.trim().isEmpty
                    ? 'General'
                    : categoryController.text.trim();
                final sets = int.tryParse(setsController.text) ?? 3;
                final reps = repController.text.trim().isEmpty
                    ? '8-10'
                    : repController.text.trim();
                final ex = Exercise(
                  name: name,
                  category: category,
                  description: '',
                  difficulty: 'Medium',
                  type: type,
                  presetSets: sets,
                  repRange: reps,
                );
                await ExerciseLibrary.addUserExercise(ex);
                await _loadExercises();
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditExerciseDialog(
    Exercise ex, {
    bool isDefault = false,
  }) async {
    final nameController = TextEditingController(text: ex.name);
    final categoryController = TextEditingController(text: ex.category);
    final descController = TextEditingController(text: ex.description);
    final repController = TextEditingController(text: ex.repRange);
    final setsController = TextEditingController(
      text: ex.presetSets.toString(),
    );
    String type = ex.type;
    String difficulty = ex.difficulty;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isDefault ? 'Edit Exercise (Override)' : 'Edit Exercise',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      enabled: !isDefault, // Can't rename default exercises
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: repController,
                      decoration: const InputDecoration(
                        labelText: 'Default Reps/Range',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: setsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Default Sets',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: type,
                      items: ['Gym', 'Running', 'Recovery']
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => type = v ?? ex.type),
                      decoration: const InputDecoration(labelText: 'Type'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: difficulty,
                      items: ['Low', 'Medium', 'High']
                          .map(
                            (d) => DropdownMenuItem(value: d, child: Text(d)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => difficulty = v ?? ex.difficulty),
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                if (isDefault)
                  TextButton(
                    onPressed: () async {
                      // Reset to default by removing override
                      await ExerciseLibrary.removeUserExercise(ex.name);
                      await _loadExercises();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Reset to Default',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                TextButton(
                  onPressed: () async {
                    final newName = isDefault
                        ? ex.name
                        : nameController.text.trim();
                    if (newName.isEmpty) return;
                    final newCategory = categoryController.text.trim().isEmpty
                        ? 'General'
                        : categoryController.text.trim();
                    final newDesc = descController.text.trim();
                    final newSets =
                        int.tryParse(setsController.text) ?? ex.presetSets;
                    final newReps = repController.text.trim().isEmpty
                        ? ex.repRange
                        : repController.text.trim();
                    final updated = Exercise(
                      name: newName,
                      category: newCategory,
                      description: newDesc,
                      difficulty: difficulty,
                      type: type,
                      presetSets: newSets,
                      repRange: newReps,
                      startingWeight: ex.startingWeight,
                    );

                    if (isDefault) {
                      // For default exercises, save as user override
                      await ExerciseLibrary.addOrUpdateUserExercise(updated);
                    } else {
                      await ExerciseLibrary.updateUserExercise(
                        ex.name,
                        updated,
                      );
                    }
                    await _loadExercises();
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter exercises
    List<Exercise> filteredExercises = _allExercises.where((e) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          e.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          selectedCategory == null || e.category == selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    // Separate user-added exercises
    final userExercises = filteredExercises
        .where((e) => _isUserAddedExercise(e.name))
        .toList();
    final defaultExercises = filteredExercises
        .where((e) => !_isUserAddedExercise(e.name))
        .toList();

    // Count exercises per category
    Map<String, int> categoryCounts = {};
    for (var cat in _categories) {
      categoryCounts[cat] = _allExercises
          .where((e) => e.category == cat)
          .length;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Exercise Library"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Exercise',
            onPressed: () async {
              await _showAddExerciseDialog();
              await _loadExercises();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Category Chips
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text("All (${_allExercises.length})"),
                      selected: selectedCategory == null,
                      onSelected: (b) =>
                          setState(() => selectedCategory = null),
                    ),
                  );
                }
                final cat = _categories[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text("$cat (${categoryCounts[cat] ?? 0})"),
                    selected: selectedCategory == cat,
                    onSelected: (b) =>
                        setState(() => selectedCategory = b ? cat : null),
                  ),
                );
              },
            ),
          ),

          // Exercise List
          Expanded(
            child: ListView(
              children: [
                // User Exercises Section
                if (userExercises.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Your Exercises (${userExercises.length})",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...userExercises.map(
                    (ex) => _buildExerciseCard(ex, isUserAdded: true),
                  ),
                  const Divider(height: 24),
                ],

                // Default Exercises Section
                if (defaultExercises.isNotEmpty) ...[
                  if (userExercises.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fitness_center,
                            size: 18,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Default Exercises (${defaultExercises.length})",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ...defaultExercises.map(
                    (ex) => _buildExerciseCard(ex, isUserAdded: false),
                  ),
                ],

                // Empty state
                if (filteredExercises.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        "No exercises found",
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(Exercise ex, {required bool isUserAdded}) {
    final isDefault = _isDefaultExercise(ex.name);

    return Dismissible(
      key: Key(ex.name),
      direction: isUserAdded
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: AppColors.textPrimary),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Exercise?'),
            content: Text('Remove "${ex.name}" from your exercises?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await ExerciseLibrary.removeUserExercise(ex.name);
        await _loadExercises();
      },
      child: Card(
        color: AppColors.card,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isUserAdded
                ? AppColors.primary.withOpacity(0.2)
                : AppColors.secondary.withOpacity(0.2),
            child: Icon(
              _getTypeIcon(ex.type),
              color: isUserAdded ? AppColors.primary : AppColors.secondary,
              size: 20,
            ),
          ),
          title: Text(
            ex.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text("${ex.presetSets} sets × ${ex.repRange}"),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Blue: Workout settings
              IconButton(
                icon: const Icon(
                  Icons.tune,
                  color: AppColors.secondary,
                  size: 22,
                ),
                tooltip: 'Workout Settings',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExerciseEditorScreen(exercise: ex),
                    ),
                  );
                  await _loadExercises();
                },
              ),
              // Orange: Edit details
              IconButton(
                icon: const Icon(Icons.edit, color: AppColors.accent, size: 22),
                tooltip: 'Edit Details',
                onPressed: () async {
                  await _showEditExerciseDialog(ex, isDefault: isDefault);
                  await _loadExercises();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Running':
        return Icons.directions_run;
      case 'Recovery':
        return Icons.self_improvement;
      default:
        return Icons.fitness_center;
    }
  }
}

// --- TEMPLATE SELECTION SCREEN ---
class TemplateSelectionScreen extends StatefulWidget {
  const TemplateSelectionScreen({super.key});
  @override
  State<TemplateSelectionScreen> createState() =>
      _TemplateSelectionScreenState();
}

class _TemplateSelectionScreenState extends State<TemplateSelectionScreen> {
  List<WorkoutTemplate> _loadedTemplates = [];
  
  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final String? templatesJson = prefs.getString('user_templates');
    if (!mounted) return;
    
    if (templatesJson != null) {
      List<dynamic> decoded = jsonDecode(templatesJson);
      setState(() {
        _loadedTemplates = decoded
            .map((e) => WorkoutTemplate.fromJson(e))
            .toList();
      });
    } else {
      // No templates yet - user will create their own
      setState(() {
        _loadedTemplates = [];
      });
    }
  }

  Future<void> _deleteTemplate(WorkoutTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete Template', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${template.name}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      _loadedTemplates.removeWhere((t) => t.name == template.name);
      final encoded = jsonEncode(_loadedTemplates.map((t) => t.toJson()).toList());
      await prefs.setString('user_templates', encoded);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template "${template.name}" deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose Workout"),
        actions: [
          IconButton(
            icon: const Icon(Icons.library_books),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ExerciseLibraryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _loadedTemplates.length,
              itemBuilder: (context, index) {
                final template = _loadedTemplates[index];
                return Card(
                  color: AppColors.card,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: ListTile(
                    title: Text(
                      template.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      template.exercises.length > 3
                          ? "${template.exercises.sublist(0, 3).join(", ")}..."
                          : template.exercises.join(", "),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteTemplate(template),
                        ),
                        const Icon(
                          Icons.play_arrow,
                          color: AppColors.secondary,
                        ),
                      ],
                    ),
                    onTap: () => _startWorkout(template),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("CREATE NEW TEMPLATE"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  padding: const EdgeInsets.all(15),
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateTemplateScreen(),
                    ),
                  );
                  if (result == true) _loadTemplates();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startWorkout(WorkoutTemplate template) async {
    bool hasRunning = false;
    bool hasGym = false;
    final all = await ExerciseLibrary.getAllExercisesWithUser();
    for (String exName in template.exercises) {
      final exercise = all.firstWhere(
        (e) => e.name.toLowerCase() == exName.toLowerCase(),
        orElse: () => const Exercise(
          name: "Unknown",
          category: "Running",
          description: "",
          difficulty: "Medium",
          type: "Gym",
        ),
      );
      if (exercise.type == "Running")
        hasRunning = true;
      else if (exercise.type == "Gym" || exercise.type == "Recovery")
        hasGym = true;
    }

    if (hasRunning && !hasGym) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedRunScreen(template: template),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkoutRunnerScreen(template: template),
        ),
      );
    }
  }
}

// --- CREATE TEMPLATE SCREEN ---
class CreateTemplateScreen extends StatefulWidget {
  const CreateTemplateScreen({super.key});
  @override
  State<CreateTemplateScreen> createState() => _CreateTemplateScreenState();
}

class _CreateTemplateScreenState extends State<CreateTemplateScreen> {
  final TextEditingController _nameController = TextEditingController();
  final List<String?> _selectedExercises = [null];
  List<Exercise> _availableExercises = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableExercises();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableExercises() async {
    final list = await ExerciseLibrary.getAllExercisesWithUser();
    if (!mounted) return;
    setState(() => _availableExercises = list);
  }

  void _addExerciseField() {
    setState(() {
      _selectedExercises.add(null);
    });
  }

  Future<void> _saveTemplate() async {
    if (_nameController.text.isEmpty) return;
    List<String> raw = _selectedExercises
        .map((s) => s?.trim() ?? '')
        .where((text) => text.isNotEmpty)
        .toList();
    final seen = <String>{};
    List<String> newExercises = [];
    for (var name in raw) {
      final low = name.toLowerCase();
      if (!seen.contains(low)) {
        seen.add(low);
        newExercises.add(name);
      }
    }
    if (newExercises.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final String? templatesJson = prefs.getString('user_templates');
    List<WorkoutTemplate> currentList = [];
    if (templatesJson != null) {
      List<dynamic> decoded = jsonDecode(templatesJson);
      currentList = decoded.map((e) => WorkoutTemplate.fromJson(e)).toList();
    }

    currentList.add(
      WorkoutTemplate(name: _nameController.text, exercises: newExercises),
    );
    final String encoded = jsonEncode(
      currentList.map((e) => e.toJson()).toList(),
    );
    await prefs.setString('user_templates', encoded);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Workout")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Workout Name",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.black12,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _selectedExercises.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedExercises[index],
                  decoration: const InputDecoration(
                    labelText: "Exercise",
                    filled: true,
                    fillColor: Colors.black12,
                  ),
                  items: _availableExercises
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.name,
                          child: Text(e.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedExercises[index] = v),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _addExerciseField,
                  child: const Text("+ Exercise"),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _saveTemplate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text("Save"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- SET ROW WIDGET (Isolated state for text fields) ---
class _SetRowWidget extends StatefulWidget {
  final int index;
  final String initialWeight;
  final String initialReps;
  final Function(String) onWeightChanged;
  final Function(String) onRepsChanged;

  const _SetRowWidget({
    super.key,
    required this.index,
    required this.initialWeight,
    required this.initialReps,
    required this.onWeightChanged,
    required this.onRepsChanged,
  });

  @override
  State<_SetRowWidget> createState() => _SetRowWidgetState();
}

class _SetRowWidgetState extends State<_SetRowWidget> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.initialWeight);
    _repsController = TextEditingController(text: widget.initialReps);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Text(
              "${widget.index + 1}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "kg",
                  isDense: true,
                ),
                onChanged: widget.onWeightChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _repsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Reps",
                  isDense: true,
                ),
                onChanged: widget.onRepsChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WORKOUT RUNNER ---
class WorkoutRunnerScreen extends StatefulWidget {
  final WorkoutTemplate template;
  const WorkoutRunnerScreen({super.key, required this.template});
  @override
  State<WorkoutRunnerScreen> createState() => _WorkoutRunnerScreenState();
}

class _WorkoutRunnerScreenState extends State<WorkoutRunnerScreen> {
  int currentExerciseIndex = 0;
  final List<Map<String, dynamic>> _allWorkoutSets = [];
  List<Map<String, String>> _currentSets = [];
  String _suggestedWeight = "";
  String _lastWeight = "";
  String _currentTime = "";
  String _currentReps = "";
  late TextEditingController _sprintRepsController;

  // Key to force rebuild of set list when sets change
  int _setListKey = 0;

  // Rest Timer
  bool _isResting = false;
  int _restSeconds = 90;
  int _restSecondsRemaining = 0;
  Timer? _restTimer;

  // Energy & Notes Tracking
  int _energyLevel = 3;
  List<String> _selectedMoods = [];
  final TextEditingController _notesController = TextEditingController();
  final List<String> _moodOptions = [
    '💪 Strong',
    '🔥 Pumped',
    '😴 Tired',
    '😤 Struggled',
    '🎯 Focused',
    '😌 Easy',
  ];

  @override
  void initState() {
    super.initState();
    _sprintRepsController = TextEditingController();
    _setupCurrentExercise();
  }

  @override
  void dispose() {
    _sprintRepsController.dispose();
    _notesController.dispose();
    _restTimer?.cancel();
    super.dispose();
  }

  void _startRestTimer() {
    _restTimer?.cancel(); // Cancel existing timer to prevent leaks
    setState(() {
      _isResting = true;
      _restSecondsRemaining = _restSeconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_restSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _isResting = false);
      } else {
        setState(() => _restSecondsRemaining--);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    if (!mounted) return;
    setState(() => _isResting = false);
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _setupCurrentExercise() async {
    if (currentExerciseIndex >= widget.template.exercises.length) return;
    String currentExerciseName =
        widget.template.exercises[currentExerciseIndex];

    final all = await ExerciseLibrary.getAllExercisesWithUser();
    Exercise exerciseDef = all.firstWhere(
      (e) => e.name.toLowerCase() == currentExerciseName.toLowerCase(),
      orElse: () => const Exercise(
        name: "Unknown",
        category: "Unknown",
        description: "",
        difficulty: "Unknown",
        type: "Gym",
      ),
    );
    Exercise exercise = await ExerciseSettingsManager.getExerciseWithSettings(
      exerciseDef,
    );
    if (!mounted) return;

    final int sets = exercise.presetSets;
    final String reps = exercise.repRange;

    // Clean reps value - only keep if it's a number
    String cleanReps = '';
    if (reps.isNotEmpty && int.tryParse(reps) != null) {
      cleanReps = reps;
    }

    List<Map<String, String>> newSets = [];
    if (exercise.type == "Gym" && !_isRecoveryExercise(exercise.name)) {
      for (int i = 0; i < sets; i++) {
        newSets.add({"weight": "", "reps": cleanReps});
      }
    }
    if (newSets.isEmpty) newSets.add({"weight": "", "reps": ""});

    String forcedWeight = exercise.startingWeight != null
        ? exercise.startingWeight.toString()
        : "";

    setState(() {
      _currentSets = newSets;
      _suggestedWeight = forcedWeight;
      _lastWeight = "";
      _currentTime = "";
      _currentReps = cleanReps;
      _sprintRepsController.text = cleanReps;
      _setListKey++; // Force rebuild of list
    });

    if (forcedWeight.isEmpty) {
      _analyzeLastSession(currentExerciseName);
    }
  }

  bool _isSprintExercise(String exerciseName) {
    final sprintExercises = [
      "10m Sprint Test",
      "10m Sprints",
      "Flying 30s",
      "Short Sprints",
      "Suicides (Shuttles)",
    ];
    return sprintExercises.any(
      (e) => e.toLowerCase() == exerciseName.toLowerCase(),
    );
  }

  bool _isRecoveryExercise(String exerciseName) {
    final recoveryExercises = [
      "Sleep",
      "Recovery",
      "Stretching",
      "Foam Roll",
      "Dynamic Warmup",
      "Visualization",
    ];
    return recoveryExercises.any(
      (e) => e.toLowerCase() == exerciseName.toLowerCase(),
    );
  }

  double _getIncrement(String exerciseName) {
    String name = exerciseName.toLowerCase();
    if (name.contains("squat") ||
        name.contains("deadlift") ||
        name.contains("trap bar"))
      return 5.0;
    if (name.contains("bench") ||
        name.contains("pull") ||
        name.contains("row") ||
        name.contains("press"))
      return 2.5;
    return 1.25;
  }

  Future<void> _analyzeLastSession(String currentExercise) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    List<String>? currentHistory = prefs.getStringList('workout_history');
    if (currentHistory == null || currentHistory.isEmpty) return;

    for (int i = currentHistory.length - 1; i >= 0; i--) {
      try {
        Map<String, dynamic> workout = jsonDecode(currentHistory[i]);
        List<dynamic> sets = workout['sets'];
        if (sets.isEmpty) continue;

        for (var s in sets) {
          String exName = s['exercise']?.toString() ?? "";
          if (exName.toLowerCase() == currentExercise.toLowerCase()) {
            List<dynamic> setsList = s['sets'];
            if (setsList.isNotEmpty) {
              String lastWeight = "0";
              for (int j = setsList.length - 1; j >= 0; j--) {
                String w = setsList[j]['weight']?.toString() ?? "";
                if (w.isNotEmpty && w != "0") {
                  lastWeight = w;
                  break;
                }
              }

              double lastWeightNum = double.tryParse(lastWeight) ?? 0;
              if (lastWeightNum > 0) {
                double increment = _getIncrement(currentExercise);
                setState(() {
                  _lastWeight = lastWeightNum.toString();
                  _suggestedWeight = (lastWeightNum + increment).toString();
                });
                return;
              }
            }
          }
        }
      } catch (e) {
        continue;
      }
    }
  }

  void _nextExercise() async {
    String exerciseName = widget.template.exercises[currentExerciseIndex];
    _allWorkoutSets.add({
      "exercise": exerciseName,
      "sets": List.from(_currentSets),
    });

    if (currentExerciseIndex < widget.template.exercises.length - 1) {
      currentExerciseIndex++;
      _setupCurrentExercise();
    } else {
      double maxWeight = 0;
      String bestExercise = "";
      for (var ex in _allWorkoutSets) {
        for (var s in ex['sets']) {
          double w = double.tryParse(s['weight'] ?? "0") ?? 0;
          if (w > maxWeight) {
            maxWeight = w;
            bestExercise = ex['exercise'];
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList('workout_history') ?? [];
      final workoutData = {
        'date': DateTime.now().toString().split(' ')[0],
        'template_name': widget.template.name,
        'sets': _allWorkoutSets,
        'energy': _energyLevel,
        'mood': _selectedMoods,
        'notes': _notesController.text,
      };
      history.add(jsonEncode(workoutData));
      await prefs.setStringList('workout_history', history);

      // Mark this day as logged in the calendar with workout details
      final today = DateTime.now();
      await logWorkoutForDate(DateTime(today.year, today.month, today.day), {
        'name': widget.template.name,
        'energy': _energyLevel,
        'mood': _selectedMoods,
      });

      // Count running exercises in this workout
      int runCount = 0;
      final allExercises = await ExerciseLibrary.getAllExercisesWithUser();
      for (var exerciseName in widget.template.exercises) {
        final match = allExercises.where(
          (e) => e.name.toLowerCase() == exerciseName.toLowerCase(),
        );
        if (match.isNotEmpty && match.first.type == "Running") {
          runCount++;
        }
      }

      // Update profile with running count
      if (runCount > 0) {
        UserProfile profile = await ProfileManager.getProfile();
        profile.totalRunExercises += runCount;
        await ProfileManager.saveProfile(profile);
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutSummaryScreen(
              type: "Gym",
              scoreName: bestExercise.isEmpty ? "Workout" : bestExercise,
              scoreValue: maxWeight,
              unit: "kg",
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentExerciseIndex >= widget.template.exercises.length)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    String currentExercise = widget.template.exercises[currentExerciseIndex];
    int total = widget.template.exercises.length;
    bool isSprint = _isSprintExercise(currentExercise);
    bool isRecovery = _isRecoveryExercise(currentExercise);
    bool isGym = !isSprint && !isRecovery;

    // Rest Timer Overlay
    if (_isResting) {
      return Scaffold(
        backgroundColor: Colors.black.withOpacity(0.95),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "REST",
                style: TextStyle(
                  fontSize: 24,
                  color: AppColors.textMuted,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _formatTime(_restSecondsRemaining),
                style: const TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Next: $currentExercise",
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 32),
                    color: AppColors.textMuted,
                    onPressed: () => setState(
                      () => _restSeconds = (_restSeconds - 15).clamp(15, 300),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "${_restSeconds}s default",
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 32),
                    color: AppColors.textMuted,
                    onPressed: () => setState(
                      () => _restSeconds = (_restSeconds + 15).clamp(15, 300),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _skipRest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                ),
                child: const Text(
                  "SKIP REST",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Workout in Progress")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: (currentExerciseIndex + 1) / total,
                  minHeight: 8,
                  color: AppColors.secondary,
                ),
                const SizedBox(height: 8),
                Text(
                  "Exercise ${currentExerciseIndex + 1} of $total",
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            currentExercise,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          if (isRecovery) ...[
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Mark as completed when done.",
                    style: TextStyle(color: AppColors.primary, fontSize: 16),
                  ),
                ),
              ),
            ),
          ] else if (isSprint) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextField(
                      controller: _sprintRepsController,
                      decoration: const InputDecoration(
                        labelText: "Reps",
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      onChanged: (val) => _currentReps = val,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Best Time (s)",
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      onChanged: (val) => _currentTime = val,
                    ),
                  ],
                ),
              ),
            ),
          ] else if (isGym) ...[
            if (_suggestedWeight.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_lastWeight.isNotEmpty)
                      Text(
                        "Last: ${_lastWeight}kg",
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    if (_lastWeight.isNotEmpty) const SizedBox(width: 15),
                    if (_lastWeight.isNotEmpty)
                      const Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    if (_lastWeight.isNotEmpty) const SizedBox(width: 15),
                    Text(
                      "Suggested: ${_suggestedWeight}kg",
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: ListView.builder(
                key: ValueKey('setlist_$_setListKey'),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _currentSets.length,
                itemBuilder: (context, index) {
                  // Apply suggested weight to first set if empty
                  if (index == 0 &&
                      (_currentSets[index]['weight'] ?? '').isEmpty &&
                      _suggestedWeight.isNotEmpty) {
                    _currentSets[index]['weight'] = _suggestedWeight;
                  }

                  return _SetRowWidget(
                    key: ValueKey('setrow_${_setListKey}_$index'),
                    index: index,
                    initialWeight: _currentSets[index]['weight'] ?? '',
                    initialReps: _currentSets[index]['reps'] ?? '',
                    onWeightChanged: (val) =>
                        _currentSets[index]['weight'] = val,
                    onRepsChanged: (val) => _currentSets[index]['reps'] = val,
                  );
                },
              ),
            ),
          ],

          // Energy & Notes section (only show on last exercise)
          if (currentExerciseIndex == total - 1) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "How did it feel?",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text("Energy:"),
                      const SizedBox(width: 10),
                      ...List.generate(
                        5,
                        (i) => GestureDetector(
                          onTap: () => setState(() => _energyLevel = i + 1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _moodOptions
                        .map(
                          (mood) => FilterChip(
                            label: Text(
                              mood,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: _selectedMoods.contains(mood),
                            onSelected: (selected) => setState(() {
                              if (selected)
                                _selectedMoods.add(mood);
                              else
                                _selectedMoods.remove(mood);
                            }),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      hintText: "Notes (optional)...",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                if (isGym)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _currentSets.add({"weight": "", "reps": ""});
                              _setListKey++;
                            });
                          },
                          child: const Text("ADD SET"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _currentSets.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    _currentSets.removeLast();
                                    _setListKey++;
                                  });
                                },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: _currentSets.isEmpty
                                  ? AppColors.textMuted
                                  : AppColors.error,
                            ),
                          ),
                          child: Text(
                            "DELETE SET",
                            style: TextStyle(
                              color: _currentSets.isEmpty
                                  ? AppColors.textMuted
                                  : AppColors.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (isGym) const SizedBox(height: 10),
                if (isGym)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.timer, size: 18),
                          label: Text("REST ${_restSeconds}s"),
                          onPressed: _startRestTimer,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (isSprint) {
                        _currentSets = [
                          {"reps": _currentReps, "time": _currentTime},
                        ];
                      }
                      _nextExercise();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.all(15),
                    ),
                    child: Text(
                      currentExerciseIndex == total - 1
                          ? "FINISH WORKOUT"
                          : "NEXT EXERCISE",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- RUN SCREEN ---
class EnhancedRunScreen extends StatefulWidget {
  final WorkoutTemplate? template;
  const EnhancedRunScreen({super.key, this.template});
  @override
  State<EnhancedRunScreen> createState() => _EnhancedRunScreenState();
}

class _EnhancedRunScreenState extends State<EnhancedRunScreen> {
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _sprintDistanceController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String selectedRunType = "Steady State";

  // Energy & Notes Tracking
  int _energyLevel = 3;
  List<String> _selectedMoods = [];
  final List<String> _moodOptions = [
    '💪 Strong',
    '🔥 Pumped',
    '😴 Tired',
    '😤 Struggled',
    '🎯 Focused',
    '😌 Easy',
  ];

  @override
  void initState() {
    super.initState();
    _setupRunDefaults();
  }

  void _setupRunDefaults() async {
    String runName = "Run";

    if (widget.template != null && widget.template!.exercises.isNotEmpty) {
      for (var name in widget.template!.exercises) {
        if ([
          "10m",
          "sprint",
          "run",
          "walk",
          "shuttle",
          "suicide",
        ].any((k) => name.toLowerCase().contains(k))) {
          runName = name;
          break;
        }
      }
    }

    String lower = runName.toLowerCase();
    if (lower.contains("interval") || lower.contains("15/15")) {
      selectedRunType = "Intervals (15/15)";
    } else if (lower.contains("suicide") || lower.contains("shuttle")) {
      selectedRunType = "Suicides";
    } else if (lower.contains("sprint") || lower.contains("flying")) {
      selectedRunType = "Sprints";
    } else {
      selectedRunType = "Steady State";
    }

    Exercise dummy = Exercise(
      name: runName,
      category: "Running",
      description: "",
      difficulty: "Medium",
    );
    Exercise settings = await ExerciseSettingsManager.getExerciseWithSettings(
      dummy,
    );

    setState(() {
      String val = settings.repRange.toLowerCase();
      if (val.contains("min")) {
        _timeController.text = val.replaceAll(RegExp(r'[^0-9]'), '');
      } else if (val.contains("km") || val.contains("m")) {
        _distanceController.text = val.replaceAll(RegExp(r'[^0-9]'), '');
      } else if (val.contains("rep")) {
        _repsController.text = val.replaceAll(RegExp(r'[^0-9]'), '');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Log Run")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const Text(
                "Run Type",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (var type in [
                    "Steady State",
                    "Intervals (15/15)",
                    "Sprints",
                    "Suicides",
                  ])
                    FilterChip(
                      label: Text(type),
                      selected: selectedRunType == type,
                      onSelected: (b) => setState(() => selectedRunType = type),
                    ),
                ],
              ),
              const SizedBox(height: 30),

              if (selectedRunType.contains("Sprint") ||
                  selectedRunType.contains("Suicides")) ...[
                TextField(
                  controller: _repsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Reps",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              if (selectedRunType == "Sprints") ...[
                TextField(
                  controller: _sprintDistanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Distance per Sprint (m)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              if (!selectedRunType.contains("Suicides") &&
                  selectedRunType != "Sprints") ...[
                TextField(
                  controller: _distanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Distance (km or m)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              TextField(
                controller: _timeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Total Time (min)",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 30),

              // Energy & Notes section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "How did it feel?",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text("Energy:"),
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
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _moodOptions
                          .map(
                            (mood) => FilterChip(
                              label: Text(
                                mood,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: _selectedMoods.contains(mood),
                              onSelected: (selected) => setState(() {
                                if (selected)
                                  _selectedMoods.add(mood);
                                else
                                  _selectedMoods.remove(mood);
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        hintText: "Notes (optional)...",
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _logRun,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(15),
                  ),
                  child: const Text("LOG RUN"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _logRun() async {
    double distance = double.tryParse(_distanceController.text) ?? 0;
    double time = double.tryParse(_timeController.text) ?? 0;

    if (selectedRunType == "Suicides") {
      int reps = int.tryParse(_repsController.text) ?? 0;
      distance = (reps * 60) / 1000;
    } else if (selectedRunType == "Sprints") {
      int reps = int.tryParse(_repsController.text) ?? 0;
      int distPerSprint = int.tryParse(_sprintDistanceController.text) ?? 0;
      distance = (reps * distPerSprint) / 1000;
    }

    double pace = (distance > 0) ? time / distance : 0;

    // Save to history with energy/mood/notes
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('workout_history') ?? [];
    final workoutData = {
      'date': DateTime.now().toString().split(' ')[0],
      'template_name': widget.template?.name ?? 'Run',
      'type': 'running',
      'runType': selectedRunType,
      'distance': distance,
      'time': time,
      'pace': pace,
      'energy': _energyLevel,
      'mood': _selectedMoods,
      'notes': _notesController.text,
      'sets': [],
    };
    history.add(jsonEncode(workoutData));
    await prefs.setStringList('workout_history', history);

    // Mark this day as logged in the calendar with details
    final today = DateTime.now();
    await logWorkoutForDate(DateTime(today.year, today.month, today.day), {
      'name': 'Run: $selectedRunType',
      'type': 'running',
      'energy': _energyLevel,
      'mood': _selectedMoods,
    });

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RunSummaryScreen(
          distance: distance,
          time: time,
          pace: pace,
          runType: selectedRunType,
        ),
      ),
    );
  }
}

// --- SUMMARIES ---
class RunSummaryScreen extends StatelessWidget {
  final double distance, time, pace;
  final String runType;
  const RunSummaryScreen({
    super.key,
    required this.distance,
    required this.time,
    required this.pace,
    this.runType = "Run",
  });

  Future<void> _updateProfile() async {
    UserProfile profile = await ProfileManager.getProfile();
    profile.totalExercises++;
    profile.totalRunExercises++; // Track running sessions
    if (distance > profile.longestRunDistance)
      profile.longestRunDistance = distance;
    if (time > profile.longestRunTime) profile.longestRunTime = time;
    await ProfileManager.saveProfile(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Run Complete"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              runType,
              style: const TextStyle(fontSize: 22, color: AppColors.secondary),
            ),
            const SizedBox(height: 20),
            Text(
              "${distance.toStringAsFixed(2)} km",
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),
            Text(
              "${time.toStringAsFixed(0)} min",
              style: const TextStyle(fontSize: 20, color: AppColors.textMuted),
            ),
            Text(
              "${pace.toStringAsFixed(2)} min/km",
              style: const TextStyle(fontSize: 20, color: AppColors.primary),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                await _updateProfile();
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text("DONE"),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkoutSummaryScreen extends StatelessWidget {
  final String type, scoreName, unit;
  final double scoreValue;
  const WorkoutSummaryScreen({
    super.key,
    required this.type,
    required this.scoreName,
    required this.scoreValue,
    required this.unit,
  });

  Future<void> _updateProfile() async {
    UserProfile profile = await ProfileManager.getProfile();
    profile.totalExercises++;
    if (type == "Gym") {
      double current = profile.personalRecords[scoreName] ?? 0;
      profile.personalRecords[scoreName] = max(current, scoreValue);
      if (scoreValue > profile.maxLifted) profile.maxLifted = scoreValue;
    }
    await ProfileManager.saveProfile(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Workout Complete"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EditGoalsScreen()),
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, double>>(
        future: ProStats.getGoals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          double goal = 0;
          if (snapshot.hasData) goal = snapshot.data![scoreName] ?? 0;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  scoreName,
                  style: const TextStyle(
                    fontSize: 20,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  "${scoreValue.toStringAsFixed(1)} $unit",
                  style: const TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (goal > 0) ...[
                  const SizedBox(height: 20),
                  Text(
                    "Pro Goal: $goal $unit",
                    style: const TextStyle(color: AppColors.secondary),
                  ),
                ],
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () async {
                    await _updateProfile();
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text("DONE"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
