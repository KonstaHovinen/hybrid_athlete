import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'preferences_cache.dart';
import 'device_id.dart';

/// Hybrid Athlete AI System
/// Self-learning AI assistant that evolves with user data and project development
class HybridAthleteAI {
  static const String _aiBaseUrl = 'http://localhost:11434'; // Ollama API
  static const String _aiModel = 'llama3.2'; // Your local model
  static Timer? _learningTimer;
  static Map<String, dynamic> _aiMemory = {};
  static List<Map<String, dynamic>> _interactionHistory = [];
  
  /// Initialize AI system with user data and learning capabilities
  static Future<bool> initialize() async {
    try {
      // Check if Ollama is running
      final response = await http.get(Uri.parse('$_aiBaseUrl/api/tags')).timeout(Duration(seconds: 3));
      if (response.statusCode != 200) return false;
      
      // Load AI memory and interaction history
      await _loadAIMemory();
      await _loadInteractionHistory();
      
      // Start continuous learning process
      _startContinuousLearning();
      
      print('Hybrid Athlete AI initialized successfully');
      return true;
    } catch (e) {
      print('AI initialization failed: $e');
      return false;
    }
  }
  
  /// AI-powered workout analysis and recommendations
  static Future<String?> analyzeWorkout(Map<String, dynamic> workoutData) async {
    try {
      final prompt = _buildWorkoutAnalysisPrompt(workoutData);
      final response = await _callAI(prompt);
      
      if (response != null) {
        // Learn from this interaction
        await _recordInteraction('workout_analysis', workoutData, response);
        return response;
      }
    } catch (e) {
      print('Workout analysis error: $e');
    }
    return null;
  }
  
  /// AI-powered workout planning based on user history and goals
  static Future<String?> generateWorkoutPlan(Map<String, dynamic> userProfile) async {
    try {
      final prompt = _buildWorkoutPlanningPrompt(userProfile);
      final response = await _callAI(prompt);
      
      if (response != null) {
        await _recordInteraction('workout_planning', userProfile, response);
        return response;
      }
    } catch (e) {
      print('Workout planning error: $e');
    }
    return null;
  }
  
  /// Natural language command processing
  static Future<String?> processCommand(String userCommand) async {
    try {
      final prompt = _buildCommandPrompt(userCommand);
      final response = await _callAI(prompt);
      
      if (response != null) {
        await _recordInteraction('command', {'command': userCommand}, response);
        return response;
      }
    } catch (e) {
      print('Command processing error: $e');
    }
    return null;
  }
  
  /// AI-powered insights and recommendations
  static Future<String?> generateInsights() async {
    try {
      final userData = await _getUserData();
      final prompt = _buildInsightsPrompt(userData);
      final response = await _callAI(prompt);
      
      if (response != null) {
        await _recordInteraction('insights', userData, response);
        return response;
      }
    } catch (e) {
      print('Insights generation error: $e');
    }
    return null;
  }
  
  /// Self-learning: Analyze patterns and improve recommendations
  static Future<void> _continuousLearning() async {
    try {
      // Analyze user interaction patterns
      final patterns = await _analyzeInteractionPatterns();
      
      // Update AI memory with new insights
      _aiMemory['last_learning'] = DateTime.now().toIso8601String();
      _aiMemory['patterns_detected'] = patterns;
      
      // Improve response accuracy based on feedback
      await _optimizeResponses();
      
      // Save updated AI memory
      await _saveAIMemory();
      
      print('AI learning cycle completed');
    } catch (e) {
      print('Continuous learning error: $e');
    }
  }
  
