import 'dart:math';
import '../models/trip.dart';

enum TravelMode { walking, driving, idle }
enum BehaviorEvent { overspeeding, harshBraking, harshAcceleration, sharpTurn }

class BehaviorAnalysis {
  final TravelMode mode;
  final double averageSpeed;
  final List<BehaviorEvent> events;
  final int score;

  BehaviorAnalysis({
    required this.mode,
    required this.averageSpeed,
    required this.events,
    required this.score,
  });
}

class BehaviorService {
  static const double walkingSpeedThreshold = 8.0; // km/h
  static const double overspeedThreshold = 80.0; // km/h
  static const double harshBrakingThreshold = -3.0; // m/s²
  static const double harshAccelerationThreshold = 3.0; // m/s²
  static const double sharpTurnThreshold = 45.0; // degrees

  static BehaviorAnalysis analyzeTrip(Trip trip) {
    if (trip.locations.length < 3) {
      return BehaviorAnalysis(
        mode: TravelMode.idle,
        averageSpeed: 0.0,
        events: [],
        score: 100,
      );
    }

    final speeds = _calculateSpeeds(trip.locations);
    final accelerations = _calculateAccelerations(speeds);
    final turns = _calculateTurns(trip.locations);
    
    final averageSpeed = speeds.isNotEmpty ? speeds.reduce((a, b) => a + b) / speeds.length : 0.0;
    final mode = _determineTravelMode(averageSpeed);
    
    final events = <BehaviorEvent>[];
    
    // Check for overspeeding
    for (final speed in speeds) {
      if (speed > overspeedThreshold) {
        events.add(BehaviorEvent.overspeeding);
        break;
      }
    }
    
    // Check for harsh braking/acceleration
    for (final acceleration in accelerations) {
      if (acceleration < harshBrakingThreshold) {
        events.add(BehaviorEvent.harshBraking);
      } else if (acceleration > harshAccelerationThreshold) {
        events.add(BehaviorEvent.harshAcceleration);
      }
    }
    
    // Check for sharp turns
    for (final turn in turns) {
      if (turn.abs() > sharpTurnThreshold) {
        events.add(BehaviorEvent.sharpTurn);
        break;
      }
    }
    
    final score = _calculateScore(events, averageSpeed, mode);
    
    return BehaviorAnalysis(
      mode: mode,
      averageSpeed: averageSpeed,
      events: events,
      score: score,
    );
  }

  static List<double> _calculateSpeeds(List<TripLocation> locations) {
    final speeds = <double>[];
    
    for (int i = 1; i < locations.length; i++) {
      final prev = locations[i - 1];
      final curr = locations[i];
      
      final distance = _calculateDistance(prev, curr); // meters
      final timeDiff = curr.timestamp.difference(prev.timestamp).inSeconds;
      
      if (timeDiff > 0) {
        final speedMs = distance / timeDiff; // m/s
        final speedKmh = speedMs * 3.6; // km/h
        speeds.add(speedKmh);
      }
    }
    
    return speeds;
  }

  static List<double> _calculateAccelerations(List<double> speeds) {
    final accelerations = <double>[];
    
    for (int i = 1; i < speeds.length; i++) {
      final speedDiff = (speeds[i] - speeds[i - 1]) / 3.6; // Convert to m/s
      final acceleration = speedDiff / 5.0; // Assuming 5-second intervals
      accelerations.add(acceleration);
    }
    
    return accelerations;
  }

  static List<double> _calculateTurns(List<TripLocation> locations) {
    final turns = <double>[];
    
    for (int i = 2; i < locations.length; i++) {
      final p1 = locations[i - 2];
      final p2 = locations[i - 1];
      final p3 = locations[i];
      
      final bearing1 = _calculateBearing(p1, p2);
      final bearing2 = _calculateBearing(p2, p3);
      
      double turn = bearing2 - bearing1;
      if (turn > 180) turn -= 360;
      if (turn < -180) turn += 360;
      
      turns.add(turn);
    }
    
    return turns;
  }

  static double _calculateDistance(TripLocation p1, TripLocation p2) {
    const double earthRadius = 6371000; // meters
    final lat1Rad = p1.latitude * pi / 180;
    final lat2Rad = p2.latitude * pi / 180;
    final deltaLatRad = (p2.latitude - p1.latitude) * pi / 180;
    final deltaLngRad = (p2.longitude - p1.longitude) * pi / 180;

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static double _calculateBearing(TripLocation p1, TripLocation p2) {
    final lat1Rad = p1.latitude * pi / 180;
    final lat2Rad = p2.latitude * pi / 180;
    final deltaLngRad = (p2.longitude - p1.longitude) * pi / 180;

    final y = sin(deltaLngRad) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(deltaLngRad);

    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  static TravelMode _determineTravelMode(double averageSpeed) {
    if (averageSpeed < 2.0) return TravelMode.idle;
    if (averageSpeed < walkingSpeedThreshold) return TravelMode.walking;
    return TravelMode.driving;
  }

  static int _calculateScore(List<BehaviorEvent> events, double averageSpeed, TravelMode mode) {
    int score = 100;
    
    // Deduct points for each bad behavior
    for (final event in events) {
      switch (event) {
        case BehaviorEvent.overspeeding:
          score -= 20;
          break;
        case BehaviorEvent.harshBraking:
          score -= 15;
          break;
        case BehaviorEvent.harshAcceleration:
          score -= 15;
          break;
        case BehaviorEvent.sharpTurn:
          score -= 10;
          break;
      }
    }
    
    return score.clamp(0, 100);
  }
}
