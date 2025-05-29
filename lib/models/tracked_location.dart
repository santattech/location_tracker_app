import 'package:hive/hive.dart';

part 'tracked_location.g.dart';

@HiveType(typeId: 1)
class TrackedLocation {
  @HiveField(0)
  final DateTime timestamp;

  @HiveField(1)
  final double latitude;

  @HiveField(2)
  final double longitude;

  @HiveField(3)
  final double? accuracy;

  @HiveField(4)
  final String date; // YYYY-MM-DD format for easy querying

  TrackedLocation({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.date,
  });

  // Helper method to create from Position
  factory TrackedLocation.fromPosition(Position position) {
    final now = DateTime.now();
    return TrackedLocation(
      timestamp: now,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      date: "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
    );
  }
} 