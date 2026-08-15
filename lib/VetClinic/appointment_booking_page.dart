import 'package:flutter/material.dart';

class AppointmentBookingPage extends StatefulWidget {
  final Map<String, dynamic> clinicData;

  const AppointmentBookingPage({super.key, required this.clinicData});

  @override
  State<AppointmentBookingPage> createState() => _AppointmentBookingPageState();
}

class _AppointmentBookingPageState extends State<AppointmentBookingPage> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedService = 'General Checkup';
  String _petGender = 'F';

  final _ownerNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _petNameCtrl = TextEditingController();
  final _petAgeCtrl = TextEditingController(text: '1');
  final _petBreedCtrl = TextEditingController();

  final List<String> _services = [
    'General Checkup',
    'Vaccination',
    'Neutering / Spaying',
    'Dental Cleaning',
    'Grooming & Spa',
  ];

  @override
  void dispose() {
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _petNameCtrl.dispose();
    _petAgeCtrl.dispose();
    _petBreedCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.brown[700]!),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _confirmBooking() {
    if (_ownerNameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty || _petNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all mandatory booking fields.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Appointment Confirmed!'),
        content: Text(
          'Booked at ${widget.clinicData['name']} for ${_petNameCtrl.text} on ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700]),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        iconTheme: IconThemeData(color: primaryColor),
        titleTextStyle: TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Selection (Wireframe 3)
            const Text('Date :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: primaryColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_selectedDate.day} / ${_selectedDate.month} / ${_selectedDate.year}'),
                    const Icon(Icons.calendar_month, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Service Selection
            const Text('Service(s) :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedService,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              items: _services.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _selectedService = val!),
            ),
            const SizedBox(height: 14),

            // Owner Details
            const Text('Owner Name :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(controller: _ownerNameCtrl, decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 14),

            const Text('Phone Number :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 18),
            const Divider(),

            // Pet Details Header
            Text('Pet Details :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryColor)),
            const SizedBox(height: 10),

            const Text('Name :'),
            TextField(controller: _petNameCtrl, decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Age :'),
                      TextField(controller: _petAgeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder())),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gender :'),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('F'),
                            selected: _petGender == 'F',
                            onSelected: (_) => setState(() => _petGender = 'F'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('M'),
                            selected: _petGender == 'M',
                            onSelected: (_) => setState(() => _petGender = 'M'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const Text('Breed :'),
            TextField(controller: _petBreedCtrl, decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 24),

            // Confirm / Back Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700]),
                  onPressed: _confirmBooking,
                  child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}