import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 4)
class AppSettings extends HiveObject {
  @HiveField(0)
  bool isTracking;

  @HiveField(1)
  DateTime? lastTrackingUpdate;

  AppSettings({
    this.isTracking = false,
    this.lastTrackingUpdate,
  });
} 