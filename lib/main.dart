import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:petcare_asgm/Home/home_page.dart';
import 'package:petcare_asgm/UserProfile/user_profile_page.dart';
import 'package:petcare_asgm/VetClinic/vet_clinic_page.dart';
import 'package:petcare_asgm/VetClinic/appointment_storage.dart';
import 'package:petcare_asgm/VetClinic/appointment_time_utils.dart';
import 'package:petcare_asgm/Map/stray_animal_map_page.dart';
import 'package:petcare_asgm/Map/record.dart';
import 'package:petcare_asgm/Auth/welcome_page.dart';
import 'package:petcare_asgm/Auth/auth_service.dart';
import 'package:petcare_asgm/PetAdoption/pet_adoption_page.dart';
import 'package:petcare_asgm/UserProfile/my_appointments_page.dart';

final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier(false);
final ValueNotifier<int> notificationSignal = ValueNotifier(0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  isDarkModeNotifier.value = prefs.getBool('dark_mode') ?? false;

  runApp(const PetHealthCareApp());
}

class PetHealthCareApp extends StatelessWidget {
  const PetHealthCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          title: 'Pet Health Care',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.brown,
            scaffoldBackgroundColor: Colors.white,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.brown,
            scaffoldBackgroundColor: Colors.grey[900],
            cardColor: Colors.grey[850],
          ),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _isLoggedIn = false;
  String _username = 'User';

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final loggedIn = await AuthService.isLoggedIn();
    final username = await AuthService.getLoggedInUsername();

    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _username = username ?? 'User';
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.brown)),
      );
    }

    return _isLoggedIn
        ? MainNavigationScreen(username: _username)
        : const WelcomePage();
  }
}

class MainNavigationScreen extends StatefulWidget {
  final String username;

  const MainNavigationScreen({super.key, required this.username});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 2;
  bool _hasNewNotifications = false;

  Map<String, dynamic>? _upcomingAppointment;
  int _strayPinCount = 0;
  bool _hasNewStrayPins = false;
  bool _hasNewAppt = false;

  @override
  void initState() {
    super.initState();
    _checkNotifications();
    notificationSignal.addListener(_checkNotifications);
  }

  @override
  void dispose() {
    notificationSignal.removeListener(_checkNotifications);
    super.dispose();
  }

  Future<void> _checkNotifications() async {
    final prefs = await SharedPreferences.getInstance();

    final appointments = await AppointmentStorage.getAppointments();
    final upcomingList = appointments
        .where((app) => app['status'] == 'Upcoming' && !isAppointmentPast(app))
        .toList();

    _strayPinCount = await _countNearbyStrayPins(prefs);
    int lastSeenCount = prefs.getInt('last_seen_stray_count') ?? 0;
    _hasNewStrayPins = _strayPinCount > lastSeenCount;

    bool showApptReminder = prefs.getBool('reminder') ?? true;
    bool showStrayAlert = prefs.getBool('stray_alert') ?? true;

    if (mounted) {
      setState(() {
        if (upcomingList.isNotEmpty) {
          _upcomingAppointment = upcomingList.last;
        } else {
          _upcomingAppointment = null;
        }

        String lastSeenApptId = prefs.getString('last_seen_appt_id') ?? '';
        _hasNewAppt = _upcomingAppointment != null && _upcomingAppointment!['id'] != lastSeenApptId;

        _hasNewNotifications = false;

        if (_hasNewAppt && showApptReminder) {
          _hasNewNotifications = true;
        }

        if (_hasNewStrayPins && showStrayAlert) {
          _hasNewNotifications = true;
        }
      });
    }
  }

  /// Counts stray reports within 1km of the user's current location. If a
  /// location fix can't be obtained (permission denied, GPS off, etc.),
  /// falls back to counting every report so the alert doesn't just vanish.
  Future<int> _countNearbyStrayPins(SharedPreferences prefs) async {
    final List<String>? recordsJson = prefs.getStringList('stray_pins');
    if (recordsJson == null || recordsJson.isEmpty) return 0;

    Position? position;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (_) {
      position = null;
    }

    if (position == null) return recordsJson.length;

    const Distance distanceCalc = Distance();
    final userLocation = LatLng(position.latitude, position.longitude);
    int nearbyCount = 0;

    for (final jsonStr in recordsJson) {
      try {
        final record = StrayAnimalRecord.fromJson(jsonDecode(jsonStr));
        if (distanceCalc(userLocation, record.location) <= 1000) {
          nearbyCount++;
        }
      } catch (_) {}
    }

    return nearbyCount;
  }

