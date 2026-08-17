import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AppointmentStorage {
  static const String _key = 'my_booked_appointments';

  static Future<void> saveAppointment(Map<String, dynamic> appointmentData) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> storedList = prefs.getStringList(_key) ?? [];

    appointmentData['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    appointmentData['status'] = 'Upcoming';

    storedList.add(jsonEncode(appointmentData));
    await prefs.setStringList(_key, storedList);
  }

  static Future<List<Map<String, dynamic>>> getAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> storedList = prefs.getStringList(_key) ?? [];

    return storedList.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
  }

  static Future<void> cancelAppointment(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> storedList = prefs.getStringList(_key) ?? [];

    List<Map<String, dynamic>> appointments = storedList
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .toList();

    for (var app in appointments) {
      if (app['id'] == id) {
        app['status'] = 'Cancelled';
        break;
      }
    }

    List<String> updatedList = appointments.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList(_key, updatedList);
  }
}