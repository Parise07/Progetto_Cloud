import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferenceManager {
  static late SharedPreferences _preferences;

  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  static SharedPreferences get instance {
    // ignore: unnecessary_null_comparison
    if (_preferences == null) {
      throw Exception(
          'SharedPreferenceManager not initialized. Call init() first.');
    }

    return _preferences;
  }

  static Future<void> clear() async {
    await _preferences.clear();
  }
}
