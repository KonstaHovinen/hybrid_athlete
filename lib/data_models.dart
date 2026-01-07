import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/sync_service.dart';

// --- PROFESSIONAL GOALS DATABASE ---
class ProStats {
  static const Map<String, double> defaultGoals = {
    "Back Squat": 220, "Deadlift": 250, "Bench Press": 140,
    "Overhead Press": 95, "Pull Ups": 25, "Box Jumps": 65,
    "Pace (min/km)": 4.4,
  };

  static Future<Map<String, double>> getGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final String? goalsJson = prefs.getString('pro_goals');
    if (goalsJson != null) {
      try {
        Map<String, dynamic> decoded = jsonDecode(goalsJson);
        Map<String, double> userGoals = {};
        decoded.forEach((key, value) {
          userGoals[key] = (value is int) ? value.toDouble() : (value as double);
        });
        return userGoals;
      } catch (e) { debugPrint("Error loading goals"); }
    }
    return Map.from(defaultGoals);
  }

  static Future<void> saveGoals(Map<String, double> newGoals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pro_goals', jsonEncode(newGoals));
  }
}

// --- DATA MODELS ---
class WorkoutTemplate {
  final String name;
  final List<String> exercises;
  WorkoutTemplate({required this.name, required this.exercises});

  Map<String, dynamic> toJson() => { 'name': name, 'exercises': exercises };

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) {
    return WorkoutTemplate(
      name: json['name'],
      exercises: List<String>.from(json['exercises']),
    );
  }
}

// Templates are now stored in SharedPreferences as 'user_templates'
// No hardcoded default templates - users create their own

class Exercise {
  final String name;
  final String category;
  final String description;
  final String difficulty;
  final String type; 
  final int presetSets; // Changed to non-nullable for easier logic
  final String repRange;
  final double? startingWeight; // NEW: Custom starting weight
  
  const Exercise({
    required this.name, required this.category, required this.description,
    required this.difficulty, this.type = "Gym", this.presetSets = 3,
    this.repRange = "8-10", this.startingWeight,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'description': description,
    'difficulty': difficulty,
    'type': type,
    'presetSets': presetSets,
    'repRange': repRange,
    'startingWeight': startingWeight,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      name: json['name'] ?? 'Unknown',
      category: json['category'] ?? 'Unknown',
      description: json['description'] ?? '',
      difficulty: json['difficulty'] ?? 'Medium',
      type: json['type'] ?? 'Gym',
      presetSets: (json['presetSets'] is num) ? (json['presetSets'] as num).toInt() : 3,
      repRange: json['repRange'] ?? '8-10',
      startingWeight: json['startingWeight'] != null ? (json['startingWeight'] as num).toDouble() : null,
    );
  }
}

// --- NEW: EXERCISE SETTINGS MANAGER ---
class ExerciseSettingsManager {
  static const String _key = 'exercise_custom_settings';

  // Saves a user's custom settings for a specific exercise
  static Future<void> saveSettings(String exerciseName, int sets, String reps, double? weight) async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonStr = prefs.getString(_key);
    Map<String, dynamic> allSettings = jsonStr != null ? jsonDecode(jsonStr) : {};

    // Normalize key to lowercase to make lookups case-insensitive
    final key = exerciseName.toLowerCase();
    allSettings[key] = {
      'sets': sets,
      'reps': reps,
      'weight': weight
    };

    await prefs.setString(_key, jsonEncode(allSettings));
  }

  // Loads settings, merging defaults with user overrides
  static Future<Exercise> getExerciseWithSettings(Exercise defaultEx) async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonStr = prefs.getString(_key);
    if (jsonStr == null) return defaultEx;

    Map<String, dynamic> allSettings = jsonDecode(jsonStr);
    // Use lowercase key lookup for case-insensitive matching
    final key = defaultEx.name.toLowerCase();
    if (!allSettings.containsKey(key)) return defaultEx;

    var custom = allSettings[key];

    return Exercise(
      name: defaultEx.name,
      category: defaultEx.category,
      description: defaultEx.description,
      difficulty: defaultEx.difficulty,
      type: defaultEx.type,
      // OVERRIDES:
      presetSets: custom['sets'] ?? defaultEx.presetSets,
      repRange: custom['reps'] ?? defaultEx.repRange,
      startingWeight: custom['weight'] != null ? (custom['weight'] as num).toDouble() : null,
    );
  }
}

