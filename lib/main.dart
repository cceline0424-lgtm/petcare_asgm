import 'package:flutter/material.dart';

void main() {
  runApp(const PetHealthCareApp());
}

class PetHealthCareApp extends StatelessWidget {
  const PetHealthCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pet Health Care', // Updated App Name
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.brown,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 2; // Default to Home Page

  final List<Widget> _pages = [
    const Center(child: Text('Pet Adoption Page', style: TextStyle(fontSize: 24))),
    const Center(child: Text('Vet Clinic Page', style: TextStyle(fontSize: 24))),
    const Center(child: Text('Home Page', style: TextStyle(fontSize: 24))),
    const Center(child: Text('Stray Map Page', style: TextStyle(fontSize: 24))),
    const Center(child: Text('User Profile Page', style: TextStyle(fontSize: 24))),
  ];

  @override
  Widget build(BuildContext context) {
    bool isHomeSelected = _currentIndex == 2;

    return Scaffold(
      // ==========================================
      // REDESIGNED TOP BANNER (APP BAR)
      // ==========================================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 3, // Gives a modern, soft drop shadow instead of a hard line
        shadowColor: Colors.brown.withOpacity(0.3), // Softens the shadow color

        // 1. Stylized Left Icon (Leading)
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.brown[100], // Soft background circle
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pets,
              color: Colors.brown[800],
              size: 22,
            ),
          ),
        ),
        titleSpacing: 0, // Pulls the title closer to the logo

        // 2. The Center Text (Title) - Updated Name
        title: Text(
          'Pet Health Care',
          style: TextStyle(
            color: Colors.brown[800],
            fontSize: 22,
            fontWeight: FontWeight.w800, // Bolder, cleaner font weight
            letterSpacing: 0.5,
          ),
        ),

        // 3. The Right Icon (Actions) - Added a functional notification bell
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(
                Icons.notifications_none_rounded,
                color: Colors.brown[800],
                size: 28,
              ),
              onPressed: () {
                // Future feature: Open notifications
              },
            ),
          ),
        ],
      ),
      // ==========================================
      // END OF APP BAR
      // ==========================================

      body: _pages[_currentIndex],

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