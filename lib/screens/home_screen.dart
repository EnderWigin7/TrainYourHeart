import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../services/units_service.dart';
import '../theme.dart';
import '../widgets/animated_number.dart';
import 'run_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  UserProfile _profile = UserProfile.empty;
  double _todayKm = 0;
  Stats _stats = Stats.empty;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    StorageService.runsChanged.addListener(_refresh);
    UnitsService.instance.addListener(_onUnitsChanged);
  }

  @override
  void dispose() {
    StorageService.runsChanged.removeListener(_refresh);
    UnitsService.instance.removeListener(_onUnitsChanged);
    super.dispose();
  }

  void _onUnitsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    final p = await _storage.loadProfile();
    final profile = p ?? UserProfile.empty;
    final km = await _storage.todaysDistanceKm();
    final stats = await _storage.loadStats(profile.dailyGoalKm);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _todayKm = km;
      _stats = stats;
      _loading = false;
    });
  }

  Future<void> _startRun() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RunScreen(weightKg: _profile.weightKg),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final units = UnitsService.instance;
    final goal = _profile.dailyGoalKm;
    final progress = goal <= 0 ? 0.0 : (_todayKm / goal).clamp(0.0, 1.0);
    final completed = _todayKm >= goal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TRAIN YOUR HEART'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).padding.bottom +
                kBottomNavigationBarHeight +
                32,
          ),
          children: [
            Text(
              'Bonjour${_profile.username.isNotEmpty ? ', ${_profile.username}' : ''}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Prêt pour aujourd\'hui ?',
              style: TextStyle(color: AppColors.subtleGrey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            _GoalCard(
              goalKm: goal,
              todayKm: _todayKm,
              progress: progress,
              completed: completed,
              units: units,
            ),
            const SizedBox(height: 16),
            _SummaryTiles(stats: _stats, profile: _profile),
            const SizedBox(height: 16),
            _PersonalBestsCard(stats: _stats),
            const SizedBox(height: 24),
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _startRun,
                icon: const Icon(Icons.play_arrow, size: 32),
                label: const Text('COMMENCER UNE COURSE'),
              ),
            ),
            const SizedBox(height: 24),
            const _MotivationCard(),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final double goalKm;
  final double todayKm;
  final double progress;
  final bool completed;
  final UnitsService units;
  const _GoalCard({
    required this.goalKm,
    required this.todayKm,
    required this.progress,
    required this.completed,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  completed ? Icons.check_circle : Icons.flag,
                  color: AppColors.stravaOrange,
                ),
                const SizedBox(width: 8),
                const Text(
                  'OBJECTIF DU JOUR',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AnimatedNumber(
                  value: units.distance(todayKm),
                  formatter: (v) => v.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  ' / ${units.distance(goalKm).toStringAsFixed(1)} ${units.distanceUnit()}',
                  style: const TextStyle(
                    fontSize: 20,
                    color: AppColors.subtleGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.stravaOrange),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              completed
                  ? 'Objectif atteint ! Excellent travail.'
                  : '${units.distance(goalKm - todayKm).toStringAsFixed(2)} ${units.distanceUnit()} restants',
              style: TextStyle(
                color: completed
                    ? AppColors.stravaOrange
                    : AppColors.subtleGrey,
                fontWeight:
                    completed ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTiles extends StatelessWidget {
  final Stats stats;
  final UserProfile profile;
  const _SummaryTiles({required this.stats, required this.profile});

  @override
  Widget build(BuildContext context) {
    final units = UnitsService.instance;
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            icon: Icons.local_fire_department,
            label: 'SÉRIE',
            value: stats.streakDays.toDouble(),
            format: (v) => v.toInt().toString(),
            unit: stats.streakDays == 1 ? 'jour' : 'jours',
            goal: 0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            icon: Icons.calendar_view_week,
            label: 'SEMAINE',
            value: units.distance(stats.weekKm),
            format: (v) => v.toStringAsFixed(1),
            unit: units.distanceUnit(),
            goal: units.distance(profile.weeklyGoalKm),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            icon: Icons.calendar_month,
            label: 'MOIS',
            value: units.distance(stats.monthKm),
            format: (v) => v.toStringAsFixed(1),
            unit: units.distanceUnit(),
            goal: units.distance(profile.monthlyGoalKm),
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final String Function(double) format;
  final String unit;
  final double goal;
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.format,
    required this.unit,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.stravaOrange, size: 18),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.subtleGrey,
                letterSpacing: 1.2,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: AnimatedNumber(
                    value: value,
                    formatter: format,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: const TextStyle(
                    color: AppColors.subtleGrey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            if (goal > 0) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (value / goal).clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.stravaOrange),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '/ ${goal.toStringAsFixed(0)} $unit',
                style: const TextStyle(
                  color: AppColors.subtleGrey,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PersonalBestsCard extends StatelessWidget {
  final Stats stats;
  const _PersonalBestsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final empty = stats.longestRunKm == 0 &&
        stats.fastestSpeedKmh == 0 &&
        stats.mostCalories == 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.emoji_events, color: AppColors.stravaOrange),
                SizedBox(width: 8),
                Text(
                  'RECORDS PERSONNELS',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (empty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Aucun record pour l\'instant. Lancez votre première course !',
                  style:
                      TextStyle(color: AppColors.subtleGrey, fontSize: 13),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _BestStat(
                    label: 'Distance',
                    value: UnitsService.instance.distance(stats.longestRunKm),
                    format: (v) =>
                        '${v.toStringAsFixed(2)} ${UnitsService.instance.distanceUnit()}',
                  ),
                  _BestStat(
                    label: 'Vitesse',
                    value: UnitsService.instance.speed(stats.fastestSpeedKmh),
                    format: (v) =>
                        '${v.toStringAsFixed(1)} ${UnitsService.instance.speedUnit()}',
                  ),
                  _BestStat(
                    label: 'Kcal',
                    value: stats.mostCalories,
                    format: (v) => v.toStringAsFixed(0),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _BestStat extends StatelessWidget {
  final String label;
  final double value;
  final String Function(double) format;
  const _BestStat({
    required this.label,
    required this.value,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.subtleGrey,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedNumber(
          value: value,
          formatter: format,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _MotivationCard extends StatelessWidget {
  const _MotivationCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.bolt, color: AppColors.stravaOrange, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Un pas à la fois',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Chaque course compte. Reste concentré sur ton objectif.',
                    style: TextStyle(
                      color: AppColors.subtleGrey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
