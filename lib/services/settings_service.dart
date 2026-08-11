import 'package:shared_preferences/shared_preferences.dart';

/// Persists the Accessibility screen's toggles (and the home location used
/// by Auto Safe Arrival) across app restarts. Local device storage only —
/// these are per-device safety preferences, not synced data.
class SettingsService {
  SettingsService._();

  static const _keySmsFallback = 'settings.smsFallback';
  static const _keyAutoSafeArrival = 'settings.autoSafeArrival';
  static const _keyVoiceCommand = 'settings.voiceCommand';
  static const _keyHomeLat = 'settings.homeLat';
  static const _keyHomeLng = 'settings.homeLng';
  static const _keyHomeLabel = 'settings.homeLabel';

  static Future<bool> getSmsFallback() async =>
      (await SharedPreferences.getInstance()).getBool(_keySmsFallback) ?? true;

  static Future<void> setSmsFallback(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_keySmsFallback, value);

  static Future<bool> getAutoSafeArrival() async =>
      (await SharedPreferences.getInstance()).getBool(_keyAutoSafeArrival) ?? false;

  static Future<void> setAutoSafeArrival(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_keyAutoSafeArrival, value);

  static Future<bool> getVoiceCommand() async =>
      (await SharedPreferences.getInstance()).getBool(_keyVoiceCommand) ?? false;

  static Future<void> setVoiceCommand(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_keyVoiceCommand, value);

  /// (lat, lng, label) if a home location has been set, else null.
  static Future<(double, double, String)?> getHomeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_keyHomeLat);
    final lng = prefs.getDouble(_keyHomeLng);
    if (lat == null || lng == null) return null;
    return (lat, lng, prefs.getString(_keyHomeLabel) ?? 'Home');
  }

  static Future<void> setHomeLocation({
    required double lat,
    required double lng,
    required String label,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyHomeLat, lat);
    await prefs.setDouble(_keyHomeLng, lng);
    await prefs.setString(_keyHomeLabel, label);
  }

  static Future<void> clearHomeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHomeLat);
    await prefs.remove(_keyHomeLng);
    await prefs.remove(_keyHomeLabel);
  }
}
