import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Notification toggle states
  bool _appointmentReminders = true;
  bool _strayMapAlerts = true;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load saved settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appointmentReminders = prefs.getBool('reminder') ?? true;
      _strayMapAlerts = prefs.getBool('stray_alert') ?? true;
      _darkMode = prefs.getBool('dark_mode') ?? false;
    });
  }

  // Save toggle changes instantly
  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(key, value);
  }

  // ==========================================
  // CHANGE PASSWORD DIALOG POPUP
  // ==========================================
  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700]),
              onPressed: () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New passwords do not match!')),
                  );
                  return;
                }

                // Save the new password locally
                final prefs = await SharedPreferences.getInstance();
                prefs.setString('password', newPasswordController.text);

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password changed successfully!')),
                );
              },
              child: const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.brown[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Account & Security',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.brown),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            child: ListTile(
              leading: const Icon(Icons.lock_outline, color: Colors.brown),
              title: const Text('Change Password'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showChangePasswordDialog,
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            'Preferences',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.brown),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark Mode'), // Removed the "(Mock)" text!
                  // Link the switch value directly to our global notifier
                  value: isDarkModeNotifier.value,
                  activeColor: Colors.brown[300], // Lighter brown so it's visible in dark mode
                  onChanged: (bool value) {
                    setState(() {
                      _darkMode = value;
                    });
                    // Tell the whole app to change color instantly!
                    isDarkModeNotifier.value = value;

                    // Save the choice so it remembers next time you open the app
                    _saveSetting('dark_mode', value);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            'Notifications',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.brown),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined, color: Colors.brown),
                  title: const Text('Appointment Reminders'),
                  subtitle: const Text('Get notified before scheduled vet visits'),
                  value: _appointmentReminders,
                  activeColor: Colors.brown,
                  onChanged: (bool value) {
                    setState(() {
                      _appointmentReminders = value;
                    });
                    _saveSetting('reminder', value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.map_outlined, color: Colors.brown),
                  title: const Text('Stray Map Alerts'),
                  subtitle: const Text('Alerts when strays are pinned near you'),
                  value: _strayMapAlerts,
                  activeColor: Colors.brown,
                  onChanged: (bool value) {
                    setState(() {
                      _strayMapAlerts = value;
                    });
                    _saveSetting('stray_alert', value);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            'About',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.brown),
          ),
          const SizedBox(height: 8),
          const Card(
            elevation: 1,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('App Version', style: TextStyle(fontSize: 16)),
                  Text('v1.0.0', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}