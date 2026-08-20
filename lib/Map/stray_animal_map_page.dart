import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class StrayAnimalMapPage extends StatefulWidget {
  const StrayAnimalMapPage({super.key});

  @override
  State<StrayAnimalMapPage> createState() => _StrayAnimalMapPageState();
}

class _StrayAnimalMapPageState extends State<StrayAnimalMapPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  LatLng? _myCurrentLocation;
  String _weatherDescription = 'Loading...';
  IconData _weatherIcon = Icons.hourglass_empty;

  @override
  void initState() {
    super.initState();
    _getRealUserLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeather(double lat, double lon) async {
    try {
      final geoResponse = await http.get(Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon'));
      String queryLocation = 'Johor';

      if (geoResponse.statusCode == 200) {
        final geoData = jsonDecode(geoResponse.body);
        final address = geoData['address'] ?? {};
        queryLocation = address['district'] ?? address['city'] ?? address['town'] ?? address['state'] ?? 'Johor';
        queryLocation = queryLocation.replaceAll(' District', '');
      }

      final weatherResponse = await http.get(Uri.parse('https://api.data.gov.my/weather/forecast?contains=$queryLocation@location__location_name'));

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

          setState(() {
            _weatherDescription = englishDesc;
            _weatherIcon = icon;
          });
          return;
        }
      }
    } catch (e) {}

    final fallbackHour = DateTime.now().hour;
    final fallbackNight = fallbackHour < 7 || fallbackHour >= 19;
    setState(() {
      _weatherDescription = fallbackNight ? 'Clear' : 'Sunny';
      _weatherIcon = fallbackNight ? Icons.nights_stay : Icons.wb_sunny;
    });
  }

  Future<void> _getRealUserLocation() async {
    void loadFallbackLocation() {
      setState(() {
        _myCurrentLocation = const LatLng(1.9449, 103.0232);
      });
      _fetchWeather(1.9449, 103.0232);
    }

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      loadFallbackLocation();
      return;
    }

    permission = await Geolocator.checkPermission();
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
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      setState(() {
        _myCurrentLocation = LatLng(position.latitude, position.longitude);
      });
      _fetchWeather(position.latitude, position.longitude);
      _mapController.move(_myCurrentLocation!, 16.0);
    } catch (e) {
      Position? lastKnown = await Geolocator.getLastKnownPosition();

      if (lastKnown != null) {
        setState(() {
          _myCurrentLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
        });
        _fetchWeather(lastKnown.latitude, lastKnown.longitude);
        _mapController.move(_myCurrentLocation!, 16.0);
      } else {
        loadFallbackLocation();
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final response = await http.get(Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final newLocation = LatLng(lat, lon);

          setState(() {
            _myCurrentLocation = newLocation;
          });

          _mapController.move(newLocation, 16.0);
          _fetchWeather(lat, lon);
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
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.petcare_app',
              ),
              MarkerLayer(
                markers: [
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'camera_btn',
        backgroundColor: Colors.brown,
        onPressed: () {},
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
    );
  }
}