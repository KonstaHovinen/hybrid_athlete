import 'package:flutter/material.dart';
import 'dart:async';
import '../app_theme.dart';
import '../design_system.dart';
import '../utils/hybrid_athlete_ai.dart';

/// AI Assistant Screen - Interface for Hybrid Athlete AI
class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isAIInitialized = false;
  bool _isProcessing = false;
  final List<Map<String, dynamic>> _conversation = [];
  String? _currentInsight;
  Timer? _insightTimer;
  Map<String, dynamic>? _aiStatus;

  @override
  void initState() {
    super.initState();
    _initializeAI();
    _startInsightGeneration();
  }

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    _insightTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeAI() async {
    final initialized = await HybridAthleteAI.initialize();
    if (mounted) {
      setState(() {
        _isAIInitialized = initialized;
        _aiStatus = HybridAthleteAI.getStatus();
      });
      
      if (initialized) {
        _addMessage('AI', 'Hybrid Athlete AI ready! I can analyze workouts, create plans, and provide personalized insights. How can I help you today?', true);
      } else {
        _addMessage('System', 'AI initialization failed. Make sure Ollama is running on localhost:11434', false);
      }
    }
  }

  void _startInsightGeneration() {
    _insightTimer?.cancel();
    _insightTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (_isAIInitialized && mounted) {
        final insight = await HybridAthleteAI.generateInsights();
        if (insight != null && mounted) {
          setState(() {
            _currentInsight = insight;
          });
        }
      }
    });
  }

  Future<void> _sendCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;

    _addMessage('You', command, false);
    _commandController.clear();
    
    setState(() => _isProcessing = true);

    try {
      final response = await HybridAthleteAI.processCommand(command);
      if (response != null && mounted) {
        _addMessage('AI', response, true);
      }
    } catch (e) {
      if (mounted) {
        _addMessage('System', 'Error processing command: $e', false);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _addMessage(String sender, String message, bool isAI) {
    setState(() {
      _conversation.add({
        'sender': sender,
        'message': message,
        'timestamp': DateTime.now(),
        'isAI': isAI,
      });
    });
    
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _analyzeCurrentWorkout() async {
    setState(() => _isProcessing = true);
    
    try {
      // Mock workout data - in real app, get from current session
      final workoutData = {
        'type': 'strength',
        'exercises': ['Squat', 'Bench Press', 'Deadlift'],
        'duration': 45,
        'volume': 5000,
        'rating': 8,
      };
      
      final analysis = await HybridAthleteAI.analyzeWorkout(workoutData);
      if (analysis != null && mounted) {
        _addMessage('AI Workout Analysis', analysis, true);
      }
    } catch (e) {
      if (mounted) {
        _addMessage('System', 'Workout analysis error: $e', false);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _generateWorkoutPlan() async {
    setState(() => _isProcessing = true);
    
    try {
      // Mock user profile - in real app, get from user data
      final userProfile = {
        'goals': 'strength_gain',
        'experience': 'intermediate',
        'days_per_week': 4,
        'session_duration': 60,
      };
      
      final plan = await HybridAthleteAI.generateWorkoutPlan(userProfile);
      if (plan != null && mounted) {
        _addMessage('AI Workout Plan', plan, true);
      }
    } catch (e) {
      if (mounted) {
        _addMessage('System', 'Workout plan generation error: $e', false);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.psychology, color: AppColors.primary),
            AppSpacing.gapHorizontalSM,
            const Text('AI Assistant'),
            if (_isAIInitialized)
              Container(
                margin: const EdgeInsets.only(left: 8),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        actions: [
          if (_aiStatus != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showAIStatus(),
            ),
        ],
      ),
      body: Column(
        children: [
          // AI Insight Banner
          if (_currentInsight != null)
            Container(
              width: double.infinity,
              padding: AppSpacing.paddingMD,
              margin: AppSpacing.marginHorizontalMD + AppSpacing.marginVerticalSM,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: AppBorderRadius.borderRadiusMD,
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb, color: Colors.white, size: 20),
                  AppSpacing.gapHorizontalSM,
                  Expanded(
                    child: Text(
                      _currentInsight!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 16),
                    onPressed: () => setState(() => _currentInsight = null),
                  ),
                ],
              ),
            ),

          // Conversation Area
          Expanded(
            child: Container(
              margin: AppSpacing.marginHorizontalMD,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: AppBorderRadius.borderRadiusLG,
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: _conversation.isEmpty
                  ? _buildEmptyState()
                  : _buildConversation(),
            ),
          ),

          // Quick Actions
          if (_isAIInitialized)
            Container(
              margin: AppSpacing.marginMD,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.analytics),
                      label: const Text('Analyze Workout'),
                      onPressed: _isProcessing ? null : _analyzeCurrentWorkout,
                    ),
                  ),
                  AppSpacing.gapHorizontalMD,
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Generate Plan'),
                      onPressed: _isProcessing ? null : _generateWorkoutPlan,
                    ),
                  ),
                ],
              ),
            ),

          // Command Input
          Container(
            margin: AppSpacing.marginMD,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: AppBorderRadius.borderRadiusLG,
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    enabled: _isAIInitialized && !_isProcessing,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: _isAIInitialized 
                          ? 'Ask AI anything about your training...' 
                          : 'Initializing AI...',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      border: InputBorder.none,
                      contentPadding: AppSpacing.paddingLG,
                    ),
                    onSubmitted: (_) => _sendCommand(),
                  ),
                ),
                if (_isProcessing)
                  Container(
                    padding: AppSpacing.paddingLG,
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _isAIInitialized ? _sendCommand : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.psychology,
            size: 64,
            color: AppColors.textMuted,
          ),
          AppSpacing.gapVerticalMD,
          Text(
            _isAIInitialized 
                ? 'Start a conversation with your AI assistant'
                : 'Initializing AI...',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          if (_isAIInitialized) ...[
            AppSpacing.gapVerticalSM,
            Text(
              'Try: "Analyze my last workout" or "Create a strength plan"',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConversation() {
    return ListView.builder(
      controller: _scrollController,
      padding: AppSpacing.paddingLG,
      itemCount: _conversation.length,
      itemBuilder: (context, index) {
        final message = _conversation[index];
        final isAI = message['isAI'] as bool;
        
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAI ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message['sender'] as String,
                      style: TextStyle(
                        color: isAI ? Colors.white : AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  AppSpacing.gapHorizontalSM,
                  Text(
                    _formatTime(message['timestamp'] as DateTime),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapVerticalXS,
              Container(
                width: double.infinity,
                padding: AppSpacing.paddingMD,
                decoration: BoxDecoration(
                  color: isAI ? AppColors.surface : Colors.transparent,
                  borderRadius: AppBorderRadius.borderRadiusMD,
                ),
                child: Text(
                  message['message'] as String,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showAIStatus() {
    if (_aiStatus == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('AI Status', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusItem('Initialized', _aiStatus!['initialized']?.toString() ?? 'false'),
            _buildStatusItem('Interactions', _aiStatus!['interaction_count']?.toString() ?? '0'),
            _buildStatusItem('Memory Size', '${_aiStatus!['memory_size'] ?? 0} items'),
            _buildStatusItem('History Size', '${_aiStatus!['history_size'] ?? 0} items'),
            _buildStatusItem('Learning Active', _aiStatus!['learning_active']?.toString() ?? 'false'),
            if (_aiStatus!['last_learning'] != null)
              _buildStatusItem('Last Learning', _formatLearningTime(_aiStatus!['last_learning'])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLearningTime(String? timestamp) {
    if (timestamp == null) return 'Never';
    try {
      final time = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(time);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    } catch (e) {
      return 'Unknown';
    }
  }
}