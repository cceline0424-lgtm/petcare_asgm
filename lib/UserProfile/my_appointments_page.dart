import 'package:flutter/material.dart';
import 'package:petcare_asgm/VetClinic/appointment_storage.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MyAppointmentsPage extends StatefulWidget {
  const MyAppointmentsPage({super.key});

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage> {
  List<Map<String, dynamic>> _upcoming = [];
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    final allAppointments = await AppointmentStorage.getAppointments();
    final DateTime today = DateTime.now();
    final DateTime todayDateOnly = DateTime(today.year, today.month, today.day);
    bool needsStorageUpdate = false;

    for (var app in allAppointments) {
      if (app['status'] == 'Upcoming') {
        List<String> dateParts = app['date'].split('/');
        if (dateParts.length == 3) {
          int day = int.parse(dateParts[0]);
          int month = int.parse(dateParts[1]);
          int year = int.parse(dateParts[2]);

          DateTime appointmentDate = DateTime(year, month, day);
          if (appointmentDate.isBefore(todayDateOnly)) {
            app['status'] = 'Completed';
            needsStorageUpdate = true;
          }
        }
      }
    }

    if (needsStorageUpdate) {
      final prefs = await SharedPreferences.getInstance();
      List<String> updatedList = allAppointments.map((item) => jsonEncode(item)).toList();
      await prefs.setStringList('my_booked_appointments', updatedList);
    }

    setState(() {
      _upcoming = allAppointments.where((app) => app['status'] == 'Upcoming').toList();
      _history = allAppointments.where((app) => app['status'] != 'Upcoming').toList();
      _upcoming = _upcoming.reversed.toList();
      _history = _history.reversed.toList();
      _isLoading = false;
    });
  }

  Future<void> _cancelAppointment(String id) async {
    await AppointmentStorage.cancelAppointment(id);
    _loadAppointments();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment Cancelled'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = isDark ? Colors.white : Colors.brown[800]!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Appointments'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: primaryColor),
          titleTextStyle: TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.bold),
          bottom: TabBar(
            labelColor: primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryColor,
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : TabBarView(
          children: [
            _buildAppointmentList(_upcoming, true, primaryColor),
            _buildAppointmentList(_history, false, primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentList(List<Map<String, dynamic>> list, bool isUpcoming, Color primaryColor) {
    if (list.isEmpty) {
      return const Center(
        child: Text('No appointments found.', style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final app = list[index];
        final bool isCancelled = app['status'] == 'Cancelled';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        app['clinicName'] ?? 'Clinic',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCancelled ? Colors.red[100] : Colors.green[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        app['status'],
                        style: TextStyle(
                          color: isCancelled ? Colors.red[800] : Colors.green[800],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Text('📅 Date: ${app['date']} at ${app['time']}'),
                const SizedBox(height: 4),
                Text('🐾 Pet: ${app['petName']}'),
                const SizedBox(height: 4),
                Text('⚕️ Service: ${app['service']}'),

                if (isUpcoming) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _cancelAppointment(app['id']),
                      child: const Text('Cancel Appointment'),
                    ),
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}