import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../design_system.dart';
import '../utils/preferences_cache.dart';
import '../utils/hybrid_athlete_ai.dart';

/// AI Chat Login Screen
class AIChatLoginScreen extends StatefulWidget {
  const AIChatLoginScreen({super.key});

  @override
  State<AIChatLoginScreen> createState() => _AIChatLoginScreenState();
}

class _AIChatLoginScreenState extends State<AIChatLoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isGuestMode = false;
  bool _isLoading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isGuestMode) {
      // Guest mode - no password required
    } else {
      // Account mode - validate name and password
      if (_nameController.text.trim().isEmpty) {
        _showError('Please enter your name');
        return;
      }
      if (_passwordController.text.trim().isEmpty) {
        _showError('Please enter password');
        return;
      }
      if (_passwordController.text != 'AIGYM') {
        _showError('Incorrect password');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await PreferencesCache.getInstance();
      
      if (_isGuestMode) {
        // Guest mode: clear all data on close
        await prefs.setBool('guest_mode', true);
        await prefs.setString('guest_name', 'Guest User');
        await HybridAthleteAI.initialize(); // Fresh AI instance for guest
      } else {
        // Account mode: persistent data
        await prefs.setBool('guest_mode', false);
        await prefs.setString('account_name', _nameController.text.trim());
        await HybridAthleteAI.initialize(); // AI with personal memory
      }
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/ai_chat');
      }
    } catch (e) {
      if (mounted) {
        _showError('Login failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingXL,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // AI Logo/Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              
              AppSpacing.gapVerticalXL,
              
              // Title
              Text(
                'Hybrid Athlete AI',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              
              AppSpacing.gapVerticalSM,
              
              Text(
                'Your personal training assistant',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              
              AppSpacing.gapVerticalXXL,
              
              // Mode Selection
              Container(
                padding: AppSpacing.paddingLG,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: AppBorderRadius.borderRadiusLG,
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isGuestMode = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_isGuestMode ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                                borderRadius: AppBorderRadius.borderRadiusMD,
                                border: Border.all(
                                  color: !_isGuestMode ? AppColors.primary : AppColors.surfaceLight,
                                  width: !_isGuestMode ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                'Account Mode',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: !_isGuestMode ? AppColors.primary : AppColors.textMuted,
                                  fontWeight: !_isGuestMode ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                        AppSpacing.gapHorizontalMD,
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isGuestMode = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isGuestMode ? AppColors.accent.withValues(alpha: 0.1) : Colors.transparent,
                                borderRadius: AppBorderRadius.borderRadiusMD,
                                border: Border.all(
                                  color: _isGuestMode ? AppColors.accent : AppColors.surfaceLight,
                                  width: _isGuestMode ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                'Guest Mode',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _isGuestMode ? AppColors.accent : AppColors.textMuted,
                                  fontWeight: _isGuestMode ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    if (!_isGuestMode) ...[
                      AppSpacing.gapVerticalMD,
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Enter your name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: AppBorderRadius.borderRadiusMD,
                          ),
                        ),
                      ),
                      AppSpacing.gapVerticalMD,
                      TextField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          hintText: 'Enter password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                          border: const OutlineInputBorder(
                            borderRadius: AppBorderRadius.borderRadiusMD,
                          ),
                        ),
                      ),
                    ],
                    
                    if (_isGuestMode) ...[
                      AppSpacing.gapVerticalMD,
                      Container(
                        padding: AppSpacing.paddingMD,
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppBorderRadius.borderRadiusMD,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                            AppSpacing.gapHorizontalSM,
                            Expanded(
                              child: Text(
                                'Guest mode: Data is temporary and will be cleared when you close the app. Perfect for testing and trying out features.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              AppSpacing.gapVerticalXL,
              
              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isGuestMode ? AppColors.accent : AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppBorderRadius.borderRadiusMD,
                    ),
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            AppSpacing.gapHorizontalSM,
                            Text('Connecting...', style: TextStyle(color: Colors.white)),
                          ],
                        )
                      : Text(
                          _isGuestMode ? 'Continue as Guest' : 'Login',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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

/// Enhanced AI Assistant Screen with Login Integration
class EnhancedAIAssistantScreen extends StatefulWidget {
  const EnhancedAIAssistantScreen({super.key});

  @override
  State<EnhancedAIAssistantScreen> createState() => _EnhancedAIAssistantScreenState();
}

class _EnhancedAIAssistantScreenState extends State<EnhancedAIAssistantScreen> {
  String _userName = 'User';
  bool _isGuestMode = false;
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserMode();
  }

  Future<void> _loadUserMode() async {
    final prefs = await PreferencesCache.getInstance();
    final guestMode = prefs.getBool('guest_mode') ?? false;
    final userName = guestMode 
        ? (prefs.getString('guest_name') ?? 'Guest')
        : (prefs.getString('account_name') ?? 'User');
    
    if (mounted) {
      setState(() {
        _isGuestMode = guestMode;
        _userName = userName;
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await PreferencesCache.getInstance();
    
    if (_isGuestMode) {
      // Clear all guest data
      await prefs.clear();
      await HybridAthleteAI.shutdown();
    } else {
      // Just logout, keep data
      await prefs.remove('account_name');
    }
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AIChatLoginScreen()),
      );
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
            if (_isGuestMode)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'GUEST',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 16),
                    AppSpacing.gapHorizontalSM,
                    Text(_isGuestMode ? 'Clear Data & Exit' : 'Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // User Info Header
          Container(
            width: double.infinity,
            padding: AppSpacing.paddingLG,
            margin: AppSpacing.marginHorizontalMD + AppSpacing.marginVerticalSM,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: AppBorderRadius.borderRadiusLG,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Icon(
                    _isGuestMode ? Icons.person_outline : Icons.person,
                    color: Colors.white,
                  ),
                ),
                AppSpacing.gapHorizontalMD,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $_userName!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _isGuestMode 
                            ? 'Temporary session - data cleared on exit'
                            : 'Personal AI with persistent memory',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // AI Chat Interface (placeholder for now)
          Expanded(
            child: Container(
              margin: AppSpacing.marginMD,
              padding: AppSpacing.paddingLG,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: AppBorderRadius.borderRadiusLG,
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.psychology,
                    size: 64,
                    color: AppColors.primary,
                  ),
                  AppSpacing.gapVerticalMD,
                  Text(
                    'AI Chat Interface',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  AppSpacing.gapVerticalSM,
                  Text(
                    _isGuestMode 
                        ? 'Guest mode ready - Start a conversation with the AI assistant!'
                        : 'Personal AI ready - I remember our conversations!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapVerticalXL,
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.chat),
                          label: const Text('Start Chat'),
onPressed: () {
                            // Navigate to actual AI chat (will be imported properly)
                            _showError('AI Chat interface coming soon!');
                          },
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
    );
  }
}