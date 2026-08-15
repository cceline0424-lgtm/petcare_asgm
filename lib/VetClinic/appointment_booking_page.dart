import 'package:flutter/material.dart';

class AppointmentBookingPage extends StatefulWidget {
  final Map<String, dynamic> clinicData;

  const AppointmentBookingPage({super.key, required this.clinicData});

  @override
  State<AppointmentBookingPage> createState() => _AppointmentBookingPageState();
}

class _AppointmentBookingPageState extends State<AppointmentBookingPage> {
  // Step indicator: 0 = Screen 3 (Calendar / Date Selection), 1 = Screen 4 (Booking Form)
  int _currentStep = 0;

  // Selected Date & Time
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTimeSlot = '10:00 AM';

  // Available Time Slots
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

  // Selected Service
  String _selectedService = 'General Consultation';
  final List<String> _services = [
    'General Consultation',
    'Vaccination & De-worming',
    'Neutering / Spaying',
    'Dental Cleaning',
    'Grooming & Hygiene',
    'Surgery / Minor Procedure',
  ];

  // Form Controllers
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _petNameController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();

  int _petAge = 1;
  String _petGender = 'F'; // 'F' or 'M'

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _ownerNameController.dispose();
    _phoneController.dispose();
    _petNameController.dispose();
    _breedController.dispose();
    super.dispose();
  }

  // Pick Date via Calendar Dialog
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

  void _submitAppointment(Color primaryColor) {
    if (!_formKey.currentState!.validate()) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: primaryColor, size: 28),
            const SizedBox(width: 8),
            const Text(
              'Booking Confirmed',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Clinic: ${widget.clinicData['name']}'),
            const SizedBox(height: 6),
            Text('Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} at $_selectedTimeSlot'),
            const SizedBox(height: 6),
            Text('Service: $_selectedService'),
            const SizedBox(height: 6),
            Text('Pet: ${_petNameController.text.trim()} ($_petGender, $_petAge yrs, ${_breedController.text.trim()})'),
            const SizedBox(height: 6),
            Text('Owner: ${_ownerNameController.text.trim()} (${_phoneController.text.trim()})'),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Return to Clinic Details
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
              // If on Step 2, go back to Step 1
              setState(() {
                _currentStep = 0;
              });
            } else {
              // If on Step 1, completely close the page
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
              : _buildStep2BookingForm(primaryColor, cardBackground, textColor, isDark),
        ),
      ),
    );
  }

  // =========================================================
  // SCREEN 3: CALENDAR & APPOINTMENT SLOT SELECTION
  // =========================================================
  Widget _buildStep1DateSelection(Color primaryColor, Color cardBackground, Color textColor, bool isDark) {
    const List<String> monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clinic Summary Card
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

        // Date Display & Picker Box
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

              // Calendar Days Quick Strip
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

        // Available Time Slots
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

        // Next Button (to Screen 4)
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

  // =========================================================
  // SCREEN 4: BOOKING FORM (OWNER & PET DETAILS)
  // =========================================================
  Widget _buildStep2BookingForm(Color primaryColor, Color cardBackground, Color textColor, bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Date Pill (Clickable to open the calendar directly)
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

          // Service Dropdown
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

          // Owner Name
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

          // Phone Number
          const Text('Phone Number :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'e.g. 012-3456789',
              filled: true,
              fillColor: cardBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter phone number' : null,
          ),
          const SizedBox(height: 20),

          // Pet Details Section
          Text(
            'Pet Details :',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor),
          ),
          const Divider(thickness: 1.2),
          const SizedBox(height: 8),

          // Pet Name
          const Text('Name :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _petNameController,
            decoration: InputDecoration(
              hintText: 'e.g. Milo',
              filled: true,
              fillColor: cardBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter pet name' : null,
          ),
          const SizedBox(height: 14),

          // Pet Age & Gender Row
          Row(
            children: [
              // Age Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Age :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _petAge,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: cardBackground,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: List.generate(20, (i) => i + 1).map((age) {
                        return DropdownMenuItem(value: age, child: Text('$age yr${age > 1 ? 's' : ''}'));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _petAge = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Gender Toggle (F / M)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gender :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('F', style: TextStyle(fontWeight: FontWeight.bold)),
                          selected: _petGender == 'F',
                          selectedColor: primaryColor,
                          checkmarkColor: _petGender == 'F' ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
                          labelStyle: TextStyle(color: _petGender == 'F' ? Theme.of(context).scaffoldBackgroundColor : primaryColor),
                          onSelected: (_) => setState(() => _petGender = 'F'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('M', style: TextStyle(fontWeight: FontWeight.bold)),
                          selected: _petGender == 'M',
                          selectedColor: primaryColor,
                          checkmarkColor: _petGender == 'M' ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
                          labelStyle: TextStyle(color: _petGender == 'M' ? Theme.of(context).scaffoldBackgroundColor : primaryColor),
                          onSelected: (_) => setState(() => _petGender = 'M'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Breed
          const Text('Breed :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _breedController,
            decoration: InputDecoration(
              hintText: 'e.g. Domestic Shorthair / Poodle',
              filled: true,
              fillColor: cardBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter breed' : null,
          ),
          const SizedBox(height: 28),

          // Bottom Navigation Buttons [ Back | Confirm ]
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () {
                  setState(() {
                    _currentStep = 0; // Return to Date selection
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