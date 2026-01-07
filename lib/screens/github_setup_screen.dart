import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../design_system.dart';
import '../utils/github_gist_sync.dart';
import '../utils/preferences_cache.dart';

/// GitHub Token Setup Screen
class GitHubSetupScreen extends StatefulWidget {
  const GitHubSetupScreen({super.key});

  @override
  State<GitHubSetupScreen> createState() => _GitHubSetupScreenState();
}

class _GitHubSetupScreenState extends State<GitHubSetupScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = false;
  bool _tokenValid = false;
  String? _errorMessage;
  
  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _validateAndSaveToken() async {
    final token = _tokenController.text.trim();
    
    if (token.isEmpty) {
      setState(() => _errorMessage = 'Please enter a GitHub token');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final success = await GitHubGistSync.setupToken(token);
      
      if (mounted) {
        setState(() {
          _tokenValid = success;
          _isLoading = false;
          _errorMessage = success ? null : 'Invalid GitHub token';
        });
        
        if (success) {
          _showSuccessMessage();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _showSuccessMessage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('✅ Success!', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'GitHub token validated! Your data will now sync to your private GitHub Gist.',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GitHub Sync Setup'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingXL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions Card
            Container(
              width: double.infinity,
              padding: AppSpacing.paddingLG,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: AppBorderRadius.borderRadiusLG,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_upload, color: Colors.white, size: 28),
                      AppSpacing.gapHorizontalMD,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Free Cloud Sync with GitHub',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            AppSpacing.gapVerticalXS,
                            Text(
                              'Use GitHub Gists to sync your workout data across all devices',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            AppSpacing.gapVerticalXL,
            
            // Steps to create token
            Container(
              width: double.infinity,
              padding: AppSpacing.paddingLG,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: AppBorderRadius.borderRadiusLG,
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to get your GitHub token:',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.gapVerticalMD,
                  _buildStep('1', 'Go to github.com and log in'),
                  _buildStep('2', 'Click your profile → Settings'),
                  _buildStep('3', 'Scroll to "Developer settings"'),
                  _buildStep('4', 'Click "Personal access tokens" → "Tokens (classic)"'),
                  _buildStep('5', 'Click "Generate new token"'),
                  _buildStep('6', 'Give it a name like "Hybrid Athlete"'),
                  _buildStep('7', 'Select "gist" scope'),
                  _buildStep('8', 'Copy the generated token'),
                  _buildStep('9', 'Paste it below'),
                ],
              ),
            ),
            
            AppSpacing.gapVerticalXL,
            
            // Token Input
            Container(
              width: double.infinity,
              padding: AppSpacing.paddingLG,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: AppBorderRadius.borderRadiusLG,
                border: Border.all(
                  color: _errorMessage != null 
                      ? AppColors.error 
                      : (_tokenValid ? AppColors.primary : AppColors.surfaceLight),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GitHub Personal Access Token',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.gapVerticalMD,
                  TextField(
                    controller: _tokenController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'ghp_...',
                      prefixIcon: Icon(Icons.lock),
                      suffixIcon: _tokenValid
                          ? Icon(Icons.check_circle, color: AppColors.primary)
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: AppBorderRadius.borderRadiusMD,
                      ),
                      errorText: _errorMessage,
                    ),
                    onChanged: (value) {
                      if (_errorMessage != null) {
                        setState(() => _errorMessage = null);
                      }
                    },
                  ),
                  
                  if (_tokenValid) ...[
                    AppSpacing.gapVerticalMD,
                    Container(
                      padding: AppSpacing.paddingMD,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: AppBorderRadius.borderRadiusMD,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                          AppSpacing.gapHorizontalSM,
                          Expanded(
                            child: Text(
                              'Token validated! Ready to sync your data.',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
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
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _validateAndSaveToken,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppBorderRadius.borderRadiusMD,
                      ),
                    ),
                    child: _isLoading
                        ? Row(
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
                              Text('Validating...', style: TextStyle(color: Colors.white)),
                            ],
                          )
                        : Text(
                            'Validate & Save Token',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            
            AppSpacing.gapVerticalMD,
            
            // Skip option
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Skip for now (use local sync only)',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          AppSpacing.gapHorizontalMD,
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}