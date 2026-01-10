import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data_models.dart';
import '../app_theme.dart';
import '../utils/sync_service.dart';
import 'profile_screen.dart'; // For ProfileManager
import '../design_system.dart'; // For AppSpacing, etc

class FutsalLoggerScreen extends StatefulWidget {
  const FutsalLoggerScreen({super.key});

  @override
  State<FutsalLoggerScreen> createState() => _FutsalLoggerScreenState();
}

enum FutsalMode { selection, practice, match }

class _FutsalLoggerScreenState extends State<FutsalLoggerScreen> {
  FutsalMode _mode = FutsalMode.selection;

  // PRACTICE STATE
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  String _selectedPracticeType = 'Technical';
  final List<String> _practiceTypes = [
    'Technical',
    'Shooting',
    'Passing',
    'Scrimmage',
    'Gym'
  ];

  // MATCH STATE
  int _goals = 0;
  int _assists = 0;
  int _impact = 0; // -1: Negative, 0: Neutral, 1: Positive

  @override
  Widget build(BuildContext context) {
    String title = "Futsal Logger";
    if (_mode == FutsalMode.practice) title = "Log Practice";
    if (_mode == FutsalMode.match) title = "Log Match";

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_mode == FutsalMode.selection) {
              Navigator.pop(context);
            } else {
              setState(() => _mode = FutsalMode.selection);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingXL,
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_mode) {
      case FutsalMode.selection:
        return _buildSelectionView();
      case FutsalMode.practice:
        return _buildPracticeView();
      case FutsalMode.match:
        return _buildMatchView();
    }
  }

  // --- SELECTION VIEW ---
  Widget _buildSelectionView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectionCard(
          title: "PRACTISE",
          icon: Icons.timer,
          color: AppColors.secondary,
          onTap: () => setState(() => _mode = FutsalMode.practice),
        ),
        AppSpacing.gapVerticalXL,
        _SelectionCard(
          title: "MATCH",
          icon: Icons.sports_soccer,
          color: AppColors.primary,
          onTap: () => setState(() => _mode = FutsalMode.match),
        ),
      ],
    );
  }

  // --- PRACTICE VIEW ---
  Widget _buildPracticeView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Duration Input
          Text("Duration (minutes)", style: Theme.of(context).textTheme.labelLarge),
          AppSpacing.gapVerticalSM,
          TextField(
            controller: _durationController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: "e.g. 90",
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          AppSpacing.gapVerticalLG,

          // Type Dropdown
          Text("Type", style: Theme.of(context).textTheme.labelLarge),
          AppSpacing.gapVerticalSM,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPracticeType,
                isExpanded: true,
                items: _practiceTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPracticeType = val);
                },
              ),
            ),
          ),
          AppSpacing.gapVerticalLG,

          // Details Input
          Text("Details", style: Theme.of(context).textTheme.labelLarge),
          AppSpacing.gapVerticalSM,
          TextField(
            controller: _detailsController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "Drills focus, intensity, teammates...",
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          AppSpacing.gapVerticalXXL,

          // Submit Button
          ElevatedButton(
            onPressed: _savePractice,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              padding: const EdgeInsets.all(16),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text("LOG PRACTICE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _savePractice() async {
    final duration = int.tryParse(_durationController.text) ?? 0;
    if (duration == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid duration")));
      return;
    }

    final session = {
      'date': DateTime.now().toString().split(' ')[0],
      'type': 'practice',
      'practice_type': _selectedPracticeType,
      'duration': duration,
      'details': _detailsController.text,
      'template_name': 'Practice Session', // For compatibility
    };

    await _saveToHistory(session);
    if (mounted) Navigator.pop(context); // Go back to Home
  }

  // --- MATCH VIEW ---
  Widget _buildMatchView() {
    int points = _goals + _assists; // Assuming 1 point per goal/assist
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Points Display
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text("TOTAL POINTS", style: TextStyle(color: Colors.white70, letterSpacing: 1.5)),
                Text("$points", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          AppSpacing.gapVerticalLG,

          // Goals & Assists
          Row(
            children: [
              Expanded(
                child: _CounterCard(
                  label: "Goals",
                  value: _goals,
                  onInc: () => setState(() => _goals++),
                  onDec: () => setState(() => _goals > 0 ? _goals-- : null),
                ),
              ),
              AppSpacing.gapHorizontalMD,
              Expanded(
                child: _CounterCard(
                  label: "Assists",
                  value: _assists,
                  onInc: () => setState(() => _assists++),
                  onDec: () => setState(() => _assists > 0 ? _assists-- : null),
                ),
              ),
            ],
          ),
          AppSpacing.gapVerticalLG,

          // Impact Selector
          Text("Impact", style: Theme.of(context).textTheme.labelLarge),
          AppSpacing.gapVerticalSM,
          Row(
            children: [
              Expanded(
                child: _ImpactButton(
                  label: "-",
                  isSelected: _impact == -1,
                  color: AppColors.error,
                  onTap: () => setState(() => _impact = -1),
                ),
              ),
              AppSpacing.gapHorizontalSM,
              Expanded(
                 child: _ImpactButton(
                  label: "0",
                  isSelected: _impact == 0,
                  color: AppColors.textMuted,
                  onTap: () => setState(() => _impact = 0),
                ),
              ),
               AppSpacing.gapHorizontalSM,
              Expanded(
                 child: _ImpactButton(
                  label: "+",
                  isSelected: _impact == 1,
                  color: AppColors.primary,
                  onTap: () => setState(() => _impact = 1),
                ),
              ),
            ],
          ),
          
          AppSpacing.gapVerticalXXL,

           // Submit Button
          ElevatedButton(
            onPressed: _saveMatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.all(16),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text("LOG MATCH", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMatch() async {
    final session = {
      'date': DateTime.now().toString().split(' ')[0],
      'type': 'futsal', // 'futsal' usually means match context in previous app logic
      'totalGoals': _goals,
      'totalAssists': _assists,
      'points': _goals + _assists,
      'impact': _impact,
      'template_name': 'Futsal Match',
    };

    await _saveToHistory(session);
    if (mounted) Navigator.pop(context);
  }

  // --- HELPERS ---
  Future<void> _saveToHistory(Map<String, dynamic> sessionData) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('workout_history') ?? [];
    
    history.add(jsonEncode(sessionData));
    await prefs.setStringList('workout_history', history);
    
    // Sync if needed
    await SyncService.exportData();

    // Update profile exercises count
    UserProfile profile = await ProfileManager.getProfile();
    profile.totalExercises++;
    await ProfileManager.saveProfile(profile);
  }
}

class _SelectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SelectionCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 150,
          decoration: BoxDecoration(
             color: color.withValues(alpha: 0.15),
             borderRadius: BorderRadius.circular(20),
             border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color, letterSpacing: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onInc;
  final VoidCallback onDec;

  const _CounterCard({required this.label, required this.value, required this.onInc, required this.onDec});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.remove), onPressed: onDec),
              Text("$value", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.add), onPressed: onInc),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ImpactButton({required this.label, required this.isSelected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
