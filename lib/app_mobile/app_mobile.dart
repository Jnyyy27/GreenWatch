import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'screens/auth_screen.dart';
import 'screens/report_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/issues_screen.dart';
import 'screens/issue_detail_screen.dart';
import 'screens/announcement_screen.dart';

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
  final Map<String, BitmapDescriptor> _markerIcons = {};
  Set<Marker> _issueMarkers = {};
  Set<String> _loadedDocumentIds =
      {}; // Track loaded documents to avoid unnecessary updates
  StreamSubscription<QuerySnapshot>? _reportsSubscription;

  // Default location (fallback if location permission is denied)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(5.4164, 100.3327), //Penang, Georgetown
    zoom: 12.0,
  );

  // Map category names to asset file names
  String _getMarkerAssetPath(String category) {
    switch (category) {
      case 'Damage roads':
        return 'assets/markers/Damage roads.png';
      case 'Road potholes':
        return 'assets/markers/Road potholes.png';
      case 'Road signs':
        return 'assets/markers/Road signs.png';
      case 'Faded road markings':
        return 'assets/markers/Faded road markings.png';
      case 'Fallen trees':
        return 'assets/markers/Fallen Trees.png';
      case 'Traffic lights':
        return 'assets/markers/Traffic lights.png';
      case 'Streetlights':
        return 'assets/markers/Streetlights.png';
      case 'Public facilities':
        return 'assets/markers/Public facilities.png';
      default:
        return 'assets/markers/Public facilities.png'; // Default fallback
    }
  }

  // Load custom marker icon from asset
  Future<BitmapDescriptor> _loadMarkerIcon(String assetPath) async {
    if (_markerIcons.containsKey(assetPath)) {
      return _markerIcons[assetPath]!;
    }

    try {
      final ByteData data = await rootBundle.load(assetPath);
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 100, // Resize to 100px width
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ByteData? byteData = await frameInfo.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final Uint8List uint8List = byteData!.buffer.asUint8List();

      final BitmapDescriptor icon = BitmapDescriptor.fromBytes(uint8List);
      _markerIcons[assetPath] = icon;
      return icon;
    } catch (e) {
      print('Error loading marker icon: $e');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _preloadMarkerIcons();
    _setupReportsListener();
  }

  // Set up Firestore listener without rebuilding widgets
  void _setupReportsListener() {
    _reportsSubscription = FirebaseFirestore.instance
        .collection('reports')
        .where('status', whereIn: ['Submitted', 'Viewed', 'In Progress'])
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            _updateMarkersFromSnapshot(snapshot);
          }
        });
  }

  // Pre-load all marker icons at startup to avoid loading during updates
  Future<void> _preloadMarkerIcons() async {
    final categories = [
      'Damage roads',
      'Road potholes',
      'Road signs',
      'Faded road markings',
      'Fallen trees',
      'Traffic lights',
      'Streetlights',
      'Public facilities',
    ];

    for (final category in categories) {
      final assetPath = _getMarkerAssetPath(category);
      await _loadMarkerIcon(assetPath);
    }
  }

  @override
  void dispose() {
    _reportsSubscription?.cancel();
    _mapController?.dispose();
    _mapController = null;
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
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _currentLocation!, zoom: 15.0),
          ),
        );
      }
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

  // Update markers from Firestore snapshot (only if documents changed)
  // Hides reports whose status is "resolved" from the map.
  Future<void> _updateMarkersFromSnapshot(QuerySnapshot snapshot) async {
    try {
      // Check if documents have actually changed
      final currentDocIds = snapshot.docs.map((doc) => doc.id).toSet();
      if (currentDocIds.length == _loadedDocumentIds.length &&
          currentDocIds.every((id) => _loadedDocumentIds.contains(id))) {
        // No changes, skip update
        return;
      }

      final Set<Marker> markers = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final latitude = data['latitude'] as double?;
        final longitude = data['longitude'] as double?;
        final category = data['category'] as String? ?? '';
        final description = data['description'] as String? ?? '';
        final location = data['exactLocation'] as String? ?? '';
        final status = (data['status'] as String? ?? '');

        // Skip resolved reports so they don't appear on the map
        if (status == 'Resolved') {
          continue;
        }

        if (latitude != null && longitude != null) {
          final assetPath = _getMarkerAssetPath(category);
          // Icons are pre-loaded, so this should be instant
          final icon = await _loadMarkerIcon(assetPath);

          markers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(latitude, longitude),
              icon: icon,
              infoWindow: InfoWindow(
                title: category,
                snippet: description.isNotEmpty ? description : location,
              ),
              onTap: () {
                // Navigate to issue detail screen when marker is tapped
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        IssueDetailScreen(issueData: data, docId: doc.id),
                  ),
                );
              },
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _issueMarkers = markers;
          _loadedDocumentIds = currentDocIds;
        });
      }
    } catch (e) {
      print('Error updating issue markers: $e');
    }
  }

  Set<Marker> get _markers {
    final Set<Marker> allMarkers = Set.from(_issueMarkers);

    if (_currentLocation != null) {
      allMarkers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'You are here',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
    return allMarkers;
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
          // GoogleMap widget - only rebuilds when _markers state changes
          GoogleMap(
            key: const ValueKey(
              'map',
            ), // Stable key prevents unnecessary rebuilds
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
        ],
      ),

      // --------------------
      // Tab 1: Issues Screen
      // --------------------
      const IssuesScreen(),

      // --------------------
      // Tab 2: Report Screen
      // --------------------
      const ReportScreenWithMLValidation(),

      // ---------------------
      // Tab 3: Announcement Screen
      // ---------------------
      const AnnouncementScreen(),

      // ---------------------
      // Tab 4: Profile Screen
      // ---------------------
      const ProfileScreen(),
    ];

    return Scaffold(
      // Switch the body based on the selected index
      body: pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        selectedFontSize: 11.5,
        unselectedFontSize: 8,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Issues'),
          BottomNavigationBarItem(icon: Icon(Icons.report), label: 'Report'),
          BottomNavigationBarItem(
            icon: Icon(Icons.announcement),
            label: 'Info Hub',
          ),
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
