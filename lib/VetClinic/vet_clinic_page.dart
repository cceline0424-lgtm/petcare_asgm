import 'package:flutter/material.dart';
import 'package:petcare_asgm/VetClinic/clinic_details_page.dart';
import 'package:petcare_asgm/VetClinic/vet_clinic_service.dart';

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

  final List<String> _malaysiaStates = VetClinicService.malaysiaStates;

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
      final clinics = await VetClinicService.loadClinics();
      final extracted = clinics.map((pin) => pin.toClinicData()).toList();

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