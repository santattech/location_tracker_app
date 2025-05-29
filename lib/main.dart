import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'models/daily_distance.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  final appDocumentDir = await path_provider.getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  Hive.registerAdapter(DailyDistanceAdapter());
  await Hive.openBox<DailyDistance>('distances');
  
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

  @override
  void initState() {
    super.initState();
    _distancesBox = Hive.box<DailyDistance>('distances');
    _checkPermissions();
    _loadTodayDistance();
    _todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadCSVData();
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

  Future<void> _startTracking() async {
    setState(() => _isTracking = true);

    // Start periodic location updates
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        Position newPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

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
        _lastUpdateTime = DateFormat('HH:mm:ss').format(dailyDistance.lastUpdated);
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
                      Text(
                        'Stoppages',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          itemCount: _csvData.length,
                          itemBuilder: (context, index) {
                            final row = _csvData[index];
                            return ListTile(
                              title: Text(row[0].toString()),
                              trailing: Text('${row[4]} km'),
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
