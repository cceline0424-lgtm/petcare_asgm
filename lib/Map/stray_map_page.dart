import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:camera/camera.dart'; // 🛑 NEW CAMERA PACKAGE

class StrayMapPage extends StatefulWidget {
  const StrayMapPage({super.key});

  @override
  State<StrayMapPage> createState() => _StrayMapPageState();
}

class _StrayMapPageState extends State<StrayMapPage> {
  final LatLng _initialCenter = const LatLng(3.1390, 101.6869);
  final List<Marker> _strayMarkers = [];

  @override
  void initState() {
    super.initState();
    _loadDummyMarkers();
  }

  void _loadDummyMarkers() {
    _strayMarkers.addAll([
      _buildMarker(const LatLng(3.1400, 101.6860), Colors.pink),
      _buildMarker(const LatLng(3.1380, 101.6890), Colors.blue),
      _buildMarker(const LatLng(3.1410, 101.6830), Colors.pink),
    ]);
  }

  Marker _buildMarker(LatLng position, Color color) {
    return Marker(
      point: position,
      width: 40,
      height: 40,
      child: Icon(Icons.pets, color: color, size: 30),
    );
  }

  // 🛑 OPENS OUR NEW CUSTOM CAMERA INSTEAD OF THE SYSTEM CAMERA
  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final firstCamera = cameras.first;

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomCameraScreen(
            camera: firstCamera,
            onPictureTaken: (String imagePath) {
              Navigator.pop(context); // Close the camera page
              Navigator.push( // Open the confirmation page
                context,
                MaterialPageRoute(
                  builder: (context) => ReportStrayPage(
                    imageFile: File(imagePath),
                    onConfirm: (LatLng newLocation) {
                      setState(() {
                        _strayMarkers.add(_buildMarker(newLocation, Colors.orange));
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color headerColor = isDark ? Colors.grey[850]! : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.brown[900]!;

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 16),
            decoration: BoxDecoration(
              color: headerColor,
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('U Pet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.brown[700])),
                    Text('welcome, User', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Stray Animals Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    Row(
                      children: [
                        const Icon(Icons.cloudy_snowing, color: Colors.blueGrey, size: 20),
                        const SizedBox(width: 4),
                        Text('Rainy', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: 14.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'tarc.edu.petcare_asgm',
                ),
                MarkerLayer(
                  markers: _strayMarkers,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20.0, right: 8.0),
        child: FloatingActionButton(
          backgroundColor: Colors.brown[700],
          onPressed: _openCamera,
          child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// =====================================================================
// CUSTOM CAMERA SCREEN (Matches your wireframe exactly!)
// =====================================================================
class CustomCameraScreen extends StatefulWidget {
  final CameraDescription camera;
  final Function(String) onPictureTaken;

  const CustomCameraScreen({super.key, required this.camera, required this.onPictureTaken});

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.high);
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                // 1. Camera Feed
                Positioned.fill(
                  child: CameraPreview(_controller),
                ),

                // 2. Grid Overlay (Matches Wireframe)
                Positioned.fill(
                  child: Column(
                    children: [
                      Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white30, width: 0.5)))),
                      Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white30, width: 0.5)))),
                      Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white30, width: 0.5)))),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    children: [
                      Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white30, width: 0.5)))),
                      Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white30, width: 0.5)))),
                      Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white30, width: 0.5)))),
                    ],
                  ),
                ),

                // 3. Top Back Arrow Button
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),

                // 4. Capture Button
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40.0),
                    child: GestureDetector(
                      onTap: () async {
                        try {
                          await _initializeControllerFuture;
                          final image = await _controller.takePicture();
                          widget.onPictureTaken(image.path);
                        } catch (e) {
                          debugPrint(e.toString());
                        }
                      },
                      child: Container(
                        height: 75,
                        width: 75,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
        },
      ),
    );
  }
}

// =====================================================================
// CONFIRMATION SCREEN (Wireframe Screen 3)
// =====================================================================
class ReportStrayPage extends StatefulWidget {
  final File imageFile;
  final Function(LatLng) onConfirm;

  const ReportStrayPage({super.key, required this.imageFile, required this.onConfirm});

  @override
  State<ReportStrayPage> createState() => _ReportStrayPageState();
}

class _ReportStrayPageState extends State<ReportStrayPage> {
  final TextEditingController _locationCtrl = TextEditingController();

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : Colors.brown[900]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Stray'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.brown, width: 2),
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: FileImage(widget.imageFile),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _locationCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.location_on, color: Colors.brown),
                labelText: 'Location Details',
                hintText: 'e.g., Near TAR UMT Block A',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey, width: 2),
                    ),
                    child: const Icon(Icons.refresh, size: 32, color: Colors.grey),
                  ),
                ),
                InkWell(
                  onTap: () {
                    widget.onConfirm(const LatLng(3.1395, 101.6875));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Stray reported successfully!'), backgroundColor: Colors.green),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: const Icon(Icons.check, size: 32, color: Colors.green),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}