import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide units preference. Internal storage stays metric (km, km/h);
/// this service converts and formats for display.
class UnitsService extends ChangeNotifier {
  UnitsService._();
  static final UnitsService instance = UnitsService._();

  static const _kImperial = 'unitsImperial';
  static const _kmPerMile = 0.621371;

  bool _imperial = false;
  bool get imperial => _imperial;
  bool get metric => !_imperial;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _imperial = prefs.getBool(_kImperial) ?? false;
    notifyListeners();
  }

  Future<void> setImperial(bool value) async {
    if (_imperial == value) return;
    _imperial = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kImperial, value);
    notifyListeners();
  }

  String distanceUnit() => _imperial ? 'mi' : 'km';
  String speedUnit() => _imperial ? 'mph' : 'km/h';

  double distance(double km) => _imperial ? km * _kmPerMile : km;
  double distanceToKm(double displayed) =>
      _imperial ? displayed / _kmPerMile : displayed;

  double speed(double kmh) => _imperial ? kmh * _kmPerMile : kmh;

  /// Pace in min per displayed unit (min/km or min/mi).
  double paceMinPerUnit(double kmh) {
    final adjusted = _imperial ? kmh * _kmPerMile : kmh;
    if (adjusted <= 0) return 0;
    return 60.0 / adjusted;
  }

  String formatDistance(double km, {int decimals = 2}) =>
      '${distance(km).toStringAsFixed(decimals)} ${distanceUnit()}';

  String formatSpeed(double kmh, {int decimals = 1}) =>
      '${speed(kmh).toStringAsFixed(decimals)} ${speedUnit()}';

  String formatPace(double kmh) {
    final p = paceMinPerUnit(kmh);
    if (p <= 0 || !p.isFinite) return '--:--';
    final m = p.floor();
    final s = ((p - m) * 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
