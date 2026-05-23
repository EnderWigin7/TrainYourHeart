import 'package:shared_preferences/shared_preferences.dart';

/// Device-local preferences. User profile and runs live in Firestore via
/// FirestoreService — this class only owns settings that are per-device.
class StorageService {
  static const _kBiometricEnabled = 'biometricEnabled';
  static const _kAutoPause = 'autoPause';
  static const _kHapticFeedback = 'hapticFeedback';
  static const _kOnboardingDone = 'onboardingDone';

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
