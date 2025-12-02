import 'package:hive/hive.dart';
import 'package:geolocator/geolocator.dart';

part 'trip.g.dart';

@HiveType(typeId: 5)
class Trip extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime startTime;

  @HiveField(2)
  DateTime? endTime;

  @HiveField(3)
  List<TripLocation> locations;

  @HiveField(4)
  double totalDistance;

  Trip({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.locations,
    this.totalDistance = 0.0,
  });
}

@HiveType(typeId: 6)
class TripLocation extends HiveObject {
  @HiveField(0)
  double latitude;

  @HiveField(1)
  double longitude;

  @HiveField(2)
  DateTime timestamp;

  TripLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
}
