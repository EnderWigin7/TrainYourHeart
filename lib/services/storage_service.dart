import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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

class StorageService {
  static const _kProfile = 'profile';
  static const _kRuns = 'runs';
  static const _kLoggedIn = 'loggedIn';
  static const _kBiometricEnabled = 'biometricEnabled';
  static const _kAutoPause = 'autoPause';
  static const _kHapticFeedback = 'hapticFeedback';
  static const _kOnboardingDone = 'onboardingDone';

  Future<UserProfile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProfile);
    if (raw == null) return null;
    return UserProfile.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfile, json.encode(profile.toJson()));
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kLoggedIn) ?? false;
  }

  Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLoggedIn, value);
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBiometricEnabled) ?? false;
  }

  Future<void> setBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricEnabled, value);
  }

  Future<bool> isAutoPauseEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAutoPause) ?? false;
  }

  Future<void> setAutoPauseEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoPause, value);
  }

  Future<bool> isHapticEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kHapticFeedback) ?? true;
  }

  Future<void> setHapticEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHapticFeedback, value);
  }

  Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingDone) ?? false;
  }

  Future<void> setOnboardingDone(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingDone, value);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kProfile);
    await prefs.remove(_kRuns);
    await prefs.remove(_kLoggedIn);
    await prefs.remove(_kBiometricEnabled);
    await prefs.remove(_kAutoPause);
    await prefs.remove(_kHapticFeedback);
    // Keep _kOnboardingDone — wiping data shouldn't re-show onboarding.
  }

  Future<List<Run>> loadRuns() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kRuns) ?? [];
    return list
        .map((s) => Run.fromJson(json.decode(s) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  Future<void> addRun(Run run) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kRuns) ?? [];
    list.add(json.encode(run.toJson()));
    await prefs.setStringList(_kRuns, list);
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
      final day = DateTime(r.startTime.year, r.startTime.month, r.startTime.day);
      byDay[day] = (byDay[day] ?? 0) + r.distanceKm;
      if (!day.isBefore(weekStart)) weekKm += r.distanceKm;
      if (!day.isBefore(monthStart)) monthKm += r.distanceKm;
      if (r.distanceKm > longest) longest = r.distanceKm;
      if (r.averageSpeedKmh > fastest) fastest = r.averageSpeedKmh;
      if (r.caloriesBurned > mostCal) mostCal = r.caloriesBurned;
    }

    int streak = 0;
    var cursor = today;
    final todayHit = (byDay[today] ?? 0) >= dailyGoalKm;
    if (todayHit) {
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
      final day = DateTime(r.startTime.year, r.startTime.month, r.startTime.day);
      if (result.containsKey(day)) {
        result[day] = result[day]! + r.distanceKm;
      }
    }
    return result;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
