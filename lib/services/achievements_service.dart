import 'package:flutter/material.dart';
import 'firestore_service.dart';

enum AchievementKind {
  firstRun,
  fiveKmClub,
  tenKmClub,
  halfMarathon,
  marathon,
  tenRuns,
  fiftyRuns,
  hundredKm,
  fiveHundredKm,
  streak7,
  streak30,
}

class Achievement {
  final AchievementKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.unlocked,
    this.unlockedAt,
  });
}

class AchievementsService {
  final _firestore = FirestoreService();

  Future<List<Achievement>> compute() async {
    final runs = await _firestore.loadRuns();
    final sorted = [...runs]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    DateTime? firstRunDistanceAtLeast(double km) {
      for (final r in sorted) {
        if (r.distanceKm >= km) return r.startTime;
      }
      return null;
    }

    DateTime? unlockedAtAfterNRuns(int n) {
      if (sorted.length < n) return null;
      return sorted[n - 1].startTime;
    }

    DateTime? unlockedAtAtLeastTotalKm(double km) {
      double cumulative = 0;
      for (final r in sorted) {
        cumulative += r.distanceKm;
        if (cumulative >= km) return r.startTime;
      }
      return null;
    }

    DateTime? unlockedAtStreak(int days) {
      // Walk through days from first run forward; find any window of `days`
      // consecutive days each containing ≥ 1 run.
      final daysWithRun = <DateTime>{};
      for (final r in sorted) {
        daysWithRun.add(
            DateTime(r.startTime.year, r.startTime.month, r.startTime.day));
      }
      if (daysWithRun.isEmpty) return null;
      final allDays = daysWithRun.toList()..sort();
      int streak = 1;
      DateTime? prev;
      DateTime? unlockedDay;
      for (final day in allDays) {
        if (prev != null && day.difference(prev).inDays == 1) {
          streak++;
        } else if (prev != null) {
          streak = 1;
        }
        if (streak >= days) {
          unlockedDay = day;
          break;
        }
        prev = day;
      }
      return unlockedDay;
    }

    Achievement buildFor({
      required AchievementKind kind,
      required String title,
      required String subtitle,
      required IconData icon,
      required DateTime? unlockedAt,
    }) {
      return Achievement(
        kind: kind,
        title: title,
        subtitle: subtitle,
        icon: icon,
        unlocked: unlockedAt != null,
        unlockedAt: unlockedAt,
      );
    }

    return [
      buildFor(
        kind: AchievementKind.firstRun,
        title: 'Premier pas',
        subtitle: 'Première course',
        icon: Icons.flag,
        unlockedAt: unlockedAtAfterNRuns(1),
      ),
      buildFor(
        kind: AchievementKind.fiveKmClub,
        title: '5 km club',
        subtitle: 'Une course ≥ 5 km',
        icon: Icons.directions_run,
        unlockedAt: firstRunDistanceAtLeast(5),
      ),
      buildFor(
        kind: AchievementKind.tenKmClub,
        title: '10 km club',
        subtitle: 'Une course ≥ 10 km',
        icon: Icons.local_fire_department,
        unlockedAt: firstRunDistanceAtLeast(10),
      ),
      buildFor(
        kind: AchievementKind.halfMarathon,
        title: 'Semi-marathon',
        subtitle: 'Une course ≥ 21,1 km',
        icon: Icons.military_tech,
        unlockedAt: firstRunDistanceAtLeast(21.0975),
      ),
      buildFor(
        kind: AchievementKind.marathon,
        title: 'Marathon',
        subtitle: 'Une course ≥ 42,2 km',
        icon: Icons.workspace_premium,
        unlockedAt: firstRunDistanceAtLeast(42.195),
      ),
      buildFor(
        kind: AchievementKind.tenRuns,
        title: 'Régulier',
        subtitle: '10 courses au total',
        icon: Icons.repeat,
        unlockedAt: unlockedAtAfterNRuns(10),
      ),
      buildFor(
        kind: AchievementKind.fiftyRuns,
        title: 'Passionné',
        subtitle: '50 courses au total',
        icon: Icons.bolt,
        unlockedAt: unlockedAtAfterNRuns(50),
      ),
      buildFor(
        kind: AchievementKind.hundredKm,
        title: 'Centenaire',
        subtitle: '100 km cumulés',
        icon: Icons.terrain,
        unlockedAt: unlockedAtAtLeastTotalKm(100),
      ),
      buildFor(
        kind: AchievementKind.fiveHundredKm,
        title: 'Marathonien',
        subtitle: '500 km cumulés',
        icon: Icons.public,
        unlockedAt: unlockedAtAtLeastTotalKm(500),
      ),
      buildFor(
        kind: AchievementKind.streak7,
        title: 'Série de 7',
        subtitle: '7 jours consécutifs',
        icon: Icons.calendar_view_week,
        unlockedAt: unlockedAtStreak(7),
      ),
      buildFor(
        kind: AchievementKind.streak30,
        title: 'Série de 30',
        subtitle: '30 jours consécutifs',
        icon: Icons.calendar_month,
        unlockedAt: unlockedAtStreak(30),
      ),
    ];
  }
}
