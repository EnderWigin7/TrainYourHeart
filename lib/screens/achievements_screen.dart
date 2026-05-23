import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/achievements_service.dart';
import '../theme.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<Achievement> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await AchievementsService().compute();
    items.sort((a, b) {
      if (a.unlocked == b.unlocked) return 0;
      return a.unlocked ? -1 : 1;
    });
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final unlocked = _items.where((a) => a.unlocked).length;
    return Scaffold(
      appBar: AppBar(title: const Text('BADGES')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events,
                      color: AppColors.stravaOrange, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$unlocked / ${_items.length} débloqués',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Continuez à courir pour débloquer les autres.',
                          style: TextStyle(
                            color: AppColors.subtleGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 0.95,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final a in _items) _AchievementCard(achievement: a),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final color = unlocked ? AppColors.stravaOrange : AppColors.subtleGrey;
    return Card(
      color: unlocked
          ? AppColors.stravaOrange.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: unlocked
                        ? const LinearGradient(
                            colors: [
                              AppColors.stravaOrange,
                              Color(0xFFFF7A36),
                            ],
                          )
                        : null,
                    color: unlocked ? null : Colors.white12,
                  ),
                  child: Icon(
                    achievement.icon,
                    color: unlocked
                        ? Colors.white
                        : AppColors.subtleGrey.withValues(alpha: 0.6),
                    size: 32,
                  ),
                ),
                if (!unlocked)
                  const Icon(Icons.lock,
                      size: 16, color: AppColors.subtleGrey),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              achievement.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unlocked ? Colors.white : AppColors.subtleGrey,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              achievement.subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
              ),
            ),
            if (unlocked && achievement.unlockedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('d MMM yyyy', 'fr_FR')
                    .format(achievement.unlockedAt!),
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
