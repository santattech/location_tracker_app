import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/trip.dart';
import 'trip_list_screen.dart';

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
  late Box<Trip> _tripsBox;

  @override
  void initState() {
    super.initState();
    _tripsBox = Hive.box<Trip>('trips');
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
      _mapController.move(LatLng(position.latitude, position.longitude), 15.0);
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _startTrip() {
    if (_currentPosition == null) return;

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

    _tripsBox.add(trip);
    
    setState(() {
      _currentTrip = trip;
      _isTracking = true;
    });

    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateLocation();
    });
  }

  void _stopTrip() {
    if (_currentTrip == null) return;

    _currentTrip!.endTime = DateTime.now();
    _currentTrip!.save();

    _locationTimer?.cancel();
    
    setState(() {
      _isTracking = false;
      _currentTrip = null;
    });
  }

  Future<void> _updateLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      
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
        }
        
        _currentTrip!.save();
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
                    if (_isTracking && _currentTrip != null) ...[
                      Text(
                        'Distance: ${(_currentTrip!.totalDistance / 1000).toStringAsFixed(2)} km',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                    ],
                    ElevatedButton(
                      onPressed: _isTracking ? _stopTrip : _startTrip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTracking ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text(_isTracking ? 'Stop Trip' : 'Start Trip'),
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
