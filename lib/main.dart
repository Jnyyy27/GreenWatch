import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_options.dart';
import 'screens/profile_screen.dart';
import 'screens/report_screen.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Green Watch',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 114, 164, 117)),
      ),
      // GATEKEEPER LOGIC:
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. If user is logged in, show the App (MyHomePage)
          if (snapshot.hasData) {
            return const MyHomePage(title: 'Green Watch');
          }
          // 2. If user is NOT logged in, show Login Page
          return const AuthScreen();
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  int _selectedIndex = 0;
  bool _mapError = false;
  String? _mapErrorMessage;

  // Default location (fallback if location permission is denied)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(5.4164, 100.3327), //Penang, Georgetown
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    // Request location permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location services are disabled. Please enable them.',
            ),
          ),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are permanently denied. Please enable them in settings.',
            ),
          ),
        );
      }
      return;
    }

    // Get current position
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      // Move camera to current location
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!, zoom: 15.0),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    }
  }

  CameraPosition get _cameraPosition {
    if (_currentLocation != null) {
      return CameraPosition(target: _currentLocation!, zoom: 15.0);
    }
    return _initialPosition;
  }

  Set<Marker> get _markers {
    if (_currentLocation != null) {
      return {
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'You are here',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };
    }
    return {};
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Handle navigation based on selected index
    switch (index) {
      case 0:
        // Map - already on this page
        break;
      case 1:
        // Report - Navigate to report page (you'll need to create this)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report page')),
        );
        break;
      case 2:
        // Profile - Navigate to profile page (you'll need to create this)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile page')),
        );
        break;
    }
  }

@override
  Widget build(BuildContext context) {
    // Define the screens for each tab
    final List<Widget> pages = [
      // -----------------
      // Tab 0: Map Screen
      // -----------------
      Stack(
        children: [
          // 1. Map or Error View
          if (_mapError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Map Failed to Load',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _mapErrorMessage ?? 'Unknown error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _mapError = false;
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GoogleMap(
              initialCameraPosition: _cameraPosition,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                print('🗺️ Google Map created successfully');
                setState(() {
                  _mapError = false;
                  _mapErrorMessage = null;
                });
                // If location is already loaded, move camera to it
                if (_currentLocation != null) {
                  controller.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(target: _currentLocation!, zoom: 15.0),
                    ),
                  );
                }
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapType: MapType.normal,
              markers: _markers,
              onTap: (LatLng position) {
                print('Map tapped at: ${position.latitude}, ${position.longitude}');
              },
            ),

          // 2. Floating Action Button (Custom Location Button)
          Positioned(
            top: 50,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _getCurrentLocation,
              child: const Icon(
                Icons.my_location,
                color: Color.fromARGB(255, 114, 164, 117),
              ),
            ),
          ),
        ],
      ),

      // --------------------
      // Tab 1: Report Screen
      // --------------------
      const ReportScreen(),

      // ---------------------
      // Tab 2: Profile Screen
      // ---------------------
      const ProfileScreen(),
    ];

    return Scaffold(
      // Switch the body based on the selected index
      body: pages[_selectedIndex],
      
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.report), label: 'Report'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color.fromARGB(255, 114, 164, 117),
        onTap: _onItemTapped,
      ),
    );
  }
}