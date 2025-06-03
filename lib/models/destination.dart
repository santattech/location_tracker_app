import 'package:hive/hive.dart';

part 'destination.g.dart';

@HiveType(typeId: 5)  // Using 4 assuming 0-3 are used by other models
class Destination {
  @HiveField(0)
  final double destLatitude;

  @HiveField(1)
  final double destLongitude;

  Destination({
    required this.destLatitude,
    required this.destLongitude,
  });
} 