  void _showNotificationTray(BuildContext context, bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    bool showApptReminder = prefs.getBool('reminder') ?? true;
    bool showStrayAlert = prefs.getBool('stray_alert') ?? true;

    if (!context.mounted) return;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          Color textColor = isDark ? Colors.white : Colors.brown[800]!;
          Color subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Notifications',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close', style: TextStyle(color: Colors.red)),
                        )
                      ],
                    ),
                    const Divider(),

                    if (_upcomingAppointment != null && showApptReminder)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.brown[100],
                          child: Icon(Icons.calendar_month, color: Colors.brown[800]),
                        ),
                        title: Text(
                            _hasNewAppt ? 'New Appointment Reminder!' : 'Upcoming Appointment',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)
                        ),
                        subtitle: Text(
                            'Your vet visit at ${_upcomingAppointment!['clinicName']} is coming up on ${_upcomingAppointment!['date']} at ${_upcomingAppointment!['time']}.',
                            style: TextStyle(color: subtitleColor)
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MyAppointmentsPage()),
                          ).then((_) => _checkNotifications());
                        },
                      ),

                    if (showStrayAlert && _strayPinCount > 0)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red[100],
                          child: const Icon(Icons.location_pin, color: Colors.red),
                        ),
                        title: Text(
                            _hasNewStrayPins ? 'New Stray Map Alert!' : 'Stray Map Summary',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)
                        ),
                        subtitle: Text(
                            '$_strayPinCount stray animal(s) reported within 1km of you. Tap to view the locations.',
                            style: TextStyle(color: subtitleColor)
                        ),
                        onTap: () {
                          setState(() {
                            _hasNewStrayPins = false;
                            _currentIndex = 3;
                          });
                          Navigator.pop(context);
                        },
                      ),

                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green[100],
                        child: const Icon(Icons.local_offer, color: Colors.green),
                      ),
                      title: Text('Welcome to U Pet!', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                      subtitle: Text('Complete your profile to get full access to all features.', style: TextStyle(color: subtitleColor)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isHomeSelected = _currentIndex == 2;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> pages = [
      const PetAdoptionPage(),
      const VetClinicPage(),
      HomePage(
        username: widget.username,
        onNavigate: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      const StrayAnimalMapPage(),
      UserProfilePage(username: widget.username),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 3,
        shadowColor: Colors.brown.withValues(alpha: 0.3),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.brown[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pets,
              color: isDark ? Colors.white : Colors.brown[800],
              size: 22,
            ),
          ),
        ),
        titleSpacing: 0,
        title: Text(
          'Pet Health Care',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.brown[800],
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: isDark ? Colors.white : Colors.brown[800],
                    size: 28,
                  ),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    if (_upcomingAppointment != null) {
                      await prefs.setString('last_seen_appt_id', _upcomingAppointment!['id']);
                    }
                    await prefs.setInt('last_seen_stray_count', _strayPinCount);

                    setState(() {
                      _hasNewNotifications = false;
                    });

                    if (!context.mounted) return;
                    _showNotificationTray(context, isDark);
                  },
                ),
                if (_hasNewNotifications)
                  Positioned(
                    right: 12,
                    top: 14,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: pages[_currentIndex],
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.brown[700],
        elevation: isHomeSelected ? 6 : 0,
        shape: const CircleBorder(),
        onPressed: () {
          setState(() {
            _currentIndex = 2;
          });
        },
        child: Icon(
          Icons.home,
          size: isHomeSelected ? 38 : 30,
          color: isHomeSelected ? Colors.white : Colors.white54,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.brown[700],
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 60.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(
                  Icons.pets,
                  size: _currentIndex == 0 ? 32 : 28,
                  color: _currentIndex == 0 ? Colors.white : Colors.white60,
                ),
                onPressed: () => setState(() => _currentIndex = 0),
              ),
              IconButton(
                icon: Icon(
                  Icons.medical_services,
                  size: _currentIndex == 1 ? 32 : 28,
                  color: _currentIndex == 1 ? Colors.white : Colors.white60,
                ),
                onPressed: () => setState(() => _currentIndex = 1),
              ),
              const SizedBox(width: 48.0),
              IconButton(
                icon: Icon(
                  Icons.map,
                  size: _currentIndex == 3 ? 32 : 28,
                  color: _currentIndex == 3 ? Colors.white : Colors.white60,
                ),
                onPressed: () {
                  setState(() => _currentIndex = 3);
                  _checkNotifications();
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.person,
                  size: _currentIndex == 4 ? 32 : 28,
                  color: _currentIndex == 4 ? Colors.white : Colors.white60,
                ),
                onPressed: () => setState(() => _currentIndex = 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}