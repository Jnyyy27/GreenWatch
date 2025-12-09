import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class MapSearchScreen extends StatefulWidget {
  const MapSearchScreen({super.key});

  @override
  State<MapSearchScreen> createState() => _MapSearchScreenState();
}

class _MapSearchScreenState extends State<MapSearchScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _pickedLatLng;
  String? _pickedAddress;
  bool _isSearching = false;
  bool _isGettingLocation = false;

  // Google Maps API Key - you'll need to get this from local.properties or environment
  // For now, using a placeholder - you should load this from your config
  static const String _googleMapsApiKey =
      'AIzaSyAJTrzgxdxSqyCu9GLIr5EVJIqb4ZuhIu4';

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(3.1390, 101.6869), // fallback to Kuala Lumpur roughly
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _jumpToCurrentLocation();
  }

  Future<void> _jumpToCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isGettingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isGettingLocation = false;
          });
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final controller = await _controller.future;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 16),
        ),
      );
    } catch (e) {
      // ignore
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      // First try Google Places API for place names (like "KFC", "restaurant", etc.)
      final placeResult = await _searchPlaces(query);

      if (placeResult != null) {
        final latlng = LatLng(placeResult['lat'], placeResult['lng']);
        final address = placeResult['address'] as String;

        final controller = await _controller.future;
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: latlng, zoom: 16),
          ),
        );

        setState(() {
          _pickedLatLng = latlng;
          _pickedAddress = address;
        });
        return;
      }

      // Fallback to geocoding for addresses
      try {
        final List<Location> locations = await locationFromAddress(query);
        if (locations.isNotEmpty) {
          final loc = locations.first;
          final latlng = LatLng(loc.latitude, loc.longitude);

          final controller = await _controller.future;
          await controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: latlng, zoom: 16),
            ),
          );

          // Reverse geocode for a friendly address string
          final placemarks = await placemarkFromCoordinates(
            loc.latitude,
            loc.longitude,
          );
          String address = _formatPlacemark(
            placemarks.isNotEmpty ? placemarks.first : null,
          );

          setState(() {
            _pickedLatLng = latlng;
            _pickedAddress = address.isNotEmpty ? address : query;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No results found for that query')),
          );
        }
      } catch (geocodeError) {
        // If geocoding also fails, show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No results found. Try searching with a more specific address or place name.',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  // Search using Google Places API Text Search
  Future<Map<String, dynamic>?> _searchPlaces(String query) async {
    try {
      // Use Places API Text Search
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json'
        '?query=${Uri.encodeComponent(query)}'
        '&key=$_googleMapsApiKey',
      );

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' &&
            data['results'] != null &&
            data['results'].isNotEmpty) {
          final result = data['results'][0];
          final location = result['geometry']['location'];

          return {
            'lat': location['lat'] as double,
            'lng': location['lng'] as double,
            'address':
                result['formatted_address'] as String? ??
                result['name'] as String? ??
                query,
            'name': result['name'] as String? ?? query,
          };
        } else if (data['status'] == 'ZERO_RESULTS') {
          return null; // No results, will try geocoding
        } else {
          // Handle other statuses (OVER_QUERY_LIMIT, REQUEST_DENIED, etc.)
          print(
            'Places API error: ${data['status']} - ${data['error_message'] ?? ''}',
          );
          return null;
        }
      } else {
        print('Places API HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Places API search error: $e');
      return null; // Return null to fallback to geocoding
    }
  }

  String _formatPlacemark(Placemark? p) {
    if (p == null) return '';
    final parts = <String>[];
    if (p.street != null && p.street!.isNotEmpty) parts.add(p.street!);
    if (p.subLocality != null && p.subLocality!.isNotEmpty)
      parts.add(p.subLocality!);
    if (p.locality != null && p.locality!.isNotEmpty) parts.add(p.locality!);
    if (p.postalCode != null && p.postalCode!.isNotEmpty)
      parts.add(p.postalCode!);
    if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty)
      parts.add(p.administrativeArea!);
    return parts.isNotEmpty ? parts.join(', ') : '';
  }

  Future<void> _onMapLongPress(LatLng pos) async {
    setState(() {
      _pickedLatLng = pos;
      _pickedAddress = null;
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      setState(() {
        _pickedAddress = _formatPlacemark(
          placemarks.isNotEmpty ? placemarks.first : null,
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reverse geocode failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final marker = _pickedLatLng != null
        ? Marker(markerId: const MarkerId('picked'), position: _pickedLatLng!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Location'),
        backgroundColor: const Color.fromARGB(255, 96, 156, 101),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _searchAddress,
                    decoration: InputDecoration(
                      hintText: 'Search address or place name',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isGettingLocation ? null : _jumpToCurrentLocation,
                  icon: _isGettingLocation
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  tooltip: 'Center on current location',
                ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: _initialCamera,
              onMapCreated: (controller) => _controller.complete(controller),
              myLocationEnabled: true,
              zoomControlsEnabled: false,
              onLongPress: _onMapLongPress,
              markers: marker != null ? {marker} : {},
            ),
          ),
          if (_pickedAddress != null || _pickedLatLng != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_pickedAddress != null)
                    Text(
                      _pickedAddress!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(height: 6),
                  if (_pickedLatLng != null)
                    Text(
                      'GPS: ${_pickedLatLng!.latitude.toStringAsFixed(6)}, ${_pickedLatLng!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (_pickedLatLng != null) {
                        Navigator.of(context).pop({
                          'address':
                              _pickedAddress ?? _searchController.text.trim(),
                          'latitude': _pickedLatLng!.latitude,
                          'longitude': _pickedLatLng!.longitude,
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please pick a location first'),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Use this location'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
