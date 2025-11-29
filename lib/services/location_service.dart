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
        
        // Schedule next task in 1 minute if trip is still active
        await Workmanager().registerOneOffTask(
          "location-${DateTime.now().millisecondsSinceEpoch}",
          locationTaskName,
          initialDelay: const Duration(minutes: 1),
        );
        
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
    // Start with immediate task, then chain 1-minute intervals
    await Workmanager().registerOneOffTask(
      "location-initial",
      locationTaskName,
      initialDelay: const Duration(minutes: 1),
    );
  }
  
  static Future<void> stopTracking() async {
    await Workmanager().cancelAll();
  }
}