  /// Call Ollama AI API
  static Future<String?> _callAI(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('$_aiBaseUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': _aiModel,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': 0.7,
            'top_p': 0.9,
            'max_tokens': 1000,
          }
        }),
      ).timeout(Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['response'] as String?;
      }
    } catch (e) {
      print('AI API call error: $e');
    }
    return null;
  }
  
  /// Build context-aware prompts for different AI tasks
  static String _buildWorkoutAnalysisPrompt(Map<String, dynamic> workoutData) {
    return '''
You are Hybrid Athlete AI, a personal training assistant with access to this user's history and patterns.

User Context:
- Device ID: ${_aiMemory['device_id'] ?? 'Unknown'}
- Training Level: ${_aiMemory['training_level'] ?? 'Intermediate'}
- Goals: ${_aiMemory['user_goals'] ?? 'General fitness'}
- Previous Patterns: ${_aiMemory['patterns_detected'] ?? 'No data yet'}

Current Workout Data:
${jsonEncode(workoutData)}

Analyze this workout and provide:
1. Performance assessment (1-10 scale)
2. Key observations and insights
3. Recommendations for next session
4. Potential adjustments to training plan
5. Risk factors or concerns

Be specific, actionable, and reference their training history when relevant.
''';
  }
  
  static String _buildWorkoutPlanningPrompt(Map<String, dynamic> userProfile) {
    return '''
You are Hybrid Athlete AI, creating personalized workout plans.

User Profile:
${jsonEncode(userProfile)}

AI Memory:
${jsonEncode(_aiMemory)}

Create a detailed workout plan that includes:
1. Weekly structure (days, split, intensity)
2. Specific exercises with sets/reps
3. Progression strategy
4. Recovery recommendations
5. Adaptation based on their patterns

Consider their goals, experience level, and past performance.
''';
  }
  
  static String _buildCommandPrompt(String userCommand) {
    return '''
You are Hybrid Athlete AI, controlling the fitness app through natural language.

User Command: "$userCommand"

Available Actions:
- Start workout [type]
- Log exercise [name] [sets] [reps] [weight]
- Show stats [period]
- Generate workout plan
- Analyze performance
- Set goals [type]
- Schedule workout [date]

Respond with the specific action to take and any parameters needed.
If the command is unclear, ask for clarification.
''';
  }
  
  static String _buildInsightsPrompt(Map<String, dynamic> userData) {
    return '''
You are Hybrid Athlete AI, providing intelligent insights based on user data.

User Data:
${jsonEncode(userData)}

AI Learning History:
${jsonEncode(_aiMemory)}

Provide actionable insights about:
1. Training progress trends
2. Performance patterns
3. Recovery needs
4. Goal achievement status
5. Recommendations for optimization

Be data-driven and personalized.
''';
  }
  
  /// Load AI memory from persistent storage
  static Future<void> _loadAIMemory() async {
    try {
      final prefs = await PreferencesCache.getInstance();
      final memoryJson = prefs.getString('ai_memory');
      if (memoryJson != null) {
        _aiMemory = jsonDecode(memoryJson) as Map<String, dynamic>;
      }
      
      // Initialize basic memory if empty
      if (_aiMemory.isEmpty) {
        _aiMemory = {
          'created_at': DateTime.now().toIso8601String(),
          'device_id': await DeviceId.getDeviceId(),
          'training_level': 'intermediate',
          'user_goals': 'general_fitness',
          'interaction_count': 0,
        };
      }
    } catch (e) {
      print('Error loading AI memory: $e');
    }
  }
  
  /// Save AI memory to persistent storage
  static Future<void> _saveAIMemory() async {
    try {
      final prefs = await PreferencesCache.getInstance();
      await prefs.setString('ai_memory', jsonEncode(_aiMemory));
    } catch (e) {
      print('Error saving AI memory: $e');
    }
  }
  
  /// Load interaction history
  static Future<void> _loadInteractionHistory() async {
    try {
      final prefs = await PreferencesCache.getInstance();
      final historyJson = prefs.getStringList('ai_interaction_history');
      if (historyJson != null) {
        _interactionHistory = historyJson
            .map((json) => jsonDecode(json) as Map<String, dynamic>)
            .toList();
      }
    } catch (e) {
      print('Error loading interaction history: $e');
    }
  }
  
  /// Record AI interactions for learning
  static Future<void> _recordInteraction(String type, Map<String, dynamic> input, String response) async {
    final interaction = {
      'timestamp': DateTime.now().toIso8601String(),
      'type': type,
      'input': input,
      'response': response,
      'user_feedback': null, // To be added later
    };
    
    _interactionHistory.add(interaction);
    
    // Keep only last 100 interactions
    if (_interactionHistory.length > 100) {
      _interactionHistory = _interactionHistory.sublist(_interactionHistory.length - 100);
    }
    
    // Save to persistent storage
    final prefs = await PreferencesCache.getInstance();
    final historyJson = _interactionHistory.map((i) => jsonEncode(i)).toList();
    await prefs.setStringList('ai_interaction_history', historyJson);
    
    // Update memory
    _aiMemory['interaction_count'] = (_aiMemory['interaction_count'] ?? 0) + 1;
    await _saveAIMemory();
  }
  
  /// Get comprehensive user data for AI analysis
  static Future<Map<String, dynamic>> _getUserData() async {
    final prefs = await PreferencesCache.getInstance();
    
    return {
      'workout_history': prefs.getStringList('workout_history') ?? [],
      'user_profile': prefs.getString('user_profile'),
      'weekly_goal': prefs.getInt('weekly_goal'),
      'stats': prefs.getString('cached_stats'),
      'ai_memory': _aiMemory,
      'interaction_history': _interactionHistory.take(10).toList(), // Last 10 interactions
    };
  }
  
  /// Analyze interaction patterns for learning
  static Future<Map<String, dynamic>> _analyzeInteractionPatterns() async {
    final recentInteractions = _interactionHistory.take(20).toList();
    
    // Simple pattern analysis - can be enhanced with ML
    final patterns = <String, dynamic>{};
    
    // Most common interaction types
    final typeCounts = <String, int>{};
    for (final interaction in recentInteractions) {
      final type = interaction['type'] as String;
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
    patterns['most_common_types'] = typeCounts;
    
    // Interaction frequency
    final now = DateTime.now();
    final recentCount = recentInteractions.where((i) {
      final timestamp = DateTime.parse(i['timestamp'] as String);
      return now.difference(timestamp).inDays <= 7;
    }).length;
    patterns['weekly_interactions'] = recentCount;
    
    return patterns;
  }
  
  /// Optimize AI responses based on feedback
  static Future<void> _optimizeResponses() async {
    // This is where you'd implement ML-based response optimization
    // For now, we'll do simple pattern-based adjustments
    
    final feedback = _interactionHistory.where((i) => i['user_feedback'] != null).toList();
    
    if (feedback.isNotEmpty) {
      // Analyze what responses got positive feedback
      final positiveFeedback = feedback.where((i) => i['user_feedback'] == 'positive').toList();
      
      // Update AI memory with optimization insights
      _aiMemory['response_optimizations'] = {
        'total_feedback': feedback.length,
        'positive_feedback': positiveFeedback.length,
        'last_optimization': DateTime.now().toIso8601String(),
      };
    }
  }
  
  /// Start continuous learning timer
  static void _startContinuousLearning() {
    _learningTimer?.cancel();
    _learningTimer = Timer.periodic(Duration(hours: 1), (timer) {
      _continuousLearning();
    });
  }
  
  /// Stop AI system
  static Future<void> shutdown() async {
    _learningTimer?.cancel();
    await _saveAIMemory();
    print('Hybrid Athlete AI shutdown complete');
  }
  
  /// Get AI status and capabilities
  static Map<String, dynamic> getStatus() {
    return {
      'initialized': _aiMemory.isNotEmpty,
      'interaction_count': _aiMemory['interaction_count'] ?? 0,
      'memory_size': _aiMemory.length,
      'history_size': _interactionHistory.length,
      'learning_active': _learningTimer?.isActive ?? false,
      'last_learning': _aiMemory['last_learning'],
    };
  }
}