import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../services/behavior_service.dart';

class DrivingScoreScreen extends StatefulWidget {
  const DrivingScoreScreen({super.key});

  @override
  State<DrivingScoreScreen> createState() => _DrivingScoreScreenState();
}

class _DrivingScoreScreenState extends State<DrivingScoreScreen> {
  late Box<Trip> _tripsBox;
  Timer? _updateTimer;
  BehaviorAnalysis? _currentAnalysis;

  @override
  void initState() {
    super.initState();
    _tripsBox = Hive.box<Trip>('trips');
    _updateScore();
    
    // Update score every 10 seconds for real-time updates
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _updateScore();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _updateScore() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // Get today's trips
    final todayTrips = _tripsBox.values.where((trip) {
      return trip.startTime.isAfter(todayStart) && trip.startTime.isBefore(todayEnd);
    }).toList();

    if (todayTrips.isEmpty) {
      setState(() {
        _currentAnalysis = null;
      });
      return;
    }

    // Combine all today's trips for analysis
    final combinedTrip = Trip(
      id: 'combined',
      startTime: todayTrips.first.startTime,
      locations: [],
      totalDistance: 0.0,
    );

    for (final trip in todayTrips) {
      combinedTrip.locations.addAll(trip.locations);
      combinedTrip.totalDistance += trip.totalDistance;
    }

    if (combinedTrip.locations.isNotEmpty) {
      final analysis = BehaviorService.analyzeTrip(combinedTrip);
      setState(() {
        _currentAnalysis = analysis;
      });
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF4CAF50); // Green
    if (score >= 60) return const Color(0xFFFF7043); // Orange
    return const Color(0xFFD32F2F); // Red
  }

  String _getScoreText(int score) {
    if (score >= 80) return 'Good';
    if (score >= 60) return 'Moderate';
    return 'Poor';
  }

  String _getTravelModeText(TravelMode mode) {
    switch (mode) {
      case TravelMode.walking:
        return 'Walking';
      case TravelMode.driving:
        return 'Driving';
      case TravelMode.idle:
        return 'Idle';
    }
  }

  String _getBehaviorEventText(BehaviorEvent event) {
    switch (event) {
      case BehaviorEvent.overspeeding:
        return 'Overspeeding detected';
      case BehaviorEvent.harshBraking:
        return 'Harsh braking detected';
      case BehaviorEvent.harshAcceleration:
        return 'Harsh acceleration detected';
      case BehaviorEvent.sharpTurn:
        return 'Sharp turn detected';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driving Score'),
      ),
      body: _currentAnalysis == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No trips recorded today',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start a trip to see your driving score',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Score Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Text(
                            'Today\'s Score',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getScoreColor(_currentAnalysis!.score),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${_currentAnalysis!.score}',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    _getScoreText(_currentAnalysis!.score),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Travel Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Travel Information',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Mode:'),
                              Text(
                                _getTravelModeText(_currentAnalysis!.mode),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Average Speed:'),
                              Text(
                                '${_currentAnalysis!.averageSpeed.toStringAsFixed(1)} km/h',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Behavior Events Card
                  if (_currentAnalysis!.events.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Behavior Alerts',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            ...Set.from(_currentAnalysis!.events).map((event) => 
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning,
                                      color: Color(0xFFFF7043),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(_getBehaviorEventText(event)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  if (_currentAnalysis!.events.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF4CAF50),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'No behavior issues detected',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
