import 'dart:async';

import 'package:flutter/material.dart';
import 'package:petcare_asgm/VetClinic/places_service.dart';

class VetClinicPage extends StatefulWidget {
  const VetClinicPage({super.key});

  @override
  State<VetClinicPage> createState() => _VetClinicPageState();
}

class _VetClinicPageState extends State<VetClinicPage> {
  final TextEditingController _searchController =
  TextEditingController();

  Timer? _debounceTimer;

  List<Map<String, dynamic>> clinics = [];

  String selectedArea = 'All Areas';

  bool isLoading = true;
  String? errorMessage;

  final List<String> areas = [
    'All Areas',
    'Kuala Lumpur',
    'Selangor',
    'Johor',
    'Penang',
    'Perak',
    'Melaka',
    'Negeri Sembilan',
    'Pahang',
    'Kedah',
    'Kelantan',
    'Terengganu',
    'Perlis',
    'Sabah',
    'Sarawak',
    'Putrajaya',
    'Labuan',
  ];

  @override
  void initState() {
    super.initState();

    _loadClinics();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();

    super.dispose();
  }

  // =========================================================
  // LOAD REAL VETERINARY CLINICS FROM GOOGLE PLACES API
  // =========================================================

  Future<void> _loadClinics() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results =
      await PlacesService.searchVeterinaryClinics(
        searchText: _searchController.text.trim(),
        selectedArea: selectedArea,
      );

      if (!mounted) return;

