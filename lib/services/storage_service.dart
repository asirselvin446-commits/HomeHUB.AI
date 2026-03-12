import 'package:shared_preferences/shared_preferences.dart';

/// Local storage service for device-specific preferences only.
/// All app data is now stored in Firebase Firestore.
class StorageService {
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Theme preference (stored locally per device)
  bool getIsDarkMode() => _prefs.getBool('isDarkMode') ?? true;
  Future<void> setIsDarkMode(bool value) =>
      _prefs.setBool('isDarkMode', value);

  // Notification preference
  bool getNotificationsEnabled() =>
      _prefs.getBool('notificationsEnabled') ?? true;
  Future<void> setNotificationsEnabled(bool value) =>
      _prefs.setBool('notificationsEnabled', value);

  // Clear local preferences
  Future<void> clear() async => await _prefs.clear();
}
