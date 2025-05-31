import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/tracked_location.dart';
import '../config/constants.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  List<TrackedLocation> _trackedLocations = [];
  bool _isFollowingLocation = true;
  String _todayDate = '';

  @override
  void initState() {
    super.initState();
    _todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadTrackedLocations();
    _getCurrentLocation();
  }

  void _loadTrackedLocations() {
    final locationsBox = Hive.box<TrackedLocation>('locations');
    setState(() {
      // Filter locations for today only
      _trackedLocations = locationsBox.values
          .where((location) => location.date == _todayDate)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp)); // Sort by timestamp
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });

      if (_isFollowingLocation) {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          15.0,
        );
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Today\'s Tracked Locations'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(
              _isFollowingLocation ? Icons.gps_fixed : Icons.gps_not_fixed,
            ),
            onPressed: () {
              setState(() {
                _isFollowingLocation = !_isFollowingLocation;
                if (_isFollowingLocation && _currentPosition != null) {
                  _mapController.move(
                    LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    15.0,
                  );
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Showing ${_trackedLocations.length} locations for $_todayDate',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _currentPosition != null
                    ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                    : _trackedLocations.isNotEmpty
                        ? LatLng(_trackedLocations.last.latitude, _trackedLocations.last.longitude)
                        : LatLng(LocationConstants.HOME_LATITUDE, LocationConstants.HOME_LONGITUDE),
                zoom: 13.0,
                onTap: (_, __) {
                  setState(() {
                    _isFollowingLocation = false;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.location_tracker_app',
                ),
                // Draw path of tracked locations
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _trackedLocations
                          .map((loc) => LatLng(
                                loc.latitude,
                                loc.longitude,
                              ))
                          .toList(),
                      color: Colors.blue,
                      strokeWidth: 3.0,
                    ),
                  ],
                ),
                // Show tracked location markers
                MarkerLayer(
                  markers: [
                    // Home marker
                    Marker(
                      point: LatLng(
                        LocationConstants.HOME_LATITUDE,
                        LocationConstants.HOME_LONGITUDE,
                      ),
                      width: 80,
                      height: 80,
                      builder: (context) => const Icon(
                        Icons.home,
                        color: Colors.red,
                        size: 30,
                      ),
                    ),
                    // Current location marker
                    if (_currentPosition != null)
                      Marker(
                        point: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        width: 80,
                        height: 80,
                        builder: (context) => Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 30,
                          ),
                        ),
                      ),
                    // Tracked locations markers with timestamps
                    ..._trackedLocations.map(
                      (loc) => Marker(
                        point: LatLng(
                          loc.latitude,
                          loc.longitude,
                        ),
                        width: 60,
                        height: 60,
                        builder: (context) => Tooltip(
                          message: DateFormat('HH:mm:ss').format(loc.timestamp),
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _getCurrentLocation();
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
} 