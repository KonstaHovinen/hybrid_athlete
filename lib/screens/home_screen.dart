import 'package:flutter/material.dart' hide Badge;
import 'package:intl/intl.dart';
import '../data_models.dart';
import '../app_theme.dart';
import 'profile_screen.dart';
import 'workout_screens.dart';
import 'history_screen.dart';
import 'workout_calendar_screen.dart';
import 'stats_screen.dart';
import 'quick_log_screen.dart';
import 'futsal_screen.dart';

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
      default:
        screen = SimpleInputScreen(type: activity);
    }
    await Navigator.push(context, MaterialPageRoute(builder: (context) => screen!));
    _loadProfile();
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
            // Custom App Bar
            SliverToBoxAdapter(
              child: _buildHeader(dateDisplay, greeting, activeBadge),
            ),
            
            // Active Badge Display
            SliverToBoxAdapter(
              child: _buildBadgeSection(activeBadge),
            ),
            
            // Quick Actions
            SliverToBoxAdapter(
              child: _buildQuickActions(),
            ),
            
            // Main Menu Grid
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "$greeting, ${_userProfile?.name ?? 'Athlete'}",
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              if (_userProfile != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen(profile: _userProfile!)),
                ).then((_) => _loadProfile());
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
        ],
      ),
    );
  }

  Widget _buildBadgeSection(Badge? activeBadge) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            activeBadge != null
                ? activeBadge.color.withOpacity(0.1)
                : AppColors.surfaceLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: activeBadge?.color.withOpacity(0.3) ?? AppColors.surfaceLight,
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
                      color: activeBadge.color.withOpacity(0.15),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: activeBadge.color.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(activeBadge.icon, size: 40, color: activeBadge.color),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "ACTIVE BADGE",
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activeBadge.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activeBadge.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
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
                const SizedBox(width: 20),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "NO BADGE SELECTED",
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Earn badges by working out!",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
          const SizedBox(width: 12),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: "Dashboard", icon: Icons.dashboard_rounded),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
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
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const QuickLogScreen()))
              .then((_) => _loadProfile());
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.surfaceLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
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
