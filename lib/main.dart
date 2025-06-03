import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'services/background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'models/daily_distance.dart';
import 'models/tracked_location.dart';
import 'models/completed_place.dart';
import 'models/app_settings.dart';
import 'models/destination.dart';
import 'screens/location_tracker_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Geolocator.requestPermission();

  await FlutterBackgroundService().configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true, 
      autoStart: false,
      notificationChannelId: 'location_tracking',
      initialNotificationTitle: 'Location tracking',
      initialNotificationContent: 'Service is running in the background',
    ),
    iosConfiguration: IosConfiguration()
  );

  // Initialize Hive
  final appDocumentDir = await path_provider.getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  
  // Register Hive adapters
  Hive.registerAdapter(DailyDistanceAdapter());
  Hive.registerAdapter(TrackedLocationAdapter());
  Hive.registerAdapter(CompletedPlaceAdapter());
  Hive.registerAdapter(AppSettingsAdapter());
  Hive.registerAdapter(DestinationAdapter());
  
  // Open Hive boxes
  await Hive.openBox<DailyDistance>('distances');
  await Hive.openBox<TrackedLocation>('locations');
  await Hive.openBox<CompletedPlace>('completed_places');
  await Hive.openBox<AppSettings>('settings');
  await Hive.openBox<Destination>('destinationBox');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LocationTrackerScreen(),
    );
  }
}
