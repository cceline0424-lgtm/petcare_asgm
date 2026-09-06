import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petcare_asgm/Map/record.dart';
import 'package:petcare_asgm/main.dart';
import 'package:petcare_asgm/VetClinic/vet_clinic_service.dart';
import 'package:petcare_asgm/VetClinic/clinic_details_page.dart';

class StrayAnimalMapPage extends StatefulWidget {
  const StrayAnimalMapPage({super.key});

  @override
  State<StrayAnimalMapPage> createState() => _StrayAnimalMapPageState();
}

class _StrayAnimalMapPageState extends State<StrayAnimalMapPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  LatLng? _myCurrentLocation;
  String _weatherDescription = 'Loading...';
  IconData _weatherIcon = Icons.hourglass_empty;
  String _currentAddress = 'Fetching location...';
  bool _isNightMode = false;

  final List<StrayAnimalRecord> _strayRecords = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _strayPinsSub;
  bool _isCreatingPin = false;

  List<VetClinicPin> _allClinics = [];
  final List<VetClinicPin> _visibleClinicPins = [];
  bool _showVetClinics = false;
  bool _isLoadingClinics = false;
  bool _stopClinicLoad = false;

  @override
  void initState() {
    super.initState();
    _listenToPins();
    _getRealUserLocation();
    _loadClinicDirectory();
  }

  @override
  void dispose() {
    _stopClinicLoad = true;
    _strayPinsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClinicDirectory() async {
    try {
      final clinics = await VetClinicService.loadClinics();
      if (mounted) {
        setState(() {
          _allClinics = clinics;
        });
      }
    } catch (_) {

    }
  }

  Future<void> _loadAllClinicPins() async {
    if (_isLoadingClinics) return;

    setState(() {
      _isLoadingClinics = true;
      _visibleClinicPins.clear();
    });

    _stopClinicLoad = false;
    await VetClinicService.resolveLocations(
      _allClinics,
      shouldStop: () => _stopClinicLoad,
      onEachResolved: (pin) {
        if (!mounted) return;
        setState(() {
          if (!_visibleClinicPins.any((p) => p.id == pin.id)) {
            _visibleClinicPins.add(pin);
          }
        });
      },
    );

    if (mounted) {
      setState(() => _isLoadingClinics = false);
    }
  }

  void _toggleVetClinics() {
    setState(() => _showVetClinics = !_showVetClinics);
    if (_showVetClinics && _visibleClinicPins.isEmpty && !_isLoadingClinics) {
      _loadAllClinicPins();
    }
  }

  void _openClinicDetails(VetClinicPin pin) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClinicDetailsPage(clinicData: pin.toClinicData()),
      ),
    );
  }

  void _listenToPins() {
    _strayPinsSub = FirebaseFirestore.instance.collection('stray_pins').snapshots().listen((snap) async {
      if (!mounted) return;

      final records = <StrayAnimalRecord>[];
      for (final doc in snap.docs) {
        try {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          records.add(StrayAnimalRecord.fromJson(data));
        } catch (_) {}
      }

      setState(() {
        _strayRecords
          ..clear()
          ..addAll(records);
      });
    });
  }

  Future<String> _encodePinPhoto(File file, String pinId) async {
    final bytes = await file.readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  Future<void> _updatePin(String id, Map<String, dynamic> fields) async {
    try {
      await FirebaseFirestore.instance.collection('stray_pins').doc(id).update(fields);
    } catch (_) {

    }
  }

  Future<void> _deletePin(StrayAnimalRecord record) async {
    try {
      await FirebaseFirestore.instance.collection('stray_pins').doc(record.id).delete();
    } catch (_) {}
  }

  Future<void> _fetchWeatherAndAddress(double lat, double lon) async {
    try {
      final geoResponse = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon'),
        headers: {'User-Agent': 'PetHealthCareApp/1.0'},
      );

      String queryLocation = 'Johor';

      if (geoResponse.statusCode == 200) {
        final geoData = jsonDecode(geoResponse.body);
        final address = geoData['address'] ?? {};

        if (mounted) {
          setState(() {
            _currentAddress = geoData['display_name'] ?? 'Unknown Location';
          });
        }

        queryLocation = address['district'] ?? address['city'] ?? address['town'] ?? address['state'] ?? 'Johor';
        queryLocation = queryLocation.replaceAll(' District', '');
      }

      final weatherResponse = await http.get(
        Uri.parse('https://api.data.gov.my/weather/forecast?contains=$queryLocation@location__location_name'),
      );

      if (weatherResponse.statusCode == 200) {
        final weatherData = jsonDecode(weatherResponse.body);
        if (weatherData is List && weatherData.isNotEmpty) {
          final todayForecast = weatherData[0];

          final hour = DateTime.now().hour;
          bool isNight = hour < 7 || hour >= 19;

          String forecastKey = 'summary_forecast';
          if (hour >= 0 && hour < 12) {
            forecastKey = 'morning_forecast';
          } else if (hour >= 12 && hour < 19) {
            forecastKey = 'afternoon_forecast';
          } else {
            forecastKey = 'night_forecast';
          }

          String rawForecast = todayForecast[forecastKey] ?? todayForecast['summary_forecast'] ?? 'Cerah';
          String forecastLower = rawForecast.toLowerCase();

          String englishDesc = 'Cloudy';
          IconData icon = Icons.cloud;

          if (forecastLower.contains('tiada') || forecastLower.contains('cerah') || forecastLower.contains('baik') || forecastLower.contains('clear')) {
            englishDesc = isNight ? 'Clear' : 'Sunny';
            icon = isNight ? Icons.nights_stay : Icons.wb_sunny;
          } else if (forecastLower.contains('ribut') || forecastLower.contains('thunder')) {
            englishDesc = 'Storms';
            icon = Icons.flash_on;
          } else if (forecastLower.contains('hujan') || forecastLower.contains('rain')) {
            englishDesc = 'Rainy';
            icon = Icons.cloudy_snowing;
          } else if (forecastLower.contains('mendung') || forecastLower.contains('cloud')) {
            englishDesc = 'Cloudy';
            icon = Icons.cloud;
          }

          if (mounted) {
            setState(() {
              _weatherDescription = englishDesc;
              _weatherIcon = icon;
              _isNightMode = isNight;
            });
          }
          return;
        }
      }
    } catch (e) {}

    final fallbackHour = DateTime.now().hour;
    final fallbackNight = fallbackHour < 7 || fallbackHour >= 19;
    if (mounted) {
      setState(() {
        _weatherDescription = fallbackNight ? 'Clear' : 'Sunny';
        _weatherIcon = fallbackNight ? Icons.nights_stay : Icons.wb_sunny;
        _isNightMode = fallbackNight;
      });
    }
  }

  Future<void> _getRealUserLocation() async {
    void loadFallbackLocation() {
      final fallback = const LatLng(1.9449, 103.0232);
      if (mounted) {
        setState(() {
          _myCurrentLocation = fallback;
        });
      }
      _fetchWeatherAndAddress(fallback.latitude, fallback.longitude);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(fallback, 16.0);
        }
      });
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      loadFallbackLocation();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        loadFallbackLocation();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      loadFallbackLocation();
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      final newLocation = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _myCurrentLocation = newLocation;
        });
      }

      _fetchWeatherAndAddress(position.latitude, position.longitude);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(newLocation, 16.0);
        }
      });
    } catch (e) {
      Position? lastKnown = await Geolocator.getLastKnownPosition();

      if (lastKnown != null) {
        final lastLoc = LatLng(lastKnown.latitude, lastKnown.longitude);
        if (mounted) {
          setState(() {
            _myCurrentLocation = lastLoc;
          });
        }
        _fetchWeatherAndAddress(lastKnown.latitude, lastKnown.longitude);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(lastLoc, 16.0);
          }
        });
      } else {
        loadFallbackLocation();
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final clinicMatch = _findMatchingClinic(trimmed);
    if (clinicMatch != null) {
      await _focusOnClinic(clinicMatch);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1'),
        headers: {'User-Agent': 'PetHealthCareApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final newLocation = LatLng(lat, lon);

          if (mounted) {
            setState(() {
              _myCurrentLocation = newLocation;
            });
          }

          _mapController.move(newLocation, 16.0);
          _fetchWeatherAndAddress(lat, lon);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location not found. Please try another name.')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error searching location.')),
      );
    }
  }

  VetClinicPin? _findMatchingClinic(String query) {
    final lowerQuery = query.toLowerCase();
    for (final clinic in _allClinics) {
      if (clinic.name.toLowerCase().contains(lowerQuery)) {
        return clinic;
      }
    }
    return null;
  }

  Future<void> _focusOnClinic(VetClinicPin clinic) async {
    FocusScope.of(context).unfocus();

    if (clinic.location == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Locating clinic...')),
        );
      }
      await VetClinicService.resolveLocations([clinic]);
    }

    if (!mounted) return;

    if (clinic.location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find that clinic on the map.')),
      );
      return;
    }

    setState(() {
      _showVetClinics = true;
      if (!_visibleClinicPins.any((p) => p.id == clinic.id)) {
        _visibleClinicPins.add(clinic);
      }
    });

    _mapController.move(clinic.location!, 17.0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tap the pin to see clinic details.')),
    );
  }

  Future<void> _openCamera() async {
    if (_myCurrentLocation == null) return;

    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 60,
    );

    if (photo != null && mounted) {
      _showConfirmationScreen(File(photo.path), _myCurrentLocation!);
    }
  }

  void _showConfirmationScreen(File imageFile, LatLng locationToPin) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.brown),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Container(
                  height: 400,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.brown, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(imageFile),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.brown),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentAddress,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.brown),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _openCamera();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.brown, width: 2),
                        ),
                        child: const Icon(Icons.refresh, size: 40, color: Colors.brown),
                      ),
                    ),
                    StatefulBuilder(
                      builder: (context, setConfirmState) {
                        return InkWell(
                          onTap: _isCreatingPin
                              ? null
                              : () async {
                            setConfirmState(() => _isCreatingPin = true);

                            try {
                              final docRef = FirebaseFirestore.instance.collection('stray_pins').doc();
                              final imageUrl = await _encodePinPhoto(imageFile, docRef.id);
                              final uid = FirebaseAuth.instance.currentUser?.uid;

                              await docRef.set({
                                'lat': locationToPin.latitude,
                                'lng': locationToPin.longitude,
                                'imageUrl': imageUrl,
                                'isRescued': false,
                                'condition': '',
                                'activityLog': '',
                                'medicalActions': '',
                                'reporterUid': uid,
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                              notificationSignal.value++;
                              if (mounted) {
                                Navigator.pop(context);
                                _mapController.move(locationToPin, 17.0);
                              }
                            } catch (e) {
                              setConfirmState(() => _isCreatingPin = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not save report: $e')),
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.brown, width: 2),
                            ),
                            child: _isCreatingPin
                                ? const SizedBox(
                                width: 40, height: 40,
                                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.brown))
                                : const Icon(Icons.check, size: 40, color: Colors.brown),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editFieldDialog(String title, String currentValue, String pinId, String fieldName, Function(String) onSave, StateSetter setModalState) async {
    TextEditingController controller = TextEditingController(text: currentValue);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Update $title', style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter details here...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.brown, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
            onPressed: () {
              onSave(controller.text);
              setModalState(() {});
              setState(() {});
              _updatePin(pinId, {fieldName: controller.text});
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: Colors.blueAccent, size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right, color: Colors.blueAccent),
        onTap: onTap,
      ),
    );
  }

  void _showPinDetailsModal(StrayAnimalRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 20, right: 20, top: 20
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Update Situation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.brown)),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _deletePin(record);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final XFile? newPhoto = await _picker.pickImage(
                          source: ImageSource.camera,
                          maxWidth: 1024,
                          imageQuality: 60,
                        );
                        if (newPhoto != null) {
                          final newUrl = await _encodePinPhoto(File(newPhoto.path), record.id);
                          setModalState(() {
                            record.imageUrl = newUrl;
                          });
                          setState(() {});
                          _updatePin(record.id, {'imageUrl': newUrl});
                        }
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                              image: record.imageProvider != null
                                  ? DecorationImage(image: record.imageProvider!, fit: BoxFit.cover)
                                  : null,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          record.isRescued ? 'Rescued' : 'Needs Helps',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: record.isRescued ? Colors.green : Colors.red
                          ),
                        ),
                        Switch(
                          value: record.isRescued,
                          activeThumbColor: Colors.green,
                          inactiveThumbColor: Colors.red,
                          inactiveTrackColor: Colors.red.withValues(alpha: 0.3),
                          onChanged: (val) {
                            setModalState(() {
                              record.isRescued = val;
                            });
                            setState(() {});
                            _updatePin(record.id, {'isRescued': val});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildUpdateCard(
                      icon: Icons.monitor_heart,
                      title: 'Animal Condition',
                      subtitle: record.condition.isEmpty ? 'Tap to update condition...' : record.condition,
                      onTap: () => _editFieldDialog(
                          'Condition',
                          record.condition,
                          record.id,
                          'condition',
                              (newText) => record.condition = newText,
                          setModalState
                      ),
                    ),
                    _buildUpdateCard(
                      icon: Icons.history,
                      title: 'Activity Log',
                      subtitle: record.activityLog.isEmpty ? 'Tap to add activity...' : record.activityLog,
                      onTap: () => _editFieldDialog(
                          'Activity Log',
                          record.activityLog,
                          record.id,
                          'activityLog',
                              (newText) => record.activityLog = newText,
                          setModalState
                      ),
                    ),
                    _buildUpdateCard(
                      icon: Icons.medical_services,
                      title: 'Medical Actions',
                      subtitle: record.medicalActions.isEmpty ? 'Tap to record medical actions...' : record.medicalActions,
                      onTap: () => _editFieldDialog(
                          'Medical Actions',
                          record.medicalActions,
                          record.id,
                          'medicalActions',
                              (newText) => record.medicalActions = newText,
                          setModalState
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Marker _buildVetClinicMarker(VetClinicPin pin) {
    return Marker(
      point: pin.location!,
      width: 48,
      height: 48,
      child: GestureDetector(
        onTap: () => _openClinicDetails(pin),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Icon(
              Icons.location_on,
              size: 48,
              color: Colors.teal[700],
              shadows: const [
                Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_hospital, size: 13, color: Colors.teal[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Stray Animals Location',
          style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.brown),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Icon(_weatherIcon, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _weatherDescription,
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )
        ],
      ),
      body: _myCurrentLocation == null
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.brown),
            SizedBox(height: 16),
            Text(
              "Locating you...",
              style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      )
          : Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _myCurrentLocation!,
              initialZoom: 16.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              if (_isNightMode)
                ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    -0.85, 0.0, 0.0, 0.0, 220.0,
                    0.0, -0.85, 0.0, 0.0, 230.0,
                    0.0, 0.0, -0.85, 0.0, 255.0,
                    0.0, 0.0, 0.0, 1.0, 0.0,
                  ]),
                  child: TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.petcare_app',
                  ),
                )
              else
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.petcare_app',
                ),
              MarkerLayer(
                markers: [
                  if (_showVetClinics)
                    ..._visibleClinicPins
                        .where((pin) => pin.location != null)
                        .map(_buildVetClinicMarker),
                  ..._strayRecords.map((record) {
                    return Marker(
                      point: record.location,
                      width: 60,
                      height: 60,
                      child: GestureDetector(
                        onTap: () => _showPinDetailsModal(record),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: record.isRescued ? Colors.green : Colors.red,
                                width: 4
                            ),
                            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                            image: record.imageProvider != null
                                ? DecorationImage(image: record.imageProvider!, fit: BoxFit.cover)
                                : null,
                          ),
                        ),
                      ),
                    );
                  }),
                  Marker(
                    point: _myCurrentLocation!,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4)
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4)
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search Location...',
                  border: InputBorder.none,
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.brown),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      _searchLocation(_searchController.text);
                    },
                  ),
                ),
                onSubmitted: (value) {
                  _searchLocation(value);
                },
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 160,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'zoomInBtn',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                  child: const Icon(Icons.add, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoomOutBtn',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                  child: const Icon(Icons.remove, color: Colors.black54),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 90,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'locate_btn',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                _getRealUserLocation();
              },
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 90,
            child: FloatingActionButton(
              heroTag: 'vet_clinic_btn',
              mini: true,
              backgroundColor: _showVetClinics ? Colors.teal[700] : Colors.white,
              onPressed: _toggleVetClinics,
              tooltip: 'Show vet clinics',
              child: Icon(
                Icons.local_hospital,
                color: _showVetClinics ? Colors.white : Colors.teal[700],
              ),
            ),
          ),
          if (_showVetClinics && _isLoadingClinics)
            Positioned(
              top: 66,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pinning clinics... ${_visibleClinicPins.length}/${_allClinics.length}',
                      style: TextStyle(
                        color: Colors.teal[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'camera_btn',
        backgroundColor: Colors.brown,
        onPressed: _openCamera,
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
    );
  }
}