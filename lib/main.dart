import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

import 'app_theme.dart';
import 'utils/preferences_cache.dart';
import 'screens/github_setup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Dark icons for light metallic bg
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const HybridAthleteApp());
}

class HybridAthleteApp extends StatefulWidget {
  const HybridAthleteApp({super.key});

  @override
  State<HybridAthleteApp> createState() => _HybridAthleteAppState();
}

class _HybridAthleteAppState extends State<HybridAthleteApp> {
  bool? _firstRun;

  @override
  void initState() {
    super.initState();
    _initFirstRun();
  }

  Future<void> _initFirstRun() async {
    final prefs = await PreferencesCache.getInstance();
    final done = prefs.getBool('first_run_complete') ?? false;
    setState(() { _firstRun = !done; });
  }

  @override
  Widget build(BuildContext context) {
    if (_firstRun == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MaterialApp(
      title: 'Hybrid Athlete',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme, // Metallic Light Theme
      home: _firstRun! ? _OnboardingScreen(onComplete: () async {
        final prefs = await PreferencesCache.getInstance();
        await prefs.setBool('first_run_complete', true);
        if (mounted) setState(() { _firstRun = false; });
      }) : const HomeScreen(),
    );
  }
}

class _OnboardingScreen extends StatelessWidget {
  final VoidCallback onComplete;
  const _OnboardingScreen({required this.onComplete});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome to Hybrid Athlete', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Set up free cloud sync using GitHub Gists or continue with local-only mode.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const GitHubSetupScreen()))
                  .then((_) => onComplete());
              },
              child: const Text('Set up GitHub Sync'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onComplete,
              child: const Text('Continue without Sync'),
            ),
          ],
        ),
      ),
    );
  }
}