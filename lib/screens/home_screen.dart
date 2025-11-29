import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/trip.dart';
import '../services/location_service.dart';
import 'trip_list_screen.dart';
import 'driving_score_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  Trip? _currentTrip;
  Timer? _locationTimer;
  bool _isTracking = false;
  String? _errorMessage;
  late Box<Trip> _tripsBox;

  @override
  void initState() {
    super.initState();
    _tripsBox = Hive.box<Trip>('trips');
    _getCurrentLocation();
    _checkActiveTrip();
  }

  void _checkActiveTrip() async {
    print('Checking for active trips...');
    try {
      final activeTrip = _tripsBox.values.where((trip) => trip.endTime == null).firstOrNull;
      if (activeTrip != null) {
        print('Found active trip: ${activeTrip.id}');
        setState(() {
          _currentTrip = activeTrip;
          _isTracking = true;
        });
        
        _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
          _updateLocation();
        });
        print('Resumed active trip tracking');
      } else {
        print('No active trips found');
      }
    } catch (e) {
      print('Error checking active trip: $e');
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _errorMessage = null;
      });

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled. Please enable GPS.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permissions denied. Please grant location access.';
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permissions permanently denied. Please enable in settings.';
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _errorMessage = null;
      });
      _mapController.move(LatLng(position.latitude, position.longitude), 15.0);
      print('Location obtained: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting location: $e';
      });
      print('Error getting location: $e');
    }
  }

  void _startTrip() async {
    print('Start trip button pressed');
    
    if (_currentPosition == null) {
      print('No current position available');
      await _getCurrentLocation();
      if (_currentPosition == null) {
        print('Still no position after getting location');
        return;
      }
    }

    try {
      final trip = Trip(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: DateTime.now(),
        locations: [
          TripLocation(
            latitude: _currentPosition!.latitude,
            longitude: _currentPosition!.longitude,
            timestamp: DateTime.now(),
          )
        ],
      );

      await _tripsBox.add(trip);
      print('Trip added to database: ${trip.id}');
      
      setState(() {
        _currentTrip = trip;
        _isTracking = true;
      });
      print('State updated: tracking = $_isTracking');

      // Start background tracking
      await LocationService.startTracking();
      print('Background tracking started');

      _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _updateLocation();
      });
      print('Location timer started');
    } catch (e) {
      print('Error starting trip: $e');
      setState(() {
        _errorMessage = 'Error starting trip: $e';
      });
    }
  }

  void _stopTrip() async {
    if (_currentTrip == null) return;

    try {
      _currentTrip!.endTime = DateTime.now();
      await _currentTrip!.save();
      print('Trip stopped and saved');

      _locationTimer?.cancel();
      
      // Stop background tracking
      await LocationService.stopTracking();
      print('Background tracking stopped');
      
      setState(() {
        _isTracking = false;
        _currentTrip = null;
      });
      print('Trip stopped successfully');
    } catch (e) {
      print('Error stopping trip: $e');
      setState(() {
        _errorMessage = 'Error stopping trip: $e';
      });
    }
  }

  Future<void> _updateLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print('Location updated: ${position.latitude}, ${position.longitude}');
      
      if (_currentTrip != null) {
        final newLocation = TripLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
        );
        
        _currentTrip!.locations.add(newLocation);
        
        if (_currentTrip!.locations.length > 1) {
          final lastLocation = _currentTrip!.locations[_currentTrip!.locations.length - 2];
          final distance = Geolocator.distanceBetween(
            lastLocation.latitude,
            lastLocation.longitude,
            position.latitude,
            position.longitude,
          );
          _currentTrip!.totalDistance += distance;
          print('Distance added: $distance, Total: ${_currentTrip!.totalDistance}');
        }
        
        await _currentTrip!.save();
        print('Trip saved with ${_currentTrip!.locations.length} locations');
      }

      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.speed),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DrivingScoreScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TripListScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(20.5937, 78.9629), // India center
              zoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.location_tracker_app',
              ),
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      builder: (context) => const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              if (_currentTrip != null && _currentTrip!.locations.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _currentTrip!.locations
                          .map((loc) => LatLng(loc.latitude, loc.longitude))
                          .toList(),
                      color: Colors.red,
                      strokeWidth: 3.0,
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _getCurrentLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3F51B5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_isTracking && _currentTrip != null) ...[
                      Text(
                        'Distance: ${(_currentTrip!.totalDistance / 1000).toStringAsFixed(2)} km',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                    ],
                    ElevatedButton(
                      onPressed: _currentPosition != null 
                          ? (_isTracking ? _stopTrip : _startTrip)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTracking 
                            ? const Color(0xFFD32F2F) // Error Red for stop
                            : const Color(0xFFFF7043), // Deep Orange for start
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isTracking ? 'Stop Trip' : 'Start Trip',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
