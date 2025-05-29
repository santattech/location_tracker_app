import 'package:hive/hive.dart';

part 'completed_place.g.dart';

@HiveType(typeId: 2)
class CompletedPlace {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final DateTime completedAt;

  CompletedPlace({
    required this.name,
    required this.completedAt,
  });
} 