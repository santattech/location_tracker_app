import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'models/daily_distance.dart';
import 'models/tracked_location.dart';
import 'models/completed_place.dart';
import 'config/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  final appDocumentDir = await path_provider.getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  Hive.registerAdapter(DailyDistanceAdapter());
  Hive.registerAdapter(TrackedLocationAdapter());
  Hive.registerAdapter(CompletedPlaceAdapter());
  await Hive.openBox<DailyDistance>('distances');
  await Hive.openBox<TrackedLocation>('locations');
  await Hive.openBox<CompletedPlace>('completed_places');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LocationTrackerScreen(),
    );
  }
}

class LocationTrackerScreen extends StatefulWidget {
  const LocationTrackerScreen({super.key});

  @override
  State<LocationTrackerScreen> createState() => _LocationTrackerScreenState();
}

class _LocationTrackerScreenState extends State<LocationTrackerScreen> {
  Position? _currentPosition;
  double _totalDistance = 0.0;
  Position? _lastPosition;
  Timer? _locationTimer;
  String _lastUpdateTime = '';
  bool _isTracking = false;
  String _todayDate = '';
  List<List<dynamic>> _csvData = [];
  late Box<DailyDistance> _distancesBox;
  late Box<TrackedLocation> _locationsBox;
  late Box<CompletedPlace> _completedPlacesBox;
  Set<String> _completedPlaces = {};
  static const int MAX_LOCATIONS_PER_DAY =
      8640; // Store max 8640 locations per day (1 location per 10 seconds)

  @override
  void initState() {
    super.initState();
    _distancesBox = Hive.box<DailyDistance>('distances');
    _locationsBox = Hive.box<TrackedLocation>('locations');
    _completedPlacesBox = Hive.box<CompletedPlace>('completed_places');
    _checkPermissions();
    _loadTodayDistance();
    _loadCompletedPlaces();
    _todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadCSVData();
    _cleanupOldLocations();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
  }

  Future<void> _cleanupOldLocations() async {
    final now = DateTime.now();
    final cutoffDate = DateTime(now.year, now.month, now.day - 7);
    final keys = _locationsBox.keys.where((key) {
      final location = _locationsBox.get(key) as TrackedLocation?;
      return location != null && location.timestamp.isBefore(cutoffDate);
    }).toList();

    await _locationsBox.deleteAll(keys);
  }

  void _loadCompletedPlaces() {
    _completedPlaces =
        _completedPlacesBox.values.map((place) => place.name).toSet();
  }

  void _checkPlaceCompletion(Position position) {
    // Calculate current aerial distance from home
    final distanceFromHome = Geolocator.distanceBetween(
          LocationConstants.HOME_LATITUDE,
          LocationConstants.HOME_LONGITUDE,
          position.latitude,
          position.longitude,
        ) /
        1000; // Convert to kilometers

    for (var row in _csvData) {
      final placeName = row[0].toString();
      final requiredDistance =
          double.parse(row[3].toString()); // Aerial distance from CSV

      if (distanceFromHome >= requiredDistance) {
        // Mark as completed if not already completed
        if (!_completedPlaces.contains(placeName)) {
          _completedPlaces.add(placeName);
          _completedPlacesBox.add(CompletedPlace(
            name: placeName,
            completedAt: DateTime.now(),
          ));
          setState(() {});
        }
      } else {
        // Mark as incomplete if previously completed
        if (_completedPlaces.contains(placeName)) {
          _completedPlaces.remove(placeName);
          // Remove from Hive box
          final keysToDelete = _completedPlacesBox.values
              .where((place) => place.name == placeName)
              .map((place) => _completedPlacesBox
                  .keyAt(_completedPlacesBox.values.toList().indexOf(place)))
              .toList();
          _completedPlacesBox.deleteAll(keysToDelete);
          setState(() {});
        }
      }
    }
  }

  void _startTracking() async {
    setState(() => _isTracking = true);

    // Start periodic location updates
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        Position newPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // Store the location
        final location = TrackedLocation.fromPosition(newPosition);
        final todayLocations = _locationsBox.values
            .where((loc) => loc.date == location.date)
            .length;

        if (todayLocations < MAX_LOCATIONS_PER_DAY) {
          await _locationsBox.add(location);
        }

        // Check for completed places
        _checkPlaceCompletion(newPosition);

        setState(() {
          _currentPosition = newPosition;
          _lastUpdateTime = DateFormat('HH:mm:ss').format(DateTime.now());

          if (_lastPosition != null) {
            double distance = Geolocator.distanceBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              newPosition.latitude,
              newPosition.longitude,
            );
            _totalDistance += distance;
            _saveTodayDistance();
          }

          _lastPosition = newPosition;
        });
      } catch (e) {
        print('Error getting location: $e');
      }
    });
  }

  void _stopTracking() {
    _locationTimer?.cancel();
    setState(() => _isTracking = false);
  }

  Future<void> _saveTodayDistance() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dailyDistance = DailyDistance(
      date: today,
      distance: _totalDistance,
      lastUpdated: DateTime.now(),
    );
    await _distancesBox.put(today, dailyDistance);
  }

  Future<void> _loadTodayDistance() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dailyDistance = _distancesBox.get(today);
    setState(() {
      _totalDistance = dailyDistance?.distance ?? 0.0;
      if (dailyDistance != null) {
        _lastUpdateTime =
            DateFormat('HH:mm:ss').format(dailyDistance.lastUpdated);
      }
    });
  }

  Future<void> _loadCSVData() async {
    final rawData = await rootBundle.loadString('lib/puri_stoppages.csv');
    List<List<dynamic>> listData = const CsvToListConverter().convert(rawData);
    setState(() {
      // Remove header row
      _csvData = listData.sublist(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Current Location',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentPosition != null
                            ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}\nLong: ${_currentPosition!.longitude.toStringAsFixed(6)}'
                            : 'Waiting for location...',
                        textAlign: TextAlign.center,
                      ),
                      if (_currentPosition != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Distance from Home: ${(Geolocator.distanceBetween(
                                LocationConstants.HOME_LATITUDE,
                                LocationConstants.HOME_LONGITUDE,
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              ) / 1000).toStringAsFixed(2)} km',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                        ),
                      ],
                      if (_lastUpdateTime.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Last updated: $_lastUpdateTime',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Today\'s Distance',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_totalDistance / 1000).toStringAsFixed(2)} km',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        _todayDate,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Stoppages',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${_completedPlaces.length}/${_csvData.length} completed',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          itemCount: _csvData.length,
                          itemBuilder: (context, index) {
                            final row = _csvData[index];
                            final placeName = row[0].toString();
                            final isCompleted =
                                _completedPlaces.contains(placeName);
                            final containsToll =
                                placeName.toLowerCase().contains('toll');

                            return ListTile(
                              title: Text(
                                placeName,
                                style: TextStyle(
                                  color: containsToll
                                      ? Colors.green
                                      : (isCompleted
                                          ? Colors.orange
                                          : Colors.black),
                                  fontWeight:
                                      isCompleted ? FontWeight.bold : null,
                                ),
                              ),
                              subtitle: Text('${row[4]} km aerial'),
                              trailing: isCompleted
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green)
                                  : Text('${row[4]} km'),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isTracking ? _stopTracking : _startTracking,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
