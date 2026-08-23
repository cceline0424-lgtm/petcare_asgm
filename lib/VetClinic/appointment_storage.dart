import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petcare_asgm/Auth/auth_service.dart';

class AppointmentStorage {

  static Future<String?> _getStorageKey() async {
    final username = await AuthService.getLoggedInUsername();
    if (username == null) return null;
    return 'user_appointments_$username';
  }

  static Future<void> saveAppointment(Map<String, dynamic> appointmentData) async {
    final key = await _getStorageKey();
    if (key == null) return;

    final prefs = await SharedPreferences.getInstance();
    final List<String> appointmentsJson = prefs.getStringList(key) ?? [];

    appointmentData['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    appointmentData['status'] = 'Upcoming';

    appointmentsJson.add(jsonEncode(appointmentData));
    await prefs.setStringList(key, appointmentsJson);
  }

  static Future<List<Map<String, dynamic>>> getAppointments() async {
    final key = await _getStorageKey();
    if (key == null) return [];

    final prefs = await SharedPreferences.getInstance();
    final List<String> appointmentsJson = prefs.getStringList(key) ?? [];

    return appointmentsJson.map((str) {
      return Map<String, dynamic>.from(jsonDecode(str));
    }).toList();
  }

  static Future<void> cancelAppointment(String id) async {
    await updateAppointmentStatus(id, 'Cancelled');
  }

  static Future<void> updateAppointmentStatus(String id, String status) async {
    final key = await _getStorageKey();
    if (key == null) return;

    final prefs = await SharedPreferences.getInstance();
    final List<String> appointmentsJson = prefs.getStringList(key) ?? [];

    List<String> updatedList = [];
    for (String jsonStr in appointmentsJson) {
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      if (data['id'] == id) {
        data['status'] = status;
      }
      updatedList.add(jsonEncode(data));
    }

    await prefs.setStringList(key, updatedList);
  }
}