class ExerciseLibrary {
  static const List<Exercise> allExercises = [
    // === RUNNING / SPRINTS ===
    Exercise(name: "10m Sprint Test", category: "Running", description: "Record best time", difficulty: "High", type: "Running", presetSets: 1, repRange: "Best time"),
    Exercise(name: "10m Sprints", category: "Running", description: "Max effort", difficulty: "High", type: "Running", presetSets: 1, repRange: "3 reps"),
    Exercise(name: "Flying 30s", category: "Running", description: "Build 20m, Sprint 30m", difficulty: "High", type: "Running", presetSets: 1, repRange: "4 reps"),
    Exercise(name: "Suicides (Shuttles)", category: "Running", description: "5m, 10m, 15m, 20m", difficulty: "High", type: "Running", presetSets: 1, repRange: "5 reps"),
    Exercise(name: "15/15 Interval Run", category: "Running", description: "Sprint 15s / Walk 15s", difficulty: "High", type: "Running", presetSets: 1, repRange: "8 mins"),
    
    // === LOWER BODY ===
    Exercise(name: "Trap Bar Deadlift", category: "Lower Body", description: "Full body power", difficulty: "High", type: "Gym", presetSets: 3, repRange: "5 reps"),
    Exercise(name: "Bulgarian Split Squat", category: "Lower Body", description: "Single leg strength", difficulty: "Medium", type: "Gym", presetSets: 3, repRange: "8/side"),
    Exercise(name: "Nordic Curl", category: "Lower Body", description: "Hamstring eccentric", difficulty: "High", type: "Gym", presetSets: 3, repRange: "6 reps"),
    
    // === UPPER BODY ===
    Exercise(name: "Bench Press", category: "Upper Body", description: "Chest strength", difficulty: "Medium", type: "Gym", presetSets: 2, repRange: "5 reps"),
    Exercise(name: "Pull Ups", category: "Upper Body", description: "Back strength", difficulty: "Medium", type: "Gym", presetSets: 3, repRange: "6 reps"),
    Exercise(name: "Weighted Pull-Up", category: "Upper Body", description: "Max strength", difficulty: "High", type: "Gym", presetSets: 2, repRange: "5 reps"),

    // === CORE ===
    Exercise(name: "Landmine Rotations", category: "Core", description: "Rotational power", difficulty: "Medium", type: "Gym", presetSets: 3, repRange: "6/side"),
    Exercise(name: "Copenhagen Plank", category: "Core", description: "Adductor health", difficulty: "Low", type: "Gym", presetSets: 2, repRange: "20s"),
    Exercise(name: "Deadbugs", category: "Core", description: "Core stability", difficulty: "Low", type: "Gym", presetSets: 3, repRange: "10 reps"),
    Exercise(name: "Planks", category: "Core", description: "Isometric hold", difficulty: "Low", type: "Gym", presetSets: 3, repRange: "60s"),
    Exercise(name: "Pallof Press", category: "Core", description: "Anti-rotation", difficulty: "Medium", type: "Gym", presetSets: 3, repRange: "10 reps"),
    
    // === PLYOMETRICS ===
    Exercise(name: "Box Jumps", category: "Plyometrics", description: "Explosive vertical", difficulty: "High", type: "Gym", presetSets: 3, repRange: "3 reps"),
    Exercise(name: "Trap Bar Jumps", category: "Plyometrics", description: "Weighted power", difficulty: "High", type: "Gym", presetSets: 3, repRange: "3 reps"),
    Exercise(name: "Lateral Heiden Jumps", category: "Plyometrics", description: "Lateral power", difficulty: "High", type: "Gym", presetSets: 3, repRange: "4/side"),
    Exercise(name: "Broad Jumps", category: "Plyometrics", description: "Horizontal power", difficulty: "High", type: "Gym", presetSets: 3, repRange: "5 reps"),

    // === RECOVERY ===
    Exercise(name: "Light Walk", category: "Recovery", description: "Active recovery", difficulty: "Low", type: "Recovery", presetSets: 1, repRange: "30 min"),
    Exercise(name: "Stretching", category: "Recovery", description: "Flexibility", difficulty: "Low", type: "Recovery"),
    Exercise(name: "Foam Roll", category: "Recovery", description: "Myofascial release", difficulty: "Low", type: "Recovery"),
    Exercise(name: "Dynamic Warmup", category: "Recovery", description: "Prep for movement", difficulty: "Low", type: "Recovery"),
    Exercise(name: "Visualization", category: "Recovery", description: "Mental prep", difficulty: "Low", type: "Recovery"),
    Exercise(name: "Sleep", category: "Recovery", description: "Critical rest", difficulty: "Low", type: "Recovery"),
    Exercise(name: "Recovery", category: "Recovery", description: "Rest day", difficulty: "Low", type: "Recovery"),
  ];
  // In-memory cache for combined list to avoid repeated SharedPreferences reads
  static List<Exercise>? _cacheAllExercises;
  
