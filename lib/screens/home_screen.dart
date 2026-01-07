import 'package:flutter/material.dart' hide Badge;
import 'package:intl/intl.dart';
import '../data_models.dart';
import '../app_theme.dart';
import '../design_system.dart';
import 'profile_screen.dart';
import 'workout_screens.dart';
import 'history_screen.dart';
import 'workout_calendar_screen.dart';
import 'stats_screen.dart';
import 'quick_log_screen.dart';
import 'futsal_screen.dart';
import 'ai_assistant_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  UserProfile? _userProfile;
  late AnimationController _badgeAnimController;
  late Animation<double> _badgePulse;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _badgeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _badgePulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _badgeAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _badgeAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    UserProfile profile = await ProfileManager.getProfile();
    if (!mounted) return;
    setState(() => _userProfile = profile);
  }

  void _handleButtonPress(String activity) async {
    Widget? screen;
    switch (activity) {
      case "WORKOUT":
        screen = const TemplateSelectionScreen();
        break;
      case "HISTORY":
        screen = const WorkoutHistoryScreen();
        break;
      case "GOALS":
        screen = const EditGoalsScreen();
        break;
      case "CALENDAR":
        screen = const WorkoutCalendarScreen();
        break;
      case "STATS":
        screen = const WeeklyStatsScreen();
        break;
      case "FUTSAL":
        screen = const FutsalLoggerScreen();
        break;
      case "AI":
        screen = const AIAssistantScreen();
        break;
      default:
        screen = SimpleInputScreen(type: activity);
    }
    await Navigator.push(context, MaterialPageRoute(builder: (context) => screen!));
    if (mounted) _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    String dateDisplay = DateFormat('EEEE, MMM d').format(DateTime.now());
    String greeting = _getGreeting();

    Badge? activeBadge;
    if (_userProfile?.activeBadgeId != null) {
      try {
        activeBadge = ProfileManager.getAllAvailableBadges()
            .firstWhere((b) => b.id == _userProfile!.activeBadgeId);
      } catch (e) {}
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(dateDisplay, greeting, activeBadge),
            ),
            SliverToBoxAdapter(
              child: _buildBadgeSection(activeBadge),
            ),
            SliverToBoxAdapter(
              child: _buildQuickActions(),
            ),
            SliverToBoxAdapter(
              child: _buildMainMenu(),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader(String date, String greeting, Badge? activeBadge) {
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.sm),
      child: Row(
        // FIXED: Syntax error corrected here
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.5,
                ),
              ),
              AppSpacing.gapVerticalXS,
              Text(
                "$greeting, ${_userProfile?.name ?? 'Athlete'}",
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ],
          ),
          Row(children: [
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings, color: AppColors.textMuted),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
            GestureDetector(
              onTap: () {
                if (_userProfile != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfileScreen(profile: _userProfile!)),
                  ).then((_) {
                     if (mounted) _loadProfile();
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.surface,
                  child: activeBadge != null
                      ? Icon(activeBadge.icon, color: activeBadge.color, size: 24)
                      : const Icon(Icons.person, color: AppColors.textMuted, size: 24),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildBadgeSection(Badge? activeBadge) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
      padding: AppSpacing.paddingXXL,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            activeBadge != null
                ? activeBadge.color.withValues(alpha: 0.1)
                : AppColors.surfaceLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppBorderRadius.borderRadiusXXL,
        border: Border.all(
          color: activeBadge?.color.withValues(alpha: 0.3) ?? AppColors.surfaceLight,
          width: 1,
        ),
      ),
      child: activeBadge != null
          ? Row(
              children: [
                ScaleTransition(
                  scale: _badgePulse,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: activeBadge.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: activeBadge.color.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(activeBadge.icon, size: 40, color: activeBadge.color),
                  ),
                ),
                AppSpacing.gapHorizontalXL,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ACTIVE BADGE",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.5,
                        ),
                      ),
                      AppSpacing.gapVerticalXS,
                      Text(
                        activeBadge.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      AppSpacing.gapVerticalXS,
                      Text(
                        activeBadge.description,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events_outlined, size: 40, color: AppColors.textMuted),
                ),
                AppSpacing.gapHorizontalXL,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "NO BADGE SELECTED",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.5,
                        ),
                      ),
                      AppSpacing.gapVerticalXS,
                      Text(
                        "Earn badges by working out!",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: AppSpacing.screenPaddingHorizontal,
      child: Row(
        children: [
          Expanded(
            child: _QuickActionChip(
              icon: Icons.play_arrow_rounded,
              label: "Start Workout",
              color: AppColors.primary,
              onTap: () => _handleButtonPress("WORKOUT"),
            ),
          ),
          AppSpacing.gapHorizontalMD,
          Expanded(
            child: _QuickActionChip(
              icon: Icons.sports_soccer,
              label: "Log Futsal",
              color: AppColors.accent,
              onTap: () => _handleButtonPress("FUTSAL"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainMenu() {
    return Padding(
      padding: AppSpacing.paddingXL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: "Dashboard", icon: Icons.dashboard_rounded),
          AppSpacing.gapVerticalMD,
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.3,
            children: [
              _MenuCard(
                icon: Icons.calendar_month_rounded,
                label: "Calendar",
                sublabel: "Track your days",
                color: AppColors.secondary,
                onTap: () => _handleButtonPress("CALENDAR"),
              ),
              _MenuCard(
                icon: Icons.bar_chart_rounded,
                label: "Statistics",
                sublabel: "View progress",
                color: AppColors.primary,
                onTap: () => _handleButtonPress("STATS"),
              ),
              _MenuCard(
                icon: Icons.history_rounded,
                label: "History",
                sublabel: "Past workouts",
                color: AppColors.accent,
                onTap: () => _handleButtonPress("HISTORY"),
              ),
              _MenuCard(
                icon: Icons.emoji_events_rounded,
                label: "Goals",
                sublabel: "Pro targets",
                color: AppColors.warning,
                onTap: () => _handleButtonPress("GOALS"),
              ),
              _MenuCard(
                icon: Icons.psychology_rounded,
                label: "AI Coach",
                sublabel: "Smart insights",
                color: AppColors.primary,
                onTap: () => _handleButtonPress("AI"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const QuickLogScreen()))
              .then((_) {
                 if(mounted) _loadProfile();
              });
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: const Text(
          "Quick Log",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppBorderRadius.borderRadiusLG,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: AppBorderRadius.borderRadiusLG,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              AppSpacing.gapHorizontalSM,
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppBorderRadius.borderRadiusXL,
        child: Container(
          padding: AppSpacing.paddingLG,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppBorderRadius.borderRadiusXL,
            border: Border.all(color: AppColors.surfaceLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: AppBorderRadius.borderRadiusMD,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    sublabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}