import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:hive/hive.dart';
import '../models/tracked_location.dart';
import 'dart:ui';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();
  
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'Location tracking',
      content: 'Service is running in the background',
    );
  }

  Timer.periodic(Duration(seconds: 60), (timer) async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      print("Location: ${position.latitude}, ${position.longitude}");

      // Create TrackedLocation instance
      final location = TrackedLocation.fromPosition(position);
      
      // Open the Hive box and store the location
      final box = await Hive.openBox<TrackedLocation>('locations');
      await box.add(location);
      
      // Update notification with current location info
      if (service is AndroidServiceInstance) {
        // I do not want to send notification every time
        // service.setForegroundNotificationInfo(
        //   title: 'Location tracking',
        //   content: 'Lat: ${position.latitude.toStringAsFixed(6)}, Long: ${position.longitude.toStringAsFixed(6)}',
        // );
      }
    } catch (e) {
      print('Error tracking location: $e');
    }
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}