  static List<Exercise> getExercisesByCategory(String category) {
    return allExercises.where((e) => e.category == category).toList();
  }
  static List<String> getCategories() {
    return allExercises.map((e) => e.category).toSet().toList();
  }

  // --- User-added exercises persistence ---
  static const String _userKey = 'user_exercises';

  static Future<List<Exercise>> _loadUserExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_userKey);
    if (jsonStr == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => Exercise.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> _saveUserExercises(List<Exercise> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_userKey, encoded);
    // invalidate cache
    _cacheAllExercises = null;
    await SyncService.exportData(); // Sync to desktop
  }

  // Public: return combined list of default + user exercises
  static Future<List<Exercise>> getAllExercisesWithUser() async {
    if (_cacheAllExercises != null) return _cacheAllExercises!;
    final users = await _loadUserExercises();
    final all = <String, Exercise>{};
    for (var ex in allExercises) {
      all[ex.name.toLowerCase()] = ex;
    }
    for (var ex in users) {
      all[ex.name.toLowerCase()] = ex;
    }
    _cacheAllExercises = all.values.toList();
    return _cacheAllExercises!;
  }

  static Future<void> addUserExercise(Exercise ex) async {
    final users = await _loadUserExercises();
    // avoid duplicates by name (case-insensitive)
    if (users.any((u) => u.name.toLowerCase() == ex.name.toLowerCase())) return;
    users.add(ex);
    await _saveUserExercises(users);
    _cacheAllExercises = null;
  }

  static Future<void> updateUserExercise(String originalName, Exercise updated) async {
    final users = await _loadUserExercises();
    for (int i = 0; i < users.length; i++) {
      if (users[i].name.toLowerCase() == originalName.toLowerCase()) {
        users[i] = updated;
        await _saveUserExercises(users);
        _cacheAllExercises = null;
        return;
      }
    }
    // if not found, add
    await addUserExercise(updated);
  }

  static Future<void> removeUserExercise(String name) async {
    final users = await _loadUserExercises();
    users.removeWhere((u) => u.name.toLowerCase() == name.toLowerCase());
    await _saveUserExercises(users);
    _cacheAllExercises = null;
  }

  // Add or update a user exercise (for overriding defaults)
  static Future<void> addOrUpdateUserExercise(Exercise ex) async {
    final users = await _loadUserExercises();
    final idx = users.indexWhere((u) => u.name.toLowerCase() == ex.name.toLowerCase());
    if (idx >= 0) {
      users[idx] = ex;
    } else {
      users.add(ex);
    }
    await _saveUserExercises(users);
    _cacheAllExercises = null;
  }

  // Get list of exercise names that have user overrides
  static Future<List<String>> getUserOverrideNames() async {
    final users = await _loadUserExercises();
    return users.map((e) => e.name).toList();
  }
}

