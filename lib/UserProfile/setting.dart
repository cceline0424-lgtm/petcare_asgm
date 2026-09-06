import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _appointmentReminders = true;
  bool _strayMapAlerts = true;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appointmentReminders = prefs.getBool('reminder') ?? true;
      _strayMapAlerts = prefs.getBool('stray_alert') ?? true;
      _darkMode = prefs.getBool('dark_mode') ?? false;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(key, value);
  }

  bool _hasMetAllPasswordCriteria(String p) {
    return p.isNotEmpty &&
        p.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(p) &&
        RegExp(r'[0-9]').hasMatch(p) &&
        RegExp(r'''[!@#\$%^&*(),.?":{}|<>_\-+=\[\]/\\~`]''').hasMatch(p);
  }

  Widget _buildPasswordHint(String text, bool isMet) {
    final color = isMet ? Colors.green : Colors.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(isMet ? Icons.check : Icons.close, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color))),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) {
        bool isDark = Theme.of(context).brightness == Brightness.dark;
        Color textColor = isDark ? Colors.white : Colors.black;
        Color hintColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final newPassText = newPasswordController.text;

            return AlertDialog(
              backgroundColor: isDark ? Colors.grey[850] : Colors.white,
              title: Text('Change Password', style: TextStyle(color: textColor)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrent,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: hintColor),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      style: TextStyle(color: textColor),
                      onChanged: (val) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_hasMetAllPasswordCriteria(newPassText)) const Icon(Icons.check_circle, color: Colors.green),
                            IconButton(
                              icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: hintColor),
                              onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (newPassText.isNotEmpty) ...[
                      _buildPasswordHint('Minimum 8 characters', newPassText.length >= 8),
                      _buildPasswordHint('At least 1 uppercase letter', RegExp(r'[A-Z]').hasMatch(newPassText)),
                      _buildPasswordHint('At least 1 number', RegExp(r'[0-9]').hasMatch(newPassText)),
                      _buildPasswordHint('At least 1 special symbol', RegExp(r'''[!@#\$%^&*(),.?":{}|<>_\-+=\[\]/\\~`]''').hasMatch(newPassText)),
                      const SizedBox(height: 16),
                    ],

                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      style: TextStyle(color: textColor),
                      onChanged: (val) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (confirmPasswordController.text.isNotEmpty)
                              Icon(confirmPasswordController.text == newPassText ? Icons.check_circle : Icons.cancel, color: confirmPasswordController.text == newPassText ? Colors.green : Colors.red),
                            IconButton(
                              icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: hintColor),
                              onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                            ),
                          ],
                        ),
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
                    String currentPass = currentPasswordController.text;
                    String newPass = newPasswordController.text;
                    String confirmPass = confirmPasswordController.text;

                    if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in all fields.')),
                      );
                      return;
                    }

                    if (!_hasMetAllPasswordCriteria(newPass)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please ensure your new password meets all criteria.')),
                      );
                      return;
                    }

                    if (newPass != confirmPass) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('New passwords do not match!')),
                      );
                      return;
                    }

                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null || user.email == null) return;

                    try {
                      final cred = EmailAuthProvider.credential(email: user.email!, password: currentPass);
                      await user.reauthenticateWithCredential(cred);
                    } on FirebaseAuthException catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Current password is incorrect.')),
                        );
                      }
                      return;
                    }

                    try {
                      await user.updatePassword(newPass);
                    } on FirebaseAuthException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.message ?? 'Could not update password. Please try again.')),
                        );
                      }
                      return;
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password changed successfully!')),
                      );
                    }
                  },
                  child: const Text('Update', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
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
                  title: const Text('Dark Mode'),
                  value: isDarkModeNotifier.value,
                  activeThumbColor: Colors.brown[300],
                  onChanged: (bool value) {
                    setState(() {
                      _darkMode = value;
                    });
                    isDarkModeNotifier.value = value;
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
                  activeThumbColor: Colors.brown,
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
                  activeThumbColor: Colors.brown,
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