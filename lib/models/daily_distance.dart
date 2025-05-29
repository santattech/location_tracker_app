import 'package:hive/hive.dart';

part 'daily_distance.g.dart';

@HiveType(typeId: 0)
class DailyDistance {
  @HiveField(0)
  final String date;

  @HiveField(1)
  final double distance;

  @HiveField(2)
  final DateTime lastUpdated;

  DailyDistance({
    required this.date,
    required this.distance,
    required this.lastUpdated,
  });
} 