import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petcare_asgm/VetClinic/appointment_storage.dart';
import 'package:petcare_asgm/UserProfile/pet_info_page.dart';
import 'package:petcare_asgm/Auth/auth_service.dart';
import 'package:petcare_asgm/Auth/database_helper.dart';
import 'package:petcare_asgm/main.dart';

class AppointmentBookingPage extends StatefulWidget {
  final Map<String, dynamic> clinicData;

  const AppointmentBookingPage({super.key, required this.clinicData});

  @override
  State<AppointmentBookingPage> createState() => _AppointmentBookingPageState();
}

class _AppointmentBookingPageState extends State<AppointmentBookingPage> {
  int _currentStep = 0;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTimeSlot = '10:00 AM';

  final List<String> _timeSlots = [
    '09:30 AM',
    '10:00 AM',
    '11:30 AM',
    '12:00 PM',
    '02:30 PM',
    '03:30 PM',
    '04:30 PM',
    '05:30 PM',
  ];

  String _selectedService = 'General Consultation';
  final List<String> _services = [
    'General Consultation',
    'Vaccination & De-worming',
    'Neutering / Spaying',
    'Dental Cleaning',
    'Grooming & Hygiene',
    'Surgery / Minor Procedure',
  ];

  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  List<PetRecord> _myPets = [];
  PetRecord? _selectedPet;
  bool _isLoadingPets = true;

  @override
  void initState() {
    super.initState();
    _loadPets();
    _loadUserProfileData();
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfileData() async {
    final username = await AuthService.getLoggedInUsername();
    if (username != null) {
      final user = await DatabaseHelper.instance.getUserByUsername(username);
      if (user != null && mounted) {
        setState(() {
          String rawContact = user['phone'] ?? '';
          if (rawContact.startsWith('+60')) {
            rawContact = rawContact.substring(3);
          }
          _phoneController.text = rawContact;
        });
      }
    }
  }

  Future<void> _loadPets() async {
    setState(() {
      _isLoadingPets = true;
    });

    final currentUser = await AuthService.getLoggedInUsername();
    if (currentUser == null) {
      if (mounted) setState(() => _isLoadingPets = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final List<String>? manualPetsJson = prefs.getStringList('my_pets_$currentUser');
    final List<String>? adoptedPetsJson = prefs.getStringList('user_adopted_pets_$currentUser');

    List<PetRecord> loadedPets = [];

    if (manualPetsJson != null) {
      for (String jsonStr in manualPetsJson) {
        try {
          loadedPets.add(PetRecord.fromJson(jsonDecode(jsonStr)));
        } catch (e) {}
      }
    }

    if (adoptedPetsJson != null) {
      for (String jsonStr in adoptedPetsJson) {
        try {
          final data = jsonDecode(jsonStr);
          data['isAdopted'] = true;
          data['age'] = data['age']?.toString().replaceAll(' Years', '').replaceAll(' Year', '').replaceAll(' Months', '');
          loadedPets.add(PetRecord.fromJson(data));
        } catch (e) {}
      }
    }

    if (mounted) {
      setState(() {
        _myPets = loadedPets;
        if (_myPets.isNotEmpty) {
          _selectedPet = _myPets.first;
        }
        _isLoadingPets = false;
      });
    }
  }

  Future<void> _pickCustomDate(Color primaryColor) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
              primary: primaryColor,
              onPrimary: Colors.black,
              onSurface: Colors.white,
              surface: Colors.grey[850]!,
            )
                : ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.brown[900]!,
              surface: Colors.white,
            ),
            dialogBackgroundColor: isDark ? Colors.grey[900] : Colors.white,
            datePickerTheme: DatePickerThemeData(
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: Colors.red,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: primaryColor,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submitAppointment(Color primaryColor) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pet for the appointment.')),
      );
      return;
    }

    Map<String, dynamic> newAppointment = {
      'clinicName': widget.clinicData['name'],
      'date': '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
      'time': _selectedTimeSlot,
      'service': _selectedService,
      'petName': _selectedPet!.name,
      'ownerName': _ownerNameController.text.trim(),
    };

    await AppointmentStorage.saveAppointment(newAppointment);

