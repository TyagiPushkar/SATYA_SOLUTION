import 'package:shared_preferences/shared_preferences.dart';
class LocalStorage {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _employeeKey = 'employee_data';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
  }

  static Future<void> saveEmployeeData(String employeeJsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_employeeKey, employeeJsonStr);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  static Future<String?> getEmployeeData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_employeeKey);
  }

  static const String _punchStatusKey = 'punch_status';
  static const String _punchInTimeKey = 'punch_in_time';

  static Future<void> savePunchStatus(bool isPunchedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_punchStatusKey, isPunchedIn);
  }

  static Future<bool> getPunchStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_punchStatusKey) ?? false;
  }

  static Future<void> savePunchInTime(String timeIsoStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_punchInTimeKey, timeIsoStr);
  }

  static Future<String?> getPunchInTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_punchInTimeKey);
  }

  static const String _unsyncedRecordsKey = 'unsynced_punch_records';

  static Future<void> saveUnsyncedRecordsJsonList(List<String> jsonList) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_unsyncedRecordsKey, jsonList);
  }

  static Future<List<String>> getUnsyncedRecordsJsonList() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_unsyncedRecordsKey) ?? [];
  }

  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_employeeKey);
    await prefs.remove(_punchStatusKey);
    await prefs.remove(_punchInTimeKey);
    await prefs.remove(_unsyncedRecordsKey);
  }
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

