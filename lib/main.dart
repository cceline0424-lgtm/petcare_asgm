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
        // Matching the brown UI styling in your wireframes
        primarySwatch: Colors.brown,
        scaffoldBackgroundColor: Colors.white,
      ),
      // In a real app, this would be the Login Page first.
      // For testing the UI layout, we will launch straight into the Main Navigation.
      home: const MainNavigationScreen(),
    );
  }
}

// This widget holds the Bottom Navigation Bar and switches between your pages
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 2; // Default to Home Page (Index 2 in the center)

  // List of your 5 main screens corresponding to the bottom icons
  final List<Widget> _pages = [
    const Center(child: Text('Pet Adoption Page')), // Placeholder for Pet Adoption
    const Center(child: Text('Vet Clinic Page')),   // Placeholder for Vet Clinic
    const Center(child: Text('Home Page')),         // Placeholder for Home
    const Center(child: Text('Stray Map Page')),    // Placeholder for Map
    const Center(child: Text('User Profile Page')), // Placeholder for Profile
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex], // Shows the currently selected page
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Changes the page when an icon is tapped
          });
        },
        type: BottomNavigationBarType.fixed, // Keeps all icons visible
        backgroundColor: Colors.brown[700],
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.pets), // Adoption icon
            label: 'Adoption',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services), // Vet Clinic icon
            label: 'Vet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 36), // Home icon (larger as per design)
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map), // Map icon
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person), // Profile icon
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
