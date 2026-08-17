import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:petcare_asgm/VetClinic/appointment_booking_page.dart';

class ClinicDetailsPage extends StatefulWidget {
  final Map<String, dynamic> clinicData;

  const ClinicDetailsPage({super.key, required this.clinicData});

  @override
  State<ClinicDetailsPage> createState() => _ClinicDetailsPageState();
}

class _ClinicDetailsPageState extends State<ClinicDetailsPage> {
  List<Map<String, String>> _matchedSuppliers = [];
  bool _isLoadingSuppliers = true;

  final List<String> _servicePool = [
    'General Consultation, Vaccination, Surgery',
    'General Consultation, Dental Cleaning, Pet Grooming',
    'Vaccination, Neutering / Spaying, Internal Medicine',
    'General Checkup, Diagnostic Imaging, Surgery',
    'Vaccination, Exotic Pet Care, Pharmacy',
    'General Consultation, Microchipping, Pet Boarding',
    'Emergency Care, Vaccination, Ultrasound',
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalSuppliers();
  }

  Future<void> _loadLocalSuppliers() async {
    try {
      final String csvData = await rootBundle.loadString('assets/pharmaceutical_wholesalers.csv');
      List<List<dynamic>> csvTable = const CsvToListConverter(eol: '\n').convert(csvData);

      if (csvTable.isNotEmpty) {
        csvTable.removeAt(0);
      }

      String clinicState = widget.clinicData['state']?.toString().toLowerCase().trim() ?? '';
      if (clinicState.contains('wilayah') || clinicState.contains('kuala lumpur')) {
        clinicState = 'w.p. kuala lumpur';
      }

      List<Map<String, String>> foundSuppliers = [];

      for (var row in csvTable) {
        if (row.length >= 10) {
          String supplierName = row[0].toString().trim();
          String supplierState = row[1].toString().toLowerCase().trim();
          String supplierAddress = row[3].toString().trim();
          bool isVetSupplier = (row[8].toString() == '1' || row[9].toString() == '1');

          if (supplierState == clinicState && isVetSupplier) {
            foundSuppliers.add({
              'name': supplierName,
              'address': supplierAddress,
            });
          }
        }
      }

      if (foundSuppliers.isEmpty) {
        foundSuppliers = [
          {'name': 'ZUELLIG PHARMA SDN BHD', 'address': 'No 15 Persiaran Pasak Bumi, Seksyen U8 Perindustrian Bukit Jelutong'},
          {'name': 'Y. S. P. INDUSTRIES (M) SDN BHD', 'address': 'Lot 3, 5 & 7, Jalan P/7, Section 13, Kawasan Perindustrian Bandar Baru Bangi'},
        ];
      }

      if (mounted) {
        setState(() {
          _matchedSuppliers = foundSuppliers.take(4).toList();
          _isLoadingSuppliers = false;
        });
      }
    } catch (e) {
      print('Error reading CSV: $e');
      if (mounted) {
        setState(() {
          _isLoadingSuppliers = false;
        });
      }
    }
  }

  String _getUniqueServices(String clinicName) {
    int index = clinicName.length % _servicePool.length;
    return _servicePool[index];
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = isDark ? Colors.white : Colors.brown[800]!;
    final Color textColor = isDark ? Colors.grey[300]! : Colors.brown[900]!;
    final Color cardBackground = isDark ? Colors.grey[850]! : Colors.white;
    String providedServices = _getUniqueServices(widget.clinicData['name'] ?? '');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Clinic Details'),
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor, width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 110,
                        height: 110,
                        child: Image.network(
                          widget.clinicData['photoUrl'] ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.brown[100],
                              child: Icon(Icons.local_hospital_rounded, color: Colors.brown[800], size: 40),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.clinicData['name'] ?? 'Unknown Clinic',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              widget.clinicData['state'] ?? 'Malaysia',
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Provided Service', providedServices, isDark),
                    const Divider(height: 24, thickness: 1),
                    _buildDetailRow('Location', widget.clinicData['address'] ?? 'No address provided', isDark),
                    const Divider(height: 24, thickness: 1),
                    _buildDetailRow('Business Hours', '9:00 AM - 6:00 PM (Mon - Sat)', isDark),
                    const Divider(height: 24, thickness: 1),
                    _buildDetailRow('Contact Number', widget.clinicData['phone'] ?? 'N/A', isDark),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Authorized Suppliers in ${widget.clinicData['state']}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor, width: 1.5),
                ),
                child: _isLoadingSuppliers
                    ? Center(child: CircularProgressIndicator(color: primaryColor))
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(_matchedSuppliers.length, (index) {
                    final supplier = _matchedSuppliers[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1}. ',
                            style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 15),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supplier['name']!,
                                  style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  supplier['address']!,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
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
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AppointmentBookingPage(clinicData: widget.clinicData),
                      ),
                    );
                  },
                  child: Text(
                    'Select Appointment',
                    style: TextStyle(
                      color: isDark ? Colors.brown[900] : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? Colors.grey[200] : Colors.brown[900], height: 1.3),
        ),
      ],
    );
  }
}