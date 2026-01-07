import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../app_theme.dart';
import '../data_models.dart';
import 'workout_screens.dart';
import 'futsal_screen.dart';
import 'quick_log_screen.dart';
import 'history_screen.dart';

/// Helper to normalize DateTime to date-only (no time component)
DateTime _normalizeDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

/// Converts a date to storage key format (YYYY-MM-DD)
String _dateToKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Parses storage key back to DateTime
DateTime _keyToDate(String key) {
  final parts = key.split('-');
  if (parts.length == 3) {
    return DateTime(
      int.tryParse(parts[0]) ?? 2020,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[2]) ?? 1,
    );
  }
  // Fallback for ISO format dates
  return _normalizeDate(DateTime.tryParse(key) ?? DateTime.now());
}

class WorkoutCalendarScreen extends StatefulWidget {
  const WorkoutCalendarScreen({super.key});

  @override
  State<WorkoutCalendarScreen> createState() => _WorkoutCalendarScreenState();
}

class _WorkoutCalendarScreenState extends State<WorkoutCalendarScreen>
    with WidgetsBindingObserver {
  Map<DateTime, String> _scheduledWorkouts = {};
  Map<DateTime, List<Map<String, dynamic>>> _loggedWorkouts =
      {}; // Now stores list of workout details
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;
  late DateTime _today; // Cached today for performance

  @override
  void initState() {
    super.initState();
    _today = _normalizeDate(DateTime.now());
    _selectedDay = _today; // Auto-select today when opening
    WidgetsBinding.instance.addObserver(this);
    _initializeCalendar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _today = _normalizeDate(DateTime.now()); // Update today on resume
      _initializeCalendar();
    }
  }

  /// Get workout details for a specific day
  List<Map<String, dynamic>> _getWorkoutsForDay(DateTime day) {
    final normalizedDay = _normalizeDate(day);
    return _loggedWorkouts[normalizedDay] ?? [];
  }

  /// Build inline workout details shown below the Schedule button
  List<Widget> _buildInlineWorkoutDetails(DateTime day) {
    final workouts = _getWorkoutsForDay(day);
    final scheduled = _scheduledWorkouts[_normalizeDate(day)];

    List<Widget> widgets = [];

    // Show scheduled workout if exists
    if (scheduled != null && scheduled.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_note, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scheduled',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            scheduled,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Cancel button
                    IconButton(
                      onPressed: () => _cancelScheduledWorkout(day),
                      icon: const Icon(Icons.close, color: AppColors.error),
                      tooltip: 'Cancel scheduled workout',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Start Workout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _startScheduledWorkout(scheduled),
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text(
                      'Start Workout',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }

    // Show completed workouts if any
    if (workouts.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: workouts
                .map((workout) => _buildWorkoutCard(workout))
                .toList(),
          ),
        ),
      );
    }

    return widgets;
  }

  /// Build workout card based on type (futsal or regular)
  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    final type = workout['type'] as String?;
    final isFutsal = type == 'futsal';

    if (isFutsal) {
      return _buildFutsalCard(workout);
    } else {
      return _buildRegularWorkoutCard(workout);
    }
  }

  /// Build futsal-specific card with stats
  Widget _buildFutsalCard(Map<String, dynamic> workout) {
    final goals = workout['totalGoals'] as int? ?? 0;
    final assists = workout['totalAssists'] as int? ?? 0;
    final points = goals + assists;
    final energy = workout['energy'] as int? ?? 0;
    final moods = workout['mood'] as List<dynamic>? ?? [];

    String energyText = '';
    switch (energy) {
      case 1:
        energyText = '😫 Very Low';
        break;
      case 2:
        energyText = '😔 Low';
        break;
      case 3:
        energyText = '😐 Normal';
        break;
      case 4:
        energyText = '😊 Good';
        break;
      case 5:
        energyText = '🔥 Excellent';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent.withValues(alpha: 0.15), AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sports_soccer,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '⚽ Futsal Session',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.surfaceLight),
          const SizedBox(height: 12),

          // Stats Grid
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.sports_soccer,
                  label: 'Goals',
                  value: '$goals',
                  color: AppColors.primary,
                ),
              ),
              Expanded(
                child: _StatTile(
                  icon: Icons.assistant,
                  label: 'Assists',
                  value: '$assists',
                  color: AppColors.secondary,
                ),
              ),
              Expanded(
                child: _StatTile(
                  icon: Icons.stars,
                  label: 'Points',
                  value: '$points',
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Session Feel
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Session Feel: ',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                Text(
                  energyText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          if (moods.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: moods
                  .map(
                    (m) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        m.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Build regular workout card
  Widget _buildRegularWorkoutCard(Map<String, dynamic> workout) {
    final name = workout['name'] as String? ?? 'Workout';
    final energy = workout['energy'] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.fitness_center,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                if (energy != null)
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (i) => Icon(
                          Icons.bolt,
                          size: 14,
                          color: i < energy
                              ? AppColors.warning
                              : AppColors.textMuted.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Initialize calendar data in a single async operation
  Future<void> _initializeCalendar() async {
    final prefs = await SharedPreferences.getInstance();

    // Clear old logged_workouts to force fresh sync from history
    // This ensures we migrate from old format to new format
    await prefs.remove('logged_workouts');

    // Sync history to calendar (rebuilds logged_workouts fresh)
    await _syncHistoryToCalendar(prefs);

    // Then load all data
    await _loadData(prefs);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Load calendar data from SharedPreferences
  Future<void> _loadData([SharedPreferences? prefsArg]) async {
    final prefs = prefsArg ?? await SharedPreferences.getInstance();
    final scheduled = prefs.getString('scheduled_workouts');
    final logged = prefs.getString('logged_workouts');

    if (!mounted) return;

    Map<DateTime, String> newScheduled = {};
    Map<DateTime, List<Map<String, dynamic>>> newLogged = {};

    if (scheduled != null) {
      try {
        final decoded = jsonDecode(scheduled) as Map<String, dynamic>;
        decoded.forEach((k, v) {
          if (v is String) {
            newScheduled[_keyToDate(k)] = v;
          }
        });
      } catch (e) {
        debugPrint('Error loading scheduled workouts: $e');
      }
    }

    if (logged != null) {
      try {
        final decoded = jsonDecode(logged) as Map<String, dynamic>;
        decoded.forEach((k, v) {
          final date = _keyToDate(k);
          if (v is List) {
            final workoutList = <Map<String, dynamic>>[];
            for (var item in v) {
              if (item is Map) {
                workoutList.add(Map<String, dynamic>.from(item));
              } else if (item is String) {
                // Legacy format: convert string to map
                workoutList.add({'name': item});
              } else {
                workoutList.add({'name': 'Workout'});
              }
            }
            newLogged[date] = workoutList;
          } else if (v is String) {
            // Legacy format: convert 'logged' string to list
            newLogged[date] = [
              {'name': 'Workout'},
            ];
          } else if (v is Map) {
            // Single workout map format
            newLogged[date] = [Map<String, dynamic>.from(v)];
          }
        });
      } catch (e) {
        debugPrint('Error loading logged workouts: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _scheduledWorkouts = newScheduled;
      _loggedWorkouts = newLogged;
    });
  }

  Future<void> _scheduleWorkout(DateTime day) async {
    final normalizedDay = _normalizeDate(day);
    
    // Load user templates + default templates
    final prefs = await SharedPreferences.getInstance();
    List<String> workoutOptions = [];
    
    // Add custom workout types
    workoutOptions.addAll(['🏃 Running', '⚽ Futsal', '🏋️ Quick Exercise']);
    
    // Load user-created templates
    final userTemplatesJson = prefs.getString('user_templates');
    if (userTemplatesJson != null) {
      try {
        final decoded = jsonDecode(userTemplatesJson) as List<dynamic>;
        for (var t in decoded) {
          final template = WorkoutTemplate.fromJson(t);
          workoutOptions.add('💪 ${template.name}');
        }
      } catch (_) {}
    }
    
    if (!mounted) return;
    
    // Show picker dialog
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final dateStr = '${day.day}/${day.month}/${day.year}';
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: AppColors.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Schedule for $dateStr',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: workoutOptions.length,
                    itemBuilder: (context, index) {
                      final option = workoutOptions[index];
                      return ListTile(
                        title: Text(option),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.textMuted,
                        ),
                        onTap: () => Navigator.pop(context, option),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    
    if (selected == null || !mounted) return;
    
    // Save the scheduled workout
    _scheduledWorkouts[normalizedDay] = selected;
    await prefs.setString(
      'scheduled_workouts',
      jsonEncode(_scheduledWorkouts.map((k, v) => MapEntry(_dateToKey(k), v))),
    );
    if (!mounted) return;
    setState(() {});
  }

  /// Cancel a scheduled workout
  Future<void> _cancelScheduledWorkout(DateTime day) async {
    final normalizedDay = _normalizeDate(day);
    final prefs = await SharedPreferences.getInstance();
    
    _scheduledWorkouts.remove(normalizedDay);
    await prefs.setString(
      'scheduled_workouts',
      jsonEncode(_scheduledWorkouts.map((k, v) => MapEntry(_dateToKey(k), v))),
    );
    if (!mounted) return;
    setState(() {});
  }

  /// Start the scheduled workout - navigate to the appropriate screen
  Future<void> _startScheduledWorkout(String scheduledName) async {
    // Parse the workout name to determine type and find matching template
    Widget? screen;
    
    if (scheduledName.startsWith('🏃')) {
      // Running workout
      screen = const SimpleInputScreen(type: 'RUNNING');
    } else if (scheduledName.startsWith('⚽')) {
      // Futsal
      screen = const FutsalLoggerScreen();
    } else if (scheduledName.startsWith('🏋️')) {
      // Quick Exercise
      screen = const QuickLogScreen();
    } else if (scheduledName.startsWith('💪')) {
      // Workout template - find the matching one
      final templateName = scheduledName.substring(2).trim(); // Remove emoji prefix
      
      // Load user templates
      final prefs = await SharedPreferences.getInstance();
      List<WorkoutTemplate> allTemplates = [];
      
      final userTemplatesJson = prefs.getString('user_templates');
      if (userTemplatesJson != null) {
        try {
          final decoded = jsonDecode(userTemplatesJson) as List<dynamic>;
          for (var t in decoded) {
            allTemplates.add(WorkoutTemplate.fromJson(t));
          }
        } catch (_) {}
      }
      
      // Find matching template
      WorkoutTemplate? matchingTemplate;
      for (var template in allTemplates) {
        if (template.name == templateName) {
          matchingTemplate = template;
          break;
        }
      }
      
      if (matchingTemplate != null) {
        screen = WorkoutRunnerScreen(template: matchingTemplate);
      } else {
        // Template not found, show error
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template "$templateName" not found'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    } else {
      // Unknown type, try to find as template name directly
      final prefs = await SharedPreferences.getInstance();
      List<WorkoutTemplate> allTemplates = [];
      
      final userTemplatesJson = prefs.getString('user_templates');
      if (userTemplatesJson != null) {
        try {
          final decoded = jsonDecode(userTemplatesJson) as List<dynamic>;
          for (var t in decoded) {
            allTemplates.add(WorkoutTemplate.fromJson(t));
          }
        } catch (_) {}
      }
      
      WorkoutTemplate? matchingTemplate;
      for (var template in allTemplates) {
        if (scheduledName.contains(template.name)) {
          matchingTemplate = template;
          break;
        }
      }
      
      if (matchingTemplate != null) {
        screen = WorkoutRunnerScreen(template: matchingTemplate);
      } else {
        // Show error instead of menu - the scheduled workout should always be recognizable
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not find workout: $scheduledName'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }
    
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen!),
    );
    
    // Refresh calendar after returning
    if (mounted) {
      _initializeCalendar();
    }
  }

  /// Sync all workout history to the calendar logged workouts
  /// This reads from workout_history and stores full workout details
  Future<void> _syncHistoryToCalendar(SharedPreferences prefs) async {
    final history = prefs.getStringList('workout_history') ?? [];

    // Build fresh map from history with full workout details
    Map<String, List<Map<String, dynamic>>> logged = {};

    // Add all workouts from history with their details
    for (final entry in history) {
      try {
        final data = jsonDecode(entry) as Map<String, dynamic>;
        if (data.containsKey('date')) {
          String dateStr = data['date'] as String;
          // Normalize the date string to YYYY-MM-DD format
          if (dateStr.contains(' ')) {
            dateStr = dateStr.split(' ')[0];
          }
          // Parse and normalize to ensure consistent format
          final parsed = DateTime.tryParse(dateStr);
          String key = parsed != null ? _dateToKey(parsed) : dateStr;

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

          // Add to list for this date
          if (!logged.containsKey(key)) {
            logged[key] = [];
          }
          logged[key]!.add(workoutDetail);
        }
      } catch (_) {}
    }

    await prefs.setString('logged_workouts', jsonEncode(logged));
  }

  Color _getDayColor(DateTime day) {
    final normalizedDay = _normalizeDate(day);
    final isPast = normalizedDay.isBefore(_today);

    final workouts = _loggedWorkouts[normalizedDay];
    if (workouts != null && workouts.isNotEmpty) {
      return AppColors.primary;
    } else if (_scheduledWorkouts.containsKey(normalizedDay) && isPast) {
      return AppColors.error;
    } else if (_scheduledWorkouts.containsKey(normalizedDay)) {
      return AppColors.accent;
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('📅 Workout Calendar')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('📅 Workout Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync with history',
            onPressed: () async {
              setState(() => _isLoading = true);
              await _initializeCalendar();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2100, 12, 31),
                focusedDay: _focusedDay,
                sixWeekMonthsEnforced: false,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  // Don't call setState here - it causes performance issues
                  // Just update the value for when we need it later
                  _focusedDay = focusedDay;
                },
                headerStyle: const HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: AppColors.primary,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: AppColors.primary,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  selectedDecoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  todayTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  weekendTextStyle: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final color = _getDayColor(day);
                    if (color != Colors.transparent) {
                      return Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    return null;
                  },
                ),
              ),
            ),
          ),

          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _LegendItem(color: AppColors.primary, label: "Completed"),
                _LegendItem(color: AppColors.accent, label: "Scheduled"),
                _LegendItem(color: AppColors.error, label: "Missed"),
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (_selectedDay != null) ...[
            // Schedule button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _scheduleWorkout(_selectedDay!),
                    icon: const Icon(Icons.event, color: Colors.white),
                    label: const Text(
                      'Schedule Workout',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.all(14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Show workout details inline if day has workouts
            ..._buildInlineWorkoutDetails(_selectedDay!),
          ],
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

/// Stat tile widget for futsal stats display
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
