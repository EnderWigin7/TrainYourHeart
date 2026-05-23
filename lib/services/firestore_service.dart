import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/run.dart';
import '../models/user_profile.dart';

class Stats {
  final int streakDays;
  final double weekKm;
  final double monthKm;
  final double longestRunKm;
  final double fastestSpeedKmh;
  final double mostCalories;

  const Stats({
    required this.streakDays,
    required this.weekKm,
    required this.monthKm,
    required this.longestRunKm,
    required this.fastestSpeedKmh,
    required this.mostCalories,
  });

  static const empty = Stats(
    streakDays: 0,
    weekKm: 0,
    monthKm: 0,
    longestRunKm: 0,
    fastestSpeedKmh: 0,
    mostCalories: 0,
  );
}

enum PbKind { distance, speed, calories }

class PbBeat {
  final PbKind kind;
  final double current;
  final double previousBest;
  const PbBeat({
    required this.kind,
    required this.current,
    required this.previousBest,
  });

  double get delta => current - previousBest;
}

class LifetimeStats {
  final int totalRuns;
  final double totalDistanceKm;
  final Duration totalActiveTime;
  final double avgDistanceKm;

  const LifetimeStats({
    required this.totalRuns,
    required this.totalDistanceKm,
    required this.totalActiveTime,
    required this.avgDistanceKm,
  });

  static const empty = LifetimeStats(
    totalRuns: 0,
    totalDistanceKm: 0,
    totalActiveTime: Duration.zero,
    avgDistanceKm: 0,
  );
}

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Bumped whenever the run list mutates (add, wipe).
  static final ValueNotifier<int> runsChanged = ValueNotifier<int>(0);

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>>? get _runsCol => _userDoc?.collection('runs');

  Future<UserProfile?> loadProfile() async {
    final doc = _userDoc;
    if (doc == null) return null;
    final snap = await doc.get();
    if (!snap.exists) return null;
    return UserProfile.fromJson(snap.data()!);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final doc = _userDoc;
    if (doc == null) throw StateError('No signed-in user');
    await doc.set(profile.toJson(), SetOptions(merge: true));
  }

  /// Ensures a user doc exists. Called right after sign-up / first Google sign-in.
  Future<UserProfile> ensureProfile({
    required String fallbackUsername,
    required String email,
  }) async {
    final existing = await loadProfile();
    if (existing != null) return existing;
    final profile = UserProfile(
      username: fallbackUsername,
      email: email,
      weightKg: 70,
      age: 25,
      dailyGoalKm: 3.0,
    );
    await saveProfile(profile);
    return profile;
  }

  Future<List<Run>> loadRuns() async {
    final col = _runsCol;
    if (col == null) return [];
    final snap = await col.orderBy('startTime', descending: true).get();
    return snap.docs.map((d) => Run.fromJson(d.data())).toList();
  }

  Future<void> addRun(Run run) async {
    final col = _runsCol;
    if (col == null) throw StateError('No signed-in user');
    await col.doc(run.id).set(run.toJson());
    runsChanged.value++;
  }

  Future<void> deleteAllRuns() async {
    final col = _runsCol;
    if (col == null) return;
    final snap = await col.get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    runsChanged.value++;
  }

  Future<void> deleteAccountData() async {
    await deleteAllRuns();
    final doc = _userDoc;
    if (doc != null) await doc.delete();
  }

  Future<double> todaysDistanceKm() async {
    final runs = await loadRuns();
    final now = DateTime.now();
    double total = 0;
    for (final r in runs) {
      if (_sameDay(r.startTime, now)) {
        total += r.distanceKm;
      }
    }
    return total;
  }

  Future<Stats> loadStats(double dailyGoalKm) async {
    final runs = await loadRuns();
    if (runs.isEmpty) return Stats.empty;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final byDay = <DateTime, double>{};
    double weekKm = 0;
    double monthKm = 0;
    double longest = 0;
    double fastest = 0;
    double mostCal = 0;

    for (final r in runs) {
      final day =
          DateTime(r.startTime.year, r.startTime.month, r.startTime.day);
      byDay[day] = (byDay[day] ?? 0) + r.distanceKm;
      if (!day.isBefore(weekStart)) weekKm += r.distanceKm;
      if (!day.isBefore(monthStart)) monthKm += r.distanceKm;
      if (r.distanceKm > longest) longest = r.distanceKm;
      if (r.averageSpeedKmh > fastest) fastest = r.averageSpeedKmh;
      if (r.caloriesBurned > mostCal) mostCal = r.caloriesBurned;
    }

    int streak = 0;
    var cursor = today;
    if ((byDay[today] ?? 0) >= dailyGoalKm) {
      streak = 1;
      cursor = cursor.subtract(const Duration(days: 1));
    } else {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (true) {
      final km = byDay[cursor] ?? 0;
      if (km >= dailyGoalKm) {
        streak += 1;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return Stats(
      streakDays: streak,
      weekKm: weekKm,
      monthKm: monthKm,
      longestRunKm: longest,
      fastestSpeedKmh: fastest,
      mostCalories: mostCal,
    );
  }

  Future<Map<DateTime, double>> last14DaysKm() async {
    final runs = await loadRuns();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <DateTime, double>{};
    for (int i = 13; i >= 0; i--) {
      result[today.subtract(Duration(days: i))] = 0;
    }
    for (final r in runs) {
      final day =
          DateTime(r.startTime.year, r.startTime.month, r.startTime.day);
      if (result.containsKey(day)) {
        result[day] = result[day]! + r.distanceKm;
      }
    }
    return result;
  }

  Future<List<PbBeat>> detectPbBeats(String currentRunId) async {
    final runs = await loadRuns();
    Run? current;
    final others = <Run>[];
    for (final r in runs) {
      if (r.id == currentRunId) {
        current = r;
      } else {
        others.add(r);
      }
    }
    if (current == null || others.isEmpty) return const [];
    double prevLongestKm = 0;
    double prevFastest = 0;
    double prevMostCal = 0;
    for (final r in others) {
      if (r.distanceKm > prevLongestKm) prevLongestKm = r.distanceKm;
      if (r.averageSpeedKmh > prevFastest) prevFastest = r.averageSpeedKmh;
      if (r.caloriesBurned > prevMostCal) prevMostCal = r.caloriesBurned;
    }
    final beats = <PbBeat>[];
    if (current.distanceKm > prevLongestKm) {
      beats.add(PbBeat(
        kind: PbKind.distance,
        current: current.distanceKm,
        previousBest: prevLongestKm,
      ));
    }
    if (current.averageSpeedKmh > prevFastest) {
      beats.add(PbBeat(
        kind: PbKind.speed,
        current: current.averageSpeedKmh,
        previousBest: prevFastest,
      ));
    }
    if (current.caloriesBurned > prevMostCal) {
      beats.add(PbBeat(
        kind: PbKind.calories,
        current: current.caloriesBurned,
        previousBest: prevMostCal,
      ));
    }
    return beats;
  }

  Future<LifetimeStats> loadLifetimeStats() async {
    final runs = await loadRuns();
    if (runs.isEmpty) return LifetimeStats.empty;
    double totalKm = 0;
    int totalSeconds = 0;
    for (final r in runs) {
      totalKm += r.distanceKm;
      totalSeconds += r.duration.inSeconds;
    }
    return LifetimeStats(
      totalRuns: runs.length,
      totalDistanceKm: totalKm,
      totalActiveTime: Duration(seconds: totalSeconds),
      avgDistanceKm: totalKm / runs.length,
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
