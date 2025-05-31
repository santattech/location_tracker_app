import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'models/daily_distance.dart';
import 'models/tracked_location.dart';
import 'models/completed_place.dart';
import 'models/app_settings.dart';
import 'screens/location_tracker_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  final appDocumentDir = await path_provider.getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  
  // Register Hive adapters
  Hive.registerAdapter(DailyDistanceAdapter());
  Hive.registerAdapter(TrackedLocationAdapter());
  Hive.registerAdapter(CompletedPlaceAdapter());
  Hive.registerAdapter(AppSettingsAdapter());
  
  // Open Hive boxes
  await Hive.openBox<DailyDistance>('distances');
  await Hive.openBox<TrackedLocation>('locations');
  await Hive.openBox<CompletedPlace>('completed_places');
  await Hive.openBox<AppSettings>('settings');

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
