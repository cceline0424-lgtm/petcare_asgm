import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:petcare_asgm/VetClinic/appointment_booking_page.dart';

class ClinicDetailsPage extends StatefulWidget {
  final Map<String, dynamic> clinicData;

  const ClinicDetailsPage({super.key, required this.clinicData});

  @override
  State<ClinicDetailsPage> createState() => _ClinicDetailsPageState();
}

class _ClinicDetailsPageState extends State<ClinicDetailsPage> {
  List<dynamic> _pairedSuppliers = [];
  bool _isLoadingSuppliers = true;

  @override
  void initState() {
    super.initState();
    _fetchAndPairMOHSuppliers();
  }

  /// Downloads live MOH pharmaceutical suppliers and pairs only those in the same State
  Future<void> _fetchAndPairMOHSuppliers() async {
    try {
      final response = await http.get(
        Uri.parse('https://data.moh.gov.my/api/data-catalogue?id=pharmaceutical_wholesalers'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> allSuppliers = json.decode(utf8.decode(response.bodyBytes));
        final String clinicState = widget.clinicData['state'] ?? 'W.P. Kuala Lumpur';

        // Regional state matching logic
        final matched = allSuppliers.where((supplier) {
          final sState = (supplier['state'] ?? '').toString().trim().toLowerCase();
          final cState = clinicState.trim().toLowerCase();
          return sState == cState || sState.contains(cState) || cState.contains(sState);
        }).toList();

        if (mounted) {
          setState(() {
            _pairedSuppliers = matched;
            _isLoadingSuppliers = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSuppliers = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = isDark ? Colors.white : Colors.brown[800]!;
    final Color textColor = isDark ? Colors.grey[200]! : Colors.brown[900]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinic Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
        titleTextStyle: TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section: Picture & Name
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: primaryColor, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      widget.clinicData['photoUrl'],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.clinicData['name'],
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.brown[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.clinicData['state'],
                          style: TextStyle(color: Colors.brown[900], fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(thickness: 1.5),

            // Provided details (Matching Sketch 2)
            _buildDetailField('provided service :', 'General Consultation, Vaccination, Surgery, Grooming, Dental'),
            _buildDetailField('location :', widget.clinicData['address']),
            _buildDetailField('Business hours :', widget.clinicData['opening_hours']),
            _buildDetailField('contact number :', widget.clinicData['phone']),

            const SizedBox(height: 16),
            const Divider(thickness: 1.5),

            // MOH Regional Supplier Subsection
            Text(
              '— Authorized Suppliers in ${widget.clinicData['state']} —',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor),
            ),
            const SizedBox(height: 8),

            _isLoadingSuppliers
                ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                : _pairedSuppliers.isEmpty
                ? Text('No registered wholesalers recorded for this state.', style: TextStyle(color: Colors.grey[600], fontSize: 12))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pairedSuppliers.length > 5 ? 5 : _pairedSuppliers.length,
              itemBuilder: (context, idx) {
                final s = _pairedSuppliers[idx];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${idx + 1}. ', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                      Expanded(
                        child: Text(
                          '${s['company']} (${s['address'] ?? 'Official Distributor'})',
                          style: TextStyle(fontSize: 12, color: textColor),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Select Appointment Button (Leads to Screens 3 & 4)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[700],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.calendar_month, color: Colors.white),
                label: const Text('Book Appointment', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AppointmentBookingPage(clinicData: widget.clinicData),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}