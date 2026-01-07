import 'package:flutter/material.dart';
import 'dart:async';
import '../app_theme.dart';
import '../design_system.dart';
import '../utils/hybrid_athlete_ai.dart';

/// AI Status Widget for Desktop Command Center
class AIStatusWidget extends StatefulWidget {
  const AIStatusWidget({super.key});

  @override
  State<AIStatusWidget> createState() => _AIStatusWidgetState();
}

class _AIStatusWidgetState extends State<AIStatusWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Map<String, dynamic>? _aiStatus;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _updateAIStatus();
    _startStatusUpdates();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startStatusUpdates() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _updateAIStatus();
    });
  }

  void _updateAIStatus() async {
    try {
      final status = HybridAthleteAI.getStatus();
      if (mounted) {
        setState(() {
          _aiStatus = status;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiStatus = {
            'initialized': false,
            'error': e.toString(),
          };
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInitialized = _aiStatus?['initialized'] ?? false;
    final hasError = _aiStatus?['error'] != null;
    final interactionCount = _aiStatus?['interaction_count'] ?? 0;
    final learningActive = _aiStatus?['learning_active'] ?? false;

    return Container(
      padding: AppSpacing.paddingLG,
      decoration: BoxDecoration(
        gradient: isInitialized ? AppColors.primaryGradient : null,
        color: isInitialized ? null : AppColors.surface,
        borderRadius: AppBorderRadius.borderRadiusLG,
        border: Border.all(
          color: isInitialized ? AppColors.primary : AppColors.surfaceLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: isInitialized ? _pulseAnimation : AlwaysStoppedAnimation(1.0),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isInitialized 
                        ? Colors.white.withOpacity(0.2) 
                        : AppColors.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasError ? Icons.error : Icons.psychology,
                    color: isInitialized ? Colors.white : AppColors.textMuted,
                    size: 24,
                  ),
                ),
              ),
              AppSpacing.gapHorizontalMD,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Assistant',
                      style: TextStyle(
                        color: isInitialized ? Colors.white : AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      hasError 
                          ? 'Connection Error'
                          : isInitialized 
                              ? 'Learning & Analyzing'
                              : 'Offline',
                      style: TextStyle(
                        color: isInitialized ? Colors.white70 : AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isInitialized && !hasError)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: learningActive 
                        ? Colors.green.withOpacity(0.3) 
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: learningActive ? Colors.green : Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        learningActive ? 'Learning' : 'Idle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (isInitialized && !hasError) ...[
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Interactions',
                    '$interactionCount',
                    isInitialized,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Memory',
                    '${_aiStatus?['memory_size'] ?? 0}',
                    isInitialized,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, bool isActive) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.1) : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: isActive ? Colors.white : AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white70 : AppColors.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}