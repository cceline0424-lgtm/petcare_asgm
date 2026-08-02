import 'package:flutter/material.dart';

void main() {
  runApp(const UPetApp());
}

class UPetApp extends StatelessWidget {
  const UPetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'U Pet',
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
    // Check if the home button is currently the active page
    bool isHomeSelected = _currentIndex == 2;

    return Scaffold(
      body: _pages[_currentIndex],

      // The Floating Action Button (Your Home Button)
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.brown[700],
        // Adds a shadow when selected to make it "pop" out, flat when not selected
        elevation: isHomeSelected ? 6 : 0,
        shape: const CircleBorder(),
        onPressed: () {
          setState(() {
            _currentIndex = 2;
          });
        },
        child: Icon(
          Icons.home,
          // Icon becomes larger when selected, smaller when clicking other pages
          size: isHomeSelected ? 38 : 30,
          // Solid light white when selected, faded white when unselected
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
                  size: _currentIndex == 0 ? 32 : 28, // Slight size bump for obvious interaction
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