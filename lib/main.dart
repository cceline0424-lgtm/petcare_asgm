import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petcare_asgm/UserProfile/user_profile_page.dart';
import 'package:petcare_asgm/VetClinic/vet_clinic_page.dart';
import 'package:petcare_asgm/VetClinic/appointment_storage.dart';
import 'Map/stray_map_page.dart';

final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier(false);

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

          home: const MainNavigationScreen(username: 'User'),
        );
      },
    );
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

  @override
  void initState() {
    super.initState();
    _checkUpcomingAppointments();
  }

  Future<void> _checkUpcomingAppointments() async {
    final appointments = await AppointmentStorage.getAppointments();

    final upcomingList = appointments.where((app) => app['status'] == 'Upcoming').toList();

    if (upcomingList.isNotEmpty) {
      if (mounted) {
        setState(() {
          _upcomingAppointment = upcomingList.last;
          _hasNewNotifications = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isHomeSelected = _currentIndex == 2;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    void _showNotificationTray(BuildContext context, bool isDark) {
      showModalBottomSheet(
          context: context,
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) {
            Color textColor = isDark ? Colors.white : Colors.brown[800]!;
            Color subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

            return Padding(
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

                  if (_upcomingAppointment != null)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.brown[100],
                        child: Icon(Icons.calendar_month, color: Colors.brown[800]),
                      ),
                      title: Text(
                          'Appointment Reminder',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold)
                      ),
                      subtitle: Text(
                          'Your vet visit at ${_upcomingAppointment!['clinicName']} is coming up on ${_upcomingAppointment!['date']} at ${_upcomingAppointment!['time']}.',
                          style: TextStyle(color: subtitleColor)
                      ),
                    ),

                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red[100],
                      child: const Icon(Icons.location_pin, color: Colors.red),
                    ),
                    title: Text('Stray Map Alert', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text('A new stray animal was reported nearby. Tap to view the location.', style: TextStyle(color: subtitleColor)),
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
            );
          }
      );
    }

    final List<Widget> pages = [
      const Center(child: Text('Pet Adoption Page', style: TextStyle(fontSize: 24))),
      const VetClinicPage(),
      const Center(child: Text('Home Page', style: TextStyle(fontSize: 24))),
      const StrayMapPage(),
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
                  onPressed: () {
                    setState(() {
                      _hasNewNotifications = false;
                    });

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
                onPressed: () => setState(() => _currentIndex = 3),
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