// --- USER PROFILE ---
class Badge {
  final String id, name, description;
  final IconData icon;
  final Color color;
  Badge({required this.id, required this.name, required this.description, required this.icon, required this.color});
}

class UserProfile {
  String name;
  Map<String, double> personalRecords;
  int totalExercises;
  int totalRunExercises;
  double longestRunDistance;
  double longestRunTime;
  double maxLifted;
  String? activeBadgeId;

  UserProfile({
    this.name = "Athlete",
    this.personalRecords = const {},
    this.totalExercises = 0,
    this.totalRunExercises = 0,
    this.longestRunDistance = 0,
    this.longestRunTime = 0,
    this.maxLifted = 0,
    this.activeBadgeId,
  });

  Map<String, dynamic> toJson() => {
    'name': name, 'personalRecords': personalRecords, 'totalExercises': totalExercises,
    'totalRunExercises': totalRunExercises, 'longestRunDistance': longestRunDistance,
    'longestRunTime': longestRunTime, 'maxLifted': maxLifted, 'activeBadgeId': activeBadgeId,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] ?? 'Athlete',
      personalRecords: Map<String, double>.from((json['personalRecords'] as Map?)?.cast<String, dynamic>().map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {}),
      totalExercises: json['totalExercises'] ?? 0,
      totalRunExercises: json['totalRunExercises'] ?? 0,
      longestRunDistance: (json['longestRunDistance'] as num?)?.toDouble() ?? 0,
      longestRunTime: (json['longestRunTime'] as num?)?.toDouble() ?? 0,
      maxLifted: (json['maxLifted'] as num?)?.toDouble() ?? 0,
      activeBadgeId: json['activeBadgeId'],
    );
  }
}

class ProfileManager {
  static const String _profileKey = 'user_profile';

  static Future<UserProfile> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? profileJson = prefs.getString(_profileKey);
    if (profileJson != null) {
      try { return UserProfile.fromJson(jsonDecode(profileJson)); } catch (e) { debugPrint(e.toString()); }
    }
    return UserProfile();
  }

  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
    await SyncService.exportData(); // Sync to desktop
  }

  static Future<bool> isFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    return !prefs.containsKey(_profileKey);
  }

  static List<Badge> getAllAvailableBadges() {
    return [
      Badge(id: 'under_development', name: 'Under Development', description: 'App is still being built', icon: Icons.construction, color: Colors.orange),
      Badge(id: 'first_exercise', name: 'Getting Started', description: 'Complete your first exercise', icon: Icons.flag, color: Colors.blue),
      Badge(id: 'hundred_exercises', name: 'Century', description: 'Complete 100 exercises', icon: Icons.stars, color: Colors.purple),
      Badge(id: 'iron_lifter', name: 'Iron Lifter', description: 'Lift 150+ kg', icon: Icons.fitness_center, color: Colors.red),
      Badge(id: 'runner', name: 'Distance Runner', description: 'Run 10+ km', icon: Icons.directions_run, color: Colors.green),
    ];
  }

  static List<Badge> awardEarnedBadges(UserProfile profile) {
    List<Badge> earned = [getAllAvailableBadges().firstWhere((b) => b.id == 'under_development')];
    if (profile.totalExercises >= 1) earned.add(getAllAvailableBadges().firstWhere((b) => b.id == 'first_exercise'));
    if (profile.totalExercises >= 100) earned.add(getAllAvailableBadges().firstWhere((b) => b.id == 'hundred_exercises'));
    if (profile.maxLifted >= 150) earned.add(getAllAvailableBadges().firstWhere((b) => b.id == 'iron_lifter'));
    if (profile.longestRunDistance >= 10) earned.add(getAllAvailableBadges().firstWhere((b) => b.id == 'runner'));
    return earned;
  }
}