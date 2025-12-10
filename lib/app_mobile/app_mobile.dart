import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'screens/auth_screen.dart';
import 'screens/report_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/issues_screen.dart';

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Green Watch',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 114, 164, 117),
        ),
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
          GoogleMap(
            initialCameraPosition: _cameraPosition,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
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
              // Handle map tap events here
              print(
                'Map tapped at: ${position.latitude}, ${position.longitude}',
              );
            },
          ),
          // Floating action button for current location
          Positioned(
            top: 50,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location, color: Colors.green),
            ),
          ),
        ],
      ),

      // --------------------
      // Tab 1: Issues Screen
      // --------------------
      const IssuesScreen(),

      // --------------------
      // Tab 2: Report Screen
      // --------------------
      const ReportScreen(),

      // ---------------------
      // Tab 3: Profile Screen
      // ---------------------
      const ProfileScreen(),
    ];

    return Scaffold(
      // Switch the body based on the selected index
      body: pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Issues'),
          BottomNavigationBarItem(icon: Icon(Icons.report), label: 'Report'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color.fromARGB(255, 114, 164, 117),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}
