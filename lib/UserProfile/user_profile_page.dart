import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:petcare_asgm/UserProfile/setting.dart';
import 'package:petcare_asgm/UserProfile/my_appointments_page.dart';
import 'package:petcare_asgm/Auth/auth_service.dart';
import 'package:petcare_asgm/Auth/welcome_page.dart';
import 'package:petcare_asgm/UserProfile/pet_info_page.dart';
import 'package:petcare_asgm/Auth/database_helper.dart';
import 'package:petcare_asgm/Auth/email_service.dart';

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

  String _originalEmail = "";
  File? _image;
  String? _photoUrl;
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

  /// Resolves the profile photo to show: the just-picked local file takes
  /// priority, otherwise the saved photo path - which is a local on-device
  /// path for photos saved under the new scheme, or (for accounts that
  /// still have one) a legacy Firebase Storage network URL.
  ImageProvider? get _profilePhoto {
    if (_image != null) return FileImage(_image!);
    if (_photoUrl == null) return null;
    return _photoUrl!.startsWith('http') ? NetworkImage(_photoUrl!) : FileImage(File(_photoUrl!));
  }

  Future<void> _loadProfileInfo() async {
    final authUser = FirebaseAuth.instance.currentUser;
    final currentUser = await AuthService.getLoggedInUsername() ?? widget.username;
    final dbUser = await DatabaseHelper.instance.getUserByUsername(currentUser);

    if (!mounted) return;
    setState(() {
      if (dbUser != null) {
        _nameCtrl.text = dbUser['name'] ?? currentUser;

        // Firebase Auth's own email is the one that actually changes once a
        // pending "confirm your new email" link is clicked, so it's the
        // authoritative source here rather than the Firestore copy (which
        // only updates after that confirmation happens).
        _emailCtrl.text = authUser?.email ?? dbUser['email'] ?? "";

        String rawContact = dbUser['phone'] ?? "";
        if (rawContact.startsWith('+60')) {
          rawContact = rawContact.substring(3);
        }
        _contactCtrl.text = rawContact;
        _photoUrl = dbUser['photoUrl'] as String?;
      } else {
        _nameCtrl.text = currentUser;
        _emailCtrl.text = authUser?.email ?? "";
        _contactCtrl.text = "";
      }

      _image = null;
      _originalEmail = _emailCtrl.text.trim();
    });
  }

  Future<void> _performSave() async {
    final authUser = FirebaseAuth.instance.currentUser;
    final currentUser = await AuthService.getLoggedInUsername() ?? widget.username;

    String phoneToSave = _contactCtrl.text.trim();
    String dbPhone = phoneToSave.startsWith('+60') ? phoneToSave : '+60$phoneToSave';

    final newEmail = _emailCtrl.text.trim();
    final emailChanged = newEmail.isNotEmpty && newEmail != _originalEmail;

    try {
      await DatabaseHelper.instance.updateUserProfile(
        currentUser,
        _nameCtrl.text.trim(),
        // Don't write the new email into Firestore yet - it isn't real
        // until the user confirms it via the link Firebase sends below, so
        // writing it immediately would break username-based login lookups
        // in the meantime.
        emailChanged ? _originalEmail : newEmail,
        dbPhone,
      );

      await authUser?.updateDisplayName(_nameCtrl.text.trim());

      if (emailChanged && authUser != null) {
        // Firebase requires its own re-verification step to change the
        // actual login email, even though the OTP step already proved
        // ownership of the new address - this sends that confirmation link.
        await authUser.verifyBeforeUpdateEmail(newEmail);
      }

      if (_image != null && authUser != null) {
        // Saved to this device's own documents folder rather than Firebase
        // Storage - only Firestore's small 'photoUrl' string is synced to
        // the cloud, so no billing plan is needed. The profile photo only
        // ever needs to be visible on the owner's own device anyway.
        final docsDir = await getApplicationDocumentsDirectory();
        final profilePhotosDir = Directory('${docsDir.path}/profile_photos');
        if (!await profilePhotosDir.exists()) {
          await profilePhotosDir.create(recursive: true);
        }
        final ext = _image!.path.contains('.') ? _image!.path.substring(_image!.path.lastIndexOf('.')) : '.jpg';
        final savedPath = '${profilePhotosDir.path}/${authUser.uid}$ext';
        await _image!.copy(savedPath);

        await FirebaseFirestore.instance.collection('users').doc(authUser.uid).set(
          {'photoUrl': savedPath},
          SetOptions(merge: true),
        );
        _photoUrl = savedPath;
      }

      setState(() {
        _image = null;
        if (!emailChanged) _originalEmail = newEmail;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(emailChanged
              ? 'Profile saved! Check your new email for a link to confirm the change.'
              : 'Profile Info Saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Email or Phone is already taken by another account.')),
        );
        _loadProfileInfo();
      }
    }
  }

  Future<void> _sendOtpAndShowDialog(String newEmail) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.brown)),
    );

    final random = Random();
    String generatedOtp = (100000 + random.nextInt(900000)).toString();

    final sent = await EmailService.sendOtpEmail(recipientEmail: newEmail, otp: generatedOtp);

    if (!mounted) return;
    Navigator.pop(context);

    if (sent) {
      _showOtpVerificationDialog(newEmail, generatedOtp);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send verification email. Please try again.')),
      );
      _showEditProfileDialog();
    }
  }

  void _showOtpVerificationDialog(String newEmail, String initialOtp) {
    final TextEditingController otpController = TextEditingController();
    bool isConfirming = false;
    String currentOtp = initialOtp;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isDark = Theme.of(context).brightness == Brightness.dark;
        Color textColor = isDark ? Colors.white : Colors.black;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? Colors.grey[850] : Colors.white,
              title: Text('Verify Email', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter the 6-digit code sent to $newEmail',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: TextStyle(letterSpacing: 8, fontSize: 18, color: textColor, fontWeight: FontWeight.bold),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'XXXXXX',
                      hintStyle: const TextStyle(letterSpacing: 4),
                      filled: true,
                      fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () async {
                        setDialogState(() => isConfirming = true);

                        final random = Random();
                        currentOtp = (100000 + random.nextInt(900000)).toString();
                        final sent = await EmailService.sendOtpEmail(recipientEmail: newEmail, otp: currentOtp);

                        if (sent) {
                          setDialogState(() => isConfirming = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A new code has been sent.')));
                          }
                        } else {
                          setDialogState(() => isConfirming = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to resend code.')));
                          }
                        }
                      },
                      child: const Text(
                        'Resend code',
                        style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditProfileDialog();
                  },
                  child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown[700],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                  onPressed: isConfirming ? null : () {
                    if (otpController.text.trim() == currentOtp) {
                      Navigator.pop(context);
                      _performSave();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect code. Please try again.')));
                    }
                  },
                  child: isConfirming
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Verify', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
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
                              backgroundImage: _profilePhoto,
                              child: (_image == null && _photoUrl == null)
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

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 56,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.6)),
                            ),
                            child: Text(
                                '🇲🇾 +60',
                                style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16
                                )
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _contactCtrl,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                border: OutlineInputBorder(),
                                hintText: '123456789',
                              ),
                            ),
                          ),
                        ],
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
                    child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700]),
                    onPressed: () {
                      final newEmail = _emailCtrl.text.trim();

                      Navigator.pop(context);

                      if (newEmail.isNotEmpty && newEmail != _originalEmail) {
                        _sendOtpAndShowDialog(newEmail);
                      } else {
                        _performSave();
                      }
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

  Future<void> _logout() async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout_rounded, color: Colors.red, size: 32),
                ),
                const SizedBox(height: 20),
                Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to log out of your account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text(
                          'Log Out',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    await AuthService.logout();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    Color primaryColor = isDark ? Colors.white : Colors.brown[800]!;
    Color subTextColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;
    Color cardBgColor = isDark ? Colors.grey[850]! : Colors.white;
    Color borderColor = isDark ? Colors.brown[300]! : Colors.brown;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: Colors.brown,
                backgroundImage: _profilePhoto,
                child: (_image == null && _photoUrl == null)
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 14, color: subTextColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _contactCtrl.text.isEmpty ? "Not set" : '+60${_contactCtrl.text}',
                            style: TextStyle(fontSize: 13, color: subTextColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.email_outlined, size: 14, color: subTextColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _emailCtrl.text.isEmpty ? "Not set" : _emailCtrl.text,
                            style: TextStyle(fontSize: 13, color: subTextColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: primaryColor, size: 22),
                onPressed: _showEditProfileDialog,
                tooltip: 'Edit Profile',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        _buildProfileMenuItem(Icons.pets, 'Pet info', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PetInfoPage()),
          );
        }, isDark: isDark),
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

        Divider(color: borderColor.withValues(alpha: 0.3), thickness: 1),

        _buildProfileMenuItem(
          Icons.logout,
          'Log out',
          _logout,
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