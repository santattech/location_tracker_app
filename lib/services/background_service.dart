import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/trip.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  await Hive.initFlutter();
  Hive.registerAdapter(TripAdapter());
  Hive.registerAdapter(TripLocationAdapter());
  await Hive.openBox<Trip>('trips');

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    try {
      final box = Hive.box<Trip>('trips');
      final activeTrip = box.values.where((trip) => trip.endTime == null).firstOrNull;
      
      if (activeTrip == null) {
        // No active trip, stop the service
        service.stopSelf();
        timer.cancel();
        return;
      }

      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          await _updateLocation(activeTrip);
        }
      }
    } catch (e) {
      print('Service timer error: $e');
    }
  });
}

Future<void> _updateLocation(Trip activeTrip) async {
  try {
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
  } catch (e) {
    print('Background location update error: $e');
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'location_tracking',
      initialNotificationTitle: 'Location Tracking',
      initialNotificationContent: 'Tracking your trip in background',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onStart,
    ),
  );
}
