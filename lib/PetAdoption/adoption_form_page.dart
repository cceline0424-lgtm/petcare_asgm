import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petcare_asgm/Auth/auth_service.dart';
import 'package:petcare_asgm/Auth/database_helper.dart';
import 'package:petcare_asgm/UserProfile/pet_info_page.dart';

class AdoptionFormPage extends StatefulWidget {
  final Map<String, dynamic> petData;

  const AdoptionFormPage({super.key, required this.petData});

  @override
  State<AdoptionFormPage> createState() => _AdoptionFormPageState();
}

class _AdoptionFormPageState extends State<AdoptionFormPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _adopterNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  final TextEditingController _icPart1 = TextEditingController();
  final TextEditingController _icPart2 = TextEditingController();
  final TextEditingController _icPart3 = TextEditingController();

  final FocusNode _icNode1 = FocusNode();
  final FocusNode _icNode2 = FocusNode();
  final FocusNode _icNode3 = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadUserProfileData();
  }

  Future<void> _loadUserProfileData() async {
    final username = await AuthService.getLoggedInUsername();

    if (username != null) {
      final user = await DatabaseHelper.instance.getUserByUsername(username);

      if (user != null && mounted) {
        setState(() {
          _emailController.text = user['email'] ?? '';

          String rawContact = user['phone'] ?? '';
          if (rawContact.startsWith('+60')) {
            rawContact = rawContact.substring(3);
          }
          _phoneController.text = rawContact;
        });
      }
    }
  }

  @override
  void dispose() {
    _adopterNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _reasonController.dispose();
    _icPart1.dispose();
    _icPart2.dispose();
    _icPart3.dispose();
    _icNode1.dispose();
    _icNode2.dispose();
    _icNode3.dispose();
    super.dispose();
  }

  Future<void> _submitAdoptionApplication(Color primaryColor) async {
    if (!_formKey.currentState!.validate()) return;
    if (_icPart1.text.length != 6 || _icPart2.text.length != 2 || _icPart3.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete your 12-digit IC Number correctly.')));
      return;
    }

    final username = await AuthService.getLoggedInUsername();
    final String adoptedPetsKey = 'user_adopted_pets_$username';

    final prefs = await SharedPreferences.getInstance();
    List<String> savedPets = prefs.getStringList(adoptedPetsKey) ?? [];

    Map<String, dynamic> newPetRecord = {
      'name': widget.petData['name'],
      'type': widget.petData['type'],
      'breed': widget.petData['breed'],
      'age': widget.petData['age'],
      'gender': widget.petData['gender'],
      'photoUrl': widget.petData['photoUrl'],
    };

    savedPets.add(jsonEncode(newPetRecord));
    await prefs.setStringList(adoptedPetsKey, savedPets);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Adoption Successful!',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text('Congratulations! ${widget.petData['name']} has been successfully added to your registered pets portfolio.'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const PetInfoPage()),
                    (route) => route.isFirst,
              );
            },
            child: const Text('View Dashboard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = isDark ? Colors.white : Colors.brown[800]!;
    final Color textColor = isDark ? Colors.grey[300]! : Colors.brown[900]!;
    final Color cardBackground = isDark ? Colors.grey[850]! : Colors.white;
    final Color lockedFieldColor = isDark ? Colors.grey[900]! : Colors.grey[200]!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Adoption Application'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
        titleTextStyle: TextStyle(
          color: primaryColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adopt ${widget.petData['name']} 🐾',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please review and complete your details below. This information will be used to process your adoption request.',
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(height: 24),

                const Text('Full Name :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _adopterNameController,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-\']")),
                  ],
                  decoration: InputDecoration(
                    hintText: 'e.g. Siti Nurhaliza',
                    filled: true,
                    fillColor: cardBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your full name' : null,
                ),
                const SizedBox(height: 16),

                const Text('IC Number :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _icPart1,
                        focusNode: _icNode1,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onChanged: (val) {
                          if (val.length == 6) FocusScope.of(context).requestFocus(_icNode2);
                        },
                        decoration: InputDecoration(
                          hintText: 'XXXXXX',
                          filled: true,
                          fillColor: cardBackground,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _icPart2,
                        focusNode: _icNode2,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        onChanged: (val) {
                          if (val.length == 2) FocusScope.of(context).requestFocus(_icNode3);
                          if (val.isEmpty) FocusScope.of(context).requestFocus(_icNode1);
                        },
                        decoration: InputDecoration(
                          hintText: 'XX',
                          filled: true,
                          fillColor: cardBackground,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _icPart3,
                        focusNode: _icNode3,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        onChanged: (val) {
                          if (val.isEmpty) FocusScope.of(context).requestFocus(_icNode2);
                        },
                        decoration: InputDecoration(
                          hintText: 'XXXX',
                          filled: true,
                          fillColor: cardBackground,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text('Email Address :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  readOnly: true,
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: lockedFieldColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Phone Number :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 48,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: lockedFieldColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('🇲🇾 +60', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        readOnly: true,
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: lockedFieldColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text('Home Address :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Where will the pet be staying?',
                    filled: true,
                    fillColor: cardBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your address' : null,
                ),
                const SizedBox(height: 16),

                const Text('Why do you want to adopt?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Share a bit about your home environment and experience with pets...',
                    filled: true,
                    fillColor: cardBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a brief note' : null,
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: () => _submitAdoptionApplication(primaryColor),
                    child: const Text(
                      'Submit Application',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}