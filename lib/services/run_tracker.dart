import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/run.dart';

/// Tracks an active run: duration, distance, speed, calories, per-km splits.
/// Uses GPS via geolocator; falls back to a time-based simulation
/// if location services are unavailable (useful for emulators).
class RunTracker extends ChangeNotifier {
  RunTracker({
    required this.weightKg,
    this.autoPause = false,
    this.hapticFeedback = false,
  });

  final double weightKg;
  final bool autoPause;
  final bool hapticFeedback;

  static const _autoPauseThresholdSeconds = 5;
  static const _autoPauseSpeedKmh = 1.0;

  Duration _duration = Duration.zero;
  double _distanceMeters = 0;
  double _currentSpeedKmh = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _autoPaused = false;
  DateTime? _startTime;
  int _lastSplitKm = 0;
  int _slowSecondsStreak = 0;
  final List<KmSplit> _splits = [];

  Position? _lastPosition;
  StreamSubscription<Position>? _positionSub;
  Timer? _tickTimer;
  bool _gpsAvailable = false;

  Duration get duration => _duration;
  double get distanceMeters => _distanceMeters;
  double get distanceKm => _distanceMeters / 1000.0;
  double get currentSpeedKmh => _currentSpeedKmh;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  bool get isAutoPaused => _autoPaused;
  DateTime? get startTime => _startTime;
  List<KmSplit> get splits => List.unmodifiable(_splits);

  double get averageSpeedKmh {
    if (_duration.inSeconds == 0) return 0;
    return (distanceKm / (_duration.inSeconds / 3600.0));
  }

  /// MET-based estimate. Running MET ≈ 1.03 * speed(km/h) (rough approximation).
  double get caloriesBurned {
    if (_duration.inSeconds == 0) return 0;
    final met = _currentSpeedKmh > 0
        ? (1.03 * averageSpeedKmh).clamp(3.0, 16.0)
        : 6.0;
    final hours = _duration.inSeconds / 3600.0;
    return met * weightKg * hours;
  }

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _isPaused = false;
    _autoPaused = false;
    _startTime = DateTime.now();
    _duration = Duration.zero;
    _distanceMeters = 0;
    _currentSpeedKmh = 0;
    _lastPosition = null;
    _lastSplitKm = 0;
    _slowSecondsStreak = 0;
    _splits.clear();

    if (hapticFeedback) HapticFeedback.mediumImpact();

    _gpsAvailable = await _initLocation();

    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPaused) return;
      _duration += const Duration(seconds: 1);
      if (!_gpsAvailable) {
        // Simulate ~10 km/h jog
        const simSpeedKmh = 9.0;
        _currentSpeedKmh = simSpeedKmh;
        _distanceMeters += simSpeedKmh * 1000.0 / 3600.0;
      }
      _maybeRecordSplit();
      _maybeAutoPause();
      notifyListeners();
    });

    notifyListeners();
  }

  Future<bool> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }
      if (permission == LocationPermission.deniedForever) return false;

      const settings = LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
      );
      _positionSub =
          Geolocator.getPositionStream(locationSettings: settings).listen(
        (pos) {
          if (_isPaused) return;
          if (_lastPosition != null) {
            final meters = Geolocator.distanceBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              pos.latitude,
              pos.longitude,
            );
            _distanceMeters += meters;
          }
          _lastPosition = pos;
          _currentSpeedKmh = (pos.speed.isFinite && pos.speed >= 0)
              ? pos.speed * 3.6
              : 0;
          notifyListeners();
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void _maybeRecordSplit() {
    final completedKm = distanceKm.floor();
    if (completedKm > _lastSplitKm) {
      // Multiple kms may have completed in a single tick (rare). Distribute
      // remaining time equally for each.
      final priorTotal = _splits.fold<Duration>(
        Duration.zero,
        (acc, s) => acc + s.duration,
      );
      final remaining = _duration - priorTotal;
      final kmsCompleted = completedKm - _lastSplitKm;
      final per = Duration(
        microseconds: remaining.inMicroseconds ~/ kmsCompleted,
      );
      for (int k = _lastSplitKm + 1; k <= completedKm; k++) {
        _splits.add(KmSplit(km: k, duration: per));
      }
      _lastSplitKm = completedKm;
      if (hapticFeedback) HapticFeedback.lightImpact();
    }
  }

  void _maybeAutoPause() {
    if (!autoPause) return;
    if (_currentSpeedKmh < _autoPauseSpeedKmh) {
      _slowSecondsStreak += 1;
      if (_slowSecondsStreak >= _autoPauseThresholdSeconds && !_autoPaused) {
        _autoPaused = true;
        _isPaused = true;
      }
    } else {
      _slowSecondsStreak = 0;
      if (_autoPaused) {
        _autoPaused = false;
        _isPaused = false;
      }
    }
  }

  void pause() {
    if (!_isRunning) return;
    _isPaused = true;
    _autoPaused = false;
    if (hapticFeedback) HapticFeedback.lightImpact();
    notifyListeners();
  }

  void resume() {
    if (!_isRunning) return;
    _isPaused = false;
    _autoPaused = false;
    if (hapticFeedback) HapticFeedback.lightImpact();
    notifyListeners();
  }

  Future<void> stop() async {
    _isRunning = false;
    _isPaused = false;
    _autoPaused = false;
    await _positionSub?.cancel();
    _tickTimer?.cancel();
    if (hapticFeedback) HapticFeedback.mediumImpact();
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }
}
