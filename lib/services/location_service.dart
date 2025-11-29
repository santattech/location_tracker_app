import 'package:workmanager/workmanager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/trip.dart';

const String locationTaskName = "locationTracking";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Hive.initFlutter();
      Hive.registerAdapter(TripAdapter());
      Hive.registerAdapter(TripLocationAdapter());
      await Hive.openBox<Trip>('trips');
      
      final box = Hive.box<Trip>('trips');
      final activeTrip = box.values.where((trip) => trip.endTime == null).firstOrNull;
      
      if (activeTrip != null) {
        final position = await Geolocator.getCurrentPosition();
        
        final newLocation = TripLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
        );
        
        activeTrip.locations.add(newLocation);
        
        if (activeTrip.locations.length > 1) {
          final lastLocation = activeTrip.locations[activeTrip.locations.length - 2];
          final distance = Geolocator.distanceBetween(
            lastLocation.latitude,
            lastLocation.longitude,
            position.latitude,
            position.longitude,
          );
          activeTrip.totalDistance += distance;
        }
        
        await activeTrip.save();
        return Future.value(true);
      }
    } catch (e) {
      print('Background location error: $e');
    }
    
    return Future.value(false);
  });
}

class LocationService {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }
  
  static Future<void> startTracking() async {
    await Workmanager().registerPeriodicTask(
      "location-tracking",
      locationTaskName,
      frequency: const Duration(minutes: 15), // Minimum allowed by Android
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
  }
  
  static Future<void> stopTracking() async {
    await Workmanager().cancelByUniqueName("location-tracking");
  }
}
