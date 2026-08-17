import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:petcare_asgm/UserProfile/setting.dart';
import 'package:petcare_asgm/UserProfile/my_appointments_page.dart';

class UserProfilePage extends StatefulWidget {
  final String username;

  const UserProfilePage({super.key, required this.username});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  File? _image;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileInfo();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfileInfo() async {
    final pref = await SharedPreferences.getInstance();

    setState(() {
      _nameCtrl.text = pref.getString('name') ?? widget.username;
      _emailCtrl.text = pref.getString('email') ?? "Not set";
      _contactCtrl.text = pref.getString('contact') ?? "Not set";
    });

    final appDataDir = await getApplicationDocumentsDirectory();
    final imagePath = '${appDataDir.path}/profile.png';
    final file = File(imagePath);

    if (await file.exists()) {
      setState(() {
        _image = file;
      });
    }
  }

  Future<void> _saveProfileInfo() async {
    final pref = await SharedPreferences.getInstance();

    pref.setString('name', _nameCtrl.text);
    pref.setString('email', _emailCtrl.text);
    pref.setString('contact', _contactCtrl.text);

    if (_image != null) {
      final appDataDir = await getApplicationDocumentsDirectory();
      final imagePath = '${appDataDir.path}/profile.png';
      try {
        _image!.copy(imagePath);
      } catch (e) {
        print('Error : ${e.toString()}');
      }
    }

    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile Info Saved')),
      );
    }
  }

  Future<void> _getImage(StateSetter setDialogState) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final newImage = File(pickedFile.path);
      setDialogState(() {
        _image = newImage;
      });
      setState(() {
        _image = newImage;
      });
    }
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
              bool isDark = Theme.of(context).brightness == Brightness.dark;

              return AlertDialog(
                backgroundColor: isDark ? Colors.grey[850] : Colors.white,
                title: Text('Edit Profile', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _getImage(setDialogState),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.brown,
                              backgroundImage: _image != null ? FileImage(_image!) : null,
                              child: _image == null
                                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                                  : null,
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.brown, size: 20),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text('Tap picture to change', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 20),

                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _contactCtrl,
                        decoration: const InputDecoration(labelText: 'Contact Number', border: OutlineInputBorder()),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      _loadProfileInfo();
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700]),
                    onPressed: () {
                      _saveProfileInfo();
                      Navigator.pop(context);
                    },
                    child: const Text('Save', style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    Color primaryColor = isDark ? Colors.white : Colors.brown[800]!;
    Color subTextColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;
    Color borderColor = isDark ? Colors.brown[300]! : Colors.brown;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.brown,
                backgroundImage: _image != null ? FileImage(_image!) : null,
                child: _image == null
                    ? const Icon(Icons.person, size: 45, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameCtrl.text.isEmpty ? widget.username : _nameCtrl.text,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _contactCtrl.text.isEmpty ? "Not set" : _contactCtrl.text,
                      style: TextStyle(fontSize: 14, color: subTextColor),
                    ),
                    Text(
                      _emailCtrl.text.isEmpty ? "Not set" : _emailCtrl.text,
                      style: TextStyle(fontSize: 14, color: subTextColor),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit, color: primaryColor),
                onPressed: _showEditProfileDialog,
                tooltip: 'Edit Profile',
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        _buildProfileMenuItem(Icons.pets, 'Pet info', () {}, isDark: isDark),
        _buildProfileMenuItem(Icons.calendar_today, 'Appointment', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MyAppointmentsPage()),
          );
        }, isDark: isDark),
        _buildProfileMenuItem(Icons.settings, 'Setting', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          );
        }, isDark: isDark),

        Divider(color: borderColor, thickness: 1),

        _buildProfileMenuItem(
          Icons.logout,
          'Log out',
              () {},
          isDark: isDark,
          itemColor: isDark ? Colors.redAccent : Colors.red,
        ),
      ],
    );
  }

  Widget _buildProfileMenuItem(IconData icon, String title, VoidCallback onTap, {Color? itemColor, required bool isDark}) {
    final Color defaultColor = isDark ? Colors.white : Colors.brown[800]!;
    final Color finalColor = itemColor ?? defaultColor;

    return ListTile(
      leading: Icon(icon, color: finalColor, size: 28),
      title: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: finalColor),
      ),
      onTap: onTap,
    );
  }
}