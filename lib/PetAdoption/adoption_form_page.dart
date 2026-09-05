import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petcare_asgm/Auth/auth_service.dart';
import 'package:petcare_asgm/Auth/database_helper.dart';
import 'package:petcare_asgm/UserProfile/pet_info_page.dart';
import 'package:petcare_asgm/VetClinic/vet_clinic_service.dart';

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
  final TextEditingController _addressLine1Controller = TextEditingController();
  final TextEditingController _addressLine2Controller = TextEditingController();
  final TextEditingController _postcodeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  final TextEditingController _icPart1 = TextEditingController();
  final TextEditingController _icPart2 = TextEditingController();
  final TextEditingController _icPart3 = TextEditingController();

  final FocusNode _icNode1 = FocusNode();
  final FocusNode _icNode2 = FocusNode();
  final FocusNode _icNode3 = FocusNode();

  // Malaysia's 13 states + 3 federal territories, minus the "All States"
  // filter option that only makes sense on the clinic list/map.
  static final List<String> _states =
  VetClinicService.malaysiaStates.where((s) => s != 'All States').toList();

  String? _selectedState;
  String? _loggedInUsername;
  Timer? _autoSaveDebounce;

  @override
  void initState() {
    super.initState();
    _loadUserProfileData();

    // Every field that should be remembered gets auto-saved (debounced) as
    // the user types, so they never have to re-type their name/address on
    // a future adoption application.
    _adopterNameController.addListener(_scheduleAutoSave);
    _addressLine1Controller.addListener(_scheduleAutoSave);
    _addressLine2Controller.addListener(_scheduleAutoSave);
    _postcodeController.addListener(_scheduleAutoSave);
    _cityController.addListener(_scheduleAutoSave);
  }

  String _savedProfileKey(String username) => 'adoption_saved_profile_$username';

  Future<void> _loadUserProfileData() async {
    final username = await AuthService.getLoggedInUsername();
    _loggedInUsername = username;
    if (username == null) return;

    final user = await DatabaseHelper.instance.getUserByUsername(username);
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString(_savedProfileKey(username));

    if (!mounted) return;

    setState(() {
      if (user != null) {
        _emailController.text = user['email'] ?? '';

        String rawContact = user['phone'] ?? '';
        if (rawContact.startsWith('+60')) {
          rawContact = rawContact.substring(3);
        }
        _phoneController.text = rawContact;
      }

      if (savedJson != null) {
        try {
          final saved = jsonDecode(savedJson) as Map<String, dynamic>;
          _adopterNameController.text = saved['name'] ?? '';
          _addressLine1Controller.text = saved['addressLine1'] ?? '';
          _addressLine2Controller.text = saved['addressLine2'] ?? '';
          _postcodeController.text = saved['postcode'] ?? '';
          _cityController.text = saved['city'] ?? '';
          final savedState = saved['state'] as String?;
          if (savedState != null && _states.contains(savedState)) {
            _selectedState = savedState;
          }
        } catch (_) {
          // Saved data is corrupted/outdated - just start with blank fields
          // instead of crashing the form.
        }
      }
    });
  }

  /// Debounces auto-save so a fast typist doesn't trigger a disk write on
  /// every single keystroke - it saves ~600ms after the user stops typing.
  void _scheduleAutoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 600), _persistProfile);
  }

  Future<void> _persistProfile() async {
    final username = _loggedInUsername;
    if (username == null) return;

    final prefs = await SharedPreferences.getInstance();
    final data = {
      'name': _adopterNameController.text.trim(),
      'addressLine1': _addressLine1Controller.text.trim(),
      'addressLine2': _addressLine2Controller.text.trim(),
      'state': _selectedState,
      'postcode': _postcodeController.text.trim(),
      'city': _cityController.text.trim(),
    };
    await prefs.setString(_savedProfileKey(username), jsonEncode(data));
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    _adopterNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _postcodeController.dispose();
    _cityController.dispose();
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
                  controller: _addressLine1Controller,
                  decoration: InputDecoration(
                    hintText: 'House no., street name',
                    filled: true,
                    fillColor: cardBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your address' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _addressLine2Controller,
                  decoration: InputDecoration(
                    hintText: 'Taman / apartment / unit no. (optional)',
                    filled: true,
                    fillColor: cardBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: DropdownButtonFormField<String>(
                        value: _selectedState,
                        isExpanded: true,
                        icon: Icon(Icons.keyboard_arrow_down, color: primaryColor),
                        style: TextStyle(color: textColor, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'State',
                          filled: true,
                          fillColor: cardBackground,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: _states
                            .map((state) => DropdownMenuItem(value: state, child: Text(state)))
                            .toList(),
                        onChanged: (val) {
                          setState(() => _selectedState = val);
                          _scheduleAutoSave();
                        },
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: TextFormField(
                        controller: _postcodeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(5),
                        ],
                        decoration: InputDecoration(
                          hintText: 'Postcode',
                          filled: true,
                          fillColor: cardBackground,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (v) =>
                        v == null || v.trim().length != 5 ? '5 digits' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    hintText: 'City',
                    filled: true,
                    fillColor: cardBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your city' : null,
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