import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/trip.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  try {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
    
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(TripAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(TripLocationAdapter());
    }
    
    if (!Hive.isBoxOpen('trips')) {
      await Hive.openBox<Trip>('trips');
    }
  } catch (e) {
    print('Background service Hive init error: $e');
  }

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
      if (!Hive.isBoxOpen('trips')) {
        timer.cancel();
        return;
      }
      
      final box = Hive.box<Trip>('trips');
      final activeTrip = box.values.where((trip) => trip.endTime == null).firstOrNull;
      
      if (activeTrip == null) {
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
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 10),
    );
    
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
    ),
  );
}
