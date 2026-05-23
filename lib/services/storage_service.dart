import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local preferences. User profile and runs live in Firestore via
/// FirestoreService — this class only owns settings that are per-device.
class StorageService {
  static const _kBiometricEnabled = 'biometricEnabled';
  static const _kAutoPause = 'autoPause';
  static const _kHapticFeedback = 'hapticFeedback';
  static const _kOnboardingDone = 'onboardingDone';
  static const _kReducedEffects = 'reducedEffects';

  /// App-wide effects toggle. Listened to by AppGradientBackground, GlassCard,
  /// and HomeShell to decide whether to draw blurs and glow blobs.
  static final ValueNotifier<bool> reducedEffects = ValueNotifier<bool>(false);

  /// Loaded once at app start.
  Future<void> loadReducedEffects() async {
    final prefs = await SharedPreferences.getInstance();
    reducedEffects.value = prefs.getBool(_kReducedEffects) ?? false;
  }

  Future<void> setReducedEffects(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReducedEffects, value);
    reducedEffects.value = value;
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

  /// Clears device preferences (biometric, auto-pause, haptic) — but
  /// **not** the onboarding flag, so wiping data doesn't re-trigger it.
  Future<void> clearDevicePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBiometricEnabled);
    await prefs.remove(_kAutoPause);
    await prefs.remove(_kHapticFeedback);
  }
}
