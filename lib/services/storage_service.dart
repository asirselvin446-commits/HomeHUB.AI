import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/models.dart';

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

  // Notification History locally
  List<AppNotification> getNotifications() {
    final String? jsonStr = _prefs.getString('notifications_history');
    if (jsonStr == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => AppNotification.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> setNotifications(List<AppNotification> notifications) async {
    final List<Map<String, dynamic>> mappedList =
        notifications.map((n) => n.toJson()).toList();
    await _prefs.setString('notifications_history', jsonEncode(mappedList));
  }

  // Clear local preferences
  Future<void> clear() async => await _prefs.clear();
}
