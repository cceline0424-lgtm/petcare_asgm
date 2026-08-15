import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ClinicDetailsPage extends StatefulWidget {
  // This variable catches the data passed from Screen 1
  final Map<String, dynamic> clinicData;

  const ClinicDetailsPage({super.key, required this.clinicData});

  @override
  State<ClinicDetailsPage> createState() => _ClinicDetailsPageState();
}

class _ClinicDetailsPageState extends State<ClinicDetailsPage> {
  List<dynamic> matchedSuppliers = [];
  bool isLoadingSuppliers = true;

  @override
  void initState() {
    super.initState();
    // Start fetching the suppliers as soon as the page opens!
    _fetchAndMatchSuppliers();
  }

  Future<void> _fetchAndMatchSuppliers() async {
    try {
      // 1. Fetch the live dataset from the MOH link
      final url = Uri.parse('https://data.moh.gov.my/api/data-catalogue?id=pharmaceutical_wholesalers');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> allSuppliers = json.decode(response.body);

        // 2. The Pairing Logic: Filter suppliers to match the clinic's state!
        String targetState = widget.clinicData['state'];

        setState(() {
          matchedSuppliers = allSuppliers.where((supplier) {
            return supplier['state'] == targetState;
          }).toList();
          isLoadingSuppliers = false;
        });
      }
    } catch (e) {
      print("Error fetching MOH data: $e");
      setState(() {
        isLoadingSuppliers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color primaryColor = isDark ? Colors.white : Colors.brown[800]!;
    Color textColor = isDark ? Colors.grey[300]! : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // TOP SECTION: Picture & Clinic Name
            // ==========================================
            Row(
              children: [
                // Clinic Picture
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: primaryColor, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    image: widget.clinicData['photoUrl'] != ''
                        ? DecorationImage(
                      image: NetworkImage(widget.clinicData['photoUrl']),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: widget.clinicData['photoUrl'] == ''
                      ? Icon(Icons.pets, size: 40, color: primaryColor)
                      : null,
                ),
                const SizedBox(width: 16),

                // Clinic Name
                Expanded(
                  child: Text(
                    widget.clinicData['name'],
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(thickness: 1.5),
            const SizedBox(height: 16),

            // ==========================================
            // MIDDLE SECTION: Clinic Details (Matching your wireframe)
            // ==========================================
            _buildDetailRow("Provided service:", "Vaccination, Surgery, General Checkup", textColor),
            _buildDetailRow("Location:", widget.clinicData['address'], textColor),
            _buildDetailRow("Business hours:", "9:00 AM - 6:00 PM (Mon-Sat)", textColor),
            _buildDetailRow("Opening date:", "Est. 2018", textColor),

            const SizedBox(height: 24),
            const Divider(thickness: 1.5),
            const SizedBox(height: 16),

            // ==========================================
            // BOTTOM SECTION: Paired Supplier List
            // ==========================================
            Text(
              "- Suppliers in ${widget.clinicData['state']} -",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: isLoadingSuppliers
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : matchedSuppliers.isEmpty
                  ? Text("No official suppliers found for this region.", style: TextStyle(color: textColor))
                  : ListView.builder(
                itemCount: matchedSuppliers.length,
                itemBuilder: (context, index) {
                  final supplier = matchedSuppliers[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text("${index + 1}.", style: TextStyle(fontSize: 16, color: textColor)),
                    title: Text(supplier['company'] ?? 'Unknown Company', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                    subtitle: Text(supplier['address'] ?? 'No Address', style: TextStyle(color: textColor)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // A helper widget to make the text layout look exactly like your sketch
  Widget _buildDetailRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140, // Fixed width so the colons align perfectly
            child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 16, color: textColor)),
          ),
        ],
      ),
    );
  }
}