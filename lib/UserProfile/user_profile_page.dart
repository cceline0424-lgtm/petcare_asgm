import 'dart:io';
import 'package:flutter/material.dart';
import 'package:petcare_asgm/UserProfile/setting.dart';
// Data Persistence Packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

// ==========================================
// USER PROFILE PAGE WIDGET (With SharedPreferences & Path Provider)
// ==========================================
class UserProfilePage extends StatefulWidget {
  final String username;

  const UserProfilePage({super.key, required this.username});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  // Global controllers for the edit dialog
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  File? _image;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Load the saved profile info immediately when the page opens
    _loadProfileInfo();
  }

  @override
  void dispose() {
    // Dispose controllers to prevent memory leaks
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ==========================================
  // CORE LOGIC: Loading and Saving (Based on reference code)
  // ==========================================

  Future<void> _loadProfileInfo() async {
    final pref = await SharedPreferences.getInstance();

    setState(() {
      // Read text data, fallback to passed username or "Not set" if null
      _nameCtrl.text = pref.getString('name') ?? widget.username;
      _emailCtrl.text = pref.getString('email') ?? "Not set";
      _contactCtrl.text = pref.getString('contact') ?? "Not set";
    });

    // Read profile image path
    final appDataDir = await getApplicationDocumentsDirectory();
    final imagePath = '${appDataDir.path}/profile.png';
    final file = File(imagePath);

    // Check if the image file exists in storage before setting it
    if (await file.exists()) {
      setState(() {
        _image = file;
      });
    }
  }

  Future<void> _saveProfileInfo() async {
    final pref = await SharedPreferences.getInstance();

    // Save the text data to SharedPreferences
    pref.setString('name', _nameCtrl.text);
    pref.setString('email', _emailCtrl.text);
    pref.setString('contact', _contactCtrl.text);

    // Save the image to the app directory if one was selected
    if (_image != null) {
      final appDataDir = await getApplicationDocumentsDirectory();
      final imagePath = '${appDataDir.path}/profile.png';
      try {
        _image!.copy(imagePath);
      } catch (e) {
        print('Error : ${e.toString()}');
      }
    }

    // Force the main screen UI to refresh with the new data
    setState(() {});

    // Show a success message
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
      // Update both the dialog popup and the underlying page state
      setDialogState(() {
        _image = newImage;
      });
      setState(() {
        _image = newImage;
      });
    }
  }

  // ==========================================
  // UI LOGIC: Edit Dialog & Main Layout
  // ==========================================

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Edit Profile'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Picture Upload Section
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

                      // Input Fields (Linked directly to controllers)
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
                      // Reload original data to discard unsaved changes
                      _loadProfileInfo();
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700]),
                    onPressed: () {
                      // Trigger the save function
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
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // 1. User Profile Display Box
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.brown, width: 2),
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
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _contactCtrl.text.isEmpty ? "Not set" : _contactCtrl.text,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    Text(
                      _emailCtrl.text.isEmpty ? "Not set" : _emailCtrl.text,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.brown),
                onPressed: _showEditProfileDialog,
                tooltip: 'Edit Profile',
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        // 2. Menu Items
        _buildProfileMenuItem(Icons.pets, 'Pet info', () {}),
        _buildProfileMenuItem(Icons.calendar_today, 'Appointment', () {}),
        _buildProfileMenuItem(
          Icons.settings,
          'Setting',
              () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
          },
        ),

        const Divider(color: Colors.brown, thickness: 1),

        // 3. Log out button
        _buildProfileMenuItem(
          Icons.logout,
          'Log out',
              () {},
          itemColor: Colors.red,
        ),
      ],
    );
  }

  // Helper widget for menu rows
  Widget _buildProfileMenuItem(IconData icon, String title, VoidCallback onTap, {Color? itemColor}) {
    final Color finalColor = itemColor ?? Colors.brown[800]!;
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