    notificationSignal.value++;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: primaryColor, size: 28),
            const SizedBox(width: 8),
            const Text('Booking Confirmed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text('Your appointment at ${widget.clinicData['name']} has been securely saved to your phone!'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = isDark ? Colors.white : Colors.brown[800]!;
    final Color cardBackground = isDark ? Colors.grey[850]! : Colors.white;
    final Color textColor = isDark ? Colors.grey[200]! : Colors.brown[900]!;
    final Color lockedFieldColor = isDark ? Colors.grey[900]! : Colors.grey[200]!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_currentStep == 0 ? 'Select Date & Slot' : 'Book Appointment'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
        titleTextStyle: TextStyle(
          color: primaryColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep == 1) {
              setState(() {
                _currentStep = 0;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: _currentStep == 0
              ? _buildStep1DateSelection(primaryColor, cardBackground, textColor, isDark)
              : _buildStep2BookingForm(primaryColor, cardBackground, textColor, lockedFieldColor, isDark),
        ),
      ),
    );
  }

  Widget _buildStep1DateSelection(Color primaryColor, Color cardBackground, Color textColor, bool isDark) {
    const List<String> monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primaryColor, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.local_hospital, color: primaryColor, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.clinicData['name'] ?? 'Clinic',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.clinicData['address'] ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Select Appointment Date',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primaryColor, width: 1.5),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedDate.year}  ${monthNames[_selectedDate.month - 1]}',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                  IconButton(
                    icon: Icon(Icons.calendar_month_rounded, color: primaryColor),
                    onPressed: () => _pickCustomDate(primaryColor),
                  ),
                ],
              ),
              const Divider(thickness: 1),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(7, (index) {
                    final date = DateTime.now().add(Duration(days: index + 1));
                    final isSelected = date.day == _selectedDate.day &&
                        date.month == _selectedDate.month &&
                        date.year == _selectedDate.year;

                    const daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = date;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor : primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: primaryColor, width: 1),
                        ),
                        child: Column(
                          children: [
                            Text(
                              daysOfWeek[date.weekday - 1],
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? Theme.of(context).scaffoldBackgroundColor : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Theme.of(context).scaffoldBackgroundColor : textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Select Time Slot',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _timeSlots.map((slot) {
            final isSelected = _selectedTimeSlot == slot;
            return ChoiceChip(
              label: Text(
                slot,
                style: TextStyle(
                  color: isSelected ? Theme.of(context).scaffoldBackgroundColor : primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: isSelected,
              selectedColor: primaryColor,
              backgroundColor: cardBackground,
              checkmarkColor: isSelected ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: primaryColor),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedTimeSlot = slot;
                  });
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() {
                _currentStep = 1;
              });
            },
            child: Text(
              'Select',
              style: TextStyle(
                  color: isDark ? Colors.brown[900] : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2BookingForm(Color primaryColor, Color cardBackground, Color textColor, Color lockedFieldColor, bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Date :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          InkWell(
            onTap: () {
              _pickCustomDate(primaryColor);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cardBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor, width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} ($_selectedTimeSlot)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                  ),
                  Icon(Icons.calendar_today, size: 18, color: primaryColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Service(s) :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedService,
            decoration: InputDecoration(
              filled: true,
              fillColor: cardBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _services.map((s) {
              return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedService = val);
            },
          ),
          const SizedBox(height: 14),
          const Text('Owner Name :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _ownerNameController,
            decoration: InputDecoration(
              hintText: 'e.g. Tan Ah Kow',
              filled: true,
              fillColor: cardBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter owner name' : null,
          ),
          const SizedBox(height: 14),
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
                child: Text(
                    '🇲🇾 +60',
                    style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 16
                    )
                ),
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
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Select Pet :',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor),
          ),
          const Divider(thickness: 1.2),
          const SizedBox(height: 8),
          if (_isLoadingPets)
            Center(child: CircularProgressIndicator(color: primaryColor))
          else if (_myPets.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.brown[900] : Colors.brown[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.pets, size: 40, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text('No pets found.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PetInfoPage())).then((_) => _loadPets());
                    },
                    child: const Text('Add a Pet', style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _myPets.length,
                itemBuilder: (context, index) {
                  final pet = _myPets[index];
                  final isSelected = _selectedPet?.name == pet.name;

                  ImageProvider? petImage;
                  if (pet.imagePath.isNotEmpty) {
                    if (pet.isAdopted) {
                      petImage = NetworkImage(pet.imagePath);
                    } else {
                      petImage = FileImage(File(pet.imagePath));
                    }
                  }

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPet = pet;
                      });
                    },
                    child: Container(
                      width: 110,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor.withValues(alpha: 0.1) : cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? primaryColor : Colors.grey.withValues(alpha: 0.4),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.brown[100],
                                  backgroundImage: petImage,
                                  child: petImage == null ? Icon(Icons.pets, color: Colors.brown[400]) : null,
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                                  child: const Icon(Icons.check, size: 16, color: Colors.white),
                                )
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pet.name,
                            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            pet.species,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                  });
                },
                child: Text('Back', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => _submitAppointment(primaryColor),
                child: Text(
                    'Confirm',
                    style: TextStyle(
                        color: isDark ? Colors.brown[900] : Colors.white,
                        fontWeight: FontWeight.bold
                    )
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}