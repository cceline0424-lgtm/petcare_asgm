import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:excel/excel.dart' hide Border;
import 'package:petcare_asgm/VetClinic/clinic_details_page.dart';

class VetClinicPage extends StatefulWidget {
  const VetClinicPage({super.key});

  @override
  State<VetClinicPage> createState() => _VetClinicPageState();
}

class _VetClinicPageState extends State<VetClinicPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allClinics = [];
  List<Map<String, dynamic>> _displayedClinics = [];

  String _selectedState = 'All States';
  bool _isLoading = true;

  final List<String> _malaysiaStates = [
    'All States',
    'W.P. Kuala Lumpur',
    'Selangor',
    'Johor',
    'Pulau Pinang',
    'Perak',
    'Melaka',
    'Negeri Sembilan',
    'Pahang',
    'Kedah',
    'Kelantan',
    'Terengganu',
    'Sabah',
    'Sarawak',
  ];

  final List<String> _clinicPhotos = [
    'https://images.unsplash.com/photo-1586773860418-d37222d8fce3?w=500&q=80',
    'https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?w=500&q=80',
    'https://images.unsplash.com/photo-1512678080530-7760d81faba6?w=500&q=80',
    'https://images.unsplash.com/photo-1538108149393-fbbd81895907?w=500&q=80',
    'https://images.unsplash.com/photo-1514416432279-50fac261c4dd?w=500&q=80',
    'https://images.unsplash.com/photo-1576091160550-2173ff3e52bf?w=500&q=80',
    'https://images.unsplash.com/photo-1581056771107-11a4208a0d9e?w=500&q=80',
    'https://images.unsplash.com/photo-1624727828456-0ba4637e77a2?w=500&q=80',
    'https://images.unsplash.com/photo-1584982751601-0571224f1661?w=500&q=80',
    'https://images.unsplash.com/photo-1516574187841-cb9cc2ca948b?w=500&q=80',
    'https://images.unsplash.com/photo-1497366216548-37526070297c?w=500&q=80',
    'https://images.unsplash.com/photo-1497366754045-fad886134a41?w=500&q=80',
    'https://images.unsplash.com/photo-1504328345606-18bbc8c9d7d1?w=500&q=80',
    'https://images.unsplash.com/photo-1551601651-2a8555f1a136?w=500&q=80',
    'https://images.unsplash.com/photo-1519494080410-f9aa76cb4283?w=500&q=80',
    'https://images.unsplash.com/photo-1504813184591-01572f98c85f?w=500&q=80',
    'https://images.unsplash.com/photo-1516549655169-df83a0774514?w=500&q=80',
    'https://images.unsplash.com/photo-1579684385127-1ef15d508118?w=500&q=80',
    'https://images.unsplash.com/photo-1629909613654-28e377c37b09?w=500&q=80',
    'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?w=500&q=80',
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalExcelData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalExcelData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      ByteData data = await rootBundle.load('assets/klinik.xlsx');
      var bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      var excel = Excel.decodeBytes(bytes);
      List<Map<String, dynamic>> extracted = [];

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table]!;

        for (int i = 3; i < sheet.maxRows; i++) {
          var row = sheet.row(i);

          if (row.length >= 8 && row[2] != null) {
            String name = row[2]?.value?.toString().trim() ?? '';

            if (name.isEmpty ||
                name.startsWith('*Nota') ||
                name.startsWith('T/B') ||
                name.toLowerCase() == 'nama klinik') {
              continue;
            }

            String address1 = row[3]?.value?.toString().trim() ?? '';
            String address2 = row[4]?.value?.toString().trim() ?? '';
            String rawState = row[7]?.value?.toString().trim() ?? '';
            String phone = row[8]?.value?.toString().trim() ?? 'N/A';
            String fullAddress = address2.isNotEmpty ? '$address1, $address2' : address1;
            String photoUrl = _clinicPhotos[(i + name.length) % _clinicPhotos.length];

            extracted.add({
              'name': name,
              'address': fullAddress,
              'state': _guessStateFromAddress('$fullAddress $rawState'),
              'phone': phone,
              'photoUrl': photoUrl,
            });
          }
        }
        break;
      }

      if (mounted) {
        setState(() {
          _allClinics = extracted;
          _displayedClinics = _allClinics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _guessStateFromAddress(String address) {
    String addr = address.toLowerCase();
    if (addr.contains('kuala lumpur') || addr.contains('w.p.')) return 'W.P. Kuala Lumpur';
    if (addr.contains('selangor') || addr.contains('petaling')) return 'Selangor';
    if (addr.contains('pulau pinang') || addr.contains('penang') || addr.contains('georgetown')) return 'Pulau Pinang';
    if (addr.contains('johor')) return 'Johor';
    if (addr.contains('perak')) return 'Perak';
    if (addr.contains('melaka')) return 'Melaka';
    if (addr.contains('negeri sembilan')) return 'Negeri Sembilan';
    if (addr.contains('pahang')) return 'Pahang';
    if (addr.contains('kedah')) return 'Kedah';
    if (addr.contains('kelantan')) return 'Kelantan';
    if (addr.contains('terengganu')) return 'Terengganu';
    if (addr.contains('sabah')) return 'Sabah';
    if (addr.contains('sarawak')) return 'Sarawak';
    return 'All States';
  }

  void _applyFilterAndSearch() {
    List<Map<String, dynamic>> results = List.from(_allClinics);

    if (_selectedState != 'All States') {
      results = results.where((c) => c['state'] == _selectedState).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      results = results.where((c) {
        final name = (c['name'] as String).toLowerCase();
        final address = (c['address'] as String).toLowerCase();
        return name.contains(query) || address.contains(query);
      }).toList();
    }

    setState(() {
      _displayedClinics = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = isDark ? Colors.white : Colors.brown[800]!;
    final Color cardBackground = isDark ? Colors.grey[850]! : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verified Vet Clinics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: cardBackground,
                      border: Border.all(color: primaryColor, width: 1.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedState,
                        icon: Icon(Icons.keyboard_arrow_down, color: primaryColor),
                        dropdownColor: cardBackground,
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                        items: _malaysiaStates.map((state) {
                          return DropdownMenuItem<String>(value: state, child: Text(state));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedState = val);
                            _applyFilterAndSearch();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => _applyFilterAndSearch(),
                        style: TextStyle(color: primaryColor),
                        decoration: InputDecoration(
                          hintText: 'Search clinic...',
                          hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 13),
                          prefixIcon: Icon(Icons.search, color: primaryColor, size: 20),
                          filled: true,
                          fillColor: cardBackground,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: primaryColor, width: 1.8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: primaryColor, width: 1.8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: primaryColor, width: 2.2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: _isLoading
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: primaryColor),
                      const SizedBox(height: 16),
                      Text('Loading clinic directory...', style: TextStyle(color: primaryColor)),
                    ],
                  ),
                )
                    : _displayedClinics.isEmpty
                    ? Center(
                  child: Text(
                    'No clinics found.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                  ),
                )
                    : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _displayedClinics.length,
                  itemBuilder: (context, index) {
                    final clinic = _displayedClinics[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: cardBackground,
                        border: Border.all(color: primaryColor, width: 1.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClinicDetailsPage(clinicData: clinic),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(10),
                                bottomLeft: Radius.circular(10),
                              ),
                              child: SizedBox(
                                width: 100,
                                height: 100,
                                child: Image.network(
                                  clinic['photoUrl'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.brown[100],
                                      child: Icon(Icons.local_hospital_rounded, color: Colors.brown[800], size: 36),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Container(
                              width: 1.8,
                              height: 100,
                              color: primaryColor,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      clinic['name'],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            clinic['address'],
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}