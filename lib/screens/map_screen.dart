import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
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
  
  // Playback state
  bool _isPlaying = false;
  int _currentLocationIndex = 0;
  Timer? _playbackTimer;
  double _playbackSpeed = 1.0; // Multiplier for playback speed
  
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

  void _startPlayback() {
    if (_trackedLocations.isEmpty) return;
    
    setState(() {
      _isPlaying = true;
      if (_currentLocationIndex >= _trackedLocations.length) {
        _currentLocationIndex = 0;
      }
    });

    // Calculate time difference between consecutive points
    _playbackTimer = Timer.periodic(Duration(milliseconds: (500 ~/ _playbackSpeed)), (timer) {
      if (_currentLocationIndex < _trackedLocations.length - 1) {
        setState(() {
          _currentLocationIndex++;
        });
        
        // Move map to follow the playback marker
        if (_isFollowingLocation) {
          _mapController.move(
            LatLng(
              _trackedLocations[_currentLocationIndex].latitude,
              _trackedLocations[_currentLocationIndex].longitude,
            ),
            15.0,
          );
        }
      } else {
        _stopPlayback();
      }
    });
  }

  void _stopPlayback() {
    _playbackTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });
  }

  void _resetPlayback() {
    _stopPlayback();
    setState(() {
      _currentLocationIndex = 0;
    });
  }

  void _onSliderChanged(double value) {
    setState(() {
      _currentLocationIndex = value.toInt();
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
                if (_isFollowingLocation) {
                  if (_isPlaying && _currentLocationIndex < _trackedLocations.length) {
                    _mapController.move(
                      LatLng(
                        _trackedLocations[_currentLocationIndex].latitude,
                        _trackedLocations[_currentLocationIndex].longitude,
                      ),
                      15.0,
                    );
                  } else if (_currentPosition != null) {
                    _mapController.move(
                      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      15.0,
                    );
                  }
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
                      color: Colors.blue.withOpacity(0.3),
                      strokeWidth: 3.0,
                    ),
                    // Draw path up to current playback position
                    if (_trackedLocations.isNotEmpty)
                      Polyline(
                        points: _trackedLocations
                            .sublist(0, _currentLocationIndex + 1)
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
                    // Playback position marker
                    if (_trackedLocations.isNotEmpty)
                      Marker(
                        point: LatLng(
                          _trackedLocations[_currentLocationIndex].latitude,
                          _trackedLocations[_currentLocationIndex].longitude,
                        ),
                        width: 30,
                        height: 30,
                        builder: (context) => Container(
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    // All tracked locations as small dots
                    ..._trackedLocations.map(
                      (loc) => Marker(
                        point: LatLng(
                          loc.latitude,
                          loc.longitude,
                        ),
                        width: 10,
                        height: 10,
                        builder: (context) => Tooltip(
                          message: DateFormat('HH:mm:ss').format(loc.timestamp),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.5),
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
          // Playback controls
          if (_trackedLocations.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Time indicator
                  Text(
                    DateFormat('HH:mm:ss').format(
                      _trackedLocations[_currentLocationIndex].timestamp,
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  // Progress slider
                  Slider(
                    value: _currentLocationIndex.toDouble(),
                    min: 0,
                    max: (_trackedLocations.length - 1).toDouble(),
                    onChanged: _onSliderChanged,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Reset button
                      IconButton(
                        icon: const Icon(Icons.replay),
                        onPressed: _resetPlayback,
                      ),
                      // Play/Pause button
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: _isPlaying ? _stopPlayback : _startPlayback,
                      ),
                      // Speed control
                      PopupMenuButton<double>(
                        initialValue: _playbackSpeed,
                        onSelected: (speed) {
                          setState(() {
                            _playbackSpeed = speed;
                          });
                          if (_isPlaying) {
                            _stopPlayback();
                            _startPlayback();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 0.5,
                            child: Text('0.5x'),
                          ),
                          const PopupMenuItem(
                            value: 1.0,
                            child: Text('1x'),
                          ),
                          const PopupMenuItem(
                            value: 2.0,
                            child: Text('2x'),
                          ),
                          const PopupMenuItem(
                            value: 5.0,
                            child: Text('5x'),
                          ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('${_playbackSpeed}x'),
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
    _playbackTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }
} 