import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petcare_asgm/UserProfile/user_profile_page.dart';

// 1. Create a global notifier for Dark Mode
final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier(false);

void main() async {
  // 2. Ensure Flutter is initialized before reading SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Load the saved dark mode preference before the app starts
  final prefs = await SharedPreferences.getInstance();
  isDarkModeNotifier.value = prefs.getBool('dark_mode') ?? false;

  runApp(const PetHealthCareApp());
}

class PetHealthCareApp extends StatelessWidget {
  const PetHealthCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 4. Wrap MaterialApp in a ValueListenableBuilder to listen for theme changes
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          title: 'Pet Health Care',
          debugShowCheckedModeBanner: false,

          // --- LIGHT THEME ---
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.brown,
            scaffoldBackgroundColor: Colors.white,
          ),

          // --- DARK THEME ---
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.brown,
            scaffoldBackgroundColor: Colors.grey[900],
            cardColor: Colors.grey[850],
          ),

          // 5. Switch between themes based on the notifier
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
  int _currentIndex = 2; // Default to Home Page
  bool _hasNewNotifications = true;

  @override
  Widget build(BuildContext context) {
    bool isHomeSelected = _currentIndex == 2;
    // Check if the app is currently in dark mode to adjust hardcoded text colors
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Function to show the notification tray
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
                  // Tray Header
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

                  // Mock Notification 1
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.brown[100],
                      child: Icon(Icons.calendar_month, color: Colors.brown[800]),
                    ),
                    title: Text('Appointment Reminder', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text('Your vet visit at Setapak Animal Clinic is tomorrow at 10:00 AM.', style: TextStyle(color: subtitleColor)),
                  ),

                  // Mock Notification 2
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red[100],
                      child: const Icon(Icons.location_pin, color: Colors.red),
                    ),
                    title: Text('Stray Map Alert', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    subtitle: Text('A new stray animal was reported nearby. Tap to view the location.', style: TextStyle(color: subtitleColor)),
                  ),

                  // Mock Notification 3
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
      const Center(child: Text('Vet Clinic Page', style: TextStyle(fontSize: 24))),
      const Center(child: Text('Home Page', style: TextStyle(fontSize: 24))),
      const Center(child: Text('Stray Map Page', style: TextStyle(fontSize: 24))),
      UserProfilePage(username: widget.username),
    ];

    return Scaffold(
      // ==========================================
      // TOP BANNER (APP BAR)
      // ==========================================
      appBar: AppBar(
        // Use scaffold background color so it adapts to dark mode automatically
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 3,
        shadowColor: Colors.brown.withOpacity(0.3),

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
            color: isDark ? Colors.white : Colors.brown[800], // Text turns white in dark mode
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
                    // 1. Tell the app the notifications have been read
                    setState(() {
                      _hasNewNotifications = false;
                    });

                    // 2. Show the tray
                    _showNotificationTray(context, isDark);
                  },
                ),

                // 3. ONLY draw the red dot if there are new notifications!
                if (_hasNewNotifications)
                  Positioned(
                    right: 12,
                    top: 14,
                    child: Container(
                      width: 10, // Added explicit width and height so it looks like a clean dot
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

      // ==========================================
      // BOTTOM NAVIGATION & FLOATING BUTTON
      // ==========================================
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