      setState(() {
        clinics = results;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // =========================================================
  // SEARCH WITH DEBOUNCE
  // =========================================================

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();

    _debounceTimer = Timer(
      const Duration(milliseconds: 700),
          () {
        _loadClinics();
      },
    );
  }

  // =========================================================
  // AREA FILTER
  // =========================================================

  void _onAreaChanged(String newArea) {
    setState(() {
      selectedArea = newArea;
    });

    _loadClinics();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;

    final Color primaryColor =
    isDark ? Colors.white : Colors.brown[800]!;

    final Color boxColor =
    isDark ? Colors.grey[850]! : Colors.white;

    return Scaffold(
      backgroundColor:
      Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text('Vet Clinics'),
        centerTitle: false,
      ),

      body: Column(
        children: [
          // =================================================
          // SEARCH AND AREA FILTER
          // =================================================

          Padding(
            padding: const EdgeInsets.all(16.0),

            child: Row(
              children: [
                // -------------------------------------------
                // AREA DROPDOWN
                // -------------------------------------------

                Container(
                  height: 52,

                  padding:
                  const EdgeInsets.symmetric(horizontal: 12),

                  decoration: BoxDecoration(
                    color: boxColor,

                    border: Border.all(
                      color: primaryColor,
                      width: 1.5,
                    ),

                    borderRadius:
                    BorderRadius.circular(12),
                  ),

                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedArea,

                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: primaryColor,
                      ),

                      dropdownColor: boxColor,

                      items: areas.map((area) {
                        return DropdownMenuItem<String>(
                          value: area,

                          child: Text(
                            area,

                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),

                      onChanged: (value) {
                        if (value != null) {
                          _onAreaChanged(value);
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // -------------------------------------------
                // SEARCH BAR
                // -------------------------------------------

                Expanded(
                  child: SizedBox(
                    height: 52,

                    child: TextField(
                      controller: _searchController,

                      onChanged: _onSearchChanged,

                      style: TextStyle(
                        color: primaryColor,
                      ),

                      decoration: InputDecoration(
                        hintText:
                        'Search clinic or area...',

                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),

                        prefixIcon: Icon(
                          Icons.search,
                          color: primaryColor,
                        ),

                        filled: true,

                        fillColor: boxColor,

                        contentPadding:
                        const EdgeInsets.symmetric(
                          vertical: 0,
                        ),

                        border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),

                          borderSide: BorderSide(
                            color: primaryColor,
                            width: 1.5,
                          ),
                        ),

                        enabledBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),

                          borderSide: BorderSide(
                            color: primaryColor,
                            width: 1.5,
                          ),
                        ),

                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),

                          borderSide: BorderSide(
                            color: primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // =================================================
          // CLINIC RESULTS
          // =================================================

          Expanded(
            child: _buildClinicContent(
              primaryColor,
              boxColor,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // BUILD CLINIC CONTENT
  // =========================================================

  Widget _buildClinicContent(
      Color primaryColor,
      Color boxColor,
      ) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [
            CircularProgressIndicator(
              color: primaryColor,
            ),

            const SizedBox(height: 16),

            Text(
              'Loading real veterinary clinics...',

              style: TextStyle(
                color: primaryColor,
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding:
          const EdgeInsets.all(24.0),

          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,

            children: [
              Icon(
                Icons.error_outline,
                size: 50,
                color: Colors.red[400],
              ),

              const SizedBox(height: 16),

              const Text(
                'Unable to load clinics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                errorMessage!,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _loadClinics,

                icon: const Icon(Icons.refresh),

                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (clinics.isEmpty) {
      return const Center(
        child: Text(
          'No veterinary clinics found.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadClinics,

      child: ListView.builder(
        padding:
        const EdgeInsets.fromLTRB(16, 0, 16, 16),

        itemCount: clinics.length,

        itemBuilder: (context, index) {
          final clinic = clinics[index];

          return _buildClinicCard(
            clinic: clinic,
            primaryColor: primaryColor,
            boxColor: boxColor,
          );
        },
      ),
    );
  }

  // =========================================================
  // CLINIC CARD
  // =========================================================

  Widget _buildClinicCard({
    required Map<String, dynamic> clinic,
    required Color primaryColor,
    required Color boxColor,
  }) {
    final String? photoUrl =
    PlacesService.getPhotoUrl(
      clinic['photoName'],
    );

    return Card(
      margin:
      const EdgeInsets.only(bottom: 16),

      elevation: 2,

      color: boxColor,

      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(16),

        side: BorderSide(
          color: primaryColor,
          width: 1,
        ),
      ),

      child: InkWell(
        borderRadius:
        BorderRadius.circular(16),

        onTap: () {
          // Step 2 will navigate to the clinic details page.
          // We will add this later.

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                clinic['name'],
              ),
            ),
          );
        },

        child: Row(
          children: [
            // ===============================================
            // REAL GOOGLE PLACE PHOTO
            // ===============================================

            ClipRRect(
              borderRadius:
              const BorderRadius.only(
                topLeft: Radius.circular(15),
                bottomLeft: Radius.circular(15),
              ),

              child: SizedBox(
                width: 120,
                height: 120,

                child: photoUrl == null
                    ? Container(
                  color: Colors.grey[300],

                  child: const Icon(
                    Icons.local_hospital,
                    size: 45,
                  ),
                )

                    : Image.network(
                  photoUrl,

                  fit: BoxFit.cover,

                  errorBuilder:
                      (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],

                      child: const Icon(
                        Icons.image_not_supported,
                        size: 40,
                      ),
                    );
                  },

                  loadingBuilder:
                      (
                      context,
                      child,
                      loadingProgress,
                      ) {
                    if (loadingProgress == null) {
                      return child;
                    }

                    return Center(
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,

                        value:
                        loadingProgress
                            .expectedTotalBytes ==
                            null
                            ? null
                            : loadingProgress
                            .cumulativeBytesLoaded /
                            loadingProgress
                                .expectedTotalBytes!,
                      ),
                    );
                  },
                ),
              ),
            ),

            // ===============================================
            // CLINIC INFORMATION
            // ===============================================

            Expanded(
              child: Padding(
                padding:
                const EdgeInsets.all(14),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      clinic['name'],

                      maxLines: 2,

                      overflow:
                      TextOverflow.ellipsis,

                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                        FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        Icon(
                          Icons.location_on_outlined,

                          size: 18,

                          color: Colors.grey[600],
                        ),

                        const SizedBox(width: 5),

                        Expanded(
                          child: Text(
                            clinic['address'],

                            maxLines: 3,

                            overflow:
                            TextOverflow.ellipsis,

                            style: TextStyle(
                              fontSize: 13,

                              color:
                              Colors.grey[600],
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
  }
}