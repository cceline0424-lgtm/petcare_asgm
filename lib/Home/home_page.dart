import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:petcare_asgm/UserProfile/my_appointments_page.dart';
import 'package:petcare_asgm/UserProfile/pet_info_page.dart';
import 'package:petcare_asgm/VetClinic/appointment_storage.dart';
import 'package:petcare_asgm/VetClinic/appointment_time_utils.dart';
import 'package:petcare_asgm/Map/record.dart';

class HomePage extends StatefulWidget {
  final String username;
  final Function(int) onNavigate;

  const HomePage({
    super.key,
    required this.username,
    required this.onNavigate,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;

  Map<String, dynamic>? _upcomingAppointment;
  List<StrayAnimalRecord> _recentStrays = [];
  Map<String, String> _strayAddresses = {};

  List<Map<String, dynamic>> _allDisplayPets = [];

  String _weatherTipTitle = 'Fetching Local Weather...';
  String _weatherTipDesc = 'Loading your daily pet care tip.';
  IconData _weatherTipIcon = Icons.hourglass_empty;
  Color _weatherTipColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    await Future.wait([
      _loadUpcomingAppointment(),
      _loadRecentStrays(),
      _loadMyPets(),
      _fetchWeatherTip(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMyPets() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> combinedPets = [];

    final String myPetsKey = 'my_pets_${widget.username}';
    final String adoptedPetsKey = 'user_adopted_pets_${widget.username}';

    final List<String>? localPetsJson = prefs.getStringList(myPetsKey);
    if (localPetsJson != null) {
      for (String jsonStr in localPetsJson) {
        try {
          final data = jsonDecode(jsonStr);
          final record = PetRecord.fromJson(data);
          combinedPets.add({'name': record.name, 'age': record.age.toString(), 'image': record.imagePath, 'isNetwork': false});
        } catch (e) {}
      }
    }

    final List<String>? adoptedPetsJson = prefs.getStringList(adoptedPetsKey);
    if (adoptedPetsJson != null) {
      for (String jsonStr in adoptedPetsJson) {
        try {
          final data = jsonDecode(jsonStr);
          combinedPets.add({
            'name': data['name'] ?? 'Unknown',
            'age': data['age']?.toString().replaceAll(' Years', '').replaceAll(' Year', '').replaceAll(' Months', '') ?? '?',
            'image': data['photoUrl'] ?? '',
            'isNetwork': true,
          });
        } catch (e) {}
      }
    }
    _allDisplayPets = combinedPets;
  }

  Future<void> _loadUpcomingAppointment() async {
    final allAppointments = await AppointmentStorage.getAppointments();
    final upcomingList = allAppointments
        .where((app) => app['status'] == 'Upcoming' && !isAppointmentPast(app))
        .toList();

    if (upcomingList.isNotEmpty) {
      _upcomingAppointment = upcomingList.first;
    } else {
      _upcomingAppointment = null;
    }
  }

  /// Best-effort location lookup shared by the "nearby strays" and weather
  /// tip features. Returns null (rather than throwing) if location services
  /// or permissions aren't available, so callers can fall back gracefully.
  Future<Position?> _getCurrentPositionSafe() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadRecentStrays() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? recordsJson = prefs.getStringList('stray_pins');

    if (recordsJson != null) {
      final position = await _getCurrentPositionSafe();
      const Distance distanceCalc = Distance();

      List<StrayAnimalRecord> loadedStrays = [];
      for (String jsonStr in recordsJson) {
        try {
          final Map<String, dynamic> data = jsonDecode(jsonStr);
          final record = StrayAnimalRecord.fromJson(data);
          if (!record.imageFile.existsSync()) continue;

          // Only surface strays within 1km of where the user actually is
          // right now. If we couldn't get a location fix, fall back to
          // showing the most recent reports rather than hiding everything.
          if (position != null) {
            final userLocation = LatLng(position.latitude, position.longitude);
            final distanceInMeters = distanceCalc(userLocation, record.location);
            if (distanceInMeters > 1000) continue;
          }

          loadedStrays.add(record);
        } catch (e) {}
      }

      _recentStrays = loadedStrays.reversed.take(2).toList();

      for (var record in _recentStrays) {
        try {
          final geoResponse = await http.get(
            Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${record.location.latitude}&lon=${record.location.longitude}'),
            headers: {'User-Agent': 'PetHealthCareApp/1.0'},
          );
          if (geoResponse.statusCode == 200) {
            final geoData = jsonDecode(geoResponse.body);
            _strayAddresses[record.id] = geoData['display_name'] ?? 'Unknown Location';
          }
        } catch (e) {
          _strayAddresses[record.id] = 'Location unavailable';
        }
      }
    }
  }

  Future<void> _fetchWeatherTip() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      final geoResponse = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}'),
        headers: {'User-Agent': 'PetHealthCareApp/1.0'},
      );

      String queryLocation = 'Johor';

      if (geoResponse.statusCode == 200) {
        final geoData = jsonDecode(geoResponse.body);
        final address = geoData['address'] ?? {};
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

          String forecastKey = (hour >= 0 && hour < 12) ? 'morning_forecast'
              : (hour >= 12 && hour < 19) ? 'afternoon_forecast'
              : 'night_forecast';

          String rawForecast = todayForecast[forecastKey] ?? todayForecast['summary_forecast'] ?? 'Cerah';
          String forecastLower = rawForecast.toLowerCase();

          _setWeatherTipLogic(forecastLower, isNight);
          return;
        }
      }
    } catch (e) {
      final hour = DateTime.now().hour;
      _setWeatherTipLogic('cerah', hour < 7 || hour >= 19);
    }
  }

  void _setWeatherTipLogic(String forecastLower, bool isNight) {
    if (forecastLower.contains('tiada') || forecastLower.contains('cerah') || forecastLower.contains('baik') || forecastLower.contains('clear')) {
      if (isNight) {
        _weatherTipTitle = 'A Peaceful Night 🌙';
        _weatherTipDesc = 'The stars are out and it\'s a clear night. Make sure your pet has a warm, comfortable bed to snuggle into. If you\'re going for a late-night stroll, don\'t forget your reflective gear to stay safe!';
        _weatherTipIcon = Icons.nights_stay;
        _weatherTipColor = Colors.indigo;
      } else {
        _weatherTipTitle = 'Hydration is Key ☀️';
        _weatherTipDesc = 'It\'s a beautiful, warm day out there! Please remember to keep your furry friends hydrated with plenty of fresh water, and provide them with a cool, shaded spot to rest. Paws can get burnt on hot pavement, so consider early morning or late evening walks!';
        _weatherTipIcon = Icons.wb_sunny;
        _weatherTipColor = Colors.orange;
      }
    } else if (forecastLower.contains('ribut') || forecastLower.contains('thunder') || forecastLower.contains('hujan') || forecastLower.contains('rain')) {
      _weatherTipTitle = 'Keep Them Dry & Cozy 🌧️';
      _weatherTipDesc = 'Looks like the skies are gloomy with rain or storms today. Bring your pets indoors where it\'s dry! Loud thunders can be scary for them, so a little extra cuddle time and a safe hiding spot will make them feel secure.';
      _weatherTipIcon = Icons.cloudy_snowing;
      _weatherTipColor = Colors.blueGrey;
    } else {
      _weatherTipTitle = 'Perfect for a Walk ☁️';
      _weatherTipDesc = 'The weather is cloudy and mild today—absolutely perfect for an outdoor adventure! Grab the leash and enjoy a lovely walk with your pet. It’s a great time for them to burn off some energy without the harsh heat of the sun.';
      _weatherTipIcon = Icons.cloud;
      _weatherTipColor = Colors.lightBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.brown[800]!;
    final Color cardColor = isDark ? Colors.grey[850]! : Colors.white;
    final Color subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final Color textBtnColor = isDark ? Colors.white : Colors.brown;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.brown));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello, ${widget.username}! 👋', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 4),
            Text('Here is your pet care summary today.', style: TextStyle(fontSize: 14, color: subTextColor)),
            const SizedBox(height: 24),

            _buildReminderCard(isDark),
            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Pets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PetInfoPage())).then((_) {
                      _loadDashboardData();
                    });
                  },
                  child: Text('Manage', style: TextStyle(color: textBtnColor)),
                ),
              ],
            ),
            _buildPetsCarousel(cardColor, textColor, subTextColor),
            const SizedBox(height: 28),

            Text('Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                _buildNavCard(context, title: 'Adoption', icon: Icons.pets, color: Colors.orange, cardColor: cardColor, textColor: textColor, onTap: () => widget.onNavigate(0)),
                _buildNavCard(context, title: 'Vets', icon: Icons.local_hospital, color: Colors.blue, cardColor: cardColor, textColor: textColor, onTap: () => widget.onNavigate(1)),
                _buildNavCard(context, title: 'Strays', icon: Icons.map, color: Colors.green, cardColor: cardColor, textColor: textColor, onTap: () => widget.onNavigate(3)),
              ],
            ),
            const SizedBox(height: 28),

            Text('Daily Tip', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 12),
            _buildHealthTipCard(isDark),
            const SizedBox(height: 28),

            Text('Recent Stray Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 12),
            _buildStrayAlertsList(cardColor, textColor, subTextColor),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAppointmentsPage()));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.brown[800] : Colors.brown[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.brown.withValues(alpha: _upcomingAppointment != null ? 0.3 : 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _upcomingAppointment != null ? Colors.brown[700] : Colors.grey[400],
                  shape: BoxShape.circle
              ),
              child: const Icon(Icons.calendar_month, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      _upcomingAppointment != null ? 'Upcoming Vet Visit' : 'No Upcoming Appointments',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.brown[900])
                  ),
                  const SizedBox(height: 4),
                  if (_upcomingAppointment != null)
                    Text(
                        '${_upcomingAppointment!['date']} at ${_upcomingAppointment!['time']} at ${_upcomingAppointment!['clinicName']}',
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.brown[700])
                    ),
                  if (_upcomingAppointment == null)
                    Text(
                        'Tap here to view your appointment history.',
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.brown[700])
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetsCarousel(Color cardColor, Color textColor, Color subTextColor) {
    final int itemCount = _allDisplayPets.isEmpty ? 1 : _allDisplayPets.length + 1;

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          final isAddButton = index == _allDisplayPets.length;

          ImageProvider? petImage;
          if (!isAddButton) {
            final pet = _allDisplayPets[index];
            if (pet['isNetwork'] == true && pet['image'].toString().isNotEmpty) {
              petImage = NetworkImage(pet['image']);
            } else if (pet['isNetwork'] == false && pet['image'].toString().isNotEmpty) {
              petImage = FileImage(File(pet['image']));
            }
          }

          return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PetInfoPage())).then((_) {
                _loadDashboardData();
              });
            },
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: isAddButton ? Border.all(color: Colors.grey.withValues(alpha: 0.3), style: BorderStyle.solid) : null,
                boxShadow: isAddButton ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isAddButton ? Colors.grey.withValues(alpha: 0.1) : Colors.brown[100],
                    backgroundImage: petImage,
                    child: (isAddButton || petImage == null)
                        ? Icon(
                      isAddButton ? Icons.add : Icons.pets,
                      color: isAddButton ? subTextColor : Colors.brown[700],
                      size: 28,
                    )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAddButton ? 'Add Pet' : _allDisplayPets[index]['name'],
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isAddButton)
                    Text(
                      '${_allDisplayPets[index]['age']} yrs',
                      style: TextStyle(fontSize: 12, color: subTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavCard(BuildContext context, {required String title, required IconData icon, required Color color, required Color cardColor, required Color textColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthTipCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.blueGrey[900] : Colors.lightBlue[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_weatherTipIcon, color: _weatherTipColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_weatherTipTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.blueGrey[900])),
                const SizedBox(height: 6),
                Text(
                  _weatherTipDesc,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.blueGrey[800], height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrayAlertsList(Color cardColor, Color textColor, Color subTextColor) {
    if (_recentStrays.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: const Text('No stray animals reported within 1km of you right now.', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: _recentStrays.map((stray) {
        bool isRescued = stray.isRescued;
        String address = _strayAddresses[stray.id] ?? 'Fetching location...';

        return GestureDetector(
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('open_stray_modal', stray.id);
            widget.onNavigate(3);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(stray.imageFile),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Condition: ${stray.condition.isEmpty ? 'Unknown' : stray.condition}', style: TextStyle(fontWeight: FontWeight.bold, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(address, style: TextStyle(fontSize: 12, color: subTextColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: isRescued ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12)
                  ),
                  child: Text(
                      isRescued ? 'Rescued' : 'Needs